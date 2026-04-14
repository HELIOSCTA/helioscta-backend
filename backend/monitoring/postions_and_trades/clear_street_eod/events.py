"""Event shaping for the Clear Street EOD → New Relic ingest job.

Each function in this module takes raw rows pulled by ``queries.py`` and
returns a list of dicts ready to POST as NR custom events. Every event is
stamped with the base attributes from ``backend.monitoring.newrelic.base_event``
(``environment``, ``hostname``, ``source``, ``timestamp``).

Event types emitted:

  * ``PipelineRun``               — one event per row of logging.pipeline_runs
  * ``ClearStreetPipelineSummary``— one row per trade_date with file/download/MUFG
                                    timestamps (for the "Pipeline Runs Summary"
                                    table on the NR dashboard)
  * ``ClearStreetEodSummary``     — stat-panel metrics for the latest sftp_date
  * ``ClearStreetTrade``          — one event per trade row (MUFG-filtered + EOD)
  * ``ClearStreetEodFileLanded``  — emitted when today's SFTP file is detected
  * ``ClearStreetEodFileLate``    — emitted by the wall-clock check (after
                                    22:00 MT, weekday, no landed signal)

The ``ClearStreetEodFileLate`` event is the replacement for the awkward
``CASE WHEN ... time >= '22:00' ... THEN 1`` SQL in the original Grafana
``rules.yaml``. The wall-clock + weekday gating now lives in Python so the
NRQL alert condition becomes a trivial "did this event arrive?" check.
"""

from __future__ import annotations

from datetime import date, datetime, time, timezone, timedelta
from typing import Any, Iterable
from zoneinfo import ZoneInfo

from backend.monitoring.newrelic import base_event

DENVER = ZoneInfo("America/Denver")

# When the wall-clock check considers today's file "late". Mirrors the
# threshold in backend/grafana/provisioning/alerting/rules.yaml (22:00 MT).
LATE_FILE_CUTOFF = time(hour=22, minute=0)


# ──────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────


def _to_jsonable(value: Any) -> Any:
    """Convert psycopg2-returned values to NR-Event-API-friendly primitives.

    NR custom events accept str / int / float / bool. Dates, decimals, etc.
    must be converted by the caller.
    """
    if value is None:
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, datetime):
        # Always include timezone in the string form, otherwise NR can't
        # disambiguate. The numeric ``timestamp`` attribute on the parent event
        # is the authoritative event time.
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.isoformat()
    if isinstance(value, date):
        return value.isoformat()
    # Decimal and anything else: stringify; NRQL string compare still works.
    return str(value)


def _row_to_attrs(row: dict[str, Any]) -> dict[str, Any]:
    return {k: _to_jsonable(v) for k, v in row.items()}


# ──────────────────────────────────────────────────────────────────────────
# Per-query event builders
# ──────────────────────────────────────────────────────────────────────────


def build_pipeline_run_events(rows: list[dict]) -> list[dict]:
    out = []
    for row in rows:
        attrs = _row_to_attrs(row)
        out.append(base_event.make_event("PipelineRun", attrs))
    return out


def build_pipeline_summary_events(rows: list[dict]) -> list[dict]:
    out = []
    for row in rows:
        attrs = _row_to_attrs(row)
        out.append(base_event.make_event("ClearStreetPipelineSummary", attrs))
    return out


def build_eod_summary_event(
    sftp_date_value: date | None,
    titan_qty_mufg: float,
    titan_qty_all: float,
    missing_product_code_grouping: int,
) -> dict | None:
    """One stat-panel summary event per ingest run.

    Combines the four Grafana billboard panels (TITAN MUFG, TITAN ALL, match,
    missing product code) into a single ``ClearStreetEodSummary`` event so the
    NR dashboard can render them as four billboards from one ``latest(...)``
    query each.
    """
    if sftp_date_value is None:
        return None

    qty_mufg = float(titan_qty_mufg or 0)
    qty_all = float(titan_qty_all or 0)
    titan_qty_match = 1 if qty_mufg == qty_all else 0

    return base_event.make_event(
        "ClearStreetEodSummary",
        {
            "sftp_date": sftp_date_value.isoformat(),
            "titan_qty_mufg": qty_mufg,
            "titan_qty_all": qty_all,
            "titan_qty_match": titan_qty_match,
            "missing_product_code_grouping": int(missing_product_code_grouping or 0),
        },
    )


def build_trade_events(rows: list[dict], *, mufg_filtered: bool) -> list[dict]:
    """Build one ``ClearStreetTrade`` event per trade row.

    ``mufg_filtered`` is stamped on every event so the NR dashboard can FACET
    on it instead of needing two separate event types.
    """
    out = []
    for row in rows:
        attrs = _row_to_attrs(row)
        attrs["mufg_filtered"] = mufg_filtered
        out.append(base_event.make_event("ClearStreetTrade", attrs))
    return out


def build_eod_file_landed_event(rows: list[dict]) -> dict | None:
    """Emit one event when today's Clear Street SFTP file has been ingested.

    Returns ``None`` if no row with today's trade_date_from_sftp exists yet.
    The NR alert condition for ``cs-eod-file-detected`` checks for the
    presence of this event over a short window.
    """
    if not rows:
        return None
    row = rows[0]
    if not row.get("detected_rows"):
        return None

    return base_event.make_event(
        "ClearStreetEodFileLanded",
        {
            "check_date": _to_jsonable(row.get("check_date")),
            "detected_rows": int(row["detected_rows"]),
        },
    )


def build_eod_file_late_event(
    landed_event: dict | None,
    *,
    now: datetime | None = None,
) -> dict | None:
    """Emit a ``ClearStreetEodFileLate`` event when:

      * it's a weekday (Mon–Fri) in America/Denver,
      * the local time is at or after 22:00 MT, and
      * the SFTP detection query did NOT find today's file (``landed_event``
        is None).

    Replaces the wall-clock CASE expression in
    ``backend/grafana/provisioning/alerting/rules.yaml`` rule
    ``cs-eod-file-late``.
    """
    if landed_event is not None:
        return None

    now = now or datetime.now(tz=DENVER)
    if now.tzinfo is None:
        now = now.replace(tzinfo=DENVER)
    else:
        now = now.astimezone(DENVER)

    if now.weekday() > 4:  # 0=Mon ... 6=Sun
        return None
    if now.time() < LATE_FILE_CUTOFF:
        return None

    return base_event.make_event(
        "ClearStreetEodFileLate",
        {
            "check_date": now.date().isoformat(),
            "checked_at_local": now.isoformat(),
            "cutoff_local": LATE_FILE_CUTOFF.isoformat(),
        },
    )


# ──────────────────────────────────────────────────────────────────────────
# Top-level orchestration
# ──────────────────────────────────────────────────────────────────────────


def build_events(raw: dict[str, Any], *, now: datetime | None = None) -> list[dict]:
    """Combine the per-query builders into a single flat list of events.

    ``raw`` is the dict returned by ``runs._pull()``. Keys must match the
    constants in ``runs.QUERY_KEY_*``.
    """
    events: list[dict] = []

    events.extend(build_pipeline_run_events(raw.get("pipeline_runs_recent", [])))
    events.extend(build_pipeline_summary_events(raw.get("pipeline_runs_summary", [])))

    latest_rows = raw.get("latest_mufg_sftp_date", [])
    sftp_date_value = latest_rows[0].get("sftp_date") if latest_rows else None
    if isinstance(sftp_date_value, str):
        sftp_date_value = date.fromisoformat(sftp_date_value)

    titan_mufg_rows = raw.get("titan_qty_mufg", [])
    titan_all_rows = raw.get("titan_qty_all_eod", [])
    missing_rows = raw.get("missing_product_code_grouping", [])
    summary = build_eod_summary_event(
        sftp_date_value=sftp_date_value,
        titan_qty_mufg=titan_mufg_rows[0]["titan_qty_mufg"] if titan_mufg_rows else 0,
        titan_qty_all=titan_all_rows[0]["titan_qty_all"] if titan_all_rows else 0,
        missing_product_code_grouping=missing_rows[0]["missing_count"] if missing_rows else 0,
    )
    if summary is not None:
        events.append(summary)

    events.extend(
        build_trade_events(raw.get("mufg_filtered_trades_detail", []), mufg_filtered=True)
    )
    events.extend(
        build_trade_events(raw.get("all_eod_trades_detail", []), mufg_filtered=False)
    )

    landed = build_eod_file_landed_event(raw.get("eod_file_landed_today", []))
    if landed is not None:
        events.append(landed)

    late = build_eod_file_late_event(landed, now=now)
    if late is not None:
        events.append(late)

    return events


def chunked(items: Iterable[dict], max_per_request: int = 1000) -> Iterable[list[dict]]:
    """Re-export of the chunker so callers don't need to know about the NR client."""
    from backend.monitoring.newrelic.newrelic_event_api_utils import chunked as _chunked

    yield from _chunked(list(items), size=max_per_request)
