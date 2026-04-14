# Power

Electricity market data across 7 U.S. ISOs. Covers load, LMPs, fuel mix, outages, and forecasts. This is the largest domain and the primary data source for daily trading and analysis.

**Use this page** to find any power scrape script, raw table, or dbt view.

## Data Sources

| Source | Type | ISOs Covered | Script Location |
|--------|------|--------------|-----------------|
| **PJM Data Miner 2 / API** | Direct API | PJM only | `backend/scrapes/power/pjm/` |
| **ERCOT Public API** | Direct API (OAuth 2.0) | ERCOT only | `backend/scrapes/power/ercot/` |
| **GridStatus (open source)** | Python library (free) | PJM, ERCOT, MISO, CAISO, NYISO, ISO-NE, SPP | `backend/scrapes/power/gridstatus_open_source/` |
| **GridStatusIO (paid API)** | REST API (paid) | PJM, ERCOT, MISO, CAISO, NYISO, ISO-NE, SPP | `backend/scrapes/power/gridstatusio_api_key/` |
| **Event-Driven Listener** | PostgreSQL LISTEN/NOTIFY | PJM (DA LMPs) | `backend/scrapes/power/event_driven/pjm/` |

## Scrape Inventory

### PJM Direct API (14 scripts)

| Script | Table | Data | Freshness |
|--------|-------|------|-----------|
| [da_hrl_lmps](scrapes/pjm-da-hrl-lmps.md) | `pjm.da_hrl_lmps` | Day-ahead hourly LMPs by pricing node | T+0 (by ~1 PM) |
| [rt_unverified_hourly_lmps](scrapes/pjm-rt-unverified-lmps.md) | `pjm.rt_unverified_hourly_lmps` | Real-time unverified hourly LMPs | Same-day |
| [rt_settlements_verified_hourly_lmps](scrapes/pjm-rt-verified-lmps.md) | `pjm.rt_settlements_verified_hourly_lmps` | Real-time verified (settlement) hourly LMPs | ~60-day lag |
| [hourly_load_metered](scrapes/pjm-hourly-load-metered.md) | `pjm.hourly_load_metered` | Hourly metered (actual) load by area | ~2-day lag |
| [hourly_load_prelim](scrapes/pjm-hourly-load-prelim.md) | `pjm.hourly_load_prelim` | Hourly preliminary real-time load | ~1-hour lag |
| [five_min_instantaneous_load](scrapes/pjm-five-min-load.md) | `pjm.five_min_instantaneous_load_v1_2025_oct_15` | 5-minute instantaneous load by area | ~5-min lag |
| [hrl_dmd_bids](scrapes/pjm-hrl-dmd-bids.md) | `pjm.hrl_dmd_bids` | Hourly day-ahead demand bids (cleared load) | T+0 |
| [seven_day_load_forecast](scrapes/pjm-seven-day-load-forecast.md) | `pjm.seven_day_load_forecast_v1_2025_08_13` | 7-day hourly load forecast by area | Multiple revisions/day |
| [seven_day_outage_forecast](scrapes/pjm-seven-day-outage-forecast.md) | `pjm.seven_day_outage_forecast` | 7-day generation outage forecast by region | Multiple revisions/day |
| [five_min_tie_flows](scrapes/pjm-five-min-tie-flows.md) | `pjm.five_min_tie_flows` | 5-minute actual and scheduled tie flows | ~5-min lag |
| dispatched_reserves | `pjm.dispatched_reserves_v1_2025_08_13` | Dispatched reserves data | TBD |
| operational_reserves | `pjm.operational_reserves_v1_2025_08_13` | Operational reserves data | TBD |
| real_time_dispatched_reserves | `pjm.real_time_dispatched_reserves_v1_2025_08_13` | Real-time dispatched reserves | TBD |
| long_term_outages | `pjm.long_term_outages` | Long-term outage schedule | TBD |

### ERCOT Direct API (9 scripts)

See [ERCOT Scrapes](scrapes/ercot-scrapes.md) for full details including endpoints, primary keys, and operator instructions.

| Script | Table | Data | Freshness |
|--------|-------|------|-----------|
| actual_system_load | `ercot.actual_system_load` | Actual system-wide load | Same-day |
| seven_day_load_forecast | `ercot.seven_day_load_forecast` | 7-day system load forecast | Multiple revisions/day |
| dam_stlmnt_pnt_prices | `ercot.dam_stlmnt_pnt_prices` | DAM settlement point prices | T+0 |
| settlement_point_prices | `ercot.settlement_point_prices` | Settlement point prices (LMPs) | Same-day |
| seven_day_wind_forecast | `ercot.seven_day_wind_forecast` | 7-day system wind forecast | Multiple revisions/day |
| seven_day_wind_forecast_by_region | `ercot.seven_day_wind_forecast_by_region` | 7-day wind forecast by region | Multiple revisions/day |
| seven_day_solar_forecast | `ercot.seven_day_solar_forecast` | 7-day system solar forecast | Multiple revisions/day |
| seven_day_solar_forecast_by_region | `ercot.seven_day_solar_forecast_by_region` | 7-day solar forecast by region | Multiple revisions/day |
| energy_storage_resources_daily | `ercot.energy_storage_resources_daily` | Daily battery storage resource data | Daily |

### GridStatus Open Source (7 ISOs, ~40 scripts)

| ISO | Scripts | Key Data |
|-----|---------|----------|
| **PJM** | 7 | DA/RT LMPs, load, load forecast, fuel mix, solar/wind forecast |
| **ERCOT** | 10 | LMPs, load by zone, load forecast, fuel mix, solar/wind by region, outages, energy storage |
| **MISO** | 7 | DA/RT LMPs, load, load forecast, fuel mix, solar/wind forecast |
| **CAISO** | 5 | DA/RT LMPs, load, load forecast, fuel mix |
| **NYISO** | 6 | DA/RT LMPs, load, load forecast, fuel mix, BTM solar forecast |
| **ISO-NE** | 1 | Fuel mix |
| **SPP** | 6 | DA/RT LMPs, load, load forecast, fuel mix, solar/wind forecast |

### GridStatusIO Paid API (7 ISOs, ~30 scripts)

Mirrors much of the open-source GridStatus data but uses the paid API for higher reliability and additional fields. Covers PJM, ERCOT, MISO, CAISO, NYISO, ISO-NE, and SPP.

### Event-Driven (1 script)

| Script | Trigger | Purpose |
|--------|---------|---------|
| `event_driven/pjm/da_hrl_lmps.py` | PostgreSQL `NOTIFY` on `notifications_pjm_da_hrl_lmps` channel | Reacts to new DA LMP data arrival for near-real-time downstream processing |

## dbt Views (PJM Cleaned)

All PJM dbt views live in the `pjm_cleaned` schema. See [dbt views detail](dbt-views/pjm-cleaned.md).

| View | Grain | Description |
|------|-------|-------------|
| `pjm_lmps_hourly` | Hour x Node | Combined DA, RT-unverified, and RT-verified LMPs |
| `pjm_lmps_daily` | Day x Node | Daily average LMPs |
| `pjm_lmps_rt_hourly` | Hour x Node | Real-time only LMPs (verified + unverified) |
| `pjm_load_da_hourly` | Hour x Region | Day-ahead cleared load |
| `pjm_load_da_daily` | Day x Region | Daily DA load totals |
| `pjm_load_rt_metered_hourly` | Hour x Region | Metered (actual) load |
| `pjm_load_rt_metered_daily` | Day x Region | Daily metered load |
| `pjm_load_rt_prelim_hourly` | Hour x Region | Preliminary real-time load |
| `pjm_load_rt_prelim_daily` | Day x Region | Daily preliminary load |
| `pjm_load_rt_instantaneous_hourly` | Hour x Region | Hourly average of 5-min instantaneous load |
| `pjm_load_forecast_hourly` | Hour x Region | PJM 7-day load forecast |
| `pjm_load_forecast_daily` | Day x Region | Daily load forecast |
| `pjm_gridstatus_load_forecast_hourly` | Hour x Region | GridStatus-sourced load forecast |
| `pjm_fuel_mix_hourly` | Hour x Fuel Type | Hourly generation by fuel |
| `pjm_fuel_mix_daily` | Day x Fuel Type | Daily generation by fuel |
| `pjm_outages_actual_daily` | Day x Region | Actual outage MW by type |
| `pjm_outages_forecast_daily` | Day x Region | Forecast outage MW by type |
| `pjm_tie_flows_hourly` | Hour x Interface | Hourly tie flows |
| `pjm_tie_flows_daily` | Day x Interface | Daily tie flows |
| `pjm_solar_forecast_hourly` | Hour | Solar generation forecast |
| `pjm_wind_forecast_hourly` | Hour | Wind generation forecast |
