# PJM Hourly Load Preliminary

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/hourly_load_prelim.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.hourly_load_prelim` |
| **Trigger** | Scheduled |
| **Freshness** | ~1-hour lag |
| **Owner** | TBD |

## Business Purpose

Near-real-time preliminary load data by area. Used for intraday load monitoring before metered actuals are available.

## Downstream

- dbt: `pjm_cleaned.pjm_load_rt_prelim_hourly`, `pjm_cleaned.pjm_load_rt_prelim_daily`
