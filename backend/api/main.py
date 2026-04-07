"""Pipeline monitoring API — run with: uvicorn backend.api.main:app --reload

Exposes pipeline health and failure data as MCP tools for agent consumption.
"""

import logging
from enum import Enum

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from fastapi_mcp import FastApiMCP

from backend.api import configs, formatters, queries

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class OutputFormat(str, Enum):
    md = "md"
    json = "json"


app = FastAPI(
    title="HeliosCTA Pipeline Monitor",
    description="Pipeline health monitoring — exposes scrape run status by domain as MCP tools.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


# ── Health classification (from gas_ebbs/monitor.py) ─────────────────

def _classify(successes: int, failures: int) -> str:
    if failures > 0 and successes == 0:
        return "DEAD"
    if failures > successes:
        return "DEGRADED"
    if failures > 0:
        return "FLAKY"
    return "HEALTHY"


# ── Routes ───────────────────────────────────────────────────────────

@app.get("/health")
def health():
    """Server liveness check."""
    return {"status": "ok"}


@app.get("/pipelines/summary")
def get_summary(
    hours: int = Query(configs.DEFAULT_LOOKBACK_HOURS, description="Lookback window in hours"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """All-domain health rollup: healthy/flaky/degraded/dead counts per source."""
    df = queries.summary_by_domain(hours)
    detail_df = queries.domain_detail_all(hours) if not df.empty else df

    domains = []
    for _, row in df.iterrows():
        # Count per-pipeline health within this domain
        domain_pipelines = detail_df[detail_df["source"] == row["source"]] if "source" in detail_df.columns else detail_df[detail_df.index < 0]
        counts = {"HEALTHY": 0, "FLAKY": 0, "DEGRADED": 0, "DEAD": 0}
        for _, p in domain_pipelines.iterrows():
            status = _classify(int(p.get("successes", 0)), int(p.get("failures", 0)))
            counts[status] += 1

        domains.append({
            "source": row["source"],
            "total_pipelines": int(row["total_pipelines"]),
            "healthy": counts["HEALTHY"],
            "flaky": counts["FLAKY"],
            "degraded": counts["DEGRADED"],
            "dead": counts["DEAD"],
            "total_successes": int(row["total_successes"]),
            "total_failures": int(row["total_failures"]),
            "last_success": row.get("last_success"),
            "last_failure": row.get("last_failure"),
        })

    if format == OutputFormat.json:
        return domains
    return PlainTextResponse(formatters.format_summary(domains, hours), media_type="text/markdown")


@app.get("/pipelines/domain/{source}")
def get_domain_detail(
    source: str,
    hours: int = Query(configs.DEFAULT_LOOKBACK_HOURS, description="Lookback window in hours"),
    status_filter: str | None = Query(None, description="Comma-separated status filter: dead,degraded,flaky,healthy"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """Per-pipeline health within a single domain."""
    df = queries.domain_detail(source, hours)

    pipelines = []
    for _, row in df.iterrows():
        s = int(row.get("successes", 0))
        f = int(row.get("failures", 0))
        status = _classify(s, f)
        pipelines.append({
            "pipeline_name": row["pipeline_name"],
            "status": status,
            "successes": s,
            "failures": f,
            "avg_duration_s": row.get("avg_duration_s"),
            "last_success": row.get("last_success"),
            "last_failure": row.get("last_failure"),
        })

    if status_filter:
        allowed = {s.strip().upper() for s in status_filter.split(",")}
        pipelines = [p for p in pipelines if p["status"] in allowed]

    if format == OutputFormat.json:
        return pipelines
    return PlainTextResponse(formatters.format_domain_detail(pipelines, source, hours), media_type="text/markdown")


@app.get("/pipelines/failures")
def get_failures(
    hours: int = Query(configs.DEFAULT_LOOKBACK_HOURS, description="Lookback window in hours"),
    source: str | None = Query(None, description="Filter by source domain"),
    limit: int = Query(configs.DEFAULT_FAILURE_LIMIT, description="Max failures to return"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """Recent failure events across all domains."""
    df = queries.recent_failures(hours, source, limit)
    failures = df.to_dict(orient="records")

    if format == OutputFormat.json:
        return failures
    return PlainTextResponse(formatters.format_failures(failures, hours), media_type="text/markdown")


@app.get("/pipelines/{pipeline_name}/history")
def get_pipeline_history(
    pipeline_name: str,
    hours: int = Query(72, description="Lookback window in hours"),
    limit: int = Query(configs.DEFAULT_HISTORY_LIMIT, description="Max runs to return"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """Run-by-run detail for a single pipeline."""
    df = queries.pipeline_history(pipeline_name, hours, limit)
    runs = df.to_dict(orient="records")

    if format == OutputFormat.json:
        return runs
    return PlainTextResponse(formatters.format_pipeline_history(runs, pipeline_name, hours), media_type="text/markdown")


@app.get("/pipelines/scheduling")
def get_scheduling(
    hours: int = Query(configs.DEFAULT_SCHEDULING_LOOKBACK_HOURS, description="Lookback window in hours"),
    source: str | None = Query(None, description="Filter by source domain"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """Scheduling analysis: run frequency, duration, success rate per pipeline."""
    df = queries.scheduling_analysis(hours, source)
    pipelines = df.to_dict(orient="records")

    if format == OutputFormat.json:
        return pipelines
    return PlainTextResponse(formatters.format_scheduling(pipelines, hours), media_type="text/markdown")


@app.get("/pipelines/stale")
def get_stale(
    stale_hours: int = Query(configs.DEFAULT_STALE_HOURS, description="Hours since last success to consider stale"),
    format: OutputFormat = Query(OutputFormat.md, description="Response format: md or json"),
):
    """Pipelines whose last successful run is older than the threshold."""
    df = queries.stale_pipelines(stale_hours)
    pipelines = df.to_dict(orient="records")

    if format == OutputFormat.json:
        return pipelines
    return PlainTextResponse(formatters.format_stale(pipelines, stale_hours), media_type="text/markdown")


# ── MCP integration — exposes all endpoints as agent tools ───────────
mcp = FastApiMCP(app)
mcp.mount_http()
