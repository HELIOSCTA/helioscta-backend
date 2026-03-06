# PJM Cleaned dbt Views

All views are materialized in the `pjm_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### pjm_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity prices (LMPs) combining day-ahead and real-time markets |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_pjm_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, node-level price tracking, congestion analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_lmps_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily average electricity prices by pricing node and period (flat/onpeak/offpeak) |
| **Grain** | One row per date x hub x period x market |
| **Primary Keys** | `date`, `hub`, `period`, `market` |
| **Upstream** | `staging_v1_pjm_lmps_daily` |
| **Use Cases** | Daily price trend analysis, settlement reconciliation |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_lmps_rt_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Real-time only hourly LMPs, combining verified and unverified |
| **Grain** | One row per date x hour_ending x hub |
| **Primary Keys** | `date`, `hour_ending`, `hub` |
| **Upstream** | `staging_v1_pjm_lmps_rt_hourly` |
| **Logic** | Uses verified prices when available; falls back to unverified for recent data |
| **Use Cases** | Real-time price monitoring, intraday P&L |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_da_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Day-ahead cleared load by region (from demand bids) |
| **Grain** | One row per date x hour_ending x region |
| **Primary Keys** | `date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_pjm_load_da_hourly` |
| **Use Cases** | Expected next-day demand, DA load vs actual comparison |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_da_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily day-ahead cleared load by region and period (flat/peak/onpeak/offpeak) |
| **Grain** | One row per date x region x period |
| **Primary Keys** | `date`, `region`, `period` |
| **Upstream** | `staging_v1_pjm_load_da_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_rt_metered_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Actual metered load by region |
| **Grain** | One row per date x hour_ending x region |
| **Primary Keys** | `date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_pjm_load_rt_metered_hourly` |
| **Use Cases** | Ground truth load for forecast accuracy, settlement |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_rt_metered_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily metered load by region and period (flat/peak/onpeak/offpeak) |
| **Grain** | One row per date x region x period |
| **Primary Keys** | `date`, `region`, `period` |
| **Upstream** | `staging_v1_pjm_load_rt_metered_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_rt_prelim_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Preliminary real-time load by region (available same-day, ~1 hour lag) |
| **Grain** | One row per date x hour_ending x region |
| **Primary Keys** | `date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_pjm_load_rt_prelim_hourly` |
| **Use Cases** | Intraday load tracking before metered data is available |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_rt_prelim_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily preliminary load by region and period (flat/peak/onpeak/offpeak) |
| **Grain** | One row per date x region x period |
| **Primary Keys** | `date`, `region`, `period` |
| **Upstream** | `staging_v1_pjm_load_rt_prelim_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_rt_instantaneous_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly average of 5-minute instantaneous load |
| **Grain** | One row per date x hour_ending x region |
| **Primary Keys** | `date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_pjm_load_rt_instantaneous_hourly` |
| **Logic** | Aggregates 5-min readings to hourly averages |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | PJM's official 7-day hourly load forecast by area, ranked by recency |
| **Grain** | One row per forecast_rank x forecast_date x hour_ending x region |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_pjm_load_forecast_hourly` |
| **Logic** | Ranks forecasts by recency (DENSE_RANK); filters to complete 24h forecasts only |
| **Use Cases** | Compare against Meteologica/trader forecasts, anticipate demand |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_load_forecast_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily load forecast by region and period (flat/peak/onpeak/offpeak), holiday-aware |
| **Grain** | One row per forecast_rank x forecast_date x region x period |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `region`, `period` |
| **Upstream** | `staging_v1_pjm_load_forecast_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_gridstatus_load_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Load forecast sourced from GridStatus (alternative to PJM direct), ranked by recency |
| **Grain** | One row per forecast_rank x forecast_date x hour_ending x region |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_gridstatus_pjm_load_forecast_hourly` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_fuel_mix_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity generation by fuel type (total, thermal, renewables) |
| **Grain** | One row per date x hour_ending |
| **Primary Keys** | `date`, `hour_ending` |
| **Upstream** | `staging_v1_pjm_fuel_mix_hourly` |
| **Use Cases** | Monitor gas vs coal switching, renewable penetration |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_fuel_mix_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily generation by fuel type and period (flat/peak/onpeak/offpeak) |
| **Grain** | One row per date x period |
| **Primary Keys** | `date`, `period` |
| **Upstream** | `staging_v1_pjm_fuel_mix_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_outages_actual_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Actual daily generation outages by type (planned, maintenance, forced) |
| **Grain** | One row per date x region |
| **Primary Keys** | `date`, `region` |
| **Upstream** | `staging_v1_pjm_outages_actual_daily` |
| **Use Cases** | Track supply availability, compare actual vs forecast outages |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_outages_forecast_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Forecasted daily generation outages, ranked by recency (7-day lookback) |
| **Grain** | One row per forecast_rank x forecast_execution_date x forecast_date x region |
| **Primary Keys** | `forecast_rank`, `forecast_execution_date`, `forecast_date`, `region` |
| **Upstream** | `staging_v1_pjm_outages_forecast_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_tie_flows_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly tie flows between PJM and neighboring regions |
| **Grain** | One row per date x hour_ending x tie_flow_name |
| **Primary Keys** | `date`, `hour_ending`, `tie_flow_name` |
| **Upstream** | `staging_v1_pjm_tie_flows_hourly` |
| **Use Cases** | Import/export tracking, cross-ISO flow analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_tie_flows_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily net tie flows by interface and period (flat/onpeak/offpeak) |
| **Grain** | One row per date x tie_flow_name x period |
| **Primary Keys** | `date`, `tie_flow_name`, `period` |
| **Upstream** | `staging_v1_pjm_tie_flows_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_solar_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | PJM solar generation forecast (front-of-meter and behind-the-meter), ranked by recency |
| **Grain** | One row per forecast_rank x forecast_date x hour_ending |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `hour_ending` |
| **Upstream** | `staging_v1_pjm_solar_forecast_hourly` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

### pjm_wind_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | PJM wind generation forecast, ranked by recency |
| **Grain** | One row per forecast_rank x forecast_date x hour_ending |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `hour_ending` |
| **Upstream** | `staging_v1_pjm_wind_forecast_hourly` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/pjm_cleaned/marts/docs/reference.sql) |

---

## Query Views (Analysis Helpers)

These are intermediate analysis views in the `pjm_cleaned` schema:

| View | Purpose |
|------|---------|
| `query_v1_pjm_load_actual_vs_forecast` | Compares actual load against PJM's forecast for accuracy tracking |
| `query_v1_pjm_load_forecast_performance_daily` | Daily forecast error metrics |
| `query_v1_pjm_load_forecast_performance_hourly` | Hourly forecast error metrics |

## Utility Models

| Model | Purpose |
|-------|---------|
| `utils_v1_pjm_load_regions` | Maps load areas to PJM regions (MIDATL, WEST, SOUTH) |
| `utils_v1_pjm_dates_daily` | Date spine for daily models |
| `utils_v1_pjm_dates_hourly` | Date spine for hourly models |

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- Exposures defined in `exposures.yml` for downstream dashboard dependencies
