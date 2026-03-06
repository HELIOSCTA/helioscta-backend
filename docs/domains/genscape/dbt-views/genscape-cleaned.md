# Genscape Cleaned dbt Views

All views are in the `genscape_cleaned` schema.

## Architecture

```
Raw Genscape tables (genscape schema)
    -> Source (ephemeral)
    -> Staging (ephemeral, clean/rename)
    -> Mart views
```

---

## Mart Views

### genscape_gas_production_forecast

| Field | Value |
|-------|-------|
| **Business Definition** | Cleaned natural gas production forecast from Genscape |
| **Grain** | One row per date x report_date x revision |
| **Primary Keys** | `year`, `month`, `date`, `report_date`, `revision` |
| **Upstream** | `staging_v2_genscape_gas_production_forecast` |
| **Use Cases** | Natural gas supply outlook, gas-power cross-commodity analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/genscape/genscape_cleaned/.docs/genscape_gas_production_forecast.sql) |

### genscape_daily_pipeline_production

| Field | Value |
|-------|-------|
| **Business Definition** | Cleaned daily actual natural gas pipeline production by basin/region |
| **Grain** | One row per date x report_date x revision |
| **Primary Keys** | `date`, `report_date`, `revision` |
| **Upstream** | `staging_v2_daily_pipeline_production` |
| **Use Cases** | Track actual vs forecast production, monitor supply trends |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/genscape/genscape_cleaned/.docs/genscape_daily_pipeline_production.sql) |

---

## Staging Models

| Model | Purpose |
|-------|---------|
| `source_v2_genscape_gas_production_forecast` | Selects and casts from raw gas production forecast table |
| `source_v2_daily_pipeline_production` | Selects and casts from raw daily pipeline production table |
| `staging_v2_genscape_gas_production_forecast` | Cleans column names and data types |
| `staging_v2_daily_pipeline_production` | Cleans column names and data types |

## Known Limitations

- Grain and primary key details should be confirmed from the actual source data
- Genscape data is proprietary -- requires active subscription for data to flow
