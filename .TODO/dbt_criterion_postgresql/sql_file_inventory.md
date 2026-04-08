# SQL File Inventory — Criterion PostgreSQL

> Generated: 2026-03-12
> Source: `.refactor/dbt_criterion_postgresql/`

## Summary

| Metric | Count |
|--------|-------|
| Total SQL files | 10 |
| PostgreSQL-targeted | 4 |
| Snowflake-targeted | 5 |
| Metadata/exploratory | 1 |
| Modules covered | 3 (L48 Supply/Demand, LNG, Production) |

## File Inventory

### 1. Metadata

| # | File Path | Purpose | Main Tables/Functions | Status |
|---|-----------|---------|----------------------|--------|
| 1 | `.data_series/Criterion Metadata.sql` | Explore ticker metadata (filtered to LNG export tickers) | `data_series.financial_metadata` | `legacy` — exploratory query, not a model candidate |

### 2. L48 Supply & Demand (Snowflake only)

| # | File Path | Purpose | Main Tables/Functions | Status |
|---|-----------|---------|----------------------|--------|
| 2 | `l48_supply_demand_v1_2026_jan_05/snowflake/source/criterion_l48_supply_demand.sql` | Daily L48 natural gas supply/demand balance (13 tickers: production, imports, demand categories, LNG, Mexican exports) | `data_series.FLATTEN_JSON_TICKERS()` | `active candidate` — core model, needs PG port |
| 3 | `l48_supply_demand_v1_2026_jan_05/snowflake/source/criterion_l48_supply_demand_dates.sql` | Full date dimension (2010+) with NERC holidays, EIA storage weeks, seasonal flags | None (self-generated) | `active candidate` — utility model |
| 4 | `l48_supply_demand_v1_2026_jan_05/snowflake/source/sources_v1_dates_daily.sql` | Filtered date dimension (2020+) — simplified variant of #3 | None (self-generated) | `deprecated/unclear` — overlaps with #3, likely superseded |

### 3. LNG Module

| # | File Path | Purpose | Main Tables/Functions | Status |
|---|-----------|---------|----------------------|--------|
| 5 | `lng_v1_2026_jan_05/postgres/source/source_v1_criterion_freeport.sql` | Freeport LNG detail — feed gas, implied flows, intrastate receipts. Combines ticker data with pipeline nominations. | `data_series.fin_json_to_excel_tickers()`, `pipelines.nomination_points`, `pipelines.metadata`, `pipelines.regions` | `active candidate` — unique model (PG native) |
| 6 | `lng_v1_2026_jan_05/postgres/source/source_v1_criterion_lng_facilities.sql` | All 9 US LNG facilities — individual + Gulf/East Coast regional aggregations (7-day window) | `data_series.FLATTEN_JSON_TICKERS()` | `active candidate` — PG variant |
| 7 | `lng_v1_2026_jan_05/postgres/source/source_v1_criterion_lng_total.sql` | Near-term LNG forecast/actuals (7-day lookback, 1-day ahead). Same structure as #6 but filtered to latest report_date. | `data_series.fin_json_to_excel_tickers()` | `active candidate` — PG variant |
| 8 | `lng_v1_2026_jan_05/snowflake/source/source_v1_criterion_lng_facilities.sql` | Snowflake equivalent of #6 (identical logic, adapted syntax) | `data_series.FLATTEN_JSON_TICKERS()` | `deprecated/unclear` — SF duplicate, PG version is target |

### 4. Production Module

| # | File Path | Purpose | Main Tables/Functions | Status |
|---|-----------|---------|----------------------|--------|
| 9 | `prod_v1_2026_jan_05/postgres/source/source_v1_criterion_prod.sql` | Natural gas production by region/sub-region (38 tickers → 36 output columns). L48 total, 8 regions, South Central + Rockies sub-region breakdowns. From 2010. | `data_series.fin_json_to_excel_tickers()` | `active candidate` — PG variant |
| 10 | `prod_v1_2026_jan_05/snowflake/source/source_v1_criterion_prod.sql` | Snowflake equivalent of #9 | `data_series.FLATTEN_JSON_TICKERS()` | `deprecated/unclear` — SF duplicate, PG version is target |

## Decision: PostgreSQL as Target

Since the dbt project targets Azure PostgreSQL (`dbt_azure_postgresql`), all Snowflake-only queries need PostgreSQL ports. The 4 PostgreSQL files are direct migration candidates. The 3 Snowflake-only files (#2, #3, #4) need function and syntax translation.

## Status Legend

| Status | Meaning |
|--------|---------|
| `active candidate` | Ready for migration into `criterion_cleaned` dbt model layer |
| `deprecated/unclear` | Superseded by another file or purpose unclear — review before migrating |
| `legacy` | Exploratory/ad-hoc query, not intended as a repeatable model |
