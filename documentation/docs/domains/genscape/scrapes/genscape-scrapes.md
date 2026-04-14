# Genscape Scrape Cards

## Gas Production Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/genscape/gas_production_forecast_v2_2025_09_23.py` |
| **Source** | Genscape (Enverus) REST API |
| **Target Table** | `genscape.gas_production_forecast_v2_2025_09_23` |
| **Trigger** | Scheduled (Windows Task Scheduler) |
| **Cadence** | Daily (6:00 AM and 12:00 PM) |
| **Freshness** | Same-day forecast updates |

### Business Purpose

Provides a forward-looking estimate of natural gas production volumes. Used by traders to assess supply fundamentals and inform natural gas and power trading decisions.

### Data Captured

Monthly gas production forecasts by region including production volumes, dry gas production YoY change, oil rig counts, and gas rig counts. Covers 67 granular Genscape regions (US states, Texas Railroad Commission districts, sub-basins, Canadian provinces).

### Primary Key

`[month, region, item, reportDate]`

### Downstream

- `genscape_cleaned.genscape_gas_production_forecast` (dbt mart view)

### Known Caveats

- Requires active Genscape subscription
- Table name includes version date (`v2_2025_09_23`) from original migration; `API_SCRAPE_NAME` is `gas_production_forecast` for pipeline logging

---

## Daily Pipeline Production

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/genscape/daily_pipeline_production_v2_2026_mar_10.py` |
| **Source** | Genscape (Enverus) REST API |
| **Target Table** | `genscape.daily_pipeline_production_v2_2026_mar_10` |
| **Trigger** | Scheduled (Windows Task Scheduler) |
| **Cadence** | Daily (6:00 AM and 12:00 PM) |
| **Freshness** | ~1-day lag |

### Business Purpose

Tracks actual daily natural gas volumes flowing through major pipelines. Compared against forecasts to identify production surprises that may move gas and power prices.

### Data Captured

Daily dry gas production estimates (MMCF/d) pivoted by region. Includes 22 regional columns covering Lower 48, Gulf of Mexico, Gulf Coast sub-regions, Texas, Mid-Continent, Permian, San Juan, Rockies sub-basins, West, East sub-states, and Western Canada. Also includes Permian flare counts and volumes.

### Primary Key

`[reportdate, date]`

### Downstream

- `genscape_cleaned.genscape_daily_pipeline_production` (dbt mart view)

### Known Caveats

- Table name includes version date (`v2_2026_mar_10`) from the current table version

---

## Daily Power Estimate

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/genscape/daily_power_estimate.py` |
| **Source** | Genscape (Enverus) REST API |
| **Target Table** | `genscape.daily_power_estimate` |
| **Trigger** | Scheduled (Windows Task Scheduler) |
| **Cadence** | Daily (6:00 AM and 12:00 PM) |
| **Freshness** | Same-day estimates |

### Business Purpose

Provides daily power generation burn estimates by region and model type. Data arrives pivoted with region columns. Used to track gas-to-power demand across US regions and inform gas/power spread analysis.

### Data Captured

Daily power burn estimates by gas day, power burn variable, and model type. Regional columns include CONUS, East, Midwest, Mountain, Pacific, and South Central.

### Primary Key

`[gasday, power_burn_variable, modeltype]`

### Downstream

- `genscape_cleaned.genscape_daily_power_estimate` (dbt mart view)

### Known Caveats

- Response includes multiple model types (e.g., forecast vs estimate) in the same dataset
- Primary key includes `modeltype` to differentiate model versions
