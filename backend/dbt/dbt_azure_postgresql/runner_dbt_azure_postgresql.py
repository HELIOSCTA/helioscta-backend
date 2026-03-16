"""
Runner for dbt on Azure PostgreSQL.

Executes ``dbt run`` with:
- PostgreSQL advisory lock to prevent concurrent runs
- Structured logging via PipelineRunLogger
- Configurable timeout with process-tree kill
- Optional --select pass-through and --dry-run mode

Usage:
    python runner_dbt_azure_postgresql.py                        # full dbt run
    python runner_dbt_azure_postgresql.py --select tag:pjm       # selective run
    python runner_dbt_azure_postgresql.py --dry-run              # log command without executing
    python runner_dbt_azure_postgresql.py --timeout 600          # custom timeout (seconds)
"""

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend import secrets  # noqa: E402
from backend.utils import (  # noqa: E402
    logging_utils,
    pipeline_run_logger,
)
import dbt_utils  # noqa: E402  (colocated in same directory)


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

PIPELINE_NAME = "dbt_run"
LOGGING_SOURCE = "dbt"
LOGGING_TARGET_TABLE = "dbt.*"
LOGGING_OPERATION_TYPE = "consume"
LOGGING_PRIORITY = "high"
LOGGING_TAGS = "dbt,azure_postgresql"

DEFAULT_TIMEOUT_SECONDS = 1800  # 30 minutes


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run dbt with advisory lock protection")
    parser.add_argument(
        "--select",
        type=str,
        default=None,
        help="dbt --select argument (e.g. 'tag:pjm')",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log the dbt command without executing it",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT_SECONDS,
        help=f"Timeout in seconds (default {DEFAULT_TIMEOUT_SECONDS})",
    )
    return parser.parse_args()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    args = parse_args()

    # ── Logging ──────────────────────────────────────────────────────────
    logger = logging_utils.init_logging(
        name=PIPELINE_NAME,
        log_dir=Path(__file__).parent / "logs",
        log_to_file=True,
        delete_if_no_errors=True,
    )

    pipeline_name = PIPELINE_NAME
    if args.select:
        pipeline_name = f"{PIPELINE_NAME}_{args.select.replace(':', '_')}"

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=pipeline_name,
        source=LOGGING_SOURCE,
        priority=LOGGING_PRIORITY,
        tags=LOGGING_TAGS,
        log_file_path=logger.log_file_path,
        target_table=LOGGING_TARGET_TABLE,
        operation_type=LOGGING_OPERATION_TYPE,
    )

    # ── Advisory lock ────────────────────────────────────────────────────
    conn = None
    try:
        conn = dbt_utils.get_pg_connection()
        lock_acquired = dbt_utils.acquire_advisory_lock(conn)

        if not lock_acquired:
            logger.info("Advisory lock held by another session — skipping this run")
            run.start()
            run.log_warning("RUN_SKIPPED: advisory lock held by another session")
            return

        # ── Execute dbt ──────────────────────────────────────────────────
        run.start()
        logger.info(
            f"Starting dbt run "
            f"(select={args.select or 'all'}, timeout={args.timeout}s, "
            f"dry_run={args.dry_run})"
        )

        exit_code, stdout, stderr = dbt_utils.run_dbt(
            select=args.select,
            timeout_seconds=args.timeout,
            dry_run=args.dry_run,
        )

        # Log dbt output
        if stdout:
            for line in stdout.strip().splitlines():
                logger.info(f"[dbt] {line}")
        if stderr:
            for line in stderr.strip().splitlines():
                logger.warning(f"[dbt stderr] {line}")

        # ── Result handling ──────────────────────────────────────────────
        if exit_code == 0:
            logger.info("dbt run completed successfully")
            run.success(metadata={"dbt_exit_code": exit_code, "select": args.select})

        elif exit_code == -1:
            error = TimeoutError(
                f"dbt run timed out after {args.timeout}s"
            )
            logger.error(str(error))
            run.failure(
                error=error,
                metadata={"event": "RUN_TIMEOUT", "timeout_seconds": args.timeout},
            )
            sys.exit(1)

        else:
            error = RuntimeError(
                f"dbt run failed with exit code {exit_code}. "
                f"stderr: {stderr[:2000] if stderr else '(empty)'}"
            )
            logger.error(str(error))
            run.failure(
                error=error,
                metadata={"dbt_exit_code": exit_code, "select": args.select},
            )
            sys.exit(1)

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        run.failure(error=e)
        sys.exit(1)

    finally:
        if conn:
            try:
                dbt_utils.release_advisory_lock(conn)
            except Exception:
                pass
            try:
                conn.close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
