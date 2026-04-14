# PJM Hourly Demand Bids (DA Cleared Load)

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/hrl_dmd_bids.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.hrl_dmd_bids` |
| **Trigger** | Scheduled |
| **Freshness** | T+0 (same day as DA market clears) |
| **Owner** | TBD |

## Business Purpose

Shows how much load cleared in the day-ahead market by load area and market region. Indicates expected next-day demand commitments.

## Downstream

- dbt: `pjm_cleaned.pjm_load_da_hourly`, `pjm_cleaned.pjm_load_da_daily`
