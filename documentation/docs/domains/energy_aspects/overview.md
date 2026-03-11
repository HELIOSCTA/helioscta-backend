# Energy Aspects

Subscription-based energy market analytics covering power generation forecasts, dispatch costs, power prices, heat rates, spark spreads, installed capacity, and load models across all major U.S. ISOs.

**Use this page** to find Energy Aspects scrape scripts and raw table details.

## Data Source

- **API:** Energy Aspects Data API (`https://api.energyaspects.com/data/`)
- **Authentication:** API key (`ENERGY_ASPECTS_API_KEY`)
- **Documentation:** [EA Developer Portal](https://developer.energyaspects.com/reference/quickstart-guide)
- **Catalog utility:** `backend/src/energy_aspects/discover_catalog.py` (generates `output/catalog.json`)

## Scrape Inventory

| Script | Table | Description | dbt Views |
|--------|-------|-------------|-----------|
| [iso_dispatch_costs](scrapes/energy-aspects-scrapes.md#iso-dispatch-costs) | `energy_aspects.iso_dispatch_costs` | Dispatch & fuel costs by fuel type, plant type, hub across ISOs | `ea_pjm_dispatch_costs_monthly` |
| [us_regional_power_model](scrapes/energy-aspects-scrapes.md#us-regional-power-model) | `energy_aspects.us_regional_power_model` | Generation by fuel, demand, gas demand, net imports by ISO | `ea_pjm_power_model_monthly` |
| [na_power_price_heat_rate_spark_forecasts](scrapes/energy-aspects-scrapes.md#na-power-price-heat-rate--spark-forecasts) | `energy_aspects.na_power_price_heat_rate_spark_forecasts` | On-peak prices, heat rates, spark spreads for 5 hubs | `ea_pjm_price_hr_spark_monthly` |
| [monthly_iso_load_model](scrapes/energy-aspects-scrapes.md#monthly-iso-load-model) | `energy_aspects.monthly_iso_load_model` | Weather-normalized load forecasts and actuals by ISO | `ea_pjm_load_model_monthly` |
| [us_installed_capacity_by_iso_and_fuel_type](scrapes/energy-aspects-scrapes.md#us-installed-capacity-by-iso-and-fuel-type) | `energy_aspects.us_installed_capacity_by_iso_and_fuel_type` | Installed capacity by fuel type across ISOs | `ea_pjm_installed_capacity_monthly` |
| [lower_48_average_power_demand_mw](scrapes/energy-aspects-scrapes.md#lower-48-average-power-demand) | `energy_aspects.lower_48_average_power_demand_mw` | ISO-level demand (MW) | None |
| [lower_48_generation_forecast_mw](scrapes/energy-aspects-scrapes.md#lower-48-generation-forecast) | `energy_aspects.lower_48_generation_forecast_mw` | US48 generation by fuel type (MW) | None |
| [lower_48_gas_generation_forecast_mw](scrapes/energy-aspects-scrapes.md#lower-48-gas-generation-forecast) | `energy_aspects.lower_48_gas_generation_forecast_mw` | US48 natural gas generation (MW) | None |
| [lower_48_installed_capacity_mw](scrapes/energy-aspects-scrapes.md#lower-48-installed-capacity) | `energy_aspects.lower_48_installed_capacity_mw` | US48 installed capacity by fuel type (MW) | None |

## Folder Structure

```
backend/src/energy_aspects/
├── energy_aspects_api_utils.py       # API client (auth, GET, pagination, column mapping)
├── discover_catalog.py               # One-time catalog discovery utility
├── output/catalog.json               # Cached API catalog (~8 MB)
└── timeseries/
    ├── runs.py                       # CLI runner (--list, all, numbered selection)
    ├── flows.py                      # Prefect flow wrappers
    ├── iso_dispatch_costs.py
    ├── us_regional_power_model.py
    ├── na_power_price_heat_rate_spark_forecasts.py
    ├── monthly_iso_load_model.py
    ├── us_installed_capacity_by_iso_and_fuel_type.py
    ├── lower_48_average_power_demand_mw.py
    ├── lower_48_generation_forecast_mw.py
    ├── lower_48_gas_generation_forecast_mw.py
    └── lower_48_installed_capacity_mw.py
```

## Raw Table Structure

All raw tables are **wide format**: one `date` column (monthly grain) with many metric columns (one per EA dataset ID). Column names are auto-generated from EA API metadata descriptions via `build_column_map()` in `energy_aspects_api_utils.py`.

Three scripts use explicit `COLUMN_MAP` dictionaries for deterministic column names:
- `na_power_price_heat_rate_spark_forecasts`
- `monthly_iso_load_model`
- `lower_48_average_power_demand_mw`

The remaining scripts auto-generate column names from the API at runtime, which can produce long names truncated to PostgreSQL's 63-character limit with SHA1 hash suffixes.

## dbt Cleaned Views

Energy Aspects data has full dbt pipelines in the `energy_aspects_cleaned` schema (PJM initial scope):

| View | Description |
|------|-------------|
| `ea_pjm_power_model_monthly` | Generation by fuel, demand, gas demand, net imports for PJM |
| `ea_pjm_price_hr_spark_monthly` | PJM West on-peak power price, heat rate, dirty spark spread |
| `ea_pjm_load_model_monthly` | PJM weather-normalized load model |
| `ea_pjm_installed_capacity_monthly` | PJM installed capacity by fuel type (9 fuels) |
| `ea_pjm_dispatch_costs_monthly` | PJM dispatch & fuel costs by fuel/plant/hub (36 columns) |

Pipeline: `source (pass-through) -> staging (PJM column extraction + rename) -> marts (views)`

## Task Scheduler

| Field | Value |
|-------|-------|
| **PowerShell Runner** | `schedulers/task_scheduler_azurepostgresql/energy_aspects/energy_aspects_all_scripts.ps1` |
| **Python Entrypoint** | `python backend/src/energy_aspects/timeseries/runs.py all` |
| **Task Name** | `Energy Aspects (All Scripts)` |
| **Task Path** | `\helioscta-backend\Energy Aspects\` |
| **Trigger** | Daily at 6:00 AM and 6:00 PM (scheduler host local time) |
| **Register** | Run the `.ps1` as Administrator, or use `register_all_tasks.ps1` |
| **Remove** | `Unregister-ScheduledTask -TaskName "Energy Aspects (All Scripts)" -TaskPath "\helioscta-backend\Energy Aspects\"` |

## Known Caveats

- Auto-generated column names depend on EA API metadata descriptions at ingestion time; if EA changes a description, the column name changes
- Truncated column names (>63 chars) include SHA1 hash suffixes for uniqueness, making them less readable
- All tables share `date` as primary key (monthly grain); no sub-monthly data available
- EA data includes both historical actuals and forward forecasts in the same column (distinguished by date relative to today)

## Owner

TBD
