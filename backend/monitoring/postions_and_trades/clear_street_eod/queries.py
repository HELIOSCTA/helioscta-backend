"""SQL queries lifted from the Grafana ``clear-street-trades-to-mufg`` dashboard.

Each constant maps 1:1 to a panel or alert that previously executed against
PostgreSQL at render time inside Grafana. The ``backend.monitoring`` ingest
job runs these on a schedule, shapes the rows into NR custom events via
``events.py``, and POSTs them to NR's Event API. New Relic dashboards then
read from NRDB instead of Postgres.

Provenance — to verify or update a query:
  - Dashboard panels: ``backend/grafana/dashboards/Positions and Trades/clear-street-trades-to-mufg.json``
  - Alert SQL:        ``backend/grafana/provisioning/alerting/rules.yaml``

The ``${sftp_date}`` Grafana templating variable becomes a Python parameter
that is interpolated into the SQL via ``%s`` placeholders. This module returns
``(sql, params)`` tuples so callers can use parameterised execution and avoid
string-concatenation injection.
"""

from __future__ import annotations

# ──────────────────────────────────────────────────────────────────────────
# Variable population — what dates to scrape
# ──────────────────────────────────────────────────────────────────────────

# Drives the dashboard variable. Today + the most recent 30 distinct sftp_dates
# from the MUFG-filtered trades view (firms ADU/905). Identical to the panel
# JSON ``templating.list[0].query``.
SFTP_DATE_OPTIONS = """
    SELECT CURRENT_DATE::TEXT AS sftp_date
    UNION
    SELECT DISTINCT sftp_date::TEXT
    FROM trades_cleaned.clear_street_trades
    WHERE give_in_out_firm_num IN ('ADU', '905')
    ORDER BY sftp_date DESC
    LIMIT 30;
"""


# ──────────────────────────────────────────────────────────────────────────
# Pipeline run timing — "Pipeline Runs Summary" panel
# ──────────────────────────────────────────────────────────────────────────

PIPELINE_RUNS_SUMMARY = """
    WITH sftp_files AS (
        SELECT CAST(trade_date_from_sftp AS DATE) AS trade_date,
               MAX(sftp_upload_timestamp)         AS file_released_on_sftp
          FROM clear_street.helios_transactions_v2_2026_feb_23
         GROUP BY CAST(trade_date_from_sftp AS DATE)
    ),
    sftp_downloads AS (
        SELECT event_timestamp AS downloaded_at
          FROM logging.pipeline_runs
         WHERE pipeline_name = 'helios_transactions_v2_2026_feb_23'
           AND event_type    = 'RUN_SUCCESS'
    ),
    mufg_releases AS (
        SELECT event_timestamp AS released_to_mufg_at
          FROM logging.pipeline_runs
         WHERE pipeline_name = 'send_clear_street_trades_to_mufg_v1_2026_feb_02'
           AND event_type    = 'RUN_SUCCESS'
    )
    SELECT sf.trade_date,
           sf.file_released_on_sftp,
           dl.downloaded_at,
           mr.released_to_mufg_at
      FROM sftp_files sf
      LEFT JOIN LATERAL (
          SELECT downloaded_at FROM sftp_downloads
           WHERE downloaded_at >= sf.file_released_on_sftp
           ORDER BY downloaded_at ASC LIMIT 1
      ) dl ON TRUE
      LEFT JOIN LATERAL (
          SELECT released_to_mufg_at FROM mufg_releases
           WHERE released_to_mufg_at >= dl.downloaded_at
           ORDER BY released_to_mufg_at ASC LIMIT 1
      ) mr ON TRUE
     ORDER BY sf.file_released_on_sftp DESC
     LIMIT 14;
"""

# Raw pipeline_runs rows for the two pipelines we care about, last 14 days.
# Replaces the per-date "Download Clear Street SFTP" and "Send to MUFG" tables
# in Grafana — those filtered by ${sftp_date}; here we ingest a wider window
# and let NRQL filter at query time.
PIPELINE_RUNS_RECENT = """
    SELECT run_id,
           pipeline_name,
           hostname,
           event_type,
           event_timestamp,
           duration_seconds,
           status,
           error_type,
           error_message,
           rows_processed,
           files_processed
      FROM logging.pipeline_runs
     WHERE pipeline_name IN (
               'helios_transactions_v2_2026_feb_23',
               'send_clear_street_trades_to_mufg_v1_2026_feb_02'
           )
       AND event_timestamp >= NOW() - INTERVAL '14 days'
     ORDER BY event_timestamp DESC;
"""


# ──────────────────────────────────────────────────────────────────────────
# Stat panels (one row per metric, latest sftp_date with MUFG-eligible trades)
# ──────────────────────────────────────────────────────────────────────────

LATEST_MUFG_SFTP_DATE = """
    SELECT MAX(sftp_date) AS sftp_date
      FROM trades_cleaned.clear_street_trades
     WHERE give_in_out_firm_num IN ('ADU', '905');
"""

TITAN_QTY_MUFG = """
    SELECT COALESCE(SUM(quantity_cleaned), 0) AS titan_qty_mufg
      FROM trades_cleaned.clear_street_trades
     WHERE give_in_out_firm_num IN ('ADU', '905')
       AND sftp_date     = %(sftp_date)s::DATE
       AND account_name  = 'TITAN';
"""

TITAN_QTY_ALL_EOD = """
    SELECT COALESCE(SUM(quantity_cleaned), 0) AS titan_qty_all
      FROM trades_cleaned.clear_street_trades
     WHERE sftp_date    = %(sftp_date)s::DATE
       AND account_name = 'TITAN';
"""

MISSING_PRODUCT_CODE_GROUPING = """
    SELECT COUNT(*) AS missing_count
      FROM trades_cleaned.clear_street_trades
     WHERE sftp_date              = %(sftp_date)s::DATE
       AND (product_code_grouping IS NULL OR product_code_grouping = '')
       AND give_in_out_firm_num IN ('ADU', '905');
"""


# ──────────────────────────────────────────────────────────────────────────
# Trade detail tables (MUFG-filtered + all EOD) for the latest sftp_date
# ──────────────────────────────────────────────────────────────────────────

MUFG_FILTERED_TRADES_DETAIL = """
    SELECT sftp_date,
           trade_date,
           give_in_out_firm_num     AS firm,
           account_number_cleaned   AS account,
           account_name,
           exchange_name_cleaned    AS exchange,
           security_description,
           buy_sell_cleaned         AS buy_sell,
           quantity_cleaned         AS quantity,
           trade_price,
           settlement_price,
           product_code_grouping,
           product_code_region,
           ice_product_code,
           cme_product_code
      FROM trades_cleaned.clear_street_trades
     WHERE give_in_out_firm_num IN ('ADU', '905')
       AND sftp_date = %(sftp_date)s::DATE
     ORDER BY product_code_grouping, product_code_region, security_description;
"""

ALL_EOD_TRADES_DETAIL = """
    SELECT sftp_date,
           trade_date,
           give_in_out_firm_num     AS firm,
           account_number_cleaned   AS account,
           account_name,
           exchange_name_cleaned    AS exchange,
           security_description,
           buy_sell_cleaned         AS buy_sell,
           quantity_cleaned         AS quantity,
           trade_price,
           settlement_price,
           product_code_grouping,
           product_code_region,
           ice_product_code,
           cme_product_code
      FROM trades_cleaned.clear_street_trades
     WHERE sftp_date = %(sftp_date)s::DATE
     ORDER BY product_code_grouping, product_code_region, security_description;
"""


# ──────────────────────────────────────────────────────────────────────────
# Alert source: has today's Clear Street EOD file landed on SFTP?
# ──────────────────────────────────────────────────────────────────────────
#
# Provenance: ``backend/grafana/provisioning/alerting/rules.yaml`` rule
# ``cs-eod-file-detected``. The raw clear_street.helios_transactions_v2_*
# table is queried (NOT logging.pipeline_runs) because the pull task writes
# RUN_SUCCESS rows on every scheduled run regardless of whether a file
# arrived. The presence of a row with today's trade_date_from_sftp is the
# only direct, deduped signal that today's file has been ingested.
EOD_FILE_LANDED_TODAY = """
    SELECT (NOW() AT TIME ZONE 'America/Denver')::date AS check_date,
           COUNT(*)::int                                AS detected_rows
      FROM clear_street.helios_transactions_v2_2026_feb_23
     WHERE CAST(trade_date_from_sftp AS DATE)
           = (NOW() AT TIME ZONE 'America/Denver')::date;
"""
