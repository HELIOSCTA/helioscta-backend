"""View-model builders for the pipeline-runs MCP endpoints.

Each builder consumes one or more DataFrames from
``backend.mcp_server.data.pipeline_runs`` and returns a dict that the
markdown formatter (or `format=json` consumer) can render. Filter
choices live in the data layer; this layer aggregates, ranks, and
labels.

Builder → endpoint mapping (see backend/mcp_server/main.py):

    failures_recent       → build_failures_recent_view_model
    runs_summary          → build_runs_summary_view_model
    runs_throughput       → build_runs_throughput_view_model
    runs_duration         → build_runs_duration_view_model
    schedule_cadence      → build_schedule_cadence_view_model
    notifications_recent  → build_notifications_recent_view_model
"""
from __future__ import annotations

from datetime import timedelta
from typing import Any

import numpy as np
import pandas as pd

from backend.utils.file_utils import get_mst_timestamp


def _now_mst() -> pd.Timestamp:
    """Naive-MST 'now' that matches the column timestamps."""
    return pd.Timestamp(get_mst_timestamp().replace(tzinfo=None))


def _truncate(text: str | None, n: int = 240) -> str:
    if text is None:
        return ""
    s = str(text)
    return s if len(s) <= n else s[: n - 1].rstrip() + "…"


def _last_lines(text: str | None, n: int = 12) -> str:
    """Return the last ``n`` non-empty lines of a log blob, trimmed."""
    if not text:
        return ""
    lines = [ln.rstrip() for ln in str(text).splitlines() if ln.strip()]
    return "\n".join(lines[-n:])


# ─── failures_recent ─────────────────────────────────────────────────────────


def build_failures_recent_view_model(
    df: pd.DataFrame,
    lookback_hours: int,
    log_preview_lines: int = 12,
) -> dict[str, Any]:
    """One row per RUN_FAILURE event in the window, grouped by pipeline.

    Top-level fields:
      - ``window_hours`` / ``as_of_mst`` / ``total_failures``
      - ``by_pipeline``: list of {pipeline_name, failure_count,
        last_error_type, last_error_message, last_event_timestamp,
        last_target_table, latest_log_tail, failures: [...]} sorted by
        failure_count desc then last_event_timestamp desc.
    """
    as_of = _now_mst()
    base = {
        "window_hours": lookback_hours,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "total_failures": 0,
        "by_pipeline": [],
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])
    base["total_failures"] = int(len(df))

    by_pipeline: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        grp_sorted = grp.sort_values("event_timestamp", ascending=False)
        latest = grp_sorted.iloc[0]
        failures = [
            {
                "run_id": row["run_id"],
                "event_timestamp": pd.Timestamp(row["event_timestamp"]).isoformat(
                    timespec="seconds"
                ),
                "duration_seconds": (
                    float(row["duration_seconds"])
                    if pd.notna(row.get("duration_seconds"))
                    else None
                ),
                "error_type": row.get("error_type") or "",
                "error_message": _truncate(row.get("error_message"), 300),
                "target_table": row.get("target_table") or "",
                "operation_type": row.get("operation_type") or "",
                "source": row.get("source") or "",
                "hostname": row.get("hostname") or "",
            }
            for _, row in grp_sorted.iterrows()
        ]
        by_pipeline.append(
            {
                "pipeline_name": pipeline,
                "failure_count": int(len(grp_sorted)),
                "last_event_timestamp": pd.Timestamp(
                    latest["event_timestamp"]
                ).isoformat(timespec="seconds"),
                "last_error_type": latest.get("error_type") or "",
                "last_error_message": _truncate(latest.get("error_message"), 300),
                "last_target_table": latest.get("target_table") or "",
                "latest_log_tail": _last_lines(
                    latest.get("log_file_content"), n=log_preview_lines
                ),
                "failures": failures,
            }
        )

    by_pipeline.sort(
        key=lambda r: (-r["failure_count"], r["last_event_timestamp"]),
        reverse=False,
    )
    # primary sort desc by failure_count, then most-recent-first
    by_pipeline.sort(
        key=lambda r: (r["failure_count"], r["last_event_timestamp"]),
        reverse=True,
    )
    base["by_pipeline"] = by_pipeline
    return base


# ─── runs_summary ────────────────────────────────────────────────────────────


def build_runs_summary_view_model(
    df: pd.DataFrame,
    lookback_hours: int,
) -> dict[str, Any]:
    """Per-pipeline roll-up of every terminal event in the window.

    Columns per row: pipeline_name, success_count, failure_count,
    total_runs, last_run_timestamp, last_status, avg_duration_seconds,
    total_rows_processed, total_files_processed. Sorted by failure_count
    desc then total_runs desc.
    """
    as_of = _now_mst()
    base = {
        "window_hours": lookback_hours,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "total_pipelines": 0,
        "total_runs": 0,
        "total_failures": 0,
        "pipelines": [],
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])
    df["duration_seconds"] = pd.to_numeric(df["duration_seconds"], errors="coerce")
    df["rows_processed"] = pd.to_numeric(df["rows_processed"], errors="coerce").fillna(0)
    df["files_processed"] = pd.to_numeric(
        df["files_processed"], errors="coerce"
    ).fillna(0)

    rows: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        grp_sorted = grp.sort_values("event_timestamp", ascending=False)
        latest = grp_sorted.iloc[0]
        success_mask = grp_sorted["event_type"] == "RUN_SUCCESS"
        rows.append(
            {
                "pipeline_name": pipeline,
                "total_runs": int(len(grp_sorted)),
                "success_count": int(success_mask.sum()),
                "failure_count": int((~success_mask).sum()),
                "last_run_timestamp": pd.Timestamp(
                    latest["event_timestamp"]
                ).isoformat(timespec="seconds"),
                "last_status": latest.get("status") or "",
                "last_event_type": latest.get("event_type") or "",
                "avg_duration_seconds": (
                    float(grp_sorted["duration_seconds"].mean())
                    if grp_sorted["duration_seconds"].notna().any()
                    else None
                ),
                "max_duration_seconds": (
                    float(grp_sorted["duration_seconds"].max())
                    if grp_sorted["duration_seconds"].notna().any()
                    else None
                ),
                "total_rows_processed": int(grp_sorted["rows_processed"].sum()),
                "total_files_processed": int(grp_sorted["files_processed"].sum()),
                "source": latest.get("source") or "",
            }
        )

    rows.sort(
        key=lambda r: (r["failure_count"], r["total_runs"]),
        reverse=True,
    )
    base["pipelines"] = rows
    base["total_pipelines"] = len(rows)
    base["total_runs"] = int(sum(r["total_runs"] for r in rows))
    base["total_failures"] = int(sum(r["failure_count"] for r in rows))
    return base


# ─── runs_throughput ─────────────────────────────────────────────────────────


def build_runs_throughput_view_model(
    df: pd.DataFrame,
    lookback_hours: int,
    top_n: int = 25,
    sort_by: str = "runs",
) -> dict[str, Any]:
    """'What is running hard?' — per-pipeline volume in the window.

    sort_by ∈ {runs, rows, files}. Returns the top_n pipelines sorted
    by that field. Each row carries runs_per_hour for cadence-feel.
    """
    valid_sorts = {"runs", "rows", "files"}
    sort_by = sort_by if sort_by in valid_sorts else "runs"

    as_of = _now_mst()
    base = {
        "window_hours": lookback_hours,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "sort_by": sort_by,
        "top_n": top_n,
        "pipelines": [],
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["rows_processed"] = pd.to_numeric(df["rows_processed"], errors="coerce").fillna(0)
    df["files_processed"] = pd.to_numeric(
        df["files_processed"], errors="coerce"
    ).fillna(0)

    rows: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        runs = int(len(grp))
        rows.append(
            {
                "pipeline_name": pipeline,
                "runs": runs,
                "successes": int((grp["event_type"] == "RUN_SUCCESS").sum()),
                "failures": int((grp["event_type"] == "RUN_FAILURE").sum()),
                "rows_processed": int(grp["rows_processed"].sum()),
                "files_processed": int(grp["files_processed"].sum()),
                "runs_per_hour": (
                    round(runs / lookback_hours, 2) if lookback_hours else None
                ),
                "source": (grp["source"].dropna().iloc[0] if grp["source"].notna().any() else ""),
            }
        )

    key_map = {"runs": "runs", "rows": "rows_processed", "files": "files_processed"}
    rows.sort(key=lambda r: r[key_map[sort_by]], reverse=True)
    base["pipelines"] = rows[:top_n]
    return base


# ─── runs_duration ───────────────────────────────────────────────────────────


def build_runs_duration_view_model(
    df: pd.DataFrame,
    lookback_hours: int,
    top_n: int = 25,
    sort_by: str = "p95",
    min_runs: int = 1,
) -> dict[str, Any]:
    """'How long are runs taking?' — per-pipeline duration distribution.

    Per row: count, p50, p95, max, mean of duration_seconds + slowest
    run's run_id/timestamp. sort_by ∈ {p95, p50, max, mean}. Pipelines
    with fewer than ``min_runs`` finished runs in the window are dropped
    — percentiles on n=1 are noise.
    """
    valid_sorts = {"p95", "p50", "max", "mean"}
    sort_by = sort_by if sort_by in valid_sorts else "p95"

    as_of = _now_mst()
    base = {
        "window_hours": lookback_hours,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "sort_by": sort_by,
        "min_runs": min_runs,
        "top_n": top_n,
        "pipelines": [],
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])
    df["duration_seconds"] = pd.to_numeric(df["duration_seconds"], errors="coerce")
    df = df[df["duration_seconds"].notna() & (df["duration_seconds"] > 0)]
    if df.empty:
        return base

    rows: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        if len(grp) < min_runs:
            continue
        durations = grp["duration_seconds"].to_numpy()
        slowest = grp.sort_values("duration_seconds", ascending=False).iloc[0]
        rows.append(
            {
                "pipeline_name": pipeline,
                "run_count": int(len(grp)),
                "p50": float(np.percentile(durations, 50)),
                "p95": float(np.percentile(durations, 95)),
                "max": float(np.max(durations)),
                "mean": float(np.mean(durations)),
                "slowest_run_id": slowest["run_id"],
                "slowest_at": pd.Timestamp(slowest["event_timestamp"]).isoformat(
                    timespec="seconds"
                ),
                "slowest_status": slowest.get("status") or "",
            }
        )

    rows.sort(key=lambda r: r[sort_by], reverse=True)
    base["pipelines"] = rows[:top_n]
    return base


# ─── schedule_cadence ────────────────────────────────────────────────────────


def _cadence_bucket(median_hours: float) -> str:
    if median_hours is None or np.isnan(median_hours):
        return "unknown"
    if median_hours <= 1.5:
        return "hourly"
    if median_hours <= 8:
        return "intra-day"
    if median_hours <= 30:
        return "daily"
    if median_hours <= 24 * 8:
        return "weekly"
    return "ad-hoc"


def build_schedule_cadence_view_model(
    df: pd.DataFrame,
    lookback_days: int,
    stale_multiplier: float = 2.0,
    min_runs_for_cadence: int = 3,
) -> dict[str, Any]:
    """Per-pipeline observed cadence + staleness flag.

    Uses RUN_SUCCESS timestamps over the lookback. For each pipeline:
      - median_gap_hours = median of consecutive-run gaps
      - last_run_age_hours
      - bucket = hourly / intra-day / daily / weekly / ad-hoc / unknown
      - stale = last_run_age_hours > stale_multiplier * median_gap_hours
        (only when run_count >= min_runs_for_cadence; otherwise False
        with reason='insufficient_history')

    Sorted with stale pipelines first, then by last_run_age_hours desc.
    """
    as_of = _now_mst()
    base = {
        "lookback_days": lookback_days,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "stale_multiplier": stale_multiplier,
        "min_runs_for_cadence": min_runs_for_cadence,
        "pipelines": [],
        "stale_count": 0,
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])

    rows: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        grp_sorted = grp.sort_values("event_timestamp")
        timestamps = grp_sorted["event_timestamp"].to_list()
        run_count = len(timestamps)
        last_run = pd.Timestamp(timestamps[-1])
        last_run_age = (as_of - last_run).total_seconds() / 3600.0

        if run_count >= 2:
            gaps_hours = np.diff(
                np.array([t.timestamp() for t in timestamps]),
            ) / 3600.0
            median_gap = float(np.median(gaps_hours))
            min_gap = float(np.min(gaps_hours))
            max_gap = float(np.max(gaps_hours))
        else:
            median_gap = None
            min_gap = None
            max_gap = None

        if run_count >= min_runs_for_cadence and median_gap and median_gap > 0:
            stale = last_run_age > stale_multiplier * median_gap
            reason = (
                f"last run was {last_run_age:.1f}h ago vs median gap {median_gap:.1f}h"
                if stale
                else ""
            )
        else:
            stale = False
            reason = "insufficient_history" if run_count < min_runs_for_cadence else ""

        rows.append(
            {
                "pipeline_name": pipeline,
                "run_count": int(run_count),
                "last_run_timestamp": last_run.isoformat(timespec="seconds"),
                "last_run_age_hours": round(last_run_age, 2),
                "median_gap_hours": (
                    round(median_gap, 2) if median_gap is not None else None
                ),
                "min_gap_hours": (
                    round(min_gap, 2) if min_gap is not None else None
                ),
                "max_gap_hours": (
                    round(max_gap, 2) if max_gap is not None else None
                ),
                "bucket": _cadence_bucket(median_gap if median_gap else float("nan")),
                "stale": bool(stale),
                "stale_reason": reason,
                "source": (
                    grp["source"].dropna().iloc[0]
                    if grp["source"].notna().any()
                    else ""
                ),
            }
        )

    rows.sort(key=lambda r: (not r["stale"], -r["last_run_age_hours"]))
    base["pipelines"] = rows
    base["stale_count"] = sum(1 for r in rows if r["stale"])
    return base


# ─── notifications_recent ────────────────────────────────────────────────────


def build_notifications_recent_view_model(
    df: pd.DataFrame,
    lookback_hours: int,
) -> dict[str, Any]:
    """SLACK_SENT + EMAIL_SENT events, grouped by pipeline.

    Each pipeline carries channel counts so you can spot a failure
    storm vs an alert storm — and pipelines that fail but never page.
    """
    as_of = _now_mst()
    base = {
        "window_hours": lookback_hours,
        "as_of_mst": as_of.isoformat(timespec="seconds"),
        "total_notifications": 0,
        "by_pipeline": [],
        "events": [],
    }
    if df is None or df.empty:
        return base

    df = df.copy()
    df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])
    base["total_notifications"] = int(len(df))

    by_pipeline: list[dict[str, Any]] = []
    for pipeline, grp in df.groupby("pipeline_name", sort=False):
        grp_sorted = grp.sort_values("event_timestamp", ascending=False)
        latest = grp_sorted.iloc[0]
        by_pipeline.append(
            {
                "pipeline_name": pipeline,
                "total": int(len(grp_sorted)),
                "slack_count": int((grp_sorted["event_type"] == "SLACK_SENT").sum()),
                "email_count": int((grp_sorted["event_type"] == "EMAIL_SENT").sum()),
                "last_event_timestamp": pd.Timestamp(
                    latest["event_timestamp"]
                ).isoformat(timespec="seconds"),
                "last_channel": latest.get("notification_channel") or "",
                "last_recipient": latest.get("notification_recipient") or "",
            }
        )
    by_pipeline.sort(key=lambda r: r["total"], reverse=True)
    base["by_pipeline"] = by_pipeline

    base["events"] = [
        {
            "pipeline_name": row["pipeline_name"],
            "event_type": row["event_type"],
            "event_timestamp": pd.Timestamp(row["event_timestamp"]).isoformat(
                timespec="seconds"
            ),
            "channel": row.get("notification_channel") or "",
            "recipient": row.get("notification_recipient") or "",
        }
        for _, row in df.sort_values("event_timestamp", ascending=False).iterrows()
    ]
    return base
