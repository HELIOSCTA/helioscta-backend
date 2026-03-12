# Meteologica Scrape Cards

## Overview

With 533 scripts, Meteologica is far too large to document individually. Scripts follow a consistent pattern within each ISO subfolder, so this page documents the **patterns** and provides representative examples.

## Standard Script Pattern

Every Meteologica script:
1. Authenticates via `backend/src/meteologica/auth.py` (JWT token)
2. Pulls data from the xTraders API for a specific content ID (forecasts, observations, normals, projections, etc.)
3. Formats the response into a standardized DataFrame
4. Upserts to a table in the `meteologica` schema

## Naming Convention

```
usa_{iso}_{region}_{type}_power_{category}_{schema_type}.py
```

- `{iso}` = pjm, ercot, miso, caiso, nyiso, isone, spp, us48
- `{region}` = optional sub-region (e.g., `midatlantic`, `west_aep`)
- `{type}` = optional fuel type (e.g., `pv`, `wind`, `hydro`)
- `{category}` = `demand`, `generation`, `price`
- `{schema_type}` = `forecast_hourly`, `forecast_ecmwf_ens_hourly`, `observation`, `projection_hourly`, `normal_hourly`, `long_term_hourly`, `forecast_daily`

## Scripts by ISO and Data Type

### PJM (234 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | 36 | RTO + 3 regions + 32 utility-level |
| Demand Forecasts (ECMWF-ENS) | 36 | RTO + 3 regions + 32 utility-level (ensemble model) |
| Demand Observations | 36 | RTO + 3 regions + 32 utility-level |
| Demand Projections | 33 | RTO + 32 utility-level (no macro aggregates) |
| Demand Long-Term | 1 | RTO |
| Generation Forecasts (Solar) | 4 | RTO + 3 regions |
| Generation Forecasts (Wind) | 12 | RTO + 3 regions + 8 utility-level |
| Generation Forecasts (Hydro) | 1 | RTO |
| Generation Forecasts (Daily) | 1 | RTO hydro |
| Generation Forecasts (ECMWF-ENS) | 17 | Solar, wind, hydro at RTO + regional + utility-level |
| Generation Observations | 9 | Solar (4: RTO/MIDATL/WEST/SOUTH), Wind (4: RTO/MIDATL/SOUTH/WEST), Hydro (1: RTO) |
| Generation Normals | 9 | Solar (4: RTO/MIDATL/SOUTH/WEST), Wind (4: RTO/MIDATL/SOUTH/WEST), Hydro (1: RTO) |
| DA Price Forecasts | 13 | System + 12 hubs |
| DA Price Forecasts (ECMWF-ENS) | 13 | System + 12 hubs (ensemble model) |
| DA Price Observations | 13 | System + 12 hubs |

### ERCOT (49 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~20 | RTO + zones |
| Generation Forecasts | ~15 | Solar, wind by region |
| DA Price Forecasts | ~10 | Hubs and settlement points |
| Other | ~4 | Observations, projections |

### MISO (45 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~18 | RTO + regions |
| Generation Forecasts | ~15 | Solar, wind by region |
| DA Price Forecasts | ~8 | Hubs |
| Other | ~4 | Observations |

### CAISO (40 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~12 | RTO + utilities (PGE, SCE, SDGE, etc.) |
| Generation Forecasts | ~15 | Solar, wind by NP15/SP15/ZP26 + oversupply/potential |
| DA Price Forecasts | ~8 | Hubs (NP15, SP15, ZP26, DLAPs) |
| Other | ~5 | Observations, normals, projections, long-term |

### NYISO (41 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~16 | RTO + zones (Capital, Central, etc.) |
| Generation Forecasts | ~12 | Solar, wind, hydro |
| DA Price Forecasts | ~8 | Zones |
| Other | ~5 | Observations |

### ISO-NE (39 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~15 | RTO + zones (CT, ME, NH, RI, VT, SEMA, WCMA, NEMA) |
| Generation Forecasts | ~12 | Solar, wind |
| DA Price Forecasts | ~8 | Hubs |
| Other | ~4 | Observations |

### SPP (43 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~16 | RTO + zones |
| Generation Forecasts | ~15 | Solar, wind |
| DA Price Forecasts | ~8 | Hubs |
| Other | ~4 | Observations |

### L48 / US48 (35 scripts)

| Category | Count | Scope |
|----------|-------|-------|
| Demand Forecasts | ~10 | National aggregate |
| Generation Forecasts | ~15 | National solar, wind, hydro, thermal |
| Price Forecasts | ~5 | National |
| Other | ~5 | Observations, normals |

## Representative Example

### `usa_pjm_power_demand_forecast_hourly`

| Field | Value |
|-------|-------|
| **Script** | `backend/src/meteologica/pjm/usa_pjm_power_demand_forecast_hourly.py` |
| **Table** | `meteologica.usa_pjm_power_demand_forecast_hourly` |
| **API Account** | ISO (`helios_cta`) |
| **Content Type** | Demand forecast |
| **Grain** | One row per hour per model run |
| **Key Fields** | `forecast_period_start`, `forecast_period_end`, `model_run`, `value` (MW) |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Multiple model runs per day |

## Running Scripts

```bash
# List all scripts
python backend/src/meteologica/runs.py --list

# Run all scripts
python backend/src/meteologica/runs.py all

# Run specific script by number
python backend/src/meteologica/runs.py 5
```
