# PJM Five-Minute Tie Flows

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/five_min_tie_flows.py` |
| **Source** | PJM API |
| **Target Table** | `pjm.five_min_tie_flows` |
| **Trigger** | Scheduled |
| **Freshness** | ~5-minute lag |
| **Owner** | TBD |

## Business Purpose

Tracks electricity flowing in and out of PJM through its interconnections with neighboring regions (MISO, NYISO, TVA, etc.). Tie flows indicate whether PJM is importing or exporting power, which affects prices and congestion.

## Data Captured

- Actual and scheduled tie flow MW by interface
- 5-minute intervals

## Downstream

- dbt: `pjm_cleaned.pjm_tie_flows_hourly`
