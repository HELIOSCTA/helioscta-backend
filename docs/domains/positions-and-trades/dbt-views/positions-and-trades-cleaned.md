# Positions & Trades Cleaned dbt Views

## Positions Cleaned (`positions_cleaned` schema)

### Architecture

```
Raw position files (marex.*, nav.* schemas)
    -> Source (ephemeral, select from raw)
    -> NAV staging (combine 4 NAV fund tables, add product lookup)
    -> Combined staging (union Marex + NAV, forward fill, add columns, exchange codes)
    -> Mart view
```

### Mart Views (8 total)

#### marex_and_nav_positions_grouped

| Field | Value |
|-------|-------|
| **Business Definition** | Aggregated positions by exchange, contract, and account across Marex + NAV |
| **Grain** | One row per sftp_date x exchange_code x is_option x put_call x strike_price x contract_yyyymm |
| **Primary Keys** | `sftp_date`, `exchange_code`, `is_option`, `put_call`, `strike_price`, `contract_yyyymm` |
| **Materialization** | TABLE (not a view) |
| **Upstream** | `staging_v5_marex_and_nav_positions` |
| **Use Cases** | Daily position reconciliation, risk monitoring, fund-level exposure tracking |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |

#### marex_and_nav_positions_grouped_latest

| Field | Value |
|-------|-------|
| **Business Definition** | Latest-date positions with day-over-day quantity and P&L changes |
| **Grain** | Same as grouped, filtered to most recent date (7-day lookback window) |
| **Key Columns** | Includes `daily_change_total`, `daily_pnl_total`, `previous_sftp_date` |
| **Upstream** | `marex_and_nav_positions_grouped` |
| **Use Cases** | Morning position review, daily P&L attribution |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |

#### Individual Fund Views

| View | Description | SQL |
|------|-------------|-----|
| `marex_positions` | Marex-only positions (latest SFTP upload per date) | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |
| `nav_positions` | Combined NAV positions across all funds | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |
| `nav_positions_agr` | AGR fund positions with product codes | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |
| `nav_positions_moross` | Moross fund positions with product codes | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |
| `nav_positions_pnt` | PNT fund positions with product codes | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |
| `nav_positions_titan` | Titan fund positions with product codes | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/positions_cleaned/marts/docs/reference.sql) |

### Staging Pipeline (4 steps)

| Step | Model | What It Does |
|------|-------|--------------|
| 1 | `staging_v5_marex_and_nav_positions_1_combined` | Unions Marex positions with the cleaned NAV positions |
| 2 | `staging_v5_marex_and_nav_positions_2_forward_fill` | Fills in missing dates (assumes position unchanged if no file for that date) |
| 3 | `staging_v5_marex_and_nav_positions_3_add_cols` | Adds derived fields like product descriptions and categories |
| 4 | `staging_v5_marex_and_nav_positions_4_exchange_codes` | Standardizes exchange code formatting |

### NAV Sub-Pipeline (2 steps)

| Step | Model | What It Does |
|------|-------|--------------|
| 1 | `staging_v5_nav_positions_1_combined` | Unions the 4 NAV fund tables (AGR, Moross, PNT, Titan) |
| 2 | `staging_v5_nav_positions_2_product_lookup` | Maps raw product symbols to standardized codes using the product lookup table |

---

## Trades Cleaned (`trades_cleaned` schema)

### Architecture

```
Raw trade files (clear_street.*, marex.* schemas)
    -> Source (ephemeral)
    -> Staging (add columns, product codes)
    -> Mart views
```

### Mart Views (6 total)

#### Detail Views (one row per trade)

| View | Description | Upstream | SQL |
|------|-------------|----------|-----|
| `clear_street_trades` | End-of-day trade confirmations with product codes | `staging_v2_clear_street_trades_2_product_codes` | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |
| `clear_street_intraday_trades` | Intraday trade confirmations with product codes | `staging_v2_clear_street_intraday_2_product_codes` | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |
| `marex_allocated_trades` | Allocated (cleared) Marex trades with product codes | `staging_v2_marex_allocated_trades_2_product_codes` | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |

#### Grouped Views (aggregated by product/contract)

| View | Description | SQL |
|------|-------------|-----|
| `clear_street_trades_grouped` | Daily Clear Street trades aggregated by product code grouping and region | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |
| `clear_street_intraday_trades_grouped` | Intraday Clear Street trades aggregated by product grouping | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |
| `marex_allocated_trades_grouped` | Marex allocated trades aggregated by product grouping and region | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/positions_and_trades/trades_cleaned/marts/docs/reference.sql) |

### Trade Staging Pipeline (2 steps each)

Each trade type goes through:
1. **Add columns** -- Adds derived fields (trade date, settlement date, etc.)
2. **Product codes** -- Maps raw symbols to standardized product codes using the product lookup table

---

## Reference Tables (in `dbt` schema)

| Table | Description |
|-------|-------------|
| `source_v1_positions_and_trades_product_lookup` | Maps raw product symbols to standardized product names, codes, and categories |
| `source_v1_positions_and_trades_accounts_lookup` | Maps account IDs to human-readable fund names |
| `source_v1_positions_and_trades_traders_lookup` | Maps trader IDs to trader names |

---

## Utility Tables

| Table | Description |
|-------|-------------|
| `utils_v1_nerc_holidays` | NERC (North American Electric Reliability Corporation) holidays for business day calculations |
