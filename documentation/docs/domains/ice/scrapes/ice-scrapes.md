# ICE Scrape Cards

## Intraday Quotes

| Field | Value |
|-------|-------|
| **Runner** | `backend/src/ice_python/intraday_quotes/runs.py all` |
| **Script** | `backend/src/ice_python/intraday_quotes/runner_pjm_short_term.py` |
| **Symbol Registry** | `backend/src/ice_python/symbols/pjm_short_term_symbols.py` |
| **Source** | ICE Python API (PJM short-term quote snapshots) |
| **Target Table** | `ice_python.intraday_quotes` |
| **Schema** | `ice_python` |
| **Scheduler Script** | `schedulers/task_scheduler_azurepostgresql/ice_python/intraday_quotes.ps1` |
| **Task Name** | `Intraday Quotes` |
| **Task Path** | `\helioscta-backend\ICE Python\` |
| **Trigger** | Scheduled (Windows Task Scheduler) |
| **Cadence** | Every 5 minutes from 6:00 AM to 4:00 PM, Monday-Friday (scheduler host local time) |
| **Owner** | TBD |

### Business Purpose

Captures intraday ICE quote snapshots for configured PJM short-term power symbols and stores them in one long-format table for repeatable polling and downstream analysis.

### Data Captured

| Field | Description |
|-------|-------------|
| `trade_date` | MST calendar date derived from `snapshot_at` |
| `snapshot_at` | Snapshot timestamp stored in MST |
| `data_type` | Quote field name from ICE (for example `Bid`, `Ask`, `VWAP`) |
| `symbol` | ICE instrument symbol from `pjm_short_term_symbols.py` |
| `value` | Numeric quote value for the symbol and data type |

### Register the task

```powershell
# From an elevated PowerShell prompt on the scheduler host:
.\schedulers\task_scheduler_azurepostgresql\ice_python\intraday_quotes.ps1
```

### Remove the task

```powershell
Unregister-ScheduledTask -TaskName "Intraday Quotes" -TaskPath "\helioscta-backend\ICE Python\" -Confirm:$false
```

---

## Contract Dates

| Field | Value |
|-------|-------|
| **Runner** | `backend/src/ice_python/contract_dates/runs.py all` |
| **Script** | `backend/src/ice_python/contract_dates/runner_pjm_short_term.py` |
| **Symbol Registry** | `backend/src/ice_python/symbols/pjm_short_term_symbols.py` |
| **Source** | ICE Python API (`Strip`, `Startdt`, `Enddt` fields) |
| **Target Table** | `ice_python.contract_dates` |
| **Schema** | `ice_python` |
| **Scheduler Script** | `schedulers/task_scheduler_azurepostgresql/ice_python/contract_dates.ps1` |
| **Task Name** | `Contract Dates` |
| **Task Path** | `\helioscta-backend\ICE Python\` |
| **Trigger** | Scheduled (Windows Task Scheduler) |
| **Cadence** | Every 1 hour from 6:00 AM to 4:00 PM, Monday-Friday (scheduler host local time) |
| **Owner** | TBD |

### Business Purpose

Captures the rolling contract date metadata (strip label, begin date, end date) for PJM short-term power products. Weekly products like `PDP W1-IUS` ("Next Week") map to different calendar dates each week, so this table provides a historical record of which dates each symbol covered on any given trade date.

### Data Captured

| Field | Description |
|-------|-------------|
| `trade_date` | MST calendar date the snapshot was captured |
| `symbol` | ICE instrument symbol from `pjm_short_term_symbols.py` |
| `strip` | Human-readable strip label (e.g. `Bal Week`, `Next Week`, `2nd Week`) |
| `start_date` | Contract delivery begin date |
| `end_date` | Contract delivery end date |

### Register the task

```powershell
# From an elevated PowerShell prompt on the scheduler host:
.\schedulers\task_scheduler_azurepostgresql\ice_python\contract_dates.ps1
```

### Remove the task

```powershell
Unregister-ScheduledTask -TaskName "Contract Dates" -TaskPath "\helioscta-backend\ICE Python\" -Confirm:$false
```

---

## Next-Day Gas

| Field | Value |
|-------|-------|
| **Script** | `backend/src/ice_python/next_day_gas/next_day_gas_v1_2025_dec_16.py` |
| **Source** | ICE Python API (firm physical next-day gas) |
| **Target Table** | `ice_python.next_day_gas_v1_2025_dec_16` |
| **Schema** | `ice_python` |
| **dbt Views** | `ice_python_cleaned.ice_python_next_day_gas_hourly`, `ice_python_cleaned.ice_python_next_day_gas_daily` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Intraday |
| **Owner** | TBD |

### Business Purpose

Captures hourly VWAP close prices for firm physical next-day natural gas at 15 major U.S. trading hubs. These are the prices at which physical gas changes hands for delivery the next day.

### Data Captured

| Field | Description |
|-------|-------------|
| `trade_date` | Date the trade was executed |
| `symbol` | ICE instrument symbol (e.g., `XGF D1-IPG` for Henry Hub) |
| `data_type` | Price type identifier |
| `value` | Trade price ($/MMBtu) |
| `created_at` | Row creation timestamp |
| `updated_at` | Row last-update timestamp |

### Hubs Covered

Henry Hub, Transco Station 85, Pine Prairie, Waha, Houston Ship Channel, NGPL TX/OK, Transco Zone 5 South, Tetco M3, AGT, Iroquois Zone 2, SoCal Citygate, PG&E Citygate, CIG, NGPL Midcontinent, MichCon

### Known Caveats

- Raw data is in long format (one row per symbol per trade date); dbt pivots to wide format
- No data on weekends and holidays; dbt forward-fills gaps

---

## BALMO

| Field | Value |
|-------|-------|
| **Script** | `backend/src/ice_python/balmo/balmo_v1_2025_dec_16.py` |
| **Source** | ICE Python API (balance-of-month gas swaps) |
| **Target Table** | `ice_python.balmo_v1_2025_dec_16` |
| **Schema** | `ice_python` |
| **dbt Views** | `ice_python_cleaned.ice_python_balmo` |
| **Trigger** | Scheduled (Prefect) |
| **Freshness** | Daily |
| **Owner** | TBD |

### Business Purpose

Captures daily settle prices for balance-of-month (BALMO) natural gas basis swaps at 15 hubs. BALMO prices represent the remaining value of gas delivery for the current calendar month.

### Data Captured

| Field | Description |
|-------|-------------|
| `trade_date` | Date the settle was recorded |
| `symbol` | ICE instrument symbol (e.g., `HHD B0-IUS` for Henry Hub BALMO) |
| `data_type` | Price type identifier |
| `value` | Settle price ($/MMBtu) |
| `created_at` | Row creation timestamp |
| `updated_at` | Row last-update timestamp |

### Known Caveats

- BALMO prices reset at the start of each delivery month
- No data on weekends and holidays; dbt forward-fills gaps

