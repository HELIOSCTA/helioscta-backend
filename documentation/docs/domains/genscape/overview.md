# Genscape

Proprietary natural gas production and pipeline flow data from Genscape (Enverus). Feeds three cleaned views: a gas production forecast, daily pipeline production actuals, and daily power burn estimates.

**Use this page** to find Genscape scrape scripts, scheduler configuration, and dbt views.

## Data Source

- **API:** Genscape REST API (`api.genscape.com`)
- **Authentication:** API key (`GEN_API_KEY`)
- **Script location:** `backend/scrapes/genscape/`

## Scrape Inventory

| Script | Table | Description | Freshness |
|--------|-------|-------------|-----------|
| `gas_production_forecast_v2_2025_09_23.py` | `genscape.gas_production_forecast_v2_2025_09_23` | Natural gas production forecast | Daily |
| `daily_pipeline_production_v2_2026_mar_10.py` | `genscape.daily_pipeline_production_v2_2026_mar_10` | Daily actual pipeline production volumes | ~1-day lag |
| `daily_power_estimate.py` | `genscape.daily_power_estimate` | Daily power generation burn estimates | Daily |

## Folder Structure

```
backend/scrapes/genscape/
├── __init__.py
├── genscape_api_utils.py         # Shared API request helper (rate-limit retries)
├── daily_pipeline_production_v2_2026_mar_10.py  # Daily pipeline production scrape
├── daily_power_estimate.py      # Daily power burn estimate scrape
├── gas_production_forecast_v2_2025_09_23.py  # Gas production forecast scrape
├── runs.py                      # CLI runner: python runs.py all
├── flows.py                     # Prefect flow wrappers (importlib lazy-load)
└── logs/                        # Auto-created log directory
```

## Gas Production Forecast — Detail

### Business Purpose
Provides a forward-looking estimate of natural gas production, helping traders assess supply-side fundamentals for natural gas and power pricing.

### Refresh Cadence
- **Trigger:** Scheduled (Windows Task Scheduler)
- **Frequency:** Daily (6:00 AM and 12:00 PM)
- **Freshness:** Same-day forecast updates

## Daily Pipeline Production — Detail

### Business Purpose
Tracks actual daily natural gas flowing through pipelines. Used to compare against forecasts and monitor supply trends.

### Refresh Cadence
- **Trigger:** Scheduled (Windows Task Scheduler)
- **Frequency:** Daily (6:00 AM and 12:00 PM)
- **Freshness:** ~1-day lag

## Daily Power Estimate — Detail

### Business Purpose
Provides daily power generation burn estimates by region and model type. Used to track gas-to-power demand and inform gas/power spread trading.

### Refresh Cadence
- **Trigger:** Scheduled (Windows Task Scheduler)
- **Frequency:** Daily (6:00 AM and 12:00 PM)
- **Freshness:** Same-day estimates

## Task Scheduler

| PowerShell Runner | Python Entrypoint | Task Name | Task Path | Cadence |
|---|---|---|---|---|
| `backend/schedulers/.../genscape/genscape_all_scripts.ps1` | `python backend/scrapes/genscape/runs.py all` | Genscape All Scripts | `\helioscta-backend\Genscape\` | Daily 6:00 AM, 12:00 PM |

### Register / Remove Tasks

```powershell
# Register
.\schedulers\task_scheduler_azurepostgresql\genscape\genscape_all_scripts.ps1

# Remove
Unregister-ScheduledTask -TaskName "Genscape All Scripts" -TaskPath "\helioscta-backend\Genscape\" -Confirm:$false
```

## dbt Views

Three cleaned views in `genscape_cleaned` schema. See [dbt views detail](dbt-views/genscape-cleaned.md).

| View | Description |
|------|-------------|
| `genscape_gas_production_forecast` | Cleaned gas production forecast with standardized columns |
| `genscape_daily_pipeline_production` | Cleaned daily pipeline production with standardized columns |
| `genscape_daily_power_estimate` | Cleaned daily power burn estimates with standardized columns |

## Known Caveats

- Genscape data is proprietary and requires an active subscription
- `gas_production_forecast_v2_2025_09_23.py` filename includes the version date from the original table migration; the `API_SCRAPE_NAME` is `gas_production_forecast` for logging, but the target table retains the versioned name
- Genscape API rate limits to ~10 requests/second; the shared `genscape_api_utils.py` handles 429 retries

## Owner

TBD
