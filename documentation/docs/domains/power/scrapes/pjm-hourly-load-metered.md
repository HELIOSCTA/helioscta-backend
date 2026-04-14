# PJM Hourly Load Metered

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/hourly_load_metered.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.hourly_load_metered` |
| **Trigger** | Scheduled |
| **Freshness** | ~2-day lag |
| **Owner** | TBD |

## Business Purpose

Actual metered electricity load by load area. This is the "ground truth" for how much power was consumed and is used for settlement, forecast accuracy analysis, and historical studies.

## Data Captured

- Hourly load in MW by load area (zones like AE, BC, CE, DAY, DOM, DPL, etc.)
- Covers PJM RTO total and all transmission zones

## Primary Key

`datetime_beginning_utc`, `area`

## Downstream

- dbt: `pjm_cleaned.pjm_load_rt_metered_hourly`, `pjm_cleaned.pjm_load_rt_metered_daily`
