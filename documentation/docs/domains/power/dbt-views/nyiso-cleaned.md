# NYISO Cleaned dbt Views

All views are materialized in the `nyiso_cleaned` schema. The dbt pipeline follows a layered architecture:

```
Source (raw tables) -> Staging (clean/rename) -> Marts (join/aggregate, final views)
```

Source and staging models are **ephemeral** (not materialized as tables/views). Only **mart** models are exposed as views.

---

## Mart Views

### nyiso_lmps_hourly

| Field | Value |
|-------|-------|
| **Business Definition** | Hourly electricity prices (LMPs) combining day-ahead and real-time markets for 15 zones |
| **Grain** | One row per date x hour_ending x hub x market |
| **Primary Keys** | `date`, `hour_ending`, `hub`, `market` |
| **Upstream** | `staging_v1_nyiso_lmps_hourly` |
| **Use Cases** | DA vs RT price spread analysis, zone-level price tracking, congestion analysis |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_postgresql/models/power/nyiso_cleaned/.docs/nyiso_lmps_hourly.sql) |

---

## Pricing Zones

NYISO LMP data is tracked across fifteen zones:

| Zone Code | Full Name |
|-----------|-----------|
| CAPITL | Capital (Albany) |
| CENTRL | Central (Syracuse) |
| DUNWOD | Dunwoodie (Westchester) |
| GENESE | Genesee (Rochester) |
| HQ | Hydro Quebec Interface |
| HUD VL | Hudson Valley |
| LONGIL | Long Island |
| MHK VL | Mohawk Valley |
| MILLWD | Millwood |
| NORTH | North (Massena) |
| NPX | New England Interface |
| N.Y.C. | New York City |
| O H | Ontario/Hydro Interface |
| PJM | PJM Interface |
| WEST | Western (Buffalo) |

## Data Quality

- Schema tests defined in `schema.yml` for primary keys and not-null constraints
- `not_null` on `date` and `hour_ending`
