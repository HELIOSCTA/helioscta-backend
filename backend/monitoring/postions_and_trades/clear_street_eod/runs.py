"""Clear Street EOD → New Relic ingest job.

Reads the SQL queries that used to live in the Grafana ``clear-street-trades-to-mufg``
dashboard, shapes them into NR custom events, and POSTs them to the New Relic
Event API. Designed to run on the same Windows Task Scheduler VM as the
existing SFTP pull task, ~5 minutes after each pull cycle so it sees the
freshly upserted rows.

Entrypoint:

    python backend/monitoring/postions_and_trades/clear_street_eod/runs.py
    python backend/monitoring/postions_and_trades/clear_street_eod/runs.py --dry-run

Both invocation styles are supported (script-runnable absolute path for the
.ps1 to mirror ``helios_transactions_v2_2026_feb_23.ps1``, and ``python -m``
for ad-hoc testing).
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from backend.utils import (
    azure_postgresql_utils as azure_postgresql,
    logging_utils,
    pipeline_run_logger,
)
from backend.monitoring.newrelic import newrelic_event_api_utils
from backend.monitoring.postions_and_trades.clear_street_eod import events, queries

API_SCRAPE_NAME = "clear_street_eod_to_newrelic"
LOGGING_SOURCE = "monitoring"
LOGGING_PRIORITY = "medium"
LOGGING_TAGS = "clear_street,monitoring,newrelic"

logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)


# ──────────────────────────────────────────────────────────────────────────
# _pull / _format / _post / main — PJM script standard
# ──────────────────────────────────────────────────────────────────────────


def _pull() -> dict[str, list[dict]]:
    """Run every panel/alert query against helioscta and return raw rows.

    Stat-panel queries (TITAN_QTY_*, MISSING_*) need the latest sftp_date with
    MUFG-eligible trades, which we resolve in a first round-trip and then thread
    into the parameterised follow-up queries.
    """
    conn = azure_postgresql._connect_to_azure_postgressql(database="helioscta")
    try:
        with conn.cursor() as cur:
            # 1) Date-independent queries
            raw: dict[str, list[dict]] = {
                "pipeline_runs_summary": _execute(cur, queries.PIPELINE_RUNS_SUMMARY),
                "pipeline_runs_recent": _execute(cur, queries.PIPELINE_RUNS_RECENT),
                "latest_mufg_sftp_date": _execute(cur, queries.LATEST_MUFG_SFTP_DATE),
                "eod_file_landed_today": _execute(cur, queries.EOD_FILE_LANDED_TODAY),
            }

            # 2) Resolve the latest sftp_date for the date-parameterised queries
            sftp_date_value = (
                raw["latest_mufg_sftp_date"][0].get("sftp_date")
                if raw["latest_mufg_sftp_date"]
                else None
            )
            if sftp_date_value is None:
                logger.warning(
                    "No latest sftp_date found in trades_cleaned.clear_street_trades — "
                    "skipping date-parameterised queries"
                )
                for key in (
                    "titan_qty_mufg",
                    "titan_qty_all_eod",
                    "missing_product_code_grouping",
                    "mufg_filtered_trades_detail",
                    "all_eod_trades_detail",
                ):
                    raw[key] = []
                return raw

            params = {"sftp_date": sftp_date_value}
            raw["titan_qty_mufg"] = _execute(cur, queries.TITAN_QTY_MUFG, params)
            raw["titan_qty_all_eod"] = _execute(cur, queries.TITAN_QTY_ALL_EOD, params)
            raw["missing_product_code_grouping"] = _execute(
                cur, queries.MISSING_PRODUCT_CODE_GROUPING, params
            )
            raw["mufg_filtered_trades_detail"] = _execute(
                cur, queries.MUFG_FILTERED_TRADES_DETAIL, params
            )
            raw["all_eod_trades_detail"] = _execute(cur, queries.ALL_EOD_TRADES_DETAIL, params)

            return raw
    finally:
        conn.close()


def _execute(cur, sql: str, params: dict[str, Any] | None = None) -> list[dict]:
    cur.execute(sql, params or {})
    if cur.description is None:
        return []
    columns = [c.name for c in cur.description]
    return [dict(zip(columns, row)) for row in cur.fetchall()]


def _format(raw: dict[str, list[dict]], *, now: datetime | None = None) -> list[dict]:
    """Shape raw rows into NR custom events. Also runs the wall-clock late check."""
    return events.build_events(raw, now=now)


def _post(batch: list[dict], *, dry_run: bool) -> int:
    return newrelic_event_api_utils.post_events(batch, dry_run=dry_run)


def main(*, dry_run: bool = False) -> None:
    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=API_SCRAPE_NAME,
        source=LOGGING_SOURCE,
        priority=LOGGING_PRIORITY,
        tags=LOGGING_TAGS,
        log_file_path=logger.log_file_path,
    )
    run.start()
    try:
        raw = _pull()
        for key, rows in raw.items():
            logger.info("query %s → %d rows", key, len(rows))

        batch = _format(raw)
        logger.info("formatted %d events for NR", len(batch))

        sent = _post(batch, dry_run=dry_run)
        run.success(rows_processed=sent)
    except Exception as e:
        run.failure(error=e, log_file_path=logger.log_file_path)
        raise


# ──────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pull Clear Street EOD monitoring data from helioscta and POST it to New Relic.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run queries and shape events but skip the NR Event API POST. "
             "Use for local validation without a license key.",
    )
    return parser.parse_args(argv)


if __name__ == "__main__":
    args = _parse_args(sys.argv[1:])
    main(dry_run=args.dry_run)
