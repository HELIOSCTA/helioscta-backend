# PJM Real-Time Unverified Hourly LMPs

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/rt_unverified_hourly_lmps.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.rt_unverified_hourly_lmps` |
| **Trigger** | Scheduled |
| **Freshness** | Same-day, ~1 hour lag |
| **Owner** | TBD |

## Business Purpose

Captures preliminary (unverified) real-time electricity prices at pricing nodes. These are the first available RT prices and are used for intraday P&L tracking before verified settlement prices are available (~60 days later).

## Data Captured

Same structure as DA LMPs but with real-time price components (`total_lmp_rt`, `energy_lmp_rt`, `congestion_lmp_rt`, `marginal_loss_lmp_rt`).

## Primary Key

`datetime_beginning_utc`, `pnode_id`

## Downstream

- dbt: `pjm_cleaned.pjm_lmps_rt_hourly`, `pjm_cleaned.pjm_lmps_hourly`

## Known Caveats

- "Unverified" means these prices may be revised during settlement (~60 days later)
- Use for intraday monitoring; use verified LMPs for final settlement
