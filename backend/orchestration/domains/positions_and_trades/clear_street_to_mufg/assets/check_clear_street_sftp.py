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

from backend.orchestration.notification_utils import (
    already_sent_for_key,
    send_slack_once_for_key,
)
from backend.orchestration.slack_utils import send_slack
from backend.utils import azure_postgresql_utils

from ._helpers import MT, _is_dry_run, _is_test_notification
from .step_pull_from_clear_street import step_pull_from_clear_street

PIPELINE_NAME = "clear_street_sftp_file_detected"
LATE_PIPELINE_NAME = "clear_street_sftp_file_late"
TRADE_FILE_PATTERN = "Helios_Transactions_*.csv"
FILE_LATE_WARNING_DEADLINE_HOUR_MT = 22
FILE_LATE_WARNING_DEADLINE_MINUTE_MT = 0
TRADE_DATE_ROLLOVER_HOUR_MT = 12
TRADE_DATE_DEDUPE_LOOKBACK_DAYS = 14


def _expected_trade_date(now_mt: datetime) -> datetime.date:
    """Resolve the business trade date to monitor across overnight windows."""
    if now_mt.hour < TRADE_DATE_ROLLOVER_HOUR_MT:
        target = now_mt.date() - timedelta(days=1)
    else:
        target = now_mt.date()

    while target.weekday() >= 5:
        target = target - timedelta(days=1)
    return target


def _detected_notification_key(now_mt: datetime) -> str:
    return f"{PIPELINE_NAME}:{_expected_trade_date(now_mt).strftime('%Y%m%d')}"


def _late_notification_key(now_mt: datetime) -> str:
    return f"{LATE_PIPELINE_NAME}:{_expected_trade_date(now_mt).strftime('%Y%m%d')}"


def _already_notified_today() -> bool:
    """Check if detection notification already sent for the expected trade date."""
    now_mt = datetime.now(MT)
    return already_sent_for_key(
        _detected_notification_key(now_mt),
        lookback_days=TRADE_DATE_DEDUPE_LOOKBACK_DAYS,
    )


def _already_late_notified_today() -> bool:
    """Check if late warning already sent for the expected trade date."""
    now_mt = datetime.now(MT)
    return already_sent_for_key(
        _late_notification_key(now_mt),
        lookback_days=TRADE_DATE_DEDUPE_LOOKBACK_DAYS,
    )


def _warning_deadline_label_mt() -> str:
    deadline = datetime(2000, 1, 1, FILE_LATE_WARNING_DEADLINE_HOUR_MT, FILE_LATE_WARNING_DEADLINE_MINUTE_MT)
    return f"{deadline.strftime('%I:%M %p').lstrip('0')} MT"


def _is_past_warning_deadline_mt(now_mt: datetime) -> bool:
    deadline_mt = now_mt.replace(
        hour=FILE_LATE_WARNING_DEADLINE_HOUR_MT,
        minute=FILE_LATE_WARNING_DEADLINE_MINUTE_MT,
        second=0,
        microsecond=0,
    )
    return now_mt >= deadline_mt


def _check_sftp_for_todays_file() -> dict:
    """Connect to Clear Street SFTP and check if today's file exists."""
    import paramiko
    from backend import secrets

    now_mt = datetime.now(MT)
    expected_trade_date_dt = _expected_trade_date(now_mt)
    today_str = expected_trade_date_dt.strftime("%Y%m%d")
    expected_trade_date = expected_trade_date_dt.strftime("%a %b-%d")
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

        file_attrs = sorted([
            attr for attr in sftp.listdir_attr("/")
            if fnmatch.fnmatchcase(attr.filename.upper(), TRADE_FILE_PATTERN.upper())
        ], key=lambda a: a.filename, reverse=True)
        filenames = [attr.filename for attr in file_attrs]

        matched_attr = next(
            (attr for attr in file_attrs if fnmatch.fnmatchcase(attr.filename.upper(), expected_pattern.upper())),
            None,
        )
        found = matched_attr is not None
        released_from_clear_street = (
            datetime.fromtimestamp(matched_attr.st_mtime, MT).strftime("%a %b-%d %I:%M %p MT")
            if matched_attr is not None else "N/A"
        )

        return {
            "found": found,
            "expected_file": expected_pattern,
            "expected_trade_date_key": today_str,
            "expected_trade_date": expected_trade_date,
            "released_from_clear_street": released_from_clear_street,
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
        "Primary: every 15 minutes from 7:00 PM-11:45 PM MT, Monday-Friday.\n"
        "Overnight: every 15 minutes from 12:00 AM-2:45 AM MT, Tuesday-Saturday.\n"
        "Catch-up: hourly from 3:00 AM-8:00 AM MT, Tuesday-Saturday.\n\n"
        "### Dry-run mode\n"
        "Set `dry_run=true` to skip the SFTP check.\n\n"
        "### Test notification mode\n"
        "Set both `dry_run=true` and `test_notification=true` to send a "
        "Slack test notification without checking SFTP and without writing "
        "to `logging.pipeline_runs`."
    ),
)
def check_clear_street_sftp(context):
    if _is_dry_run(context):
        if _is_test_notification(context):
            now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
            expected_trade_date_dt = _expected_trade_date(datetime.now(MT))
            expected_file = f"Helios_Transactions_{expected_trade_date_dt.strftime('%Y%m%d')}.csv"
            expected_trade_date = expected_trade_date_dt.strftime("%a %b-%d")
            message = (
                ":test_tube: *[DRY RUN TEST] Clear Street SFTP EoD file notification*\n"
                f"Expected trade date: `{expected_trade_date}`\n"
                f"Expected file: `{expected_file}`\n"
                "Released from Clear Street: `N/A (dry run)`\n"
                "Downloaded at: `N/A (SFTP check only)`\n"
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
                    "expected_trade_date": MetadataValue.text(expected_trade_date),
                    "expected_file": MetadataValue.text(expected_file),
                    "released_from_clear_street": MetadataValue.text("N/A"),
                    "downloaded_at": MetadataValue.text("N/A"),
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
        now_mt = datetime.now(MT)
        now = now_mt.strftime("%a %b-%d %I:%M:%S %p MT")
        deadline_label = _warning_deadline_label_mt()
        is_past_deadline = _is_past_warning_deadline_mt(now_mt)
        warning_sent = False

        if is_past_deadline and not _already_late_notified_today() and not _already_notified_today():
            message = (
                ":warning: *Clear Street EOD file not yet received*\n"
                f"Expected trade date: `{result['expected_trade_date']}`\n"
                f"Expected file: `{result['expected_file']}`\n"
                f"Expected by: `{deadline_label}`"
            )
            warning_sent = send_slack_once_for_key(
                notification_key=_late_notification_key(now_mt),
                message=message,
                source="positions_and_trades",
                priority="medium",
                tags="sftp,clear_street,notification,late",
                metadata={
                    "expected_trade_date_key": result["expected_trade_date_key"],
                    "expected_trade_date": result["expected_trade_date"],
                    "expected_file": result["expected_file"],
                    "deadline_mt": deadline_label,
                    "notified_at": now,
                },
                lookback_days=TRADE_DATE_DEDUPE_LOOKBACK_DAYS,
            )
            if warning_sent:
                context.log.warning(f"Slack warning sent: {message}")

        context.log.info(
            f"File not yet available ({result['expected_file']}). "
            f"Recent files: {result['recent_files']}"
        )
        yield AssetCheckResult(
            check_name="eod_file_available",
            passed=False,
            metadata={
                "expected_trade_date": MetadataValue.text(result["expected_trade_date"]),
                "expected_trade_date_key": MetadataValue.text(result["expected_trade_date_key"]),
                "expected_file": MetadataValue.text(result["expected_file"]),
                "released_from_clear_street": MetadataValue.text(result["released_from_clear_street"]),
                "recent_files": MetadataValue.text(str(result["recent_files"])),
                "deadline_mt": MetadataValue.text(deadline_label),
                "past_deadline": MetadataValue.bool(is_past_deadline),
                "late_warning_sent": MetadataValue.bool(warning_sent),
            },
        )
        yield MaterializeResult(
            metadata={
                "status": MetadataValue.text("late_notified" if warning_sent else "not_found"),
                "expected_trade_date": MetadataValue.text(result["expected_trade_date"]),
                "expected_trade_date_key": MetadataValue.text(result["expected_trade_date_key"]),
                "expected_file": MetadataValue.text(result["expected_file"]),
                "released_from_clear_street": MetadataValue.text(result["released_from_clear_street"]),
                "recent_files": MetadataValue.text(str(result["recent_files"])),
                "deadline_mt": MetadataValue.text(deadline_label),
                "past_deadline": MetadataValue.bool(is_past_deadline),
                "late_warning_sent": MetadataValue.bool(warning_sent),
            }
        )
        return

    now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
    message = (
        f":inbox_tray: *Clear Street SFTP file detected*\n"
        f"Expected trade date: `{result['expected_trade_date']}`\n"
        f"File: `{result['expected_file']}`\n"
        f"Released from Clear Street: `{result['released_from_clear_street']}`\n"
        "Downloaded at: `Pending (pull step not completed yet)`\n"
        f"Time: `{now}`"
    )
    sent = send_slack_once_for_key(
        notification_key=_detected_notification_key(datetime.now(MT)),
        message=message,
        source="positions_and_trades",
        priority="medium",
        tags="sftp,clear_street,notification",
        metadata={
            "expected_trade_date_key": result["expected_trade_date_key"],
            "expected_trade_date": result["expected_trade_date"],
            "file": result["expected_file"],
            "released_from_clear_street": result["released_from_clear_street"],
            "detected_at": now,
        },
        lookback_days=TRADE_DATE_DEDUPE_LOOKBACK_DAYS,
    )
    if sent:
        context.log.info(f"Slack notification sent: {message}")
    else:
        context.log.warning("Slack notification was not sent (already sent today or send failure).")

    yield AssetCheckResult(
        check_name="eod_file_available",
        passed=True,
        metadata={
            "expected_trade_date": MetadataValue.text(result["expected_trade_date"]),
            "expected_trade_date_key": MetadataValue.text(result["expected_trade_date_key"]),
            "file": MetadataValue.text(result["expected_file"]),
            "released_from_clear_street": MetadataValue.text(result["released_from_clear_street"]),
            "detected_at": MetadataValue.text(now),
        },
    )
    yield MaterializeResult(
        metadata={
            "status": MetadataValue.text("notified"),
            "expected_trade_date": MetadataValue.text(result["expected_trade_date"]),
            "expected_trade_date_key": MetadataValue.text(result["expected_trade_date_key"]),
            "file": MetadataValue.text(result["expected_file"]),
            "released_from_clear_street": MetadataValue.text(result["released_from_clear_street"]),
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
