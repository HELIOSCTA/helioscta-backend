# EIA Cleaned dbt Views

All views are materialized in the `eia_cleaned` schema.

---

## Mart Views

### eia_930_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity generation by fuel type across all U.S. regions (60+ BAs), converted to EST |
| **Grain** | One row per date x hour_ending x respondent x fuel_type |
| **Primary Keys** | `date`, `hour_ending`, `respondent`, `fuel_type` |
| **Upstream** | `staging_v1_eia_930_hourly` |
| **Use Cases** | Track real-time generation mix by BA, gas vs coal switching analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/eia/eia_cleaned/.docs/eia_930_hourly.sql) |

### eia_930_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily average generation by fuel type and respondent with thermal % breakdowns |
| **Grain** | One row per date x respondent x fuel_type |
| **Primary Keys** | `date`, `respondent`, `fuel_type` |
| **Upstream** | `staging_v1_eia_930_daily` |
| **Use Cases** | Daily generation trend analysis, thermal mix monitoring |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/eia/eia_cleaned/.docs/eia_930_daily.sql) |

### eia_natural_gas_consumption_by_end_use_monthly

| Field | Value |
|-------|-------|
| **Business Definition** | Monthly state-level natural gas consumption pivoted by end-use sector (residential, commercial, industrial, electric power, pipeline, lease/plant fuel, vehicle fuel) |
| **Grain** | One row per year x month x area_name_standardized |
| **Primary Keys** | `year`, `month`, `area_name_standardized` |
| **Upstream** | `staging_v1_eia_ng_consumption_by_end_use_monthly` |
| **Use Cases** | Seasonal gas demand analysis by sector, state-level consumption trends, residential vs electric power demand comparison |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/eia/eia_cleaned/.docs/eia_natural_gas_consumption_by_end_use_monthly.sql) |
