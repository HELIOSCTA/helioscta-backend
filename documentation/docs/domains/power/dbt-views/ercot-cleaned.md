# ERCOT Cleaned dbt Views

All views are materialized in the `ercot_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### ercot_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly settlement point prices combining day-ahead and real-time markets for 4 hubs. Only `lmp_total` is available (no energy/congestion/loss decomposition). |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_ercot_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, hub-level price tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_lmps_hourly.sql) |

### ercot_lmps_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily average settlement point prices by hub and period (flat/onpeak/offpeak) |
| **Grain** | One row per date |
| **Primary Keys** | `date` |
| **Upstream** | `staging_v1_ercot_lmps_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_lmps_daily.sql) |

### ercot_fuel_mix_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly generation by fuel type with energy storage data |
| **Grain** | One row per date x hour_ending |
| **Primary Keys** | `date`, `hour_ending` |
| **Upstream** | `staging_v1_ercot_fuel_mix_hourly` |
| **Use Cases** | Monitor gas vs coal switching, renewable penetration, storage utilization |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_fuel_mix_hourly.sql) |

### ercot_fuel_mix_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily generation by fuel type and period (flat/onpeak/offpeak) |
| **Grain** | One row per date x period |
| **Primary Keys** | `date`, `period` |
| **Upstream** | `staging_v1_ercot_fuel_mix_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_fuel_mix_daily.sql) |

### ercot_load_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly actual load by forecast zone (total, north, south, west, houston) |
| **Grain** | One row per date x hour_ending |
| **Primary Keys** | `date`, `hour_ending` |
| **Upstream** | `source_v1_ercot_load_hourly` |
| **Use Cases** | Real-time load monitoring, zonal demand analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_load_hourly.sql) |

### ercot_load_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily load by zone and period (flat/onpeak/offpeak) |
| **Grain** | One row per date x period |
| **Primary Keys** | `date`, `period` |
| **Upstream** | `staging_v1_ercot_load_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_load_daily.sql) |

### ercot_forecasts_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Combined hourly load, solar, and wind forecasts with net load calculation, ranked by recency |
| **Grain** | One row per forecast_rank x forecast_date x hour_ending |
| **Primary Keys** | `forecast_rank`, `forecast_date`, `hour_ending` |
| **Upstream** | `staging_v1_ercot_gridstatus_forecasts_hourly` |
| **Logic** | Combines load/solar/wind forecasts; net_load = load - (solar + wind) |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_forecasts_hourly.sql) |

### ercot_forecasts_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily combined forecasts by period (flat/onpeak/offpeak) |
| **Grain** | One row per rank_forecast_execution_timestamps x forecast_date x period |
| **Primary Keys** | `rank_forecast_execution_timestamps`, `forecast_date`, `period` |
| **Upstream** | `staging_v1_ercot_gridstatus_forecasts_daily` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_forecasts_daily.sql) |

### ercot_forecasts_hourly_current

| Field | Value |
|-------|-------|
| **Business Definition** | Current (most recent) combined hourly forecasts only |
| **Grain** | One row per forecast_date x hour_ending |
| **Primary Keys** | `forecast_date`, `hour_ending` |
| **Upstream** | `staging_v1_ercot_gridstatus_forecasts_hourly_current` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_forecasts_hourly_current.sql) |

### ercot_forecasts_daily_current

| Field | Value |
|-------|-------|
| **Business Definition** | Current (most recent) daily combined forecasts by period |
| **Grain** | One row per forecast_date x period |
| **Primary Keys** | `forecast_date`, `period` |
| **Upstream** | `staging_v1_ercot_gridstatus_forecasts_daily_current` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_forecasts_daily_current.sql) |

### ercot_outages_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly reported outages (combined, dispatchable, renewable x planned/unplanned/total) |
| **Grain** | One row per date x hour_ending |
| **Primary Keys** | `date`, `hour_ending` |
| **Upstream** | `source_v1_ercot_outages_hourly` |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/ercot_cleaned/.docs/ercot_outages_hourly.sql) |

---

## Pricing Hubs

- **Houston Hub** (HB_HOUSTON) — Houston load zone
- **North Hub** (HB_NORTH) — North Texas load zone
- **South Hub** (HB_SOUTH) — South Texas load zone
- **West Hub** (HB_WEST) — West Texas load zone

## On-Peak Definition

- **onpeak** — HE07–HE22
- **offpeak** — HE01–HE06 and HE23–HE24

## Fuel Types

`nuclear`, `hydro`, `wind`, `solar`, `natural_gas`, `coal_and_lignite`, `storage_net_output`, `storage_total_charging`, `storage_total_discharging`, `other`

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- `not_null` on `date` and `hour_ending` across all models
