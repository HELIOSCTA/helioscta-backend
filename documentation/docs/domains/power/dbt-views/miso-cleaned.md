# MISO Cleaned dbt Views

All views are materialized in the `miso_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### miso_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity prices (LMPs) combining day-ahead and real-time markets for 8 hubs |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_miso_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, hub-level price tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/miso_cleaned/.docs/miso_lmps_hourly.sql) |

### miso_lmps_daily

| Field | Value |
|-------|-------|
| **Business Definition** | Daily average electricity prices by hub and period (flat/onpeak/offpeak) |
| **Grain** | One row per date x period |
| **Primary Keys** | `date`, `period` |
| **Upstream** | `staging_v1_miso_lmps_daily` |
| **Use Cases** | Daily price trend analysis, on-peak/off-peak spread tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/miso_cleaned/.docs/miso_lmps_daily.sql) |

---

## Pricing Hubs

MISO LMP data is tracked across eight hubs:

- **Arkansas Hub** — Arkansas zone
- **Illinois Hub** — Illinois zone
- **Indiana Hub** — Indiana zone
- **Louisiana Hub** — Louisiana zone
- **Michigan Hub** — Michigan zone
- **Minnesota Hub** — Minnesota zone
- **Mississippi Hub** — Mississippi zone
- **Texas Hub** — Texas zone

## On-Peak Definition

- **onpeak** — HE08–HE23
- **offpeak** — HE01–HE07 and HE24

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- `not_null` on `date` and `hour_ending` across all models
