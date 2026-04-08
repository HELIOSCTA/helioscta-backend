"""
Asset: check_mufg_sftp

Polls MUFG SFTP to confirm today's filtered trade file was uploaded.
Sends a one-time Slack notification when confirmed. Uses logging.pipeline_runs
to track whether a notification was already sent today.
"""

import fnmatch
import os
from datetime import datetime

from dagster import (
    AssetCheckResult,
    AssetCheckSpec,
    MaterializeResult,
    MetadataValue,
    asset,
)

from backend.orchestration.slack_utils import send_slack
from backend.utils import azure_postgresql_utils

from ._helpers import MT, _is_dry_run, _is_test_notification

PIPELINE_NAME = "mufg_sftp_file_confirmed"
TRADE_FILE_PATTERN = "Helios_Transactions_*_filtered.csv"


def _already_confirmed_today() -> bool:
    """Check if a confirmation notification was already sent today."""
    result = azure_postgresql_utils.pull_from_db(query=f"""
        SELECT COUNT(*) AS cnt FROM logging.pipeline_runs
        WHERE pipeline_name = '{PIPELINE_NAME}'
          AND event_type = 'RUN_SUCCESS'
          AND event_timestamp::date = CURRENT_DATE
    """)
    return int(result["cnt"].iloc[0]) > 0


def _check_mufg_sftp_for_todays_file() -> dict:
    """Connect to MUFG SFTP and check if today's filtered file exists."""
    import paramiko
    from backend import secrets

    today_str = datetime.now(MT).strftime("%Y%m%d")
    expected_pattern = f"Helios_Transactions_{today_str}_filtered.csv"

    transport = None
    sftp = None
    try:
        transport = paramiko.Transport((
            secrets.MUFG_SFTP_HOST,
            secrets.MUFG_SFTP_PORT,
        ))
        transport.connect(
            username=secrets.MUFG_SFTP_USER,
            password=secrets.MUFG_SFTP_PASSWORD,
        )
        sftp = paramiko.SFTPClient.from_transport(transport)

        remote_dir = secrets.MUFG_SFTP_REMOTE_DIR
        filenames = sorted([
            attr.filename for attr in sftp.listdir_attr(remote_dir)
            if fnmatch.fnmatchcase(attr.filename.upper(), TRADE_FILE_PATTERN.upper())
        ], reverse=True)

        found = any(
            fnmatch.fnmatchcase(f.upper(), expected_pattern.upper())
            for f in filenames
        )

        return {
            "found": found,
            "expected_file": expected_pattern,
            "recent_files": filenames[:5],
        }

    finally:
        if sftp:
            sftp.close()
        if transport:
            transport.close()


@asset(
    kinds={"python", "sftp"},
    group_name="clear_street_to_mufg",
    check_specs=[
        AssetCheckSpec(
            name="mufg_file_uploaded",
            description="Whether today's filtered trade file is present on the MUFG SFTP server.",
            asset="check_mufg_sftp",
        ),
    ],
    description=(
        "Checks MUFG SFTP for today's uploaded trade file and sends a "
        "one-time Slack notification when confirmed.\n\n"
        "Uses `logging.pipeline_runs` to track whether a notification "
        "was already sent today - subsequent runs within the same day "
        "are no-ops.\n\n"
        "### Schedule\n"
        "Every 15 minutes from 9-11:45 PM MT, Monday-Friday.\n\n"
        "### Dry-run mode\n"
        "Set `dry_run=true` to skip the SFTP check.\n\n"
        "### Test notification mode\n"
        "Set both `dry_run=true` and `test_notification=true` to send a "
        "Slack test notification without checking SFTP and without writing "
        "to `logging.pipeline_runs`."
    ),
)
def check_mufg_sftp(context):
    from backend.utils import pipeline_run_logger

    if _is_dry_run(context):
        if _is_test_notification(context):
            now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
            expected_file = f"Helios_Transactions_{datetime.now(MT).strftime('%Y%m%d')}_filtered.csv"
            message = (
                ":test_tube: *[DRY RUN TEST] MUFG SFTP file confirmation*\n"
                f"Expected file: `{expected_file}`\n"
                f"Time: `{now}`"
            )
            send_slack(message)
            context.log.info("DRY RUN TEST - Slack notification sent")
            yield AssetCheckResult(
                check_name="mufg_file_uploaded",
                passed=True,
                metadata={"status": MetadataValue.text("dry_run_test_notified")},
            )
            yield MaterializeResult(
                metadata={
                    "status": MetadataValue.text("dry_run_test_notified"),
                    "expected_file": MetadataValue.text(expected_file),
                    "notified_at": MetadataValue.text(now),
                }
            )
            return

        context.log.info("DRY RUN - skipping SFTP check")
        yield AssetCheckResult(
            check_name="mufg_file_uploaded",
            passed=False,
            metadata={"status": MetadataValue.text("dry_run — skipped")},
        )
        yield MaterializeResult(
            metadata={"status": MetadataValue.text("dry_run")}
        )
        return

    if _already_confirmed_today():
        context.log.info("Already confirmed today - skipping")
        yield AssetCheckResult(
            check_name="mufg_file_uploaded",
            passed=True,
            metadata={"status": MetadataValue.text("already_confirmed")},
        )
        yield MaterializeResult(
            metadata={"status": MetadataValue.text("already_confirmed")}
        )
        return

    try:
        result = _check_mufg_sftp_for_todays_file()
    except Exception as exc:
        context.log.warning(f"MUFG SFTP check failed: {exc}")
        yield AssetCheckResult(
            check_name="mufg_file_uploaded",
            passed=False,
            metadata={"error": MetadataValue.text(str(exc))},
        )
        yield MaterializeResult(
            metadata={
                "status": MetadataValue.text("sftp_error"),
                "error": MetadataValue.text(str(exc)),
            }
        )
        return

    if not result["found"]:
        context.log.info(
            f"File not yet confirmed ({result['expected_file']}). "
            f"Recent files: {result['recent_files']}"
        )
        yield AssetCheckResult(
            check_name="mufg_file_uploaded",
            passed=False,
            metadata={
                "expected_file": MetadataValue.text(result["expected_file"]),
                "recent_files": MetadataValue.text(str(result["recent_files"])),
            },
        )
        yield MaterializeResult(
            metadata={
                "status": MetadataValue.text("not_found"),
                "expected_file": MetadataValue.text(result["expected_file"]),
                "recent_files": MetadataValue.text(str(result["recent_files"])),
            }
        )
        return

    now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
    message = (
        f":white_check_mark: *MUFG SFTP file confirmed*\n"
        f"File: `{result['expected_file']}`\n"
        f"Time: `{now}`"
    )
    send_slack(message)
    context.log.info(f"Slack notification sent: {message}")

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=PIPELINE_NAME,
        source="positions_and_trades",
        priority="medium",
        tags="sftp,mufg,notification",
        operation_type="consume",
    )
    run.start()
    run.success(metadata={"file": result["expected_file"]})

    yield AssetCheckResult(
        check_name="mufg_file_uploaded",
        passed=True,
        metadata={
            "file": MetadataValue.text(result["expected_file"]),
            "confirmed_at": MetadataValue.text(now),
        },
    )
    yield MaterializeResult(
        metadata={
            "status": MetadataValue.text("confirmed"),
            "file": MetadataValue.text(result["expected_file"]),
            "confirmed_at": MetadataValue.text(now),
        }
    )
