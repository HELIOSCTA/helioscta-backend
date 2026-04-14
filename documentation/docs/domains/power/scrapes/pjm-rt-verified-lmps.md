# PJM Real-Time Verified (Settlement) Hourly LMPs

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/rt_settlements_verified_hourly_lmps.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.rt_settlements_verified_hourly_lmps` |
| **Trigger** | Scheduled |
| **Freshness** | ~60-day lag (settlement timeline) |
| **Owner** | TBD |

## Business Purpose

Final, verified real-time settlement prices used for official P&L calculation and reconciliation. These replace unverified prices once PJM completes its settlement process.

## Downstream

- dbt: `pjm_cleaned.pjm_lmps_rt_hourly`, `pjm_cleaned.pjm_lmps_hourly`

## Known Caveats

- ~60-day delay is normal and expected
- Not useful for intraday decision-making; use unverified LMPs for that
