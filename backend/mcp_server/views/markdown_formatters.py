"""Markdown renderers for the pipeline-runs MCP view models.

One ``format_<endpoint>`` per builder. ASCII-only; the Windows console
(cp1252) chokes on Unicode box-drawing without PYTHONIOENCODING=utf-8.
"""
from __future__ import annotations

from typing import Any


def _fmt_int(n: Any) -> str:
    if n is None or n == "":
        return "-"
    try:
        return f"{int(n):,}"
    except (TypeError, ValueError):
        return str(n)


def _fmt_float(n: Any, ndigits: int = 2) -> str:
    if n is None or n == "":
        return "-"
    try:
        return f"{float(n):,.{ndigits}f}"
    except (TypeError, ValueError):
        return str(n)


def _fmt_dur(seconds: Any) -> str:
    if seconds is None or seconds == "":
        return "-"
    try:
        s = float(seconds)
    except (TypeError, ValueError):
        return str(seconds)
    if s < 1:
        return f"{s*1000:.0f}ms"
    if s < 60:
        return f"{s:.1f}s"
    if s < 3600:
        return f"{s/60:.1f}m"
    return f"{s/3600:.2f}h"


def _trim_cell(text: str, n: int) -> str:
    s = (text or "").replace("|", "\\|").replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"


# ─── failures_recent ─────────────────────────────────────────────────────────


def format_failures_recent(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Pipeline failures — last {vm['window_hours']}h "
        f"(as of {vm['as_of_mst']} MST)"
    )
    if not vm["by_pipeline"]:
        lines.append("")
        lines.append("No RUN_FAILURE events in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append(f"Total failures: **{vm['total_failures']}** "
                 f"across **{len(vm['by_pipeline'])}** pipeline(s).")
    lines.append("")
    lines.append("| Pipeline | Fails | Last @ | Error type | Last error |")
    lines.append("|---|---:|---|---|---|")
    for p in vm["by_pipeline"]:
        lines.append(
            "| {name} | {n} | {ts} | {etype} | {emsg} |".format(
                name=_trim_cell(p["pipeline_name"], 40),
                n=p["failure_count"],
                ts=p["last_event_timestamp"],
                etype=_trim_cell(p["last_error_type"], 30),
                emsg=_trim_cell(p["last_error_message"], 80),
            )
        )

    for p in vm["by_pipeline"]:
        lines.append("")
        lines.append(f"#### {p['pipeline_name']} — {p['failure_count']} failure(s)")
        if p["last_target_table"]:
            lines.append(f"- target: `{p['last_target_table']}`")
        lines.append(f"- last error: **{p['last_error_type']}** — "
                     f"{_trim_cell(p['last_error_message'], 240)}")
        if p["latest_log_tail"]:
            lines.append("- latest log tail:")
            lines.append("```")
            lines.append(p["latest_log_tail"])
            lines.append("```")
    return "\n".join(lines)


# ─── runs_summary ────────────────────────────────────────────────────────────


def format_runs_summary(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Pipeline runs summary — last {vm['window_hours']}h "
        f"(as of {vm['as_of_mst']} MST)"
    )
    lines.append("")
    lines.append(
        f"Pipelines: **{vm['total_pipelines']}** | "
        f"Runs: **{vm['total_runs']}** | "
        f"Failures: **{vm['total_failures']}**"
    )
    if not vm["pipelines"]:
        lines.append("")
        lines.append("No runs in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append(
        "| Pipeline | Runs | Ok | Fail | Last @ | Last | Avg dur | Max dur | Rows |"
    )
    lines.append("|---|---:|---:|---:|---|---|---|---|---:|")
    for r in vm["pipelines"]:
        lines.append(
            "| {name} | {runs} | {ok} | {fail} | {ts} | {last} "
            "| {avg} | {mx} | {rows} |".format(
                name=_trim_cell(r["pipeline_name"], 40),
                runs=r["total_runs"],
                ok=r["success_count"],
                fail=r["failure_count"],
                ts=r["last_run_timestamp"],
                last=r["last_event_type"],
                avg=_fmt_dur(r["avg_duration_seconds"]),
                mx=_fmt_dur(r["max_duration_seconds"]),
                rows=_fmt_int(r["total_rows_processed"]),
            )
        )
    return "\n".join(lines)


# ─── runs_throughput ─────────────────────────────────────────────────────────


def format_runs_throughput(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Pipeline throughput — last {vm['window_hours']}h "
        f"(sort: {vm['sort_by']}, top {vm['top_n']})"
    )
    if not vm["pipelines"]:
        lines.append("")
        lines.append("No runs in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append("| Pipeline | Runs | Ok | Fail | runs/hr | Rows | Files |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|")
    for r in vm["pipelines"]:
        lines.append(
            "| {name} | {runs} | {ok} | {fail} | {rph} | {rows} | {files} |".format(
                name=_trim_cell(r["pipeline_name"], 40),
                runs=r["runs"],
                ok=r["successes"],
                fail=r["failures"],
                rph=_fmt_float(r["runs_per_hour"]),
                rows=_fmt_int(r["rows_processed"]),
                files=_fmt_int(r["files_processed"]),
            )
        )
    return "\n".join(lines)


# ─── runs_duration ───────────────────────────────────────────────────────────


def format_runs_duration(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Pipeline duration distribution — last {vm['window_hours']}h "
        f"(sort: {vm['sort_by']}, min runs: {vm['min_runs']})"
    )
    if not vm["pipelines"]:
        lines.append("")
        lines.append("No runs with non-zero duration in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append("| Pipeline | Runs | p50 | p95 | max | mean | Slowest @ |")
    lines.append("|---|---:|---|---|---|---|---|")
    for r in vm["pipelines"]:
        lines.append(
            "| {name} | {n} | {p50} | {p95} | {mx} | {mean} | {ts} |".format(
                name=_trim_cell(r["pipeline_name"], 40),
                n=r["run_count"],
                p50=_fmt_dur(r["p50"]),
                p95=_fmt_dur(r["p95"]),
                mx=_fmt_dur(r["max"]),
                mean=_fmt_dur(r["mean"]),
                ts=r["slowest_at"],
            )
        )
    return "\n".join(lines)


# ─── schedule_cadence ────────────────────────────────────────────────────────


def format_schedule_cadence(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Schedule cadence — last {vm['lookback_days']}d "
        f"(stale = last run > {vm['stale_multiplier']}× median gap)"
    )
    lines.append("")
    lines.append(
        f"Stale pipelines: **{vm['stale_count']}** / "
        f"{len(vm['pipelines'])} tracked."
    )
    if not vm["pipelines"]:
        lines.append("")
        lines.append("No RUN_SUCCESS events in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append(
        "| Pipeline | Runs | Bucket | Median gap | Last age | Stale | Reason |"
    )
    lines.append("|---|---:|---|---|---|:-:|---|")
    for r in vm["pipelines"]:
        lines.append(
            "| {name} | {n} | {bucket} | {mg} | {age} | {stale} | {reason} |".format(
                name=_trim_cell(r["pipeline_name"], 40),
                n=r["run_count"],
                bucket=r["bucket"],
                mg=(f"{r['median_gap_hours']}h" if r["median_gap_hours"] is not None else "-"),
                age=f"{r['last_run_age_hours']}h",
                stale="Y" if r["stale"] else " ",
                reason=_trim_cell(r["stale_reason"], 60),
            )
        )
    return "\n".join(lines)


# ─── notifications_recent ────────────────────────────────────────────────────


def format_notifications_recent(vm: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(
        f"### Notifications — last {vm['window_hours']}h "
        f"(as of {vm['as_of_mst']} MST)"
    )
    lines.append("")
    lines.append(
        f"Total: **{vm['total_notifications']}** across "
        f"**{len(vm['by_pipeline'])}** pipeline(s)."
    )
    if not vm["by_pipeline"]:
        lines.append("")
        lines.append("No notification events in the window.")
        return "\n".join(lines)

    lines.append("")
    lines.append("| Pipeline | Total | Slack | Email | Last @ | Last channel | Recipient |")
    lines.append("|---|---:|---:|---:|---|---|---|")
    for r in vm["by_pipeline"]:
        lines.append(
            "| {name} | {n} | {s} | {e} | {ts} | {ch} | {to} |".format(
                name=_trim_cell(r["pipeline_name"], 40),
                n=r["total"],
                s=r["slack_count"],
                e=r["email_count"],
                ts=r["last_event_timestamp"],
                ch=_trim_cell(r["last_channel"], 16),
                to=_trim_cell(r["last_recipient"], 40),
            )
        )
    return "\n".join(lines)
