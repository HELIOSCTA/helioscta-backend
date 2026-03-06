# WSI Cleaned dbt Views

All views are in the `wsi_cleaned` schema. Covers weighted degree day (WDD) data from WSI (The Weather Company).

## Architecture

```
Raw WSI tables (wsi schema)
    -> Source (ephemeral, select/cast)
    -> Staging (ephemeral, clean/rank/complete)
    -> Mart views/tables
```

---

## Mart Views

### wdd_observed

| Field | Value |
|-------|-------|
| **Business Definition** | Historical daily observed weighted degree days by region |
| **Grain** | One row per date x region |
| **Primary Keys** | `date`, `region` |
| **Upstream** | `source_v1_daily_observed_wdd` |
| **Key Columns** | `date`, `region`, `electric_cdd`, `electric_hdd`, `gas_cdd`, `gas_hdd`, `population_cdd`, `population_hdd` |
| **Use Cases** | Weather normalization, degree day tracking, historical baseline |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/wsi/wsi_cleaned/marts/docs/reference.sql) |

### wdd_normals

| Field | Value |
|-------|-------|
| **Business Definition** | 10-year and 30-year WDD normals/min/max/stddev by calendar day and region. Feb 29 folded into Feb 28. |
| **Grain** | One row per mm_dd x region |
| **Primary Keys** | `mm_dd`, `region` |
| **Materialization** | TABLE (full scan of 30-year history each run) |
| **Upstream** | `source_v1_daily_observed_wdd` |
| **Key Columns** | `mm_dd`, `month`, `region`, plus 70 aggregated columns (10yr/30yr normals, min, max, stddev for electric_cdd, electric_hdd, gas_cdd, gas_hdd, population_cdd, population_hdd, tdd) |
| **Logic** | TDD = gas_hdd + population_cdd |
| **Use Cases** | Anomaly detection, weather vs normal comparisons |
| **Refresh** | Full table rebuild on each dbt run |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/wsi/wsi_cleaned/marts/docs/reference.sql) |

### wdd_forecast_models

| Field | Value |
|-------|-------|
| **Business Definition** | WDD forecasts from individual NWP models (GFS_OP, GFS_ENS, ECMWF_OP, ECMWF_ENS) at 00Z and 12Z cycles, ranked by recency |
| **Grain** | One row per forecast_execution_datetime x forecast_date x model x cycle x bias_corrected x region |
| **Primary Keys** | `rank_forecast_execution_timestamps`, `forecast_execution_datetime`, `forecast_execution_date`, `cycle`, `forecast_date`, `model`, `bias_corrected`, `region` |
| **Upstream** | `staging_v1_wdd_forecast_2_complete` |
| **Key Columns** | `rank_forecast_execution_timestamps`, `labelled_forecast_execution_timestamp`, `forecast_execution_datetime`, `cycle`, `forecast_date`, `model`, `bias_corrected`, `region`, `tdd`, `gas_hdd`, `pw_cdd` |
| **Logic** | Ranks forecasts by recency; labels: "Current Forecast" (rank 1), "12hrs Ago" (rank 2), "24hrs Ago" (rank 3), "Friday 12z" (special logic for DOW=5, hour=12) |
| **Use Cases** | Model comparison, forecast vintage analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/wsi/wsi_cleaned/marts/docs/reference.sql) |

### wdd_forecast_wsi

| Field | Value |
|-------|-------|
| **Business Definition** | WSI blended WDD forecast (proprietary blend of NWP models), ranked by recency |
| **Grain** | One row per forecast_execution_datetime x forecast_date x bias_corrected x region |
| **Primary Keys** | `rank_forecast_execution_timestamps`, `forecast_execution_datetime`, `forecast_execution_date`, `forecast_date`, `model`, `bias_corrected`, `region` |
| **Upstream** | `staging_v1_wdd_forecast_2_complete` |
| **Key Columns** | `rank_forecast_execution_timestamps`, `labelled_forecast_execution_timestamp`, `forecast_execution_datetime`, `forecast_date`, `model`, `bias_corrected`, `region`, `tdd`, `gas_hdd`, `pw_cdd` |
| **Logic** | Filters to model = 'WSI' only; labels: "Current Forecast" (rank 1), "24hrs Ago" (rank 2), "Friday 12z" (DOW=5) |
| **Use Cases** | Primary weather forecast for trading decisions, degree day outlook |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/wsi/wsi_cleaned/marts/docs/reference.sql) |

---

## Data Quality

- Schema tests defined in `schema.yml` for primary keys (`dbt_utils.unique_combination_of_columns`) and not-null constraints
- `wdd_normals` uses a validated unique combination test on (`mm_dd`, `region`)
