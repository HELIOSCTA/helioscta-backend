"""FastAPI MCP entry point for the backend-views server.

Exposes structured views over ``logging.pipeline_runs`` so Claude
agents (and humans hitting the JSON endpoints) can answer the daily
"what's running hard, what's slow, what broke, what looks misscheduled?"
question without writing SQL.

Run:

    uvicorn backend.mcp_server.main:app --reload

Each view is ``GET /views/<name>?format=md|json``. MCP transport is
mounted at ``/mcp`` via ``FastApiMCP(app).mount_http()``. The matching
agent tools surface as ``mcp__backend-views__*``.

Endpoint → source mapping:

    /views/failures_recent       → RUN_FAILURE events with error preview
    /views/runs_summary          → per-pipeline daily roll-up
    /views/runs_throughput       → "what is running hard?" volume ranking
    /views/runs_duration         → p50/p95/max duration distribution
    /views/schedule_cadence      → observed cadence + staleness flag
    /views/notifications_recent  → SLACK_SENT / EMAIL_SENT events
"""
from __future__ import annotations

import logging
from enum import Enum

import backend.settings  # noqa: F401 — load .env vars

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from fastapi_mcp import FastApiMCP

from backend.mcp_server.data import pipeline_runs as data
from backend.mcp_server.views.markdown_formatters import (
    format_failures_recent,
    format_notifications_recent,
    format_runs_duration,
    format_runs_summary,
    format_runs_throughput,
    format_schedule_cadence,
)
from backend.mcp_server.views.pipeline_runs import (
    build_failures_recent_view_model,
    build_notifications_recent_view_model,
    build_runs_duration_view_model,
    build_runs_summary_view_model,
    build_runs_throughput_view_model,
    build_schedule_cadence_view_model,
)


class OutputFormat(str, Enum):
    md = "md"
    json = "json"


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="HeliosCTA backend views",
    description=(
        "Structured views over logging.pipeline_runs for the "
        "pipeline-health workflow."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


# ─── failures_recent ─────────────────────────────────────────────────────────


@app.get("/views/failures_recent")
def get_failures_recent(
    lookback_hours: int = Query(
        24, ge=1, le=24 * 30, description="Window in hours ending now-MST"
    ),
    log_preview_lines: int = Query(
        12,
        ge=0,
        le=200,
        description="Trailing lines of log_file_content to surface per pipeline",
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """RUN_FAILURE events in the lookback window, grouped by pipeline.

    Returns per-pipeline failure_count, last error_type/message, and the
    trailing N lines of the latest log_file_content blob. Use this as
    the entry point to the pipeline-health workflow.
    """
    df = data.pull_failures_recent(lookback_hours=lookback_hours)
    vm = build_failures_recent_view_model(
        df, lookback_hours=lookback_hours, log_preview_lines=log_preview_lines,
    )
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_failures_recent(vm),
        media_type="text/markdown",
    )


# ─── runs_summary ────────────────────────────────────────────────────────────


@app.get("/views/runs_summary")
def get_runs_summary(
    lookback_hours: int = Query(
        24, ge=1, le=24 * 30, description="Window in hours ending now-MST"
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """Per-pipeline roll-up of every terminal event in the window.

    One row per pipeline: total runs, success / failure counts, last
    run timestamp + status, average / max duration, total rows and
    files processed. Sorted by failure_count desc then total_runs desc.
    """
    df = data.pull_runs_terminal(lookback_hours=lookback_hours)
    vm = build_runs_summary_view_model(df, lookback_hours=lookback_hours)
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_runs_summary(vm),
        media_type="text/markdown",
    )


# ─── runs_throughput ─────────────────────────────────────────────────────────


class ThroughputSort(str, Enum):
    runs = "runs"
    rows = "rows"
    files = "files"


@app.get("/views/runs_throughput")
def get_runs_throughput(
    lookback_hours: int = Query(
        24, ge=1, le=24 * 30, description="Window in hours ending now-MST"
    ),
    top_n: int = Query(25, ge=1, le=200, description="Top-N pipelines to return"),
    sort_by: ThroughputSort = Query(
        ThroughputSort.runs, description="runs | rows | files"
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """'What is running hard?' — per-pipeline volume in the window.

    Ranks pipelines by run count (default), rows_processed, or
    files_processed. Includes runs_per_hour so you can spot pipelines
    that are *running* hot vs. *processing* hot.
    """
    df = data.pull_runs_terminal(lookback_hours=lookback_hours)
    vm = build_runs_throughput_view_model(
        df,
        lookback_hours=lookback_hours,
        top_n=top_n,
        sort_by=sort_by.value,
    )
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_runs_throughput(vm),
        media_type="text/markdown",
    )


# ─── runs_duration ───────────────────────────────────────────────────────────


class DurationSort(str, Enum):
    p95 = "p95"
    p50 = "p50"
    max = "max"
    mean = "mean"


@app.get("/views/runs_duration")
def get_runs_duration(
    lookback_hours: int = Query(
        24, ge=1, le=24 * 30, description="Window in hours ending now-MST"
    ),
    top_n: int = Query(25, ge=1, le=200, description="Top-N pipelines to return"),
    min_runs: int = Query(
        1,
        ge=1,
        le=100,
        description="Drop pipelines with fewer finished runs than this",
    ),
    sort_by: DurationSort = Query(
        DurationSort.p95, description="p95 | p50 | max | mean"
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """'How long are runs taking?' — per-pipeline duration distribution.

    p50 / p95 / max / mean over terminal events with non-zero duration.
    Sorted by the chosen statistic so you can pinpoint the heavy or
    long-tail pipelines.
    """
    df = data.pull_runs_terminal(lookback_hours=lookback_hours)
    vm = build_runs_duration_view_model(
        df,
        lookback_hours=lookback_hours,
        top_n=top_n,
        min_runs=min_runs,
        sort_by=sort_by.value,
    )
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_runs_duration(vm),
        media_type="text/markdown",
    )


# ─── schedule_cadence ────────────────────────────────────────────────────────


@app.get("/views/schedule_cadence")
def get_schedule_cadence(
    lookback_days: int = Query(
        14, ge=1, le=180, description="Days of RUN_SUCCESS history to consider"
    ),
    stale_multiplier: float = Query(
        2.0,
        ge=1.0,
        le=20.0,
        description="last_run_age > multiplier * median_gap → stale",
    ),
    min_runs_for_cadence: int = Query(
        3,
        ge=2,
        le=50,
        description="Skip cadence inference until at least this many successes",
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """Observed cadence + staleness flag per pipeline.

    Estimates the natural inter-run gap from successful runs and flags
    pipelines whose last successful run is older than
    ``stale_multiplier × median_gap``. Use this to find pipelines that
    *should* have run by now and haven't — silent failures the
    failures_recent view will never surface.
    """
    df = data.pull_runs_for_cadence(lookback_days=lookback_days)
    vm = build_schedule_cadence_view_model(
        df,
        lookback_days=lookback_days,
        stale_multiplier=stale_multiplier,
        min_runs_for_cadence=min_runs_for_cadence,
    )
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_schedule_cadence(vm),
        media_type="text/markdown",
    )


# ─── notifications_recent ────────────────────────────────────────────────────


@app.get("/views/notifications_recent")
def get_notifications_recent(
    lookback_hours: int = Query(
        24, ge=1, le=24 * 30, description="Window in hours ending now-MST"
    ),
    format: OutputFormat = Query(OutputFormat.md, description="md or json"),
):
    """SLACK_SENT + EMAIL_SENT events in the window.

    Cross-reference with failures_recent to find pipelines that fail
    but never page — silent failures are worse than loud ones.
    """
    df = data.pull_notifications_recent(lookback_hours=lookback_hours)
    vm = build_notifications_recent_view_model(df, lookback_hours=lookback_hours)
    if format == OutputFormat.json:
        return vm
    return PlainTextResponse(
        content=format_notifications_recent(vm),
        media_type="text/markdown",
    )


# ─── MCP integration — exposes all endpoints as agent tools ──────────────────
mcp = FastApiMCP(app)
mcp.mount_http()
