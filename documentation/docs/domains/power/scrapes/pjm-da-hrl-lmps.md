# PJM Day-Ahead Hourly LMPs

## Scrape Card

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/pjm/da_hrl_lmps.py` |
| **Source** | PJM Data Miner 2 API |
| **Target Table** | `pjm.da_hrl_lmps` |
| **Schema** | `pjm` |
| **Trigger** | Scheduled + Event-Driven |
| **Cadence** | Daily (scheduled); also triggered via PostgreSQL NOTIFY (event-driven) |
| **Freshness** | Available by ~1:30 PM ET day-ahead |
| **Owner** | TBD |

## Business Purpose

Captures the day-ahead electricity prices at every pricing node in PJM. These prices are set the day before delivery and are the primary reference for power trading, hedging, and P&L calculations.

## Data Captured

| Field | Description |
|-------|-------------|
| `datetime_beginning_utc` | Hour start in UTC |
| `datetime_beginning_ept` | Hour start in Eastern Prevailing Time |
| `pnode_id` | Pricing node identifier |
| `pnode_name` | Human-readable node name |
| `voltage` | Voltage level |
| `equipment` | Equipment type |
| `type` | Node type (e.g., ZONE, HUB, AGGREGATE) |
| `total_lmp_da` | Total day-ahead LMP ($/MWh) |
| `energy_lmp_da` | Energy component of DA LMP |
| `congestion_lmp_da` | Congestion component of DA LMP |
| `marginal_loss_lmp_da` | Marginal loss component of DA LMP |

## Primary Key

`datetime_beginning_utc`, `pnode_id`

## Event-Driven Path

In addition to scheduled pulls, this data also has an event-driven pipeline:
- `backend/scrapes/power/event_driven/pjm/da_hrl_lmps.py` listens for `notifications_pjm_da_hrl_lmps` on PostgreSQL
- Managed by the listener service (`backend/scrapes/listeners/`)
- Retries up to 3 times with 5-second backoff on failure

## Downstream

- dbt view: `pjm_cleaned.pjm_lmps_hourly` (combined with RT LMPs)
- dbt view: `pjm_cleaned.pjm_lmps_daily` (daily averages)

## Known Caveats

- PJM occasionally reissues DA prices (rebinding); later pulls will overwrite via upsert
- Multiple node types exist -- filter by `type` to get zones, hubs, or individual generators
