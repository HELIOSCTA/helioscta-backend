# Mirror of backend/grafana/dashboards/Positions and Trades/clear-street-trades-to-mufg.json
#
# All widgets query NRDB custom events emitted by the
# backend/monitoring/postions_and_trades/clear_street_eod ingest job. The
# ${sftp_date} Grafana templating variable becomes a dashboard variable of
# type NRQL that lists distinct sftp_date values from ClearStreetTrade.
#
# All NRQL filters on `environment = 'prod'` so dev runs (which stamp
# `environment = 'dev'` via base_event.py) never appear here.

resource "newrelic_one_dashboard" "clear_street_trades_to_mufg" {
  name        = "Clear Street Trades to MUFG"
  description = "End-to-end workflow monitoring: Clear Street SFTP ingest, dbt transform, and MUFG SFTP distribution."
  permissions = "public_read_write"

  variable {
    name                 = "sftp_date"
    title                = "SFTP Date"
    type                 = "nrql"
    replacement_strategy = "default"
    is_multi_selection   = false
    default_values       = ["*"]

    nrql_query {
      account_ids = [var.new_relic_account_id]
      query       = "FROM ClearStreetTrade SELECT uniques(sftp_date) WHERE environment = 'prod' SINCE 30 days ago"
    }
  }

  page {
    name = "Clear Street Trades to MUFG"

    # ───────── Workflow overview (markdown) ─────────
    widget_markdown {
      title  = ""
      row    = 1
      column = 1
      width  = 12
      height = 4

      text = <<-EOT
        ## Clear Street Trades to MUFG

        End-to-end pipeline that ingests trade files from Clear Street's SFTP server, transforms them through dbt, and sends filtered trades to MUFG via SFTP.

        ### Pipeline Phases

        | Phase | Input | Process | Output |
        |-------|-------|---------|--------|
        | **1. Ingest** | Clear Street SFTP (`Helios_Transactions_*.csv`) | SSH key auth, 5-day lookback, parse CSV, cast dtypes, upsert | `clear_street.helios_transactions_v2_2026_feb_23` |
        | **2. dbt Transform** | Raw ingestion table | source > staging (clean cols, product codes) > mart views | `trades_cleaned.clear_street_trades` + `clear_street_trades_grouped` |
        | **3. Send to MUFG** | `trades_cleaned.clear_street_trades` | Filter firms `ADU`/`905` on latest date, export CSV | MUFG SFTP (`Helios_Transactions_{YYYYMMDD}_filtered.csv`) |
      EOT
    }

    # ───────── Pipeline Runs Summary (table) ─────────
    widget_table {
      title  = "Pipeline Runs Summary"
      row    = 5
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM ClearStreetPipelineSummary
          SELECT latest(trade_date) AS 'Trade Date',
                 latest(file_released_on_sftp) AS 'Clear Street Released at SFTP',
                 latest(downloaded_at) AS 'File Downloaded',
                 latest(released_to_mufg_at) AS 'File Released to MUFG'
          WHERE environment = 'prod'
          FACET trade_date
          SINCE 14 days ago
          LIMIT 14
        EOT
      }
    }

    # ───────── Download Clear Street SFTP (table of pipeline_runs rows) ─────────
    widget_table {
      title  = "Download Clear Street SFTP"
      row    = 8
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM PipelineRun
          SELECT pipeline_name, hostname, event_timestamp, event_type, error_type, error_message
          WHERE pipeline_name = 'helios_transactions_v2_2026_feb_23'
            AND environment   = 'prod'
          SINCE 14 days ago
          LIMIT MAX
        EOT
      }
    }

    # ───────── Send to MUFG (table of pipeline_runs rows) ─────────
    widget_table {
      title  = "Send to MUFG"
      row    = 11
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM PipelineRun
          SELECT pipeline_name, hostname, event_timestamp, event_type, error_type, error_message
          WHERE pipeline_name = 'send_clear_street_trades_to_mufg_v1_2026_feb_02'
            AND environment   = 'prod'
          SINCE 14 days ago
          LIMIT MAX
        EOT
      }
    }

    # ───────── Stat: MUFG Titan Qty ─────────
    widget_billboard {
      title  = "MUFG - Titan Qty"
      row    = 14
      column = 1
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "FROM ClearStreetEodSummary SELECT latest(titan_qty_mufg) WHERE environment = 'prod' SINCE 1 day ago"
      }
    }

    # ───────── Stat: All EOD Titan Qty ─────────
    widget_billboard {
      title  = "All EOD - Titan Qty"
      row    = 14
      column = 4
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "FROM ClearStreetEodSummary SELECT latest(titan_qty_all) WHERE environment = 'prod' SINCE 1 day ago"
      }
    }

    # ───────── Stat: Titan Qty Match (1 = match, 0 = mismatch) ─────────
    widget_billboard {
      title  = "Titan Qty Match"
      row    = 14
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "FROM ClearStreetEodSummary SELECT latest(titan_qty_match) WHERE environment = 'prod' SINCE 1 day ago"
      }

      # 0 = mismatch (red), 1 = match (green)
      critical = 0.5
    }

    # ───────── Stat: Missing Product Code Grouping ─────────
    widget_billboard {
      title  = "Missing Product Code Grouping"
      row    = 14
      column = 10
      width  = 3
      height = 3

      nrql_query {
        account_id = var.new_relic_account_id
        query      = "FROM ClearStreetEodSummary SELECT latest(missing_product_code_grouping) WHERE environment = 'prod' SINCE 1 day ago"
      }

      critical = 1
    }

    # ───────── MUFG Filtered - Summary by Account ─────────
    widget_table {
      title  = "MUFG Filtered - Summary by Account"
      row    = 17
      column = 1
      width  = 12
      height = 5

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM ClearStreetTrade
          SELECT sum(quantity) AS qty_total,
                 average(trade_price) AS trade_price_avg,
                 average(settlement_price) AS settlement_price_avg
          WHERE mufg_filtered = true
            AND environment   = 'prod'
            AND sftp_date     = {{sftp_date}}
          FACET account, exchange, product_code_grouping, product_code_region
          LIMIT MAX
        EOT
      }
    }

    # ───────── All Clear Street EOD - Summary by Account ─────────
    widget_table {
      title  = "All Clear Street EOD - Summary by Account"
      row    = 22
      column = 1
      width  = 12
      height = 5

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM ClearStreetTrade
          SELECT sum(quantity) AS qty_total,
                 average(trade_price) AS trade_price_avg,
                 average(settlement_price) AS settlement_price_avg
          WHERE environment = 'prod'
            AND sftp_date   = {{sftp_date}}
          FACET account, account_name, exchange, product_code_grouping, product_code_region
          LIMIT MAX
        EOT
      }
    }

    # ───────── MUFG Filtered Trades - Detail ─────────
    widget_table {
      title  = "MUFG Filtered Trades - Detail"
      row    = 27
      column = 1
      width  = 12
      height = 6

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM ClearStreetTrade
          SELECT sftp_date, trade_date, firm, account, exchange, security_description,
                 buy_sell, quantity, trade_price, settlement_price,
                 product_code_grouping, product_code_region, ice_product_code, cme_product_code
          WHERE mufg_filtered = true
            AND environment   = 'prod'
            AND sftp_date     = {{sftp_date}}
          LIMIT MAX
        EOT
      }
    }

    # ───────── All Clear Street EOD Trades - Detail ─────────
    widget_table {
      title  = "Clear Street EOD Trades - Detail"
      row    = 33
      column = 1
      width  = 12
      height = 6

      nrql_query {
        account_id = var.new_relic_account_id
        query      = <<-EOT
          FROM ClearStreetTrade
          SELECT sftp_date, trade_date, firm, account, account_name, exchange, security_description,
                 buy_sell, quantity, trade_price, settlement_price,
                 product_code_grouping, product_code_region, ice_product_code, cme_product_code
          WHERE environment = 'prod'
            AND sftp_date   = {{sftp_date}}
          LIMIT MAX
        EOT
      }
    }
  }
}
