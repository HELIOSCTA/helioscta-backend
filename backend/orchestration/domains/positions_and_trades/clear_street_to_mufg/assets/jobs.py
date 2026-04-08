"""Job definitions for the Clear Street → MUFG pipeline."""

from datetime import datetime

from dagster import (
    AssetSelection,
    HookContext,
    define_asset_job,
    failure_hook,
    in_process_executor,
)

from backend.orchestration.slack_utils import send_slack

from ._helpers import MT
from .check_clear_street_sftp import check_clear_street_sftp
from .check_mufg_sftp import check_mufg_sftp


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


clear_street_to_mufg_pipeline = define_asset_job(
    name="clear_street_to_mufg_pipeline",
    selection=AssetSelection.groups("clear_street_to_mufg"),
    executor_def=in_process_executor,
    hooks={slack_on_failure},
    description=(
        "End-to-end pipeline: Clear Street SFTP → dbt transform → MUFG SFTP.\n\n"
        "Materializes all assets in the `clear_street_to_mufg` group in dependency "
        "order:\n\n"
        "1. `pull_from_clear_street_sftp` — download trade CSVs, upsert to raw table\n"
        "2. `data_transformation_in_sql` — dbt build: staging + mart + tests\n"
        "3. `upload_clear_street_trades_to_mufg` — filter ADU/905 trades, upload CSV\n\n"
        "Can be triggered manually from the Dagster UI (Launchpad) or via the schedule."
    ),
)

check_clear_street_sftp_job = define_asset_job(
    name="check_clear_street_sftp_job",
    selection=AssetSelection.assets(check_clear_street_sftp),
    description="Check Clear Street SFTP for today's EoD trade file and notify Slack.",
)

check_mufg_sftp_job = define_asset_job(
    name="check_mufg_sftp_job",
    selection=AssetSelection.assets(check_mufg_sftp),
    description="Check MUFG SFTP to confirm today's filtered trade file was uploaded.",
)
