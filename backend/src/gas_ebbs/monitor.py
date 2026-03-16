"""
Gas EBB scraper health monitor.

Queries logging.pipeline_runs to report scraper health status.

Usage:
    python monitor.py              # print health report
    python monitor.py --hours 6    # custom lookback window
    python monitor.py --failures   # show only failures
"""

import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend import secrets  # noqa: F401
from backend.utils import azure_postgresql_utils as azure_postgresql


def get_pipeline_health(hours: int = 24) -> list[dict]:
    """Query pipeline_runs and return health status per pipeline."""
    df = azure_postgresql.pull_from_db(f"""
        WITH recent AS (
            SELECT pipeline_name, status, created_at
            FROM logging.pipeline_runs
            WHERE source = 'gas_ebbs'
              AND event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
              AND created_at >= now() - interval '{hours} hours'
        )
        SELECT
            pipeline_name,
            COUNT(*) FILTER (WHERE status = 'success') as successes,
            COUNT(*) FILTER (WHERE status = 'failure') as failures,
            MAX(created_at) FILTER (WHERE status = 'success') as last_success,
            MAX(created_at) FILTER (WHERE status = 'failure') as last_failure
        FROM recent
        GROUP BY pipeline_name
        ORDER BY pipeline_name
    """)

    results = []
    for _, row in df.iterrows():
        s = int(row.successes)
        f = int(row.failures)
        if f > 0 and s == 0:
            status = "DEAD"
        elif f > s:
            status = "DEGRADED"
        elif f > 0:
            status = "FLAKY"
        else:
            status = "HEALTHY"
        results.append({
            "pipeline": row.pipeline_name,
            "successes": s,
            "failures": f,
            "status": status,
            "last_success": row.last_success,
            "last_failure": row.last_failure,
        })
    return results


def print_health_report(hours: int = 24, failures_only: bool = False):
    """Print a formatted health report."""
    results = get_pipeline_health(hours)

    if failures_only:
        results = [r for r in results if r["status"] != "HEALTHY"]

    dead = [r for r in results if r["status"] == "DEAD"]
    degraded = [r for r in results if r["status"] == "DEGRADED"]
    flaky = [r for r in results if r["status"] == "FLAKY"]
    healthy = [r for r in results if r["status"] == "HEALTHY"]

    print(f"\n=== Gas EBB Scraper Health (last {hours}h) ===\n")
    print(f"  {len(healthy)} healthy, {len(flaky)} flaky, "
          f"{len(degraded)} degraded, {len(dead)} dead "
          f"(of {len(results)} total)\n")

    for label, group in [("DEAD", dead), ("DEGRADED", degraded), ("FLAKY", flaky)]:
        if not group:
            continue
        print(f"  --- {label} ---")
        for r in group:
            print(f"    {r['pipeline']:45s} ok={r['successes']:3d} fail={r['failures']:3d}")
        print()

    if not failures_only and healthy:
        print(f"  --- HEALTHY ({len(healthy)}) ---")
        for r in healthy:
            print(f"    {r['pipeline']:45s} ok={r['successes']:3d}")
        print()


def main():
    hours = 24
    failures_only = False

    args = sys.argv[1:]
    if "--hours" in args:
        idx = args.index("--hours")
        hours = int(args[idx + 1])
    if "--failures" in args:
        failures_only = True

    print_health_report(hours=hours, failures_only=failures_only)


if __name__ == "__main__":
    main()
