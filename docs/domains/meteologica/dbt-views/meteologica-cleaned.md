# Meteologica Cleaned dbt Views

All views are in the `meteologica_cleaned` schema. Currently covers PJM forecasts only.

## Architecture

```
Raw Meteologica tables (meteologica schema, ~75 PJM tables)
    -> Staging (ephemeral, union + clean)
    -> Mart views (materialized as views)
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

---

## Staging Models

| Model | Description |
|-------|-------------|
| `staging_v1_meteologica_pjm_demand_forecast_hourly` | Unions and cleans all PJM demand forecast source tables |
| `staging_v1_meteologica_pjm_gen_forecast_hourly` | Unions and cleans all PJM generation forecast source tables |
| `staging_v1_meteologica_pjm_da_price_forecast_hourly` | Unions and cleans all PJM DA price forecast source tables |

## Known Limitations

- Only PJM forecasts are cleaned via dbt; other ISOs (ERCOT, MISO, CAISO, NYISO, ISO-NE, SPP) remain as raw tables
- Model run values stored as VARCHAR (not timestamp) -- see Meteologica domain overview for why
- Each staging model unions many source tables, so query performance depends on underlying table sizes
