"""
Asset: upload_clear_street_trades_to_mufg

Post-upload check: mufg_sftp_date_is_today
Pre-upload checks (assert_no_missing_product_codes) are dbt tests
that run as part of the dbt build step.
"""

from datetime import datetime

from dagster import (
    asset,
    MaterializeResult,
    MetadataValue,
)

from backend.orchestration.slack_utils import fmt_date, send_slack
from backend.utils import azure_postgresql_utils

from ._helpers import MT, _is_dry_run


@asset(
    deps=["step_dbt_transform"],
    kinds={"python", "sftp"},
    group_name="clear_street_to_mufg",
    description=(
        "**Phase 3** — filter transformed trades for MUFG firms (ADU/905), "
        "generate a CSV, and upload to MUFG SFTP.\n\n"
        "Reads from the `trades_cleaned.clear_street_trades` dbt view, filters to "
        "give-in/out firm numbers ADU and 905, and uploads the result to MUFG's "
        "SFTP server.\n\n"
        "### Metadata\n"
        "Each materialization attaches two summary tables:\n"
        "- **mufg_trades** — grouped breakdown of trades sent to MUFG\n"
        "- **all_trades** — grouped breakdown of all trades for comparison\n\n"
        "### Dry-run mode\n"
        "Set the `dry_run` run tag to `true` to skip the SFTP upload while still "
        "computing metadata.\n\n"
        "### Troubleshooting\n"
        "- **MUFG SFTP failures** — check `MUFG_SFTP_HOST`, `MUFG_SFTP_USER`, "
        "and `MUFG_SFTP_PASSWORD` env vars.\n"
        "- **Zero rows** — verify the dbt view has data for today's `sftp_date` "
        "with firms ADU/905."
    ),
)
def step_upload_to_mufg(context) -> MaterializeResult:
    from backend.src.postions_and_trades.tasks.email_sftp_files.send_clear_street_trades_to_mufg_v1_2026_feb_02 import (
        main as send_to_mufg_main,
    )

    if _is_dry_run(context):
        context.log.info("Phase 3: DRY RUN — testing MUFG SFTP connection only")
        import paramiko
        from backend import secrets

        transport = paramiko.Transport((secrets.MUFG_SFTP_HOST, secrets.MUFG_SFTP_PORT))
        try:
            transport.connect(username=secrets.MUFG_SFTP_USER, password=secrets.MUFG_SFTP_PASSWORD)
            sftp = paramiko.SFTPClient.from_transport(transport)
            context.log.info("MUFG SFTP connection OK")
            sftp.close()
        finally:
            transport.close()
    else:
        context.log.info("Phase 3: Sending filtered trades to MUFG")
        send_to_mufg_main()

    summary = azure_postgresql_utils.pull_from_db(
        query="""
        SELECT
            MAX(sftp_date)::TEXT AS latest_sftp_date,
            COUNT(*) AS row_count,
            COALESCE(SUM(quantity_cleaned), 0) AS total_qty
        FROM trades_cleaned.clear_street_trades
        WHERE give_in_out_firm_num IN ('ADU', '905')
          AND sftp_date = (SELECT MAX(sftp_date) FROM trades_cleaned.clear_street_trades)
        """
    )

    row_count = int(summary["row_count"].iloc[0])
    latest_date = str(summary["latest_sftp_date"].iloc[0])
    total_qty = float(summary["total_qty"].iloc[0])

    context.log.info(f"Sent {row_count} rows for sftp_date={latest_date} to MUFG")

    # Notify Slack only when today's trades were sent
    latest_date_parsed = datetime.strptime(latest_date, "%Y-%m-%d").date()
    if latest_date_parsed == datetime.now().date():
        now = datetime.now(MT).strftime("%a %b-%d %I:%M:%S %p MT")
        sftp_date_fmt = fmt_date(latest_date)
        message = f":white_check_mark: *Clear Street → MUFG* succeeded\nSFTP Date: `{sftp_date_fmt}`\nSent to MUFG: `{now}`\nRows: `{row_count}`"
        send_slack(message)
        context.log.info(f"Slack notification sent: {message}")

    _GROUPED_QUERY = """
        WITH TRADES AS (
            SELECT
                sftp_date,
                account_number_cleaned AS clear_street_account,
                account_name,
                exchange_name_cleaned AS exchange_name,
                product_code_grouping,
                product_code_region,
                exch_comm_cd AS exchange_code,
                is_option, put_call, strike_price,
                contract_year_month AS contract_yyyymm,
                security_description AS contract_description,
                bbg_product_code, ice_product_code,
                trade_price, settlement_price,
                quantity_cleaned AS qty
            FROM trades_cleaned.clear_street_trades
            WHERE sftp_date = {sftp_date_filter}
              AND account_name IS NOT NULL
              {firm_filter}
        )
        SELECT
            sftp_date::TEXT, clear_street_account, exchange_name,
            product_code_grouping, product_code_region, exchange_code,
            put_call, strike_price, contract_yyyymm,
            bbg_product_code, ice_product_code,
            ROUND(AVG(trade_price)::NUMERIC, 4) AS trade_price_total,
            ROUND(AVG(settlement_price)::NUMERIC, 4) AS settlement_price,
            SUM(qty) AS qty_total,
            SUM(CASE WHEN account_name = 'ACIM' THEN qty ELSE 0 END) AS qty_acim,
            SUM(CASE WHEN account_name = 'ANDY' THEN qty ELSE 0 END) AS qty_andy,
            SUM(CASE WHEN account_name = 'MAC' THEN qty ELSE 0 END) AS qty_mac,
            SUM(CASE WHEN account_name = 'PNT' THEN qty ELSE 0 END) AS qty_pnt,
            SUM(CASE WHEN account_name = 'DICKSON' THEN qty ELSE 0 END) AS qty_dickson,
            SUM(CASE WHEN account_name = 'TITAN' THEN qty ELSE 0 END) AS qty_titan
        FROM TRADES
        GROUP BY sftp_date, clear_street_account, exchange_name,
                 product_code_grouping, product_code_region, exchange_code,
                 is_option, put_call, strike_price, contract_yyyymm,
                 contract_description, bbg_product_code, ice_product_code
        ORDER BY clear_street_account, product_code_grouping,
                 product_code_region, contract_yyyymm
    """

    sftp_date_filter = f"'{latest_date}'::DATE"

    mufg_trades = azure_postgresql_utils.pull_from_db(
        query=_GROUPED_QUERY.format(
            sftp_date_filter=sftp_date_filter,
            firm_filter="AND give_in_out_firm_num IN ('ADU', '905')",
        )
    )

    all_trades = azure_postgresql_utils.pull_from_db(
        query=_GROUPED_QUERY.format(
            sftp_date_filter=sftp_date_filter,
            firm_filter="",
        )
    )

    return MaterializeResult(
        metadata={
            "row_count": row_count,
            "sftp_date": MetadataValue.text(latest_date),
            "total_qty": total_qty,
            "mufg_trades": MetadataValue.md(mufg_trades.to_markdown(index=False)),
            "all_trades": MetadataValue.md(all_trades.to_markdown(index=False)),
        }
    )
