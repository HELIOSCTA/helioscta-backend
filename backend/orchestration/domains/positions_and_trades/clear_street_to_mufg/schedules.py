"""
Schedules for the Positions & Trades domain.

Every 15 minutes from 9 PM to 11:45 PM Mountain Time, Mon-Fri.
"""

from datetime import datetime
from zoneinfo import ZoneInfo

from dagster import (
    HookContext,
    ScheduleDefinition,
    define_asset_job,
    failure_hook,
    in_process_executor,
    AssetSelection,
)

from backend.orchestration.slack_utils import send_slack

MT = ZoneInfo("America/Denver")


@failure_hook
def slack_on_failure(context: HookContext):
    """Sends a Slack notification when any step in the job fails. Skips dry runs."""
    tags = context.op_execution_context.run_tags if hasattr(context, "op_execution_context") else {}
    if tags.get("dry_run", "").lower() in ("1", "true"):
        context.log.info("Dry run — skipping Slack failure notification")
        return

    step = context.step_key or "unknown"
    timestamp = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")

    # Extract error message from the step exception
    error_detail = ""
    if context.op_exception:
        error_lines = str(context.op_exception).strip().splitlines()
        error_msg = error_lines[0] if error_lines else str(context.op_exception)
        if len(error_msg) > 300:
            error_msg = error_msg[:300] + "…"
        error_detail = f"\nError: `{error_msg}`"

    message = (
        f":x: *Clear Street → MUFG* failed\n"
        f"Step: `{step}`\n"
        f"Time: `{timestamp}`"
        f"{error_detail}"
    )
    send_slack(message)
    context.log.info(f"Slack failure notification sent: {message}")


# Job that materializes the full pipeline in dependency order
clear_street_to_mufg_job = define_asset_job(
    name="clear_street_to_mufg_job",
    selection=AssetSelection.groups("positions_and_trades"),
    executor_def=in_process_executor,
    hooks={slack_on_failure},
    description=(
        "End-to-end pipeline: Clear Street SFTP → dbt transform → MUFG SFTP.\n\n"
        "Materializes all assets in the `positions_and_trades` group in dependency "
        "order:\n\n"
        "1. `pull_from_clear_street_sftp` — download trade CSVs, upsert to raw table\n"
        "2. `data_transformation_in_sql` — dbt build: staging + mart + tests\n"
        "3. `upload_clear_street_trades_to_mufg` — filter ADU/905 trades, upload CSV\n\n"
        "Can be triggered manually from the Dagster UI (Launchpad) or via the schedule."
    ),
)

# Every 15 minutes from 9 PM to 11:45 PM Mountain Time, Mon-Fri
clear_street_to_mufg_schedule = ScheduleDefinition(
    name="clear_street_to_mufg_schedule",
    job=clear_street_to_mufg_job,
    cron_schedule="*/15 21-23 * * 1-5",
    execution_timezone="America/Denver",
    description=(
        "Runs the Clear Street → MUFG pipeline every 15 minutes from "
        "9:00 PM to 11:45 PM Mountain Time, Monday through Friday.\n\n"
        "Clear Street typically publishes EOD trade files between 9–10 PM MT. "
        "The schedule retries every 15 minutes to catch late files and ensure "
        "MUFG receives the data before midnight."
    ),
)

jobs = [clear_street_to_mufg_job]
schedules = [clear_street_to_mufg_schedule]
