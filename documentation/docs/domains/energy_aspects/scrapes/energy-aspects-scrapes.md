# Energy Aspects Scrape Cards

## ISO Dispatch Costs

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/iso_dispatch_costs.py` |
| **Source** | EA API `/timeseries/csv` (Mapping ID: 157, 95 datasets) |
| **Target Table** | `energy_aspects.iso_dispatch_costs` |
| **Schema** | `energy_aspects` |
| **dbt Views** | `energy_aspects_cleaned.ea_pjm_dispatch_costs_monthly` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

Forecast dispatch costs and fuel costs by fuel type (NG, diesel, fuel oil, bituminous coal, sub-bituminous coal), plant type (CCGT, CT, ST), and pricing hub across all ISOs. PJM hubs: PJM W, PJM Dominion, PJM Nihub, PJM Adhub.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 95 metric columns (auto-generated names from API metadata)
- **PJM columns:** 36 (dispatch costs + fuel costs across 4 hubs)

---

## US Regional Power Model

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/us_regional_power_model.py` |
| **Source** | EA API `/timeseries/csv` (175 datasets) |
| **Target Table** | `energy_aspects.us_regional_power_model` |
| **Schema** | `energy_aspects` |
| **dbt Views** | `energy_aspects_cleaned.ea_pjm_power_model_monthly` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

Comprehensive regional power generation, demand, and natural gas demand model covering all major U.S. ISOs/regions. Includes EA price and forward price variants for gas and coal generation, plus weather-normalized demand and thermal generation forecasts.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 175 metric columns (auto-generated)
- **PJM columns:** 15 (coal/gas/nuclear/solar/wind/hydro/other generation, demand, net imports, gas demand in bcf/d)
- **Regions:** PJM, ERCOT, MISO, SPP, CAISO, ISONE, NYISO, Northwest, Southwest, Southeast, West, US48

---

## NA Power Price, Heat Rate & Spark Forecasts

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/na_power_price_heat_rate_spark_forecasts.py` |
| **Source** | EA API `/timeseries/csv` (Mapping ID: 45, 15 datasets) |
| **Target Table** | `energy_aspects.na_power_price_heat_rate_spark_forecasts` |
| **Schema** | `energy_aspects` |
| **dbt Views** | `energy_aspects_cleaned.ea_pjm_price_hr_spark_monthly` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

On-peak power prices ($/MWh), heat rates (MMBtu/MWh), and spark spreads ($/MWh) for 5 major pricing hubs.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 15 (explicit `COLUMN_MAP`)
- **Hubs:** ERCOT North, ISONE Mass, NYISO G, PJM West, CAISO SP15
- **PJM columns:** `fcst_on_peak_power_prices_in_pjm_west_in_usd_mwh`, `fcst_on_peak_heat_rate_in_pjm_west_in_mmbtu_per_mwh`, `fcst_on_peak_dirty_spark_spreads_in_pjm_west_in_usd_mwh`

---

## Monthly ISO Load Model

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/monthly_iso_load_model.py` |
| **Source** | EA API `/timeseries/csv` (Mapping ID: 474, 16 datasets) |
| **Target Table** | `energy_aspects.monthly_iso_load_model` |
| **Schema** | `energy_aspects` |
| **dbt Views** | `energy_aspects_cleaned.ea_pjm_load_model_monthly` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

Weather-normalized load forecasts and actual load by ISO. Two series per ISO: EA modeled historical + forecast load under normal weather, and actual load with forecast under normal weather.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 16 (explicit `COLUMN_MAP`)
- **ISOs:** PJM, ERCOT, NYISO, CAISO, ISONE, SPP, MISO, US48
- **PJM columns:** `ea_mod_hist_load_norm_weather_and_fcst_load_norm_weather_pjm_mw`, `ea_actual_load_fcst_load_norm_weather_pjm_mw`

---

## US Installed Capacity by ISO and Fuel Type

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/us_installed_capacity_by_iso_and_fuel_type.py` |
| **Source** | EA API `/timeseries/csv` (Mapping ID: 270, 84 datasets) |
| **Target Table** | `energy_aspects.us_installed_capacity_by_iso_and_fuel_type` |
| **Schema** | `energy_aspects` |
| **dbt Views** | `energy_aspects_cleaned.ea_pjm_installed_capacity_monthly` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

Installed generation capacity (MW) by fuel type across all ISOs/regions. Covers natural gas, coal, nuclear, oil, solar, onshore wind, offshore wind, hydro, and battery.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 84 (auto-generated)
- **PJM columns:** 9 (ng, coal, nuclear, oil, solar, onshore wind, offshore wind, hydro, battery)

---

## Lower 48 Average Power Demand

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/lower_48_average_power_demand_mw.py` |
| **Source** | EA API `/timeseries/csv` (7 datasets) |
| **Target Table** | `energy_aspects.lower_48_average_power_demand_mw` |
| **Schema** | `energy_aspects` |
| **dbt Views** | None |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Monthly |
| **Owner** | TBD |

### Business Purpose

ISO-level average power demand (MW). Subset of the US Regional Power Model focused on demand only.

### Data Captured

- **Grain:** One row per month
- **Primary key:** `date`
- **Columns:** 7 (explicit `COLUMN_MAP`: `caiso`, `ercot`, `isone`, `miso`, `nyiso`, `pjm`, `spp`)

---

## Lower 48 Generation Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/lower_48_generation_forecast_mw.py` |
| **Target Table** | `energy_aspects.lower_48_generation_forecast_mw` |
| **dbt Views** | None |
| **Trigger** | Scheduled (Prefect) |

US48 aggregate generation by fuel type (coal, gas, nuclear, hydro, solar, wind, other, net imports). No ISO-level breakdown.

---

## Lower 48 Gas Generation Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/lower_48_gas_generation_forecast_mw.py` |
| **Target Table** | `energy_aspects.lower_48_gas_generation_forecast_mw` |
| **dbt Views** | None |
| **Trigger** | Scheduled (Prefect) |

US48 natural gas generation (MW). Single-dataset subset of the generation forecast.

---

## Lower 48 Installed Capacity

| Field | Value |
|-------|-------|
| **Script** | `backend/src/energy_aspects/timeseries/lower_48_installed_capacity_mw.py` |
| **Target Table** | `energy_aspects.lower_48_installed_capacity_mw` |
| **dbt Views** | None |
| **Trigger** | Scheduled (Prefect) |

US48 installed capacity by fuel type (coal, gas, nuclear, oil, solar, onshore wind, hydro).
