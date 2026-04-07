"""Markdown table formatters for pipeline monitoring endpoints."""

from __future__ import annotations

from datetime import datetime, timezone


def _ago(ts) -> str:
    """Format a timestamp as a human-readable 'X ago' string."""
    if ts is None or str(ts) == "NaT":
        return "-"
    if hasattr(ts, "to_pydatetime"):
        ts = ts.to_pydatetime()
    if isinstance(ts, str):
        ts = datetime.fromisoformat(ts)
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=timezone.utc)
    delta = datetime.now(timezone.utc) - ts
    total_seconds = int(delta.total_seconds())
    if total_seconds < 60:
        return f"{total_seconds}s ago"
    if total_seconds < 3600:
        return f"{total_seconds // 60}m ago"
    if total_seconds < 86400:
        return f"{total_seconds // 3600}h ago"
    return f"{total_seconds // 86400}d ago"


def _status_icon(status: str) -> str:
    if status == "DEAD":
        return "DEAD"
    if status == "DEGRADED":
        return "DEGRADED"
    if status == "FLAKY":
        return "FLAKY"
    return "HEALTHY"


def format_summary(domains: list[dict], hours: int) -> str:
    """Format the all-domain summary."""
    md = f"# Pipeline Health Summary (last {hours}h)\n\n"
    md += "| Domain | Pipelines | Healthy | Flaky | Degraded | Dead | Last Failure |\n"
    md += "|--------|-----------|---------|-------|----------|------|--------------|\n"
    for d in domains:
        md += (
            f"| {d['source']} | {d['total_pipelines']} | "
            f"{d['healthy']} | {d['flaky']} | {d['degraded']} | {d['dead']} | "
            f"{_ago(d.get('last_failure'))} |\n"
        )
    return md


def format_domain_detail(pipelines: list[dict], source: str, hours: int) -> str:
    """Format the per-pipeline domain drill-down."""
    md = f"# {source} Pipeline Health (last {hours}h)\n\n"
    md += "| Pipeline | Status | OK | Fail | Avg Duration | Last Success | Last Failure |\n"
    md += "|----------|--------|----|------|-------------|-------------|-------------|\n"
    for p in pipelines:
        dur = f"{p['avg_duration_s']}s" if p.get("avg_duration_s") else "-"
        md += (
            f"| {p['pipeline_name']} | {_status_icon(p['status'])} | "
            f"{p['successes']} | {p['failures']} | {dur} | "
            f"{_ago(p.get('last_success'))} | {_ago(p.get('last_failure'))} |\n"
        )
    return md


def format_failures(failures: list[dict], hours: int) -> str:
    """Format recent failure events."""
    md = f"# Recent Failures (last {hours}h)\n\n"
    if not failures:
        md += "No failures found.\n"
        return md
    md += "| Pipeline | Domain | Error Type | When | Duration | Message |\n"
    md += "|----------|--------|-----------|------|----------|--------|\n"
    for f in failures:
        msg = str(f.get("error_message", ""))[:80]
        dur = f"{f.get('duration_seconds', 0):.1f}s" if f.get("duration_seconds") else "-"
        md += (
            f"| {f['pipeline_name']} | {f['source']} | "
            f"{f.get('error_type', '-')} | {_ago(f.get('event_timestamp'))} | "
            f"{dur} | {msg} |\n"
        )
    return md


def format_pipeline_history(runs: list[dict], pipeline_name: str, hours: int) -> str:
    """Format run-by-run history for a single pipeline."""
    md = f"# {pipeline_name} — Run History (last {hours}h)\n\n"
    if not runs:
        md += "No runs found.\n"
        return md
    md += "| Status | When | Duration | Rows | Error |\n"
    md += "|--------|------|----------|------|-------|\n"
    for r in runs:
        dur = f"{r.get('duration_seconds', 0):.1f}s" if r.get("duration_seconds") else "-"
        rows = str(r.get("rows_processed", "")) or "-"
        err = str(r.get("error_type", "")) or "-"
        md += (
            f"| {r['status']} | {_ago(r.get('event_timestamp'))} | "
            f"{dur} | {rows} | {err} |\n"
        )
    return md


def format_scheduling(pipelines: list[dict], hours: int) -> str:
    """Format scheduling analysis."""
    md = f"# Scheduling Analysis (last {hours}h)\n\n"
    if not pipelines:
        md += "No data.\n"
        return md
    md += "| Pipeline | Domain | Runs | Success% | Avg Dur | Avg Freq (h) | Typical Hour |\n"
    md += "|----------|--------|------|----------|---------|-------------|-------------|\n"
    for p in pipelines:
        freq = f"{p['avg_hours_between_runs']}h" if p.get("avg_hours_between_runs") else "-"
        hour = f"HE{int(p['typical_run_hour'])}" if p.get("typical_run_hour") is not None else "-"
        md += (
            f"| {p['pipeline_name']} | {p['source']} | "
            f"{p['run_count']} | {p.get('success_rate_pct', 0)}% | "
            f"{p.get('avg_duration_s', '-')}s | {freq} | {hour} |\n"
        )
    return md


def format_stale(pipelines: list[dict], stale_hours: int) -> str:
    """Format stale pipelines report."""
    md = f"# Stale Pipelines (no success in {stale_hours}h+)\n\n"
    if not pipelines:
        md += "All pipelines have recent successful runs.\n"
        return md
    md += "| Pipeline | Domain | Last Success | Hours Since |\n"
    md += "|----------|--------|-------------|------------|\n"
    for p in pipelines:
        md += (
            f"| {p['pipeline_name']} | {p['source']} | "
            f"{_ago(p.get('last_success'))} | {p.get('hours_since_success', '-')} |\n"
        )
    return md
