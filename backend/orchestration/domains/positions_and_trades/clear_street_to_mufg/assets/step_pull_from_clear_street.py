"""
Asset: pull_from_clear_street_sftp

Pulls trade CSVs from Clear Street SFTP and upserts to Azure PostgreSQL.
"""

from datetime import datetime

from dagster import (
    asset,
    MaterializeResult,
    MetadataValue,
)

from backend.orchestration.notification_utils import send_slack_once_per_day
from backend.utils import azure_postgresql_utils

from ._helpers import MT, _is_dry_run


@asset(
    kinds={"python", "postgres"},
    group_name="clear_street_to_mufg",
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
        "`CLEAR_STREET_SFTP_USER`, and `CLEAR_STREET_SSH_KEY_CONTENT` env vars.\n"
        "- **No new data** — Clear Street typically releases files after market close; "
        "check the `raw_sftp_date_is_today` asset check.\n"
        "- **Duplicate rows** — the upsert is idempotent; re-running is safe."
    ),
)
def step_pull_from_clear_street(context) -> MaterializeResult:
    if _is_dry_run(context):
        context.log.info("Phase 1: DRY RUN — testing Clear Street SFTP connection only")
        import io
        import os
        import paramiko
        from backend import secrets

        transport = paramiko.Transport((secrets.CLEAR_STREET_SFTP_HOST, secrets.CLEAR_STREET_SFTP_PORT))
        try:
            key_content = os.getenv("CLEAR_STREET_SSH_KEY_CONTENT")
            pkey = paramiko.RSAKey.from_private_key(io.StringIO(key_content))
            transport.connect(username=secrets.CLEAR_STREET_SFTP_USER, pkey=pkey)
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

    file_timing = azure_postgresql_utils.pull_from_db(
        query="""
        SELECT DISTINCT
            trade_date_from_sftp::DATE AS trade_date_sort,
            sftp_upload_timestamp AS released_sort,
            TO_CHAR(trade_date_from_sftp::DATE, 'Dy Mon-DD') AS expected_trade_date,
            TO_CHAR(sftp_upload_timestamp, 'Dy Mon-DD HH12:MI AM') AS released_from_clear_street,
            TO_CHAR(created_at, 'Dy Mon-DD HH12:MI AM') AS downloaded_at
        FROM clear_street.helios_transactions_v2_2026_feb_23
        WHERE trade_date_from_sftp::DATE >= CURRENT_DATE - 7
        ORDER BY released_sort DESC
        """
    )
    file_timing_display = file_timing[[
        "expected_trade_date",
        "released_from_clear_street",
        "downloaded_at",
    ]]

    if not file_timing_display.empty:
        latest_timing = file_timing_display.iloc[0]
        expected_trade_date = str(latest_timing["expected_trade_date"])
        released_from_clear_street = str(latest_timing["released_from_clear_street"])
        downloaded_at = str(latest_timing["downloaded_at"])
    else:
        expected_trade_date = "N/A"
        released_from_clear_street = "N/A"
        downloaded_at = "N/A"

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
    if latest_date_parsed == datetime.now(MT).date():
        message = (
            ":inbox_tray: *Clear Street SFTP file received*\n"
            f"Expected trade date: `{expected_trade_date}`\n"
            f"Released from Clear Street: `{released_from_clear_street}`\n"
            f"Downloaded at: `{downloaded_at}`"
        )
        sent = send_slack_once_per_day(
            notification_key="clear_street_sftp_file_received",
            message=message,
            source="positions_and_trades",
            priority="medium",
            tags="sftp,clear_street,notification",
            metadata={
                "expected_trade_date": expected_trade_date,
                "released_from_clear_street": released_from_clear_street,
                "downloaded_at": downloaded_at,
            },
        )
        if sent:
            context.log.info(f"Slack notification sent: {message}")
        else:
            context.log.info("Slack notification skipped (already sent today or send failure).")

    return MaterializeResult(
        metadata={
            "row_count": int(row_count),
            "latest_trade_date": MetadataValue.text(str(latest_date)),
            "expected_trade_date": MetadataValue.text(expected_trade_date),
            "released_from_clear_street": MetadataValue.text(released_from_clear_street),
            "downloaded_at": MetadataValue.text(downloaded_at),
            "file_timing": MetadataValue.md(file_timing_display.to_markdown(index=False)),
            "target_table": MetadataValue.text("clear_street.helios_transactions_v2_2026_feb_23"),
            "pipeline_timeline": MetadataValue.md(timeline_md),
        }
    )
