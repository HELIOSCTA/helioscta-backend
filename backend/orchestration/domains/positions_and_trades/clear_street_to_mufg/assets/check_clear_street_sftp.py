"""
Asset: check_clear_street_sftp_for_eod_trade_file

Polls Clear Street SFTP for today's EoD trade file. Sends a one-time Slack
notification when the file is detected. Uses logging.pipeline_runs to track
whether a notification was already sent today.
"""

import fnmatch
import io
import os
from datetime import datetime, timedelta

from dagster import (
    AssetCheckResult,
    AssetCheckSeverity,
    AssetCheckSpec,
    MaterializeResult,
    MetadataValue,
    asset,
    asset_check,
)

from backend.orchestration.slack_utils import send_slack
from backend.utils import azure_postgresql_utils

from ._helpers import MT, _is_dry_run, _is_test_notification
from .step_pull_from_clear_street import step_pull_from_clear_street

PIPELINE_NAME = "clear_street_sftp_file_detected"
TRADE_FILE_PATTERN = "Helios_Transactions_*.csv"


def _already_notified_today() -> bool:
    """Check if a Slack notification was already sent today."""
    result = azure_postgresql_utils.pull_from_db(query=f"""
        SELECT COUNT(*) AS cnt FROM logging.pipeline_runs
        WHERE pipeline_name = '{PIPELINE_NAME}'
          AND event_type = 'RUN_SUCCESS'
          AND event_timestamp::date = CURRENT_DATE
    """)
    return int(result["cnt"].iloc[0]) > 0


def _check_sftp_for_todays_file() -> dict:
    """Connect to Clear Street SFTP and check if today's file exists."""
    import paramiko
    from backend import secrets

    today_str = datetime.now(MT).strftime("%Y%m%d")
    expected_pattern = f"Helios_Transactions_{today_str}.csv"

    transport = None
    sftp = None
    try:
        transport = paramiko.Transport((
            secrets.CLEAR_STREET_SFTP_HOST,
            secrets.CLEAR_STREET_SFTP_PORT,
        ))
        key_content = os.getenv("CLEAR_STREET_SSH_KEY_CONTENT")
        pkey = paramiko.RSAKey.from_private_key(io.StringIO(key_content))
        transport.connect(username=secrets.CLEAR_STREET_SFTP_USER, pkey=pkey)
        sftp = paramiko.SFTPClient.from_transport(transport)

        filenames = sorted([
            attr.filename for attr in sftp.listdir_attr("/")
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
            name="eod_file_available",
            description="Whether today's EoD trade file is present on the SFTP server.",
            asset="check_clear_street_sftp",
        ),
    ],
    description=(
        "Checks Clear Street SFTP for today's EoD trade file and sends a "
        "one-time Slack notification when detected.\n\n"
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
def check_clear_street_sftp(context):
    from backend.utils import pipeline_run_logger

    if _is_dry_run(context):
        if _is_test_notification(context):
            now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
            expected_file = f"Helios_Transactions_{datetime.now(MT).strftime('%Y%m%d')}.csv"
            message = (
                ":test_tube: *[DRY RUN TEST] Clear Street SFTP EoD file notification*\n"
                f"Expected file: `{expected_file}`\n"
                f"Time: `{now}`"
            )
            send_slack(message)
            context.log.info("DRY RUN TEST - Slack notification sent")
            yield AssetCheckResult(
                check_name="eod_file_available",
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
            check_name="eod_file_available",
            passed=False,
            metadata={"status": MetadataValue.text("dry_run — skipped")},
        )
        yield MaterializeResult(
            metadata={"status": MetadataValue.text("dry_run")}
        )
        return

    if _already_notified_today():
        context.log.info("Already notified today - skipping")
        yield AssetCheckResult(
            check_name="eod_file_available",
            passed=True,
            metadata={"status": MetadataValue.text("already_notified")},
        )
        yield MaterializeResult(
            metadata={"status": MetadataValue.text("already_notified")}
        )
        return

    try:
        result = _check_sftp_for_todays_file()
    except Exception as exc:
        context.log.warning(f"SFTP check failed: {exc}")
        yield AssetCheckResult(
            check_name="eod_file_available",
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
            f"File not yet available ({result['expected_file']}). "
            f"Recent files: {result['recent_files']}"
        )
        yield AssetCheckResult(
            check_name="eod_file_available",
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
        f":inbox_tray: *Clear Street SFTP file detected*\n"
        f"File: `{result['expected_file']}`\n"
        f"Time: `{now}`"
    )
    send_slack(message)
    context.log.info(f"Slack notification sent: {message}")

    run = pipeline_run_logger.PipelineRunLogger(
        pipeline_name=PIPELINE_NAME,
        source="positions_and_trades",
        priority="medium",
        tags="sftp,clear_street,notification",
        operation_type="consume",
    )
    run.start()
    run.success(metadata={"file": result["expected_file"]})

    yield AssetCheckResult(
        check_name="eod_file_available",
        passed=True,
        metadata={
            "file": MetadataValue.text(result["expected_file"]),
            "detected_at": MetadataValue.text(now),
        },
    )
    yield MaterializeResult(
        metadata={
            "status": MetadataValue.text("notified"),
            "file": MetadataValue.text(result["expected_file"]),
            "notified_at": MetadataValue.text(now),
        }
    )


@asset_check(
    asset=step_pull_from_clear_street,
    blocking=False,
    description=(
        "Validates that the latest `trade_date_from_sftp` in the raw table matches "
        "today's date (or yesterday in dry-run mode). Warns but does not block "
        "downstream steps if today's file hasn't arrived."
    ),
)
def raw_sftp_date_is_today(context) -> AssetCheckResult:
    result = azure_postgresql_utils.pull_from_db(
        query="""
        SELECT MAX(trade_date_from_sftp)::TEXT AS latest_sftp_date
        FROM clear_street.helios_transactions_v2_2026_feb_23
        """
    )

    latest_date_str = str(result["latest_sftp_date"].iloc[0])
    latest_date = datetime.strptime(latest_date_str, "%Y%m%d").date()

    if _is_dry_run(context):
        expected_date = datetime.now().date() - timedelta(days=1)
        context.log.info(f"DRY RUN: using yesterday ({expected_date}) as target date")
    else:
        expected_date = datetime.now().date()

    passed = latest_date == expected_date

    context.log.info(f"SFTP date check: latest={latest_date}, expected={expected_date}, match={passed}")

    return AssetCheckResult(
        passed=passed,
        severity=AssetCheckSeverity.WARN,
        metadata={
            "latest_sftp_date": MetadataValue.text(latest_date_str),
            "expected_date": MetadataValue.text(str(expected_date)),
        },
    )
