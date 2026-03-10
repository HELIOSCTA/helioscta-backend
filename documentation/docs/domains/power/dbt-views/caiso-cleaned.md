# CAISO Cleaned dbt Views

All views are materialized in the `caiso_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### caiso_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity prices (LMPs) combining day-ahead and real-time markets for NP15 and SP15 |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_caiso_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, NP15/SP15 basis tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/caiso_cleaned/.docs/caiso_lmps_hourly.sql) |

### caiso_lmps_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily average electricity prices by hub and period (flat/onpeak/offpeak) for NP15 and SP15 |
| **Grain** | One row per date |
| **Primary Keys** | `date` |
| **Upstream** | `staging_v1_caiso_lmps_daily` |
| **Use Cases** | Daily price trend analysis, on-peak/off-peak spread tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/caiso_cleaned/.docs/caiso_lmps_daily.sql) |

---

## Pricing Hubs

- **NP15** — Northern California (North of Path 15)
- **SP15** — Southern California (South of Path 15)

## On-Peak Definition

- **onpeak** — HE07–HE22
- **offpeak** — HE01–HE06 and HE23–HE24

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- `not_null` on `date` and `hour_ending` across all models
