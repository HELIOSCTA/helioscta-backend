# Meteologica Cleaned dbt Views

All views are in the `meteologica_cleaned` schema. Covers PJM forecasts, observations, normals, and projections.

## Architecture

```
Raw Meteologica tables (meteologica schema, ~234 PJM tables)
    -> Staging (9 ephemeral models, union + clean)
    -> Mart views (9 views, materialized as views)
```

---

## Mart Views

### meteologica_pjm_demand_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Meteologica's hourly demand forecasts for PJM, covering RTO-level and all sub-regions |
| **Grain** | One row per forecast_execution_datetime x forecast_date x hour_ending x region |
| **Primary Keys** | `forecast_rank`, `forecast_execution_datetime`, `forecast_execution_date`, `forecast_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_demand_forecast_hourly` (36 source tables) |
| **Use Cases** | Compare against PJM's own load forecast, identify demand surprises |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_demand_forecast_hourly.sql) |

**Regions covered:** PJM RTO, Mid-Atlantic (total + 17 utilities: AE, BC, DPL, JC, ME, PE, PEP, PL, PN, PS, RECO, etc.), South (DOM), West (14 utilities: AEP, AP, ATSI, CE, DAY, DEOK, DUQ, EKPC, etc.)

### meteologica_pjm_generation_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Meteologica's hourly generation forecasts for PJM solar, wind, and hydro |
| **Grain** | One row per forecast_execution_datetime x forecast_date x hour_ending x source x region |
| **Primary Keys** | `forecast_rank`, `forecast_execution_datetime`, `forecast_execution_date`, `forecast_date`, `hour_ending`, `source`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_gen_forecast_hourly` (14 source tables) |
| **Use Cases** | Renewable generation outlook, net load forecasting |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_generation_forecast_hourly.sql) |

**Generation types:** Solar (PV), Wind, Hydro at RTO, regional (Mid-Atlantic, South, West), and utility level

### meteologica_pjm_da_price_forecast_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Meteologica's hourly day-ahead price forecasts for PJM system and 12 trading hubs |
| **Grain** | One row per forecast_execution_datetime x forecast_date x hour_ending x hub |
| **Primary Keys** | `forecast_rank`, `forecast_execution_datetime`, `forecast_execution_date`, `forecast_date`, `hour_ending`, `hub` |
| **Upstream** | `staging_v1_meteologica_pjm_da_price_forecast_hourly` (13 source tables) |
| **Use Cases** | Independent price signals for DA trading, compare against actual DA LMPs |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_da_price_forecast_hourly.sql) |

**Hubs covered:** System, AEP Dayton, AEP Gen, ATSI Gen, Chicago Gen, Chicago, Dominion, Eastern, New Jersey, N Illinois, Ohio, Western, West Int

### meteologica_pjm_demand_forecast_ecmwf_ens_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Meteologica's ECMWF-ENS ensemble hourly demand forecasts for PJM, covering RTO-level and all sub-regions |
| **Grain** | One row per forecast_execution_datetime x forecast_date x hour_ending x region |
| **Primary Keys** | `forecast_rank`, `forecast_execution_datetime`, `forecast_execution_date`, `forecast_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_meteo_pjm_demand_fcst_ecmwf_ens_hourly` (36 source tables) |
| **Use Cases** | Ensemble-based demand outlook, compare against deterministic forecasts and actuals |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_demand_forecast_ecmwf_ens_hourly.sql) |

**Regions covered:** Same 36 regions as the standard demand forecast (PJM RTO, Mid-Atlantic + 17 utilities, South + DOM, West + 14 utilities)

### meteologica_pjm_demand_observation

| Field | Value |
|-------|-------|
| **Business Definition** | Actual observed hourly demand for PJM across all sub-regions, sourced from Meteologica |
| **Grain** | One row per update_rank x observation_date x hour_ending x region |
| **Primary Keys** | `update_rank`, `observation_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_demand_observation` (36 source tables) |
| **Use Cases** | Forecast accuracy analysis, compare Meteologica observations against PJM actuals |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_demand_observation.sql) |

**Regions covered:** 36 regions -- PJM RTO, Mid-Atlantic (total + 17 utilities), South (total + DOM), West (total + 14 utilities)

### meteologica_pjm_generation_observation

| Field | Value |
|-------|-------|
| **Business Definition** | Actual observed hourly generation for PJM solar, wind, and hydro across regions |
| **Grain** | One row per update_rank x observation_date x hour_ending x source x region |
| **Primary Keys** | `update_rank`, `observation_date`, `hour_ending`, `source`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_generation_observation` (9 source tables) |
| **Use Cases** | Renewable generation actuals, forecast accuracy backtesting |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_generation_observation.sql) |

**Sources covered:** Solar (RTO, Mid-Atlantic, West, South), Wind (RTO, Mid-Atlantic, South, West), Hydro (RTO)

### meteologica_pjm_da_price_observation

| Field | Value |
|-------|-------|
| **Business Definition** | Actual observed hourly day-ahead prices for PJM system and 12 trading hubs |
| **Grain** | One row per update_rank x observation_date x hour_ending x hub |
| **Primary Keys** | `update_rank`, `observation_date`, `hour_ending`, `hub` |
| **Upstream** | `staging_v1_meteologica_pjm_da_price_observation` (13 source tables) |
| **Use Cases** | Price forecast accuracy analysis, compare Meteologica observed prices against PJM settlement |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_da_price_observation.sql) |

**Hubs covered:** System, AEP Dayton, AEP Gen, ATSI Gen, Chicago Gen, Chicago, Dominion, Eastern, New Jersey, N Illinois, Ohio, Western, West Int

### meteologica_pjm_demand_projection_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Meteologica's extended hourly demand projections for PJM, based on blended models |
| **Grain** | One row per update_rank x projection_date x hour_ending x region |
| **Primary Keys** | `update_rank`, `projection_date`, `hour_ending`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_demand_projection_hourly` (33 source tables) |
| **Use Cases** | Extended demand outlook beyond standard forecast horizon, seasonal planning |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_demand_projection_hourly.sql) |

**Regions covered:** 33 regions -- PJM RTO + 32 utility-level sub-regions (no macro aggregates like Mid-Atlantic, South, West totals)

### meteologica_pjm_generation_normal_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Historical average (normal) hourly generation for PJM solar, wind, and hydro |
| **Grain** | One row per update_rank x normal_date x hour_ending x source x region |
| **Primary Keys** | `update_rank`, `normal_date`, `hour_ending`, `source`, `region` |
| **Upstream** | `staging_v1_meteologica_pjm_generation_normal_hourly` (9 source tables) |
| **Use Cases** | Compare current generation against historical norms, seasonal expectation setting |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/meteologica/meteologica_cleaned/.docs/meteologica_pjm_generation_normal_hourly.sql) |

**Sources covered:** Solar (RTO, Mid-Atlantic, South, West), Wind (RTO, Mid-Atlantic, South, West), Hydro (RTO)

---

## Staging Models

| Model | Description |
|-------|-------------|
| `staging_v1_meteologica_pjm_demand_forecast_hourly` | Unions and cleans all 36 PJM demand forecast source tables |
| `staging_v1_meteologica_pjm_gen_forecast_hourly` | Unions and cleans all 14 PJM generation forecast source tables |
| `staging_v1_meteologica_pjm_da_price_forecast_hourly` | Unions and cleans all 13 PJM DA price forecast source tables |
| `staging_v1_meteo_pjm_demand_fcst_ecmwf_ens_hourly` | Unions and cleans all 36 PJM ECMWF-ENS demand forecast source tables |
| `staging_v1_meteologica_pjm_demand_observation` | Unions and cleans all 36 PJM demand observation source tables |
| `staging_v1_meteologica_pjm_generation_observation` | Unions and cleans all 9 PJM generation observation source tables |
| `staging_v1_meteologica_pjm_da_price_observation` | Unions and cleans all 13 PJM DA price observation source tables |
| `staging_v1_meteologica_pjm_demand_projection_hourly` | Unions and cleans all 33 PJM demand projection source tables |
| `staging_v1_meteologica_pjm_generation_normal_hourly` | Unions and cleans all 9 PJM generation normal source tables |

## Known Limitations

- Only PJM data is cleaned via dbt; other ISOs (ERCOT, MISO, CAISO, NYISO, ISO-NE, SPP) remain as raw tables
- Model run values stored as VARCHAR (not timestamp) -- see Meteologica domain overview for why
- Each staging model unions many source tables, so query performance depends on underlying table sizes
