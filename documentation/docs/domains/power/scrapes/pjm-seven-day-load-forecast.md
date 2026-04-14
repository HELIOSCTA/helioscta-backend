# PJM Seven-Day Load Forecast

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/seven_day_load_forecast_v1_2025_08_13.py` |
| **Source** | PJM API |
| **Target Table** | `pjm.seven_day_load_forecast_v1_2025_08_13` |
| **Trigger** | Scheduled |
| **Freshness** | Multiple revisions per day |
| **Owner** | TBD |

## Business Purpose

PJM's official 7-day hourly load forecast by forecast area. Updated multiple times per day. Used to anticipate demand and compare against trader/model-driven forecasts.

## Downstream

- dbt: `pjm_cleaned.pjm_load_forecast_hourly`, `pjm_cleaned.pjm_load_forecast_daily`
