"""
Asset: pull_from_clear_street_sftp

Pulls trade CSVs from Clear Street SFTP and upserts to Azure PostgreSQL.
"""

import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from dagster import (
    asset,
    asset_check,
    AssetCheckResult,
    AssetCheckSeverity,
    MaterializeResult,
    MetadataValue,
)

from backend.orchestration.slack_utils import fmt_date, send_slack
from backend.utils import azure_postgresql_utils

MT = ZoneInfo("America/Denver")


def _is_dry_run(context) -> bool:
    """Check env var or run tag for dry run mode."""
    if os.getenv("DAGSTER_DRY_RUN", "").lower() in ("1", "true"):
        return True
    tags = {}
    if hasattr(context, "run_tags"):
        tags = context.run_tags
    elif hasattr(context, "dagster_run") and context.dagster_run:
        tags = context.dagster_run.tags
    elif hasattr(context, "run") and context.run:
        tags = context.run.tags
    return tags.get("dry_run", "").lower() in ("1", "true")


@asset(
    kinds={"python", "postgres"},
    description=(
        "Pull Clear Street trade CSVs from SFTP and upsert to "
        "`clear_street.helios_transactions_v2_2026_feb_23`.\n\n"
        "**Phase 1** of the Clear Street → MUFG pipeline. Runs every 15 minutes "
        "from 9–11:45 PM MT on weekdays. Each run downloads all CSV files from "
        "the Clear Street SFTP directory and performs an upsert keyed on trade ID "
        "and trade date.\n\n"
        "### Dry-run mode\n"
        "Set the `dry_run` run tag to `true` or `DAGSTER_DRY_RUN=1` to skip the "
        "SFTP pull and use existing data in the table.\n\n"
        "### Troubleshooting\n"
        "- **SFTP connection failures** — check `CLEAR_STREET_SFTP_HOST`, "
        "`CLEAR_STREET_SFTP_USER`, and `CLEAR_STREET_SSH_KEY_PATH` env vars.\n"
        "- **No new data** — Clear Street typically releases files after market close; "
        "check the `raw_sftp_date_is_today` asset check.\n"
        "- **Duplicate rows** — the upsert is idempotent; re-running is safe."
    ),
)
def pull_from_clear_street_sftp(context) -> MaterializeResult:
    if _is_dry_run(context):
        context.log.info("Phase 1: DRY RUN — testing Clear Street SFTP connection only")
        import paramiko
        from backend import secrets

        transport = paramiko.Transport((secrets.CLEAR_STREET_SFTP_HOST, secrets.CLEAR_STREET_SFTP_PORT))
        try:
            private_key = paramiko.RSAKey.from_private_key_file(secrets.CLEAR_STREET_SSH_KEY_PATH)
            transport.connect(username=secrets.CLEAR_STREET_SFTP_USER, pkey=private_key)
            sftp = paramiko.SFTPClient.from_transport(transport)
            files = sftp.listdir(".")
            context.log.info(f"Clear Street SFTP connection OK — {len(files)} files found")
            sftp.close()
        finally:
            transport.close()
    else:
        from backend.src.postions_and_trades.tasks.pull_from_sftp.trades.clear_street.helios_transactions_v2_2026_feb_23 import (
            main as ingest_main,
        )
        context.log.info("Phase 1: Pulling Clear Street trades from SFTP")
        ingest_main()

    # Attach metadata for observability in Dagster UI
    row_count = azure_postgresql_utils.pull_from_db(
        query="SELECT COUNT(*) AS cnt FROM clear_street.helios_transactions_v2_2026_feb_23"
    )["cnt"].iloc[0]

    latest_date = azure_postgresql_utils.pull_from_db(
        query="SELECT MAX(trade_date_from_sftp)::TEXT AS dt FROM clear_street.helios_transactions_v2_2026_feb_23"
    )["dt"].iloc[0]

    pipeline_timeline = azure_postgresql_utils.pull_from_db(
        query="""
        WITH sftp_files AS (
            SELECT
                CAST(trade_date_from_sftp AS DATE) AS trade_date,
                MAX(sftp_upload_timestamp) AS file_released_on_sftp
            FROM clear_street.helios_transactions_v2_2026_feb_23
            GROUP BY CAST(trade_date_from_sftp AS DATE)
        ),
        sftp_downloads AS (
            SELECT event_timestamp AS downloaded_at
            FROM logging.pipeline_runs
            WHERE pipeline_name = 'helios_transactions_v2_2026_feb_23'
              AND event_type = 'RUN_SUCCESS'
        ),
        mufg_releases AS (
            SELECT event_timestamp AS released_to_mufg_at
            FROM logging.pipeline_runs
            WHERE pipeline_name = 'send_clear_street_trades_to_mufg_v1_2026_feb_02'
              AND event_type = 'RUN_SUCCESS'
        )
        SELECT
            TO_CHAR(sf.trade_date, 'Dy Mon-DD') AS trade_date,
            TO_CHAR(sf.file_released_on_sftp, 'Dy Mon-DD HH:MI:SS AM') AS sftp_released,
            TO_CHAR(dl.downloaded_at, 'Dy Mon-DD HH:MI:SS AM') AS downloaded,
            TO_CHAR(mr.released_to_mufg_at, 'Dy Mon-DD HH:MI:SS AM') AS mufg_released
        FROM sftp_files sf
        LEFT JOIN LATERAL (
            SELECT downloaded_at FROM sftp_downloads
            WHERE downloaded_at >= sf.file_released_on_sftp
            ORDER BY downloaded_at ASC LIMIT 1
        ) dl ON true
        LEFT JOIN LATERAL (
            SELECT released_to_mufg_at FROM mufg_releases
            WHERE released_to_mufg_at >= dl.downloaded_at
            ORDER BY released_to_mufg_at ASC LIMIT 1
        ) mr ON true
        ORDER BY sf.file_released_on_sftp DESC
        LIMIT 3
        """
    )

    timeline_md = pipeline_timeline.to_markdown(index=False)

    context.log.info(f"Table row count: {row_count}, latest trade date: {latest_date}")
    context.log.info(f"Pipeline timeline:\n{timeline_md}")

    # Notify Slack only when today's file has arrived
    latest_date_parsed = datetime.strptime(str(latest_date), "%Y%m%d").date()
    if latest_date_parsed == datetime.now().date():
        now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
        sftp_date_fmt = fmt_date(str(latest_date))
        message = f":inbox_tray: *Clear Street SFTP file received*\nSFTP Date: `{sftp_date_fmt}`\nDownloaded at: `{now}`"
        send_slack(message)
        context.log.info(f"Slack notification sent: {message}")

    return MaterializeResult(
        metadata={
            "row_count": int(row_count),
            "latest_trade_date": MetadataValue.text(str(latest_date)),
            "target_table": MetadataValue.text("clear_street.helios_transactions_v2_2026_feb_23"),
            "pipeline_timeline": MetadataValue.md(timeline_md),
        }
    )


@asset_check(
    asset=pull_from_clear_street_sftp,
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
