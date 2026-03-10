# SPP Cleaned dbt Views

All views are materialized in the `spp_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### spp_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity prices (LMPs) combining day-ahead and real-time markets for North and South hubs |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_spp_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, North/South hub basis tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/spp_cleaned/.docs/spp_lmps_hourly.sql) |

---

## Pricing Hubs

- **SPP North Hub** (SPPNORTH_HUB) — Northern SPP zone
- **SPP South Hub** (SPPSOUTH_HUB) — Southern SPP zone

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- `not_null` on `date` and `hour_ending`
