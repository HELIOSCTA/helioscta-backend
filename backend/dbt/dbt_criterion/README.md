# Criterion Research — SQL Script Catalogue

Runnable SQL scripts for querying Criterion Research's natural gas data platform.
All scripts target the **PostgreSQL** database at `dda.criterionrsch.com:443` (read-only).

## Connection

```
Host: dda.criterionrsch.com
Port: 443
User: c_helios
SSL:  required
```

## Database Schemas

| Schema | Description |
|--------|-------------|
| `data_series` | Ticker-based time series via `fin_json_to_excel_tickers(tickers TEXT)` function + `financial_metadata` table |
| `pipelines` | Pipeline nominations, metadata, and regional mappings (`nomination_points`, `metadata`, `regions`) |

## Ticker Naming Convention

```
{SYSTEM}.{COMMODITY}.{GEOGRAPHY}.{AGGREGATION}.{TYPE}
```

| Prefix | System | Description |
|--------|--------|-------------|
| `FDSD` | Fundamentals Daily S/D | Production, demand by component (industrial, rescomm, power) |
| `PLAG` | Pipeline Aggregation | LNG, cross-border flows, inter-regional pipeline aggregations |
| `PLNM` | Pipeline Nominations | Individual pipeline point nominations (used via `pipelines` schema) |
| `PLST` | Pipeline Storage | Storage flows, capacity, inventory, forecasts |
| `LTSD` | Long-Term S/D | Demand/production/trade forecasts >14 days out |

Type suffixes: `.A` = Actual, `.F` = Forecast, `.E` = Estimate

---

## Script Index

### `metadata/` — Exploratory
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_metadata_lookup.sql` | Browse `financial_metadata` by ticker, commodity, region, keyword | — |

### `l48_supply_demand/` — L48 Supply/Demand Balance
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_l48_supply_demand.sql` | Daily L48 S/D balance: production, demand by component, LNG, imports/exports (Bcf/d) | 13 |
| `criterion_dates_daily.sql` | Date dimension: NERC holidays, EIA storage weeks, seasonal flags (from 2010) | — |

### `production/` — Regional Production
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_production_regional.sql` | L48 + 7 regions + sub-regional production breakdowns (MMcf/d, from 2010) | 38 |

### `demand_regional/` — Regional Demand by Component
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_demand_industrial.sql` | Industrial demand: US total + 6 regions + 6 sub-regions (actual + forecast fallback) | 24 |
| `criterion_demand_rescomm.sql` | Residential/commercial demand: US total + 6 regions + 6 sub-regions | 24 |
| `criterion_demand_power.sql` | Power/gas burn demand: US total + 6 regions + 6 sub-regions | 24 |

Regions: NE, MW, ROX, SC, SE, WST. Sub-regions: ROX.SW, ROX.UPPER, SE.FL, SE.OTH, WST.CA, WST.PNW.

### `lng/` — LNG Exports & Imports
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_lng_total.sql` | LNG aggregate: total exports/imports, net, + 9 export facilities (Bcf/d) | 12 |
| `criterion_lng_facilities.sql` | All 9 US export terminals + Freeport pipeline nomination detail (Bcf/d) | 15+ |

### `long_term/` — Long-Term Forecasts (>14 Days)
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_long_term_sd.sql` | L48 demand/production/trade + regional demand & production breakdowns | 40 |
| `criterion_storage_forecasts.sql` | Storage forecasts by EIA region, salt/non-salt, end-of-season targets | 18 |

### `pipeline_flows/` — Inter-Regional Flow Aggregations
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_southeast_flows.sql` | SC→SE, SE→SC, NE→SE flows + Elba LNG | 13 |
| `criterion_northeast_flows.sql` | NE→MW, MW→NE, NE Canadian cross-border, LNG imports/exports, NE→SE | 27 |
| `criterion_midwest_flows.sql` | NE→MW, ESC→MW, WSC→MW, MW→SC, ROX→MW — all Midwest in/outflows | 33 |
| `criterion_south_central_flows.sql` | SC→SE, ESC→MW, WSC→MW, MW→SC, ROX→SC — all South Central flows | 32 |

### `imports_exports/` — Cross-Border Flows
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_canadian_imports.sql` | Regional aggregates + 19 individual border entry/exit points (NW, MW, NE) | 31 |
| `criterion_mexican_exports.sql` | Net total + 24 individual pipeline exit points (Gulf Coast, Permian, El Paso, AZ/CA) | 25 |
| `criterion_lng_imports.sql` | US total + 4 individual import terminals (Everett, Cove Point, Elba, NE Gateway) | 5 |

### `canadian/` — Canadian Supply & Demand
| Script | Description | Tickers |
|--------|-------------|---------|
| `criterion_canadian_sd.sql` | Commercial, residential, industrial, oil sands demand by province + production | 42 |

Provinces: AB, BC, MAN, NS, ONT, QUE, SK + Canada total.

### `storage/` — Storage Flows & Capacity
| Script | Description | Source |
|--------|-------------|--------|
| `criterion_storage_daily.sql` | Daily net flows by facility (uses `pipelines` schema joins) | `pipelines.*` |
| `criterion_storage_weekly.sql` | Weekly net flows by EIA week (transfer flag = 'T') | `pipelines.*` |
| `criterion_storage_capacity.sql` | Inventory/capacity by facility (PLST tickers + pipelines schema) | `pipelines.*` |

### `weather/` — Regional Weather *(placeholder)*
Ticker discovery needed via DB introspection. Check `financial_metadata` for weather-related tickers.

---

## Usage Notes

1. **All scripts run directly** against Criterion PostgreSQL — no dbt compilation needed
2. **Read-only access** — no write/create permissions on this database
3. **Actual + forecast fallback** — demand scripts use `COALESCE(actual, forecast)` pattern
4. **Units** — most scripts output in source units (MMcf/d); L48 S/D and LNG scripts convert to Bcf/d (÷1000)
5. **Date range** — most scripts filter from 2020-01-01; production and dates go back to 2010-01-01
6. **Storage scripts** use the `pipelines` schema directly (table joins) rather than the `fin_json_to_excel_tickers()` function

## Excel Reference Files

Source workbooks in `TODO/dbt_criterion_postgresql/excel_files/`:

| Workbook | Domains Covered |
|----------|----------------|
| Natural Gas Supply and Demand Catalog and Pivots | L48 S/D, regional demand, production, Canadian S/D, imports/exports, LNG |
| Pipeline+Flow+Aggregations+Catalog | SE, NE, MW, SC inter-regional pipeline flows |
| Storage+Flows+-+c_helios | Storage daily/weekly flows, capacity by facility |
| Long+Term+SD+Tables+-+250325 | Long-term S/D forecast snapshots (monthly vintages) |
| LNG+Feed+Gas+by+Terminal | LNG facility-level feed gas detail |
| South+Central+Flows+-+Full+Model+v2 | SC regional flow model |
| Southeast+Model, Northeast+Model, Midwest+Model | Regional flow models |
