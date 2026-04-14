# Weather (WSI)

Temperature forecasts, weighted degree days (HDD/CDD), and historical observations from the WSI Trader API. Weather is the primary driver of electricity demand, making this data essential for load forecasting and position management.

**Use this page** to find WSI scrape scripts, raw tables, and dbt views for degree-day data.

## Data Source

- **API:** WSI Trader (AG2) API
- **Authentication:** Username/password (`WSI_TRADER_USERNAME`, `WSI_TRADER_NAME`, `WSI_TRADER_PASSWORD`)
- **Shared utilities:** `backend/scrapes/wsi/utils.py` (auth, HTTP client, CSV pull helpers)
- **City ID reference:** `backend/scrapes/wsi/wsi_trader_city_ids.json`

## Domain Subfolders

| Folder | API Endpoint | Description | Scripts |
|--------|-------------|-------------|---------|
| `homepage_forecast_table/` | `GetCityTableForecast` | City-level min/max temp, avg temp, HDD/CDD forecasts | 3 |
| `hourly_forecast/` | `GetHourlyForecast` | Hourly temperature forecasts by city | 1 |
| `weighted_forecast_iso/` | `GetModelForecast` | Population-weighted temperature forecasts at ISO level | 2 |
| `weighted_degree_day/` | `GetWeightedDegreeDayForecast` | Weighted degree day forecasts from multiple weather models | 6 |
| `weighted_forecast_city/` | `GetWsiForecastForDDModelCities` | Population-weighted temperature forecasts at city level | 1 |
| `historical_observations/` | `GetHistoricalObservations` | Actual observed hourly temperatures and daily WDD | 2 |
| `natural_gas/` | TBD | Natural gas related forecasts (daily BCF) | 1 |
| `reference/` | N/A | City ID lookup table (not run on schedule) | 1 |

## Scrape Inventory

| Script | Table | Description |
|--------|-------|-------------|
| `hourly_forecast_temp_v4_2025_jan_12.py` | `wsi.hourly_forecast_temp_v4_2025_jan_12` | Hourly temperature forecast by city |
| `hourly_observed_temp_v2_2025_07_22.py` | `wsi.hourly_observed_temp_v2_20250722` | Actual observed hourly temperatures |
| `daily_observed_wdd_v1_2026_mar_06.py` | `wsi.daily_observed_wdd_v1_2026_mar_06` | Daily observed weighted degree days |
| `wsi_wdd_day_forecast_v2_2025_dec_17.py` | `wsi.wsi_wdd_day_forecast_v2_2025_dec_17` | WSI blended WDD daily forecast |
| `gfs_op_wdd_day_forecast_v2_2025_dec_17.py` | `wsi.gfs_op_wdd_day_forecast_v2_2025_dec_17` | GFS operational model WDD forecast |
| `gfs_ens_wdd_day_forecast_v2_2025_dec_17.py` | `wsi.gfs_ens_wdd_day_forecast_v2_2025_dec_17` | GFS ensemble WDD forecast |
| `ecmwf_op_wdd_day_forecast_v2_2025_dec_17.py` | `wsi.ecmwf_op_wdd_day_forecast_v2_2025_dec_17` | ECMWF operational model WDD forecast |
| `ecmwf_ens_wdd_day_forecast_v2_2025_dec_17.py` | `wsi.ecmwf_ens_wdd_day_forecast_v2_2025_dec_17` | ECMWF ensemble WDD forecast |
| `aifs_ens_wdd_day_forecast_v1_2026_feb_12.py` | `wsi.aifs_ens_wdd_day_forecast_v1_2026_feb_12` | AIFS ensemble WDD forecast |
| `weighted_temp_daily_forecast_iso_models_v2_2026_jan_12.py` | `wsi.weighted_temp_daily_forecast_iso_models_v2_2026_jan_12` | Weighted temp forecast by ISO (multiple models) |
| `weighted_temp_daily_forecast_iso_wsi_v2_2026_jan_12.py` | `wsi.weighted_temp_daily_forecast_iso_wsi_v2_2026_jan_12` | WSI blended weighted temp forecast by ISO |
| `weighted_temp_daily_forecast_city_v2_2026_jan_12.py` | `wsi.weighted_temp_daily_forecast_city_v2_2026_jan_12` | Weighted temp forecast by city |
| `wsi_homepage_forecast_table_minmax_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_minmax_v1_2026_jan_12` | City forecast table -- min/max temperatures |
| `wsi_homepage_forecast_table_hddcdd_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_hddcdd_v1_2026_jan_12` | City forecast table -- HDD/CDD values |
| `wsi_homepage_forecast_table_avg_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_avg_v1_2026_jan_12` | City forecast table -- average temperatures |
| `daily_forecast_bcf_v1_2026_mar_06.py` | `wsi.daily_forecast_bcf_v1_2026_mar_06` | Daily natural gas forecast in BCF |

## Refresh Cadence

- **Trigger:** Scheduled (Prefect via `flows.py` in each subfolder)
- **WDD forecasts:** Event-driven primary with scheduled reconciliation (see `weighted_degree_day/`)
- **Frequency:** 2--4 times daily (aligned with weather model run times)
- **Freshness:** Latest model run typically within 6--12 hours

## Key Concepts

- **Multiple weather models:** The WDD subfolder pulls from 6 different model sources (WSI blend, GFS op, GFS ens, ECMWF op, ECMWF ens, AIFS ens) to give traders a range of degree-day outlooks
- **City-level vs ISO-level:** Some data is at individual city granularity; other data is population-weighted to ISO/region level
- **Observations vs Forecasts:** Historical observations serve as the "truth" baseline for evaluating forecast accuracy

## Known Caveats

- dbt cleaned views exist for WDD (degree day) data in `wsi_cleaned` schema; other WSI data (hourly temps, city forecasts, BCF) is consumed raw
- DST transitions can cause duplicate key issues for some forecast types
- City IDs must be kept in sync with WSI's reference data

## Owner

TBD
