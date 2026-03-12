# NatGas Cleaned dbt Views

All views are materialized in the `natgas_cleaned` schema on Azure SQL Server (`GenscapeDataFeed`).

> **Note:** This dbt project uses `dbt-sqlserver` (T-SQL), not the PostgreSQL project used by other domains.

---

## Mart Views

### genscape_noms

| Field | Value |
|-------|-------|
| **Business Definition** | Denormalized gas nominations combining raw nominations with pipeline, location, cycle, and no-notice data into a single view |
| **Grain** | One row per gas_day x location_role_id x cycle_code |
| **Primary Keys** | `gas_day`, `location_role_id`, `cycle_code` |
| **Upstream** | `source_v1_genscape_noms` (ephemeral) |
| **Use Cases** | Trading analytics, nomination dashboards, pipeline flow monitoring |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_sql/models/natgas/natgas_cleaned/marts/genscape_noms.sql) |

Key columns: `pipeline_name`, `pipeline_short_name`, `facility`, `role`, `sign`, `scheduled_cap`, `signed_scheduled_cap`, `no_notice_capacity`, `operational_cap`, `available_cap`, `design_cap`

### lng_facilities

| Field | Value |
|-------|-------|
| **Business Definition** | LNG terminal nomination flows for 9 US export facilities with multi-pipeline aggregation (Cameron, Freeport, Sabine) and a GENSCAPE_LNG total row |
| **Grain** | One row per gas_day x lng_plant x facility x role |
| **Primary Keys** | `gas_day`, `lng_plant`, `facility`, `role` |
| **Upstream** | `source_v1_lng_noms` (ephemeral) |
| **Use Cases** | LNG export analytics, facility flow monitoring, feedgas demand tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_sql/models/natgas/natgas_cleaned/marts/lng_facilities.sql) |

LNG plants covered: CALCASIEU, CAMERON, CORPUS_CHRISTI, COVE_POINT, ELBA, FREEPORT, GOLDEN_PASS, PLAQUEMINES, SABINE, GENSCAPE_LNG (total)

### salt_facilities_bcf

| Field | Value |
|-------|-------|
| **Business Definition** | Daily aggregated salt cavern storage flows in BCF (billion cubic feet), pivoted by facility with regional subtotals for TX, LA, MS, AL |
| **Grain** | One row per gas_day |
| **Primary Keys** | `gas_day` |
| **Upstream** | `staging_v1_salts_noms` (ephemeral) |
| **Use Cases** | Storage analytics, regional flow monitoring, supply/demand balancing |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_sql/models/natgas/natgas_cleaned/marts/salt_facilities_bcf.sql) |

Facility columns: `salts_total`, `salts_tx`, `salts_la`, `salts_ms`, `salts_al`, plus individual facility columns (`golden_triangle`, `keystone`, `moss_bluff`, `tres_palacios`, `arcadia`, `boardwalk`, `bobcat`, `egan`, `jefferson_island`, `la_storage`, `perryville`, `pine_prarie`, `eminence`, `leaf_river`, `mississippi_hub`, `petal`, `southern_pines`, `bay_gas`)

### salt_inventories

| Field | Value |
|-------|-------|
| **Business Definition** | Daily salt cavern storage inventory levels with delta, daily flows, and capacity metrics (available, operational, design) for 5 tracked facilities |
| **Grain** | One row per gas_day |
| **Primary Keys** | `gas_day` |
| **Upstream** | `staging_v1_salts_inventories` (ephemeral) |
| **Use Cases** | Storage inventory analytics, capacity monitoring, injection/withdrawal tracking |
| **Refresh** | View -- refreshes on query |
| **SQL** | [GitHub](https://github.com/helioscta/helioscta-backend/blob/main/backend/dbt/dbt_azure_sql/models/natgas/natgas_cleaned/marts/salt_inventories.sql) |

Facilities tracked: Eminence (inv, delta, daily_flows), Golden Triangle (inv, delta, daily_flows), Perryville (inv, daily_flows), Pine Prairie (inv, delta, daily_flows), Southern Pines (inv, daily_flows). Each facility includes `_available_cap`, `_operational_cap`, `_design_cap`.

---

## Ephemeral Models (not in database)

These models exist only as CTEs inlined into the views above:

| Model | Layer | Purpose |
|-------|-------|---------|
| `source_v1_genscape_noms` | Source | Enriched nominations joining 6 raw tables |
| `source_v1_lng_noms` | Source | LNG-filtered nominations with CASE-mapped plant names |
| `source_v1_salts_reference_table` | Source | 16-facility salt storage lookup (TX, LA, MS, AL) |
| `source_v1_salts_inventories_reference_table` | Source | 5-facility inventory lookup |
| `staging_v1_salts_noms` | Staging | Nominations joined with salt reference, signed capacity |
| `staging_v1_salts_inventories` | Staging | Nominations joined with inventory reference, signed capacity |
| `utils_v1_nerc_holidays` | Utils | NERC holidays 2014-2028 |
| `utils_v1_gas_day_daily` | Utils | Date spine with gas day dimensions, EIA weeks, holiday flags |
