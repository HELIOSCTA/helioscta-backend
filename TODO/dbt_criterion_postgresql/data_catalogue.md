# Data Catalogue — Criterion (dbt_criterion)

> Generated: 2026-03-12
> Confidence tags: `confirmed` (from SQL/code), `inferred` (from naming/context), `unknown` (needs DB introspection)

## Overview

Criterion is a third-party natural gas and energy data platform. It provides daily time series data via a ticker-based system, pipeline flow nominations, and facility-level metrics. There is no formal vendor documentation — this catalogue is reverse-engineered from legacy SQL, Excel models, and code analysis.

**Vendor database access:** PostgreSQL (via `data_series` and `pipelines` schemas on the GenscapeDataFeed database, accessible through Azure SQL)

**Data domains covered:**
1. **Data Series** — Ticker-based time series (production, demand, LNG, imports/exports, prices)
2. **Pipelines** — Natural gas pipeline nomination and flow data
3. **Date Utilities** — NERC holidays, EIA storage weeks, seasonal calendars

---

## 1. Schema: `data_series`

### 1.1 `data_series.financial_metadata` `confirmed`

Metadata registry for all Criterion data tickers. Each row describes one data series.

| Column | Type | Description | Confidence |
|--------|------|-------------|------------|
| `metadata_desc` | VARCHAR | Description of the data series | `confirmed` |
| `cmdty_class` | VARCHAR | Commodity class (e.g., Natural Gas, Power) | `confirmed` |
| `sub_cmdty_desc` | VARCHAR | Sub-commodity description | `confirmed` |
| `asset_name` | VARCHAR | Asset or facility name | `confirmed` |
| `country_name` | VARCHAR | Country | `confirmed` |
| `region_name` | VARCHAR | Region (e.g., South Central, Northeast) | `confirmed` |
| `state_name` | VARCHAR | State | `confirmed` |
| `province_name` | VARCHAR | Province (Canadian data) | `confirmed` |
| `status` | VARCHAR | Series status (active/inactive) | `confirmed` |
| `series_desc` | VARCHAR | Detailed series description | `confirmed` |
| `series_id` | VARCHAR/INT | Unique series identifier | `confirmed` |
| `table_name` | VARCHAR | Source table for this series | `confirmed` |
| `series_type` | VARCHAR | Type of series (forecast, observation, normal, etc.) | `confirmed` |
| `sub_region` | VARCHAR | Sub-region classification | `confirmed` |
| `ticker` | VARCHAR | Unique ticker code (e.g., `FDSD.NGPR.L48.SUM.A`) | `confirmed` |

**Primary key:** `ticker` (or `series_id`) `inferred`
**Ticker naming convention:** `{SYSTEM}.{COMMODITY}.{GEOGRAPHY}.{AGGREGATION}.{TYPE}` `inferred`

**Known ticker prefixes:**
| Prefix | Meaning | Confidence |
|--------|---------|------------|
| `FDSD` | Fundamentals Daily Supply/Demand | `inferred` |
| `PLAG` | Pipeline Aggregation / LNG | `inferred` |
| `PLNM` | Pipeline Nominations | `inferred` |

### 1.2 `data_series.fin_json_to_excel_tickers(tickers TEXT[])` `confirmed`

**PostgreSQL function.** Flattens JSON-stored ticker data into tabular format for given ticker codes.

| Output Column | Type | Description | Confidence |
|---------------|------|-------------|------------|
| `entity_desc` | VARCHAR | Entity description | `confirmed` |
| `metadata_desc` | VARCHAR | Metadata description | `confirmed` |
| `region_name` | VARCHAR | Region | `confirmed` |
| `state_name` | VARCHAR | State | `confirmed` |
| `cmdty_class` | VARCHAR | Commodity class | `confirmed` |
| `series_desc` | VARCHAR | Series description | `confirmed` |
| `unit_desc` | VARCHAR | Unit of measurement (e.g., MMcf/d, Bcf/d) | `confirmed` |
| `date` | DATE | Observation/forecast target date | `confirmed` |
| `post_date` | DATE | Report/publication date (used as `report_date`) | `confirmed` |
| `ticker` | VARCHAR | Ticker code | `confirmed` |
| `value` | NUMERIC | Data value | `confirmed` |

**Notes:**
- Called with array of ticker strings: `fin_json_to_excel_tickers(ARRAY['TICKER1', 'TICKER2', ...])`
- Returns one row per ticker × date × post_date combination
- `post_date` enables revision tracking (multiple reports for the same observation date)

### 1.3 `data_series.FLATTEN_JSON_TICKERS(tickers TEXT[])` `confirmed`

**Snowflake equivalent** of `fin_json_to_excel_tickers`. Identical output schema. Used in Snowflake-targeted queries.

| Output Column | Type | Description | Confidence |
|---------------|------|-------------|------------|
| (same as 1.2) | | | `confirmed` |

**Migration note:** All Snowflake queries using this function need to be rewritten to use `fin_json_to_excel_tickers` for PostgreSQL.

---

## 2. Schema: `pipelines`

### 2.1 `pipelines.nomination_points` `confirmed`

Daily pipeline nomination data at the point/receipt/delivery level.

| Column | Type | Description | Confidence |
|--------|------|-------------|------------|
| `metadata_id` | INT | FK to `pipelines.metadata` | `confirmed` |
| `ticker` | VARCHAR | Pipeline ticker (e.g., `PLNM.073.79999.2`) | `confirmed` |
| `eff_gas_day` | DATE | Effective gas day of the nomination | `confirmed` |
| `scheduled_qty` | NUMERIC | Scheduled nomination quantity (can be negative for receipts) | `confirmed` |
| `design_capacity` | NUMERIC | Design capacity of the point | `inferred` |
| `operating_capacity` | NUMERIC | Operating capacity of the point | `inferred` |

**Grain:** One row per ticker × eff_gas_day × metadata_id `inferred`

### 2.2 `pipelines.metadata` `confirmed`

Pipeline location and classification metadata.

| Column | Type | Description | Confidence |
|--------|------|-------------|------------|
| `metadata_id` | INT | Primary key | `confirmed` |
| `location_name` | VARCHAR | Name of the pipeline point/location | `inferred` |
| `state_name` | VARCHAR | State where the point is located (FK to `regions`) | `confirmed` |

**Additional columns likely exist** but are not referenced in legacy SQL. `unknown`

### 2.3 `pipelines.regions` `confirmed`

State-level region classification for pipeline data.

| Column | Type | Description | Confidence |
|--------|------|-------------|------------|
| `state_name` | VARCHAR | State name (join key from `metadata`) | `confirmed` |
| `region` | VARCHAR | Regional classification | `inferred` |

**Additional columns likely exist** but are not referenced in legacy SQL. `unknown`

### 2.4 Relationships

```
pipelines.nomination_points
    ├── metadata_id → pipelines.metadata.metadata_id
    └── (via metadata) state_name → pipelines.regions.state_name
```

---

## 3. Ticker Registry (Known Tickers)

### 3.1 Production Tickers (38 tickers) `confirmed`

| Ticker | Description | Region | Confidence |
|--------|-------------|--------|------------|
| `FDSD.NGPR.L48.SUM.A` | L48 Total Natural Gas Production | L48 | `confirmed` |
| `FDSD.NGPR.SC.SUM.A` | South Central Total | South Central | `confirmed` |
| `FDSD.NGPR.SC.PERM.A` | Permian Basin | South Central | `confirmed` |
| `FDSD.NGPR.SC.HAYLA.A` | Haynesville (Louisiana) | South Central | `confirmed` |
| `FDSD.NGPR.SC.HAYTX.A` | Haynesville (Texas) | South Central | `confirmed` |
| `FDSD.NGPR.SC.EF.A` | Eagle Ford | South Central | `confirmed` |
| `FDSD.NGPR.SC.OKAN.A` | Oklahoma (Anadarko) | South Central | `confirmed` |
| `FDSD.NGPR.SC.BARN.A` | Barnett | South Central | `confirmed` |
| `FDSD.NGPR.SC.ARKFAY.A` | Arkansas (Fayetteville) | South Central | `confirmed` |
| `FDSD.NGPR.SC.GW.A` | Granite Wash | South Central | `confirmed` |
| `FDSD.NGPR.SC.KS.A` | Kansas | South Central | `confirmed` |
| `FDSD.NGPR.SC.LADPSH.A` | Deep Shelf (Louisiana) | South Central | `confirmed` |
| `FDSD.NGPR.SC.LATMS.A` | Tuscaloosa Marine Shale (Louisiana) | South Central | `confirmed` |
| `FDSD.NGPR.SC.LAOTH.A` | Other (Louisiana) | South Central | `confirmed` |
| `FDSD.NGPR.SC.OKOTH.A` | Other (Oklahoma) | South Central | `confirmed` |
| `FDSD.NGPR.NE.SUM.A` | Northeast Total | Northeast | `confirmed` |
| `FDSD.NGPR.NE.APP.A` | Appalachia | Northeast | `confirmed` |
| `FDSD.NGPR.MW.SUM.A` | Midwest Total | Midwest | `confirmed` |
| `FDSD.NGPR.RM.SUM.A` | Rockies Total | Rockies | `confirmed` |
| `FDSD.NGPR.RM.WY.A` | Wyoming | Rockies | `confirmed` |
| `FDSD.NGPR.RM.COBJ.A` | DJ Basin (Colorado) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.NDWILL.A` | Williston (North Dakota) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.CONMSJ.A` | San Juan (CO/NM) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.COPIC.A` | Piceance (Colorado) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.UT.A` | Utah | Rockies | `confirmed` |
| `FDSD.NGPR.RM.MT.A` | Montana | Rockies | `confirmed` |
| `FDSD.NGPR.RM.CONMRT.A` | Raton Basin (CO/NM) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.NMBRVO.A` | Bravo Dome (New Mexico) | Rockies | `confirmed` |
| `FDSD.NGPR.RM.RMOTH.A` | Other (Rockies) | Rockies | `confirmed` |
| `FDSD.NGPR.WC.SUM.A` | West Total | West | `confirmed` |
| `FDSD.NGPR.SE.SUM.A` | Southeast Total | Southeast | `confirmed` |
| `FDSD.NGPR.GOM.SUM.A` | Gulf of Mexico Total | Gulf of Mexico | `confirmed` |

### 3.2 L48 Supply/Demand Tickers (13 tickers) `confirmed`

| Ticker | Description | Type | Confidence |
|--------|-------------|------|------------|
| `FDSD.NGPR.L48.SUM.A` | L48 Production | Supply | `confirmed` |
| `PLAG.CN2US.SUM.NET.A` | Canadian Imports (Net) | Supply | `confirmed` |
| `PLAG.LNGIMP.SUM.US.A` | LNG Imports | Supply | `confirmed` |
| `FDSD.NGPWR.US.SUM.A` | Power Demand (Actual) | Demand | `confirmed` |
| `FDSD.NGPWR.US.SUM.F` | Power Demand (Forecast) | Demand | `confirmed` |
| `FDSD.NGRC.US.SUM.A` | Res/Comm Demand (Actual) | Demand | `confirmed` |
| `FDSD.NGRC.US.SUM.F` | Res/Comm Demand (Forecast) | Demand | `confirmed` |
| `FDSD.NGIND.US.SUM.A` | Industrial Demand (Actual) | Demand | `confirmed` |
| `FDSD.NGIND.US.SUM.F` | Industrial Demand (Forecast) | Demand | `confirmed` |
| `FDSD.NGLPF.US.SUM.A` | Lease & Plant Fuel | Demand | `confirmed` |
| `FDSD.NGPL.US.SUM.A` | Pipeline Loss | Demand | `confirmed` |
| `PLAG.MEXEXP.SUM.US.A` | Mexican Exports | Demand | `confirmed` |
| `PLAG.LNGEXP.SUM.US.A` | LNG Feed Gas (Export) | Demand | `confirmed` |

### 3.3 LNG Facility Tickers (15 tickers) `confirmed`

| Ticker | Description | Region | Confidence |
|--------|-------------|--------|------------|
| `PLAG.LNGEXP.SUM.PLAQ.A` | Plaquemines LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.GLDP.A` | Golden Pass LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.SABN.A` | Sabine Pass LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.CALC.A` | Calcasieu Pass LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.CCHR.A` | Corpus Christi LNG (implied) | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.CAMR.A` | Cameron LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.FRPT.A` | Freeport LNG | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.CVPT.A` | Cove Point LNG | East Coast | `confirmed` |
| `PLAG.LNGEXP.SUM.ELBA.A` | Elba Island LNG | East Coast | `confirmed` |
| `PLAG.LNGIMP.SUM.NGWY.A` | Negeway LNG Import | Import | `confirmed` |
| `PLAG.LNGIMP.SUM.EVRT.A` | Everett LNG Import | Import | `confirmed` |
| `PLAG.LNGIMP.SUM.ELBA.A` | Elba LNG Import | Import | `confirmed` |
| `PLAG.LNGIMP.SUM.CVPT.A` | Cove Point LNG Import | Import | `confirmed` |
| `PLAG.LNGEXP.SUM.CCHRIMP.A` | Corpus Christi Implied Flows | Gulf | `confirmed` |
| `PLAG.LNGEXP.SUM.CCHRINT.A` | Corpus Christi Intrastate Receipts | Gulf | `confirmed` |

### 3.4 Pipeline Nomination Tickers `confirmed`

| Ticker | Description | Confidence |
|--------|-------------|------------|
| `PLNM.073.79999.2` | Freeport LNG intrastate nomination point | `confirmed` |

**Note:** Many more pipeline tickers likely exist. The legacy code only references this one. Full introspection of `pipelines.nomination_points` required to catalogue all. `unknown`

---

## 4. Derived Entities (from Legacy SQL)

These are the analytical outputs produced by the legacy queries. They become the basis for dbt mart models.

### 4.1 L48 Supply/Demand Balance `confirmed`

**Source:** `criterion_l48_supply_demand.sql`
**Grain:** Daily (from 2020-01-01)
**Unit:** Bcf/d (values divided by 1000 from source MMcf/d)

| Output Column | Computation | Confidence |
|---------------|-------------|------------|
| `date` | Observation date | `confirmed` |
| `lower_48_prod` | L48 production ticker | `confirmed` |
| `cad_imports` | Canadian net imports ticker | `confirmed` |
| `lng_imports` | LNG imports ticker | `confirmed` |
| `power_demand` | COALESCE(actual, forecast) for power | `confirmed` |
| `rescomm` | COALESCE(actual, forecast) for res/comm | `confirmed` |
| `industrial` | COALESCE(actual, forecast) for industrial | `confirmed` |
| `lease_and_plant_fuel` | Lease & plant fuel ticker | `confirmed` |
| `pipe_loss` | Pipeline loss ticker | `confirmed` |
| `mex_exports` | Mexican exports ticker | `confirmed` |
| `lng` | LNG feed gas ticker | `confirmed` |
| `total_supply` | prod + cad_imports + lng_imports | `confirmed` |
| `total_demand` | sum of all demand components | `confirmed` |
| `net_balance` | total_supply - total_demand | `confirmed` |

### 4.2 Date Dimension `confirmed`

**Source:** `criterion_l48_supply_demand_dates.sql`
**Grain:** Daily (from 2010-01-01)

| Output Column | Description | Confidence |
|---------------|-------------|------------|
| `date` | Calendar date | `confirmed` |
| `year` | 4-digit year | `confirmed` |
| `year_month` | YYYY-MM | `confirmed` |
| `month` | Month name | `confirmed` |
| `mm_dd` | MM-DD (year-agnostic) | `confirmed` |
| `mm_dd_cy` | Same MM-DD mapped to current calendar year | `confirmed` |
| `summer_winter` | SUMMER (Apr-Oct) / WINTER (Nov-Mar) | `confirmed` |
| `summer_winter_yyyy` | Labeled season with year (e.g., "Heating 2025/2026") | `confirmed` |
| `eia_storage_week` | EIA-standard storage week (Wed-Tue cycle) | `confirmed` |
| `day_of_week` | Day name | `confirmed` |
| `day_of_week_number` | 1=Monday through 7=Sunday | `confirmed` |
| `is_weekend` | 0/1 flag | `confirmed` |
| `is_nerc_holiday` | 0/1 flag (hard-coded 2014-2028) | `confirmed` |

### 4.3 LNG Facility Breakdown `confirmed`

**Source:** `source_v1_criterion_lng_facilities.sql`
**Grain:** Daily (rolling 7-day window)
**Unit:** Bcf/d (values divided by 1000)

| Output Column | Description | Confidence |
|---------------|-------------|------------|
| `date` | Gas day | `confirmed` |
| `l48_lng_flow` | Total all 9 US LNG facilities | `confirmed` |
| `gulf_lng_flow` | Gulf region total (7 facilities) | `confirmed` |
| `east_lng_flow` | East Coast total (2 facilities) | `confirmed` |
| `calcasieu` | Calcasieu Pass | `confirmed` |
| `cameron` | Cameron LNG | `confirmed` |
| `corpus_christi` | Corpus Christi (implied) | `confirmed` |
| `freeport` | Freeport LNG | `confirmed` |
| `golden_pass` | Golden Pass LNG | `confirmed` |
| `plaquemines` | Plaquemines LNG | `confirmed` |
| `sabine` | Sabine Pass LNG | `confirmed` |
| `cove_point` | Cove Point LNG | `confirmed` |
| `elba` | Elba Island LNG | `confirmed` |
| `corpus_christi_implied` | CC implied flows detail | `confirmed` |
| `corpus_christi_intrastate` | CC intrastate receipts | `confirmed` |

### 4.4 Freeport LNG Detail `confirmed`

**Source:** `source_v1_criterion_freeport.sql`
**Grain:** Daily (from 2020-01-01)
**Unit:** Bcf/d

| Output Column | Description | Confidence |
|---------------|-------------|------------|
| `date` | Gas day | `confirmed` |
| `freeport_implied` | Implied flows from ticker data | `confirmed` |
| `freeport_feed_gas` | Feed gas = implied - intrastate | `confirmed` |
| `freeport_intrastate` | ABS(scheduled_qty) from pipeline nominations | `confirmed` |

**Unique:** Only model that joins `data_series` with `pipelines` schema.

### 4.5 Production by Region `confirmed`

**Source:** `source_v1_criterion_prod.sql`
**Grain:** Daily (from 2010-01-01)
**Unit:** As provided (MMcf/d from source)

| Output Column | Description | Region Group | Confidence |
|---------------|-------------|-------------|------------|
| `date` | Observation date | — | `confirmed` |
| `l48_total` | L48 Total | National | `confirmed` |
| `south_central_total` | South Central Total | Regional | `confirmed` |
| `northeast_total` | Northeast Total | Regional | `confirmed` |
| `midwest_total` | Midwest Total | Regional | `confirmed` |
| `rockies_total` | Rockies Total | Regional | `confirmed` |
| `west_total` | West Total | Regional | `confirmed` |
| `southeast_total` | Southeast Total | Regional | `confirmed` |
| `gulf_of_mexico_total` | Gulf of Mexico Total | Regional | `confirmed` |
| `permian` | Permian Basin | SC Sub-region | `confirmed` |
| `haynesville_la` | Haynesville (LA) | SC Sub-region | `confirmed` |
| `haynesville_tx` | Haynesville (TX) | SC Sub-region | `confirmed` |
| `eagle_ford` | Eagle Ford | SC Sub-region | `confirmed` |
| `oklahoma_anadarko` | Oklahoma/Anadarko | SC Sub-region | `confirmed` |
| `barnett` | Barnett | SC Sub-region | `confirmed` |
| `arkansas_fayetteville` | Arkansas/Fayetteville | SC Sub-region | `confirmed` |
| `granite_wash` | Granite Wash | SC Sub-region | `confirmed` |
| `kansas` | Kansas | SC Sub-region | `confirmed` |
| `deep_shelf_la` | Deep Shelf (LA) | SC Sub-region | `confirmed` |
| `tuscaloosa_marine_shale` | Tuscaloosa Marine Shale | SC Sub-region | `confirmed` |
| `other_la` | Other (LA) | SC Sub-region | `confirmed` |
| `other_ok` | Other (OK) | SC Sub-region | `confirmed` |
| `appalachia` | Appalachia | NE Sub-region | `confirmed` |
| `wyoming` | Wyoming | RM Sub-region | `confirmed` |
| `dj_basin_co` | DJ Basin (CO) | RM Sub-region | `confirmed` |
| `williston_nd` | Williston (ND) | RM Sub-region | `confirmed` |
| `san_juan_conm` | San Juan (CO/NM) | RM Sub-region | `confirmed` |
| `piceance_co` | Piceance (CO) | RM Sub-region | `confirmed` |
| `utah` | Utah | RM Sub-region | `confirmed` |
| `montana` | Montana | RM Sub-region | `confirmed` |
| `raton_basin_conm` | Raton Basin (CO/NM) | RM Sub-region | `confirmed` |
| `bravo_dome_nm` | Bravo Dome (NM) | RM Sub-region | `confirmed` |
| `other_rockies` | Other (Rockies) | RM Sub-region | `confirmed` |

---

## 5. Excel Model Coverage Mapping

The 77 Excel workbooks in `TODO/dbt_criterion_postgresql/excel_files/` map to these data domains:

| Domain | Excel Count | Legacy SQL Coverage | Gap |
|--------|------------|--------------------|----|
| **Production** | 12 (Appalachian, Haynesville, Permian, SC Production, etc.) | Covered by `criterion_prod.sql` (38 tickers) | Sub-region detail may differ |
| **LNG** | 5 (LNG Feed Gas, LNG Forecast, Criterion LNG w Day Ahead, etc.) | Covered by LNG module (3 SQL files) | Mostly covered |
| **Pipeline Flows** | 12 (Pipe Flows, Transco, TETCO, FGT, Gulf Run, etc.) | NOT covered — only Freeport nominations in SQL | **Major gap** |
| **Storage** | 6 (Storage Flows, Storage Queries, SC Salts, Dawn, TRRC, etc.) | NOT covered | **Major gap** |
| **Supply/Demand** | 4 (S&D Catalog, Fundamentals DDA, Long Term SD, etc.) | Partially covered by `criterion_l48_supply_demand.sql` | Long-term tables missing |
| **Regional Models** | 5 (Northeast, Southeast, Midwest, SC Full Model, etc.) | NOT covered as distinct models | **Gap** |
| **Power/ERCOT/PJM** | 5 (ERCOT Data Tables, PJM Data Tables, etc.) | NOT covered (separate domain) | Out of scope for Criterion |
| **Canadian** | 3 (Canadian Pipeline Noms, NGTL/Alliance, Canada S&D) | NOT covered | **Gap** |
| **Weather** | 2 (Weather Data Regional) | NOT covered | **Gap** |
| **Pipeline Metadata** | 3 (Pipeline Metadata, Pipeline Maintenance, Pipeline Query Tool) | NOT covered | **Gap** |
| **Other** | 20 (various: EIA, Coal, Baker Hughes, Mexican Exports, etc.) | NOT covered | Some may be out of scope |

### Priority for DB Introspection

Based on the gap analysis above, these areas need database exploration to expand the catalogue:

1. **Pipeline flows** — `pipelines` schema likely has much more than `nomination_points`
2. **Storage** — likely a `storage` schema or tables within `data_series`
3. **Canadian data** — likely accessible via tickers (e.g., `PLAG.CN*` prefix)
4. **Regional models** — may be composable from existing production/demand tickers
5. **Pipeline metadata** — `pipelines.metadata` needs full column inventory

---

## 6. Source Mapping

### Legacy SQL → Future dbt Model

| Legacy SQL File | Future dbt Source | Future dbt Staging | Future dbt Mart |
|----------------|-------------------|-------------------|-----------------|
| `criterion_l48_supply_demand.sql` | `source_v1_criterion_data_series.sql` | `staging_v1_criterion_l48_supply_demand_daily.sql` | `criterion_l48_supply_demand_daily` |
| `criterion_l48_supply_demand_dates.sql` | — (self-generated) | — | `criterion_dates_daily` (utils/) |
| `source_v1_criterion_freeport.sql` | `source_v1_criterion_data_series.sql` + `source_v1_criterion_pipelines.sql` | `staging_v1_criterion_freeport_lng_daily.sql` | `criterion_freeport_lng_daily` |
| `source_v1_criterion_lng_facilities.sql` | `source_v1_criterion_data_series.sql` | `staging_v1_criterion_lng_facilities_daily.sql` | `criterion_lng_facilities_daily` |
| `source_v1_criterion_lng_total.sql` | `source_v1_criterion_data_series.sql` | `staging_v1_criterion_lng_total_daily.sql` | `criterion_lng_total_daily` |
| `source_v1_criterion_prod.sql` | `source_v1_criterion_data_series.sql` | `staging_v1_criterion_production_regional_daily.sql` | `criterion_production_regional_daily` |

---

## 7. Assumptions

1. **Target database is PostgreSQL** — all Snowflake syntax (FLATTEN_JSON_TICKERS, DATEADD, CONVERT_TIMEZONE, GENERATOR) must be ported to PostgreSQL equivalents (fin_json_to_excel_tickers, interval arithmetic, AT TIME ZONE, generate_series).
2. **`fin_json_to_excel_tickers()` exists in the target PG database** — this function is called in the PostgreSQL legacy SQL and is assumed to be a UDF in the `data_series` schema.
3. **Ticker values are stable** — the ticker codes used in legacy SQL are assumed to still be valid in the current database.
4. **Unit conversion is consistent** — all LNG/supply-demand values are divided by 1000 (MMcf/d → Bcf/d). Production values are kept in source units (MMcf/d).
5. **Only PostgreSQL variants will be migrated** — Snowflake duplicates will be dropped in favor of the PG versions.
6. **Many more tables/functions likely exist** in both `data_series` and `pipelines` schemas. This catalogue only covers what is referenced in legacy SQL. DB introspection will expand coverage significantly.

---

## 8. Next Steps (DB Introspection Needed)

To complete this catalogue, the following read-only queries should be run against the Criterion database:

```sql
-- 1. List all schemas
SELECT schema_name FROM information_schema.schemata ORDER BY schema_name;

-- 2. List all tables in data_series and pipelines schemas
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('data_series', 'pipelines')
ORDER BY table_schema, table_name;

-- 3. Full column inventory for known tables
SELECT table_schema, table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema IN ('data_series', 'pipelines')
ORDER BY table_schema, table_name, ordinal_position;

-- 4. List all functions in data_series schema
SELECT routine_schema, routine_name, data_type
FROM information_schema.routines
WHERE routine_schema = 'data_series';

-- 5. Sample ticker prefixes to discover additional data domains
SELECT DISTINCT LEFT(ticker, POSITION('.' IN ticker) - 1) AS ticker_prefix, COUNT(*)
FROM data_series.financial_metadata
GROUP BY 1 ORDER BY 2 DESC;

-- 6. List all distinct region_name values
SELECT DISTINCT region_name FROM data_series.financial_metadata ORDER BY 1;
```

These are all read-only `SELECT` queries — no destructive operations.
