# ERCOT Scrapes

9 scripts pull data from the ERCOT Public Reports API (OAuth 2.0) and the ERCOT Dashboard API.

**Use this page** to find script paths, target tables, and operational details for all ERCOT scrapes.

## Orchestration

| Field | Value |
|-------|-------|
| **Runner** | `backend/scrapes/power/ercot/runs.py` |
| **Prefect Flows** | `backend/scrapes/power/ercot/flows.py` |
| **Shared Helpers** | `backend/scrapes/power/ercot/ercot_api_utils.py` |
| **Scheduler Script** | `backend/schedulers/task_scheduler_azurepostgresql/power/ercot.ps1` |
| **Task Name** | `ERCOT - ISO` |
| **Task Path** | `\helioscta-backend\Power\` |
| **Cadence** | Every hour, 24/7 (scheduler host local time) |
| **Orchestration Mode** | Scheduled |

### Register the task

```powershell
# From an elevated PowerShell prompt on the scheduler host:
.\schedulers\task_scheduler_azurepostgresql\power\ercot.ps1
```

### Remove the task

```powershell
Unregister-ScheduledTask -TaskName "ERCOT - ISO" -TaskPath "\helioscta-backend\Power\" -Confirm:$false
```

---

## Actual System Load

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/actual_system_load.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np6-346-cd/act_sys_load_by_fzn` |
| **Target Table** | `ercot.actual_system_load` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Same-day |

### Business Purpose
Actual system-wide load by forecast zone. Used for load analysis and backtesting forecast accuracy.

### Data Captured
Operating day, hour ending, and actual MW load per forecast zone.

### Primary Key
`operatingday`, `hourending`

---

## Seven-Day Load Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/seven_day_load_forecast.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np3-565-cd/lf_by_model_weather_zone` |
| **Target Table** | `ercot.seven_day_load_forecast` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Multiple revisions/day |

### Business Purpose
7-day hourly load forecast by model and weather zone. Multiple model revisions are captured per day for tracking forecast evolution.

### Data Captured
Posted datetime, delivery date, hour ending, model name, weather zone, and forecast MW.

### Primary Key
`posteddatetime`, `deliverydate`, `hourending`, `model`

---

## DAM Settlement Point Prices

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/dam_stlmnt_pnt_prices.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np4-190-cd/dam_stlmnt_pnt_prices` |
| **Target Table** | `ercot.dam_stlmnt_pnt_prices` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | T+0 (by mid-afternoon) |

### Business Purpose
Day-ahead market settlement point prices for hub nodes (HB_NORTH, HB_SOUTH, HB_WEST, HB_HOUSTON). Core pricing data for ERCOT day-ahead trading.

### Data Captured
Delivery date, hour ending, settlement point, and settlement point price.

### Primary Key
`deliverydate`, `hourending`, `settlementpoint`

---

## Settlement Point Prices (Real-Time)

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/settlement_point_prices.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np6-905-cd/spp_node_zone_hub` |
| **Target Table** | `ercot.settlement_point_prices` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Same-day |

### Business Purpose
Settlement point prices at resource nodes, hubs, and load zones. Covers real-time 15-minute interval pricing.

### Data Captured
Delivery date, delivery hour, delivery interval, settlement point, and settlement point price.

### Primary Key
`deliverydate`, `deliveryhour`, `deliveryinterval`

---

## Seven-Day Solar Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/seven_day_solar_forecast.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np4-737-cd/spp_hrly_avrg_actl_fcast` |
| **Target Table** | `ercot.seven_day_solar_forecast` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Multiple revisions/day |

### Business Purpose
Hourly averaged actual and forecasted solar power production values (system-wide).

### Data Captured
Posted datetime, delivery date, hour ending, and system-wide solar MW (actual + forecast).

### Primary Key
`posteddatetime`, `deliverydate`, `hourending`

---

## Seven-Day Solar Forecast by Region

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/seven_day_solar_forecast_by_region.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np4-745-cd/spp_hrly_actual_fcast_geo` |
| **Target Table** | `ercot.seven_day_solar_forecast_by_region` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Multiple revisions/day |

### Business Purpose
Hourly averaged actual and forecasted solar power production by geographical region.

### Data Captured
Posted datetime, delivery date, hour ending, region, and solar MW (actual + forecast).

### Primary Key
`posteddatetime`, `deliverydate`, `hourending`

---

## Seven-Day Wind Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/seven_day_wind_forecast.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np4-732-cd/wpp_hrly_avrg_actl_fcast` |
| **Target Table** | `ercot.seven_day_wind_forecast` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Multiple revisions/day |

### Business Purpose
Hourly averaged actual and forecasted wind power production values (system-wide).

### Data Captured
Posted datetime, delivery date, hour ending, and system-wide wind MW (actual + forecast).

### Primary Key
`posteddatetime`, `deliverydate`, `hourending`

---

## Seven-Day Wind Forecast by Region

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/seven_day_wind_forecast_by_region.py` |
| **Source** | ERCOT Public Reports API |
| **Endpoint** | `np4-742-cd/wpp_hrly_actual_fcast_geo` |
| **Target Table** | `ercot.seven_day_wind_forecast_by_region` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Multiple revisions/day |

### Business Purpose
Hourly averaged actual and forecasted wind power production by geographical region.

### Data Captured
Posted datetime, delivery date, hour ending, region, and wind MW (actual + forecast).

### Primary Key
`posteddatetime`, `deliverydate`, `hourending`

---

## Energy Storage Resources (Daily)

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/power/ercot/energy_storage_resources_daily.py` |
| **Source** | ERCOT Dashboard API (no OAuth) |
| **Endpoint** | `https://www.ercot.com/api/1/services/read/dashboards/energy-storage-resources.json` |
| **Target Table** | `ercot.energy_storage_resources_daily` |
| **Trigger** | Scheduled |
| **Cadence** | Hourly |
| **Freshness** | Daily |

### Business Purpose
Daily battery storage resource data — total charging, total discharging, and net output. Covers previous-day and current-day intervals.

### Data Captured
Timestamp, datetime, date, time, total charging MW, total discharging MW, net output MW.

### Primary Key
`TIMESTAMP`

### Known Caveats
- Uses the ERCOT dashboard JSON endpoint, not the OAuth-protected Public Reports API.
- Column names are UPPERCASE (matches the dashboard API response format).
- Always returns exactly two days of data (previous + current).
