# PJM Five-Minute Instantaneous Load

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/five_min_instantaneous_load_v1_2025_OCT_15.py` |
| **Source** | PJM API |
| **Target Table** | `pjm.five_min_instantaneous_load_v1_2025_oct_15` |
| **Trigger** | Scheduled |
| **Freshness** | ~5-minute lag |
| **Owner** | TBD |

## Business Purpose

Highest-frequency load data available. Shows real-time electricity demand every 5 minutes by load area. Used for real-time monitoring and intraday trading decisions.

## Downstream

- dbt: `pjm_cleaned.pjm_load_rt_instantaneous_hourly` (aggregated to hourly)
