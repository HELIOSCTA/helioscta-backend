# PJM Seven-Day Outage Forecast

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/seven_day_outage_forecast.py` |
| **Source** | PJM API |
| **Target Table** | `pjm.seven_day_outage_forecast` |
| **Trigger** | Scheduled |
| **Freshness** | Multiple revisions per day |
| **Owner** | TBD |

## Business Purpose

Shows expected generation outages (planned, maintenance, forced) over the next 7 days by region. Higher outages reduce available supply and can push prices up.

## Data Captured

- Total outage MW, planned outage MW, maintenance outage MW, forced outage MW
- By PJM region

## Downstream

- dbt: `pjm_cleaned.pjm_outages_forecast_daily`, `pjm_cleaned.pjm_outages_actual_daily`
