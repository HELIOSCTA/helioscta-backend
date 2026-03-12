# Data Catalog

Central reference for every dataset in HeliosCTA. Find any table by name, see what it answers, where data comes from, and how fresh it is.

Click any link in the Source Scrape or dbt View columns for details.

---

## Power -- PJM Electricity Markets

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `pjm_lmps_hourly` | Hourly electricity prices combining day-ahead and real-time markets | "What were DA and RT power prices at each PJM hub this hour?" | [DA LMPs](domains/power/scrapes/pjm-da-hrl-lmps.md), [RT Unverified](domains/power/scrapes/pjm-rt-unverified-lmps.md), [RT Verified](domains/power/scrapes/pjm-rt-verified-lmps.md) | [pjm_lmps_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_lmps_hourly) | DA: daily by 1 PM; RT: every 5 min | TBD |
| `pjm_lmps_daily` | Daily average prices by time period (flat, on-peak, off-peak) | "What was the average power price today during peak hours?" | Same as above | [pjm_lmps_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_lmps_daily) | Daily | TBD |
| `pjm_lmps_rt_hourly` | Real-time only prices (uses verified when available, falls back to unverified) | "What is the current real-time power price?" | [RT Unverified](domains/power/scrapes/pjm-rt-unverified-lmps.md), [RT Verified](domains/power/scrapes/pjm-rt-verified-lmps.md) | [pjm_lmps_rt_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_lmps_rt_hourly) | Every 5 min (unverified); ~60-day lag (verified) | TBD |
| `pjm_load_da_hourly` | Day-ahead cleared electricity demand by region | "How much load did the DA market clear for tomorrow?" | [DA Demand Bids](domains/power/scrapes/pjm-hrl-dmd-bids.md) | [pjm_load_da_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_load_da_hourly) | Daily by ~1 PM | TBD |
| `pjm_load_da_daily` | Daily DA load totals by region and time period | "What was yesterday's total on-peak DA load in PJM?" | Same as above | [pjm_load_da_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_load_da_daily) | Daily | TBD |
| `pjm_load_rt_metered_hourly` | Actual metered (settled) load by region | "What was the actual electricity consumption this hour?" | [Hourly Load Metered](domains/power/scrapes/pjm-hourly-load-metered.md) | [pjm_load_rt_metered_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_load_rt_metered_hourly) | ~2-day lag | TBD |
| `pjm_load_rt_metered_daily` | Daily metered load by region and time period | "What was actual daily load last week?" | Same as above | [pjm_load_rt_metered_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_load_rt_metered_daily) | ~2-day lag | TBD |
| `pjm_load_rt_prelim_hourly` | Preliminary real-time load (available same-day) | "What is load running at right now?" | [Hourly Load Prelim](domains/power/scrapes/pjm-hourly-load-prelim.md) | [pjm_load_rt_prelim_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_load_rt_prelim_hourly) | ~1-hour lag | TBD |
| `pjm_load_rt_prelim_daily` | Daily preliminary load by region and time period | "What is today's running load total?" | Same as above | [pjm_load_rt_prelim_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_load_rt_prelim_daily) | ~1-hour lag | TBD |
| `pjm_load_rt_instantaneous_hourly` | Hourly average of 5-minute real-time load readings | "What does the most granular load data show for this hour?" | [5-Min Load](domains/power/scrapes/pjm-five-min-load.md) | [pjm_load_rt_instantaneous_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_load_rt_instantaneous_hourly) | ~5-min lag | TBD |
| `pjm_load_forecast_hourly` | PJM's official 7-day load forecast, ranked by recency | "What is PJM forecasting for load tomorrow?" | [7-Day Load Forecast](domains/power/scrapes/pjm-seven-day-load-forecast.md) | [pjm_load_forecast_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_load_forecast_hourly) | Multiple times/day | TBD |
| `pjm_load_forecast_daily` | Daily load forecast by region and time period, holiday-aware | "What is forecast peak load for next Monday?" | Same as above | [pjm_load_forecast_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_load_forecast_daily) | Multiple times/day | TBD |
| `pjm_gridstatus_load_forecast_hourly` | Alternative load forecast from GridStatus (second opinion) | "How does GridStatus's load forecast compare to PJM's?" | [GridStatus](domains/power/scrapes/gridstatus-overview.md) | [pjm_gridstatus_load_forecast_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_gridstatus_load_forecast_hourly) | Multiple times/day | TBD |
| `pjm_fuel_mix_hourly` | Hourly generation by fuel type (gas, coal, nuclear, wind, solar, etc.) | "How much generation is coming from gas vs renewables right now?" | [GridStatus](domains/power/scrapes/gridstatus-overview.md) | [pjm_fuel_mix_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_fuel_mix_hourly) | Hourly | TBD |
| `pjm_fuel_mix_daily` | Daily generation totals by fuel type and time period | "What was yesterday's on-peak renewable share?" | Same as above | [pjm_fuel_mix_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_fuel_mix_daily) | Hourly | TBD |
| `pjm_outages_actual_daily` | Actual generation outages by type (planned, maintenance, forced) | "How much generation capacity was offline today?" | [7-Day Outage Forecast](domains/power/scrapes/pjm-seven-day-outage-forecast.md) | [pjm_outages_actual_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_outages_actual_daily) | Multiple times/day | TBD |
| `pjm_outages_forecast_daily` | Forecasted outages for the next 7 days, ranked by recency | "How much generation will be offline next week?" | Same as above | [pjm_outages_forecast_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_outages_forecast_daily) | Multiple times/day | TBD |
| `pjm_tie_flows_hourly` | Hourly electricity flows between PJM and neighboring grids | "How much power is PJM importing/exporting this hour?" | [5-Min Tie Flows](domains/power/scrapes/pjm-five-min-tie-flows.md) | [pjm_tie_flows_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_tie_flows_hourly) | ~5-min lag | TBD |
| `pjm_tie_flows_daily` | Daily net tie flows by interface and time period | "What was net import into PJM today?" | Same as above | [pjm_tie_flows_daily](domains/power/dbt-views/pjm-cleaned.md#pjm_tie_flows_daily) | ~5-min lag | TBD |
| `pjm_solar_forecast_hourly` | Solar generation forecast (grid-scale + rooftop), ranked by recency | "How much solar generation does PJM expect tomorrow?" | [GridStatus](domains/power/scrapes/gridstatus-overview.md) | [pjm_solar_forecast_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_solar_forecast_hourly) | Multiple times/day | TBD |
| `pjm_wind_forecast_hourly` | Wind generation forecast, ranked by recency | "How much wind generation does PJM expect tomorrow?" | [GridStatus](domains/power/scrapes/gridstatus-overview.md) | [pjm_wind_forecast_hourly](domains/power/dbt-views/pjm-cleaned.md#pjm_wind_forecast_hourly) | Multiple times/day | TBD |

---

## Meteologica -- Independent Power Forecasts

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `meteologica_pjm_demand_forecast_hourly` | Hourly demand forecast for PJM (RTO + all sub-regions) from an independent model | "What does Meteologica's model say PJM demand will be tomorrow?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (36 PJM demand scripts) | [meteologica_pjm_demand_forecast_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_demand_forecast_hourly) | Multiple times/day | TBD |
| `meteologica_pjm_generation_forecast_hourly` | Hourly solar, wind, and hydro generation forecast for PJM | "How much renewable generation does Meteologica expect in PJM?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (14 PJM gen scripts) | [meteologica_pjm_generation_forecast_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_generation_forecast_hourly) | Multiple times/day | TBD |
| `meteologica_pjm_da_price_forecast_hourly` | Hourly day-ahead price forecast for PJM system and 12 trading hubs | "What does Meteologica predict DA prices will be at Western Hub?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (13 PJM price scripts) | [meteologica_pjm_da_price_forecast_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_da_price_forecast_hourly) | Multiple times/day | TBD |
| `meteologica_pjm_demand_forecast_ecmwf_ens_hourly` | ECMWF-ENS ensemble hourly demand forecast for PJM (RTO + all sub-regions) | "What does the ECMWF ensemble model say about PJM demand?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (36 PJM ECMWF-ENS demand scripts) | [meteologica_pjm_demand_forecast_ecmwf_ens_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_demand_forecast_ecmwf_ens_hourly) | Multiple times/day | TBD |
| `meteologica_pjm_demand_observation` | Actual observed hourly demand for PJM across all sub-regions | "What was actual demand at each PJM region this hour?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (36 PJM demand observation scripts) | [meteologica_pjm_demand_observation](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_demand_observation) | Multiple times/day | TBD |
| `meteologica_pjm_generation_observation` | Actual observed hourly generation for PJM solar, wind, and hydro | "What was actual renewable generation in PJM?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (9 PJM generation observation scripts) | [meteologica_pjm_generation_observation](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_generation_observation) | Multiple times/day | TBD |
| `meteologica_pjm_da_price_observation` | Actual observed hourly DA prices for PJM system and 12 hubs | "What were actual DA prices at each PJM hub?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (13 PJM DA price observation scripts) | [meteologica_pjm_da_price_observation](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_da_price_observation) | Multiple times/day | TBD |
| `meteologica_pjm_demand_projection_hourly` | Extended hourly demand projections for PJM based on blended models | "What is the extended demand outlook for PJM sub-regions?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (33 PJM demand projection scripts) | [meteologica_pjm_demand_projection_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_demand_projection_hourly) | Multiple times/day | TBD |
| `meteologica_pjm_generation_normal_hourly` | Historical average (normal) hourly generation for PJM solar, wind, and hydro | "How does current generation compare to historical norms?" | [Meteologica Scrapes](domains/meteologica/scrapes/meteologica-scrapes.md) (9 PJM generation normal scripts) | [meteologica_pjm_generation_normal_hourly](domains/meteologica/dbt-views/meteologica-cleaned.md#meteologica_pjm_generation_normal_hourly) | Multiple times/day | TBD |

> **Note:** Meteologica covers all 7 ISOs (PJM, ERCOT, MISO, CAISO, NYISO, ISO-NE, SPP) plus a national aggregate (L48), totaling 533 scrape scripts. Only PJM currently has dbt cleaned views (forecasts, observations, normals, projections). Other ISOs are available as raw tables.

---

## WSI -- Weather Degree Days and Temperature

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `wdd_observed` | Historical daily observed weighted degree days by region | "What were actual heating/cooling degree days in PJM last week?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#daily-observed-wdd) | [wdd_observed](domains/wsi/dbt-views/wsi-cleaned.md#wdd_observed) | Daily | TBD |
| `wdd_normals` | 10-year and 30-year average degree days by calendar day (TABLE) | "Is this week's weather warmer or colder than normal?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#historical-observations) | [wdd_normals](domains/wsi/dbt-views/wsi-cleaned.md#wdd_normals) | Rebuilt on dbt run | TBD |
| `wdd_forecast_models` | Degree day forecasts from individual weather models (GFS, ECMWF) ranked by recency | "What is the GFS model saying about heating demand next week?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#weighted-degree-day-forecasts) (5 model scripts) | [wdd_forecast_models](domains/wsi/dbt-views/wsi-cleaned.md#wdd_forecast_models) | 2-4x daily | TBD |
| `wdd_forecast_wsi` | WSI's best-estimate blended degree day forecast, ranked by recency | "What is the best weather forecast for gas and power demand?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#wsi-blended-wdd-forecast) | [wdd_forecast_wsi](domains/wsi/dbt-views/wsi-cleaned.md#wdd_forecast_wsi) | 2-4x daily | TBD |
| `temp_observed_hourly` | Hourly observed temperature and weather conditions by weather station | "What was the actual temperature at each PJM station yesterday?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#historical-observations) | [temp_observed_hourly](domains/wsi/dbt-views/wsi-cleaned.md#temp_observed_hourly) | Daily | TBD |
| `temp_forecast_hourly` | Hourly temperature forecast by weather station with normal and feels-like | "What is the forecast temperature at each station for today?" | [WSI Scrapes](domains/wsi/scrapes/wsi-scrapes.md#hourly-forecasts) | [temp_forecast_hourly](domains/wsi/dbt-views/wsi-cleaned.md#temp_forecast_hourly) | 2-4x daily | TBD |

> **Note:** WSI also provides city-level forecasts and natural gas BCF forecasts as raw tables. See the [WSI overview](domains/wsi/overview.md) for the full inventory.

---

## NatGas -- WM DataFeed (Azure SQL)

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `genscape_noms` | Denormalized gas nominations with pipeline, location, cycle, and no-notice data | "What is the scheduled capacity at this pipeline location today?" | WM DataFeed (gasdatafeed_import.ps1) | [genscape_noms](domains/natgas/dbt-views/natgas-cleaned.md#genscape_noms) | Delta: every 20/30/40 min | TBD |
| `lng_facilities` | LNG terminal nomination flows for 9 US export facilities with multi-pipeline aggregation | "How much gas is flowing to Cameron LNG today?" | Same as above | [lng_facilities](domains/natgas/dbt-views/natgas-cleaned.md#lng_facilities) | Delta: every 20/30/40 min | TBD |
| `salt_facilities_bcf` | Daily salt cavern storage flows in BCF pivoted by facility with regional subtotals | "What is total salt storage injection/withdrawal in TX today?" | Same as above | [salt_facilities_bcf](domains/natgas/dbt-views/natgas-cleaned.md#salt_facilities_bcf) | Delta: every 20/30/40 min | TBD |
| `salt_inventories` | Daily salt cavern inventory levels and capacity metrics by facility | "What is the current inventory at Pine Prairie vs design capacity?" | Same as above | [salt_inventories](domains/natgas/dbt-views/natgas-cleaned.md#salt_inventories) | Delta: every 20/30/40 min | TBD |

> **Note:** NatGas views live on Azure SQL Server (`GenscapeDataFeed.natgas_cleaned`), not Azure PostgreSQL. This dbt project uses `dbt-sqlserver`.

---

## Genscape -- Natural Gas Production

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `genscape_gas_production_forecast` | Forward-looking natural gas production estimate | "What is the gas production outlook for next month?" | [Genscape Scrapes](domains/genscape/scrapes/genscape-scrapes.md#gas-production-forecast) | [genscape_gas_production_forecast](domains/genscape/dbt-views/genscape-cleaned.md#genscape_gas_production_forecast) | Daily | TBD |
| `genscape_daily_pipeline_production` | Actual daily gas flowing through pipelines by region | "How much gas was produced yesterday vs the forecast?" | [Genscape Scrapes](domains/genscape/scrapes/genscape-scrapes.md#daily-pipeline-production) | [genscape_daily_pipeline_production](domains/genscape/dbt-views/genscape-cleaned.md#genscape_daily_pipeline_production) | Daily (~1-day lag) | TBD |

---

## Positions -- Trading Positions (Marex + NAV Funds)

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `marex_and_nav_positions_grouped` | All positions aggregated by exchange, contract, and account (TABLE) | "What is our total position in each contract across all funds?" | [Positions Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#position-pulls) (5 scripts) | [marex_and_nav_positions_grouped](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#marex_and_nav_positions_grouped) | T+1 (next morning) | TBD |
| `marex_and_nav_positions_grouped_latest` | Latest positions with day-over-day quantity and P&L changes | "What changed in our positions overnight?" | Same as above | [marex_and_nav_positions_grouped_latest](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#marex_and_nav_positions_grouped_latest) | T+1 | TBD |
| `marex_positions` | Marex broker positions only | "What are our open Marex positions?" | [Positions Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#marex-positions) | [marex_positions](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |
| `nav_positions` | Combined NAV fund positions (all 4 funds) | "What does NAV show for our total positions?" | [Positions Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#nav-fund-positions-4-scripts) | [nav_positions](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |
| `nav_positions_agr` | AGR fund positions with product codes | "What are AGR's open positions?" | Same as above | [nav_positions_agr](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |
| `nav_positions_moross` | Moross fund positions with product codes | "What are Moross's open positions?" | Same as above | [nav_positions_moross](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |
| `nav_positions_pnt` | PNT fund positions with product codes | "What are PNT's open positions?" | Same as above | [nav_positions_pnt](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |
| `nav_positions_titan` | Titan fund positions with product codes | "What are Titan's open positions?" | Same as above | [nav_positions_titan](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#individual-fund-views) | T+1 | TBD |

---

## Trades -- Trade Confirmations (Clear Street + Marex)

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `clear_street_trades` | End-of-day trade confirmations with product codes | "What trades were confirmed by Clear Street today?" | [Trades Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#clear-street-end-of-day-trades) | [clear_street_trades](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#detail-views-one-row-per-trade) | T+1 | TBD |
| `clear_street_intraday_trades` | Intraday trade confirmations (available throughout the day) | "What trades have been confirmed so far today?" | [Trades Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#clear-street-intraday-trades) | [clear_street_intraday_trades](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#detail-views-one-row-per-trade) | Intraday (multiple/day) | TBD |
| `marex_allocated_trades` | Officially cleared and allocated Marex trades | "Which Marex trades have been allocated to which accounts?" | [Trades Scrapes](domains/positions-and-trades/scrapes/positions-and-trades-scrapes.md#marex-allocated-trades) | [marex_allocated_trades](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#detail-views-one-row-per-trade) | T+1 | TBD |
| `clear_street_trades_grouped` | Daily trade totals grouped by product and region | "How many lots of NG did we trade today across all accounts?" | Same as EOD trades | [clear_street_trades_grouped](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#grouped-views-aggregated-by-productcontract) | T+1 | TBD |
| `clear_street_intraday_trades_grouped` | Intraday trade totals grouped by product and region | "What is our running intraday trade count by product?" | Same as intraday trades | [clear_street_intraday_trades_grouped](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#grouped-views-aggregated-by-productcontract) | Intraday | TBD |
| `marex_allocated_trades_grouped` | Marex trade totals grouped by product and region | "What is the total volume of allocated Marex trades by product?" | Same as Marex trades | [marex_allocated_trades_grouped](domains/positions-and-trades/dbt-views/positions-and-trades-cleaned.md#grouped-views-aggregated-by-productcontract) | T+1 | TBD |

---

## ICE -- Natural Gas & Power Derivatives

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `ice_python_balmo` | Daily BALMO gas swap settle prices across 15 U.S. hubs | "What is the remaining-month gas basis at Henry Hub vs Waha?" | [ICE Scrapes](domains/ice/scrapes/ice-scrapes.md#balmo) | [ice_python_balmo](domains/ice/dbt-views/ice-python-cleaned.md#ice_python_balmo) | Daily | TBD |
| `ice_python_next_day_gas_hourly` | Hourly next-day firm physical gas prices at 15 hubs | "What is the current intraday gas price at Henry Hub?" | [ICE Scrapes](domains/ice/scrapes/ice-scrapes.md#next-day-gas) | [ice_python_next_day_gas_hourly](domains/ice/dbt-views/ice-python-cleaned.md#ice_python_next_day_gas_hourly) | Intraday | TBD |
| `ice_python_next_day_gas_daily` | Daily next-day gas cash prices (10 AM snapshot) at 15 hubs | "What was the daily gas settlement at each hub?" | [ICE Scrapes](domains/ice/scrapes/ice-scrapes.md#next-day-gas) | [ice_python_next_day_gas_daily](domains/ice/dbt-views/ice-python-cleaned.md#ice_python_next_day_gas_daily) | Daily | TBD |

---

## EIA -- Government Energy Data

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `eia_930_hourly` | Hourly electricity generation by fuel type across all U.S. regions (60+ BAs), converted to EST | "How much gas-fired generation is running in PJM right now?" | [EIA Scrapes](domains/eia/scrapes/eia-scrapes.md#hourly-generation-by-fuel-type) | [eia_930_hourly](domains/eia/dbt-views/eia-cleaned.md#eia_930_hourly) | Hourly (~1-hr lag) | TBD |
| `eia_930_daily` | Daily average generation by fuel type and respondent with thermal % breakdowns | "What was yesterday's average gas vs coal generation in ERCOT?" | [EIA Scrapes](domains/eia/scrapes/eia-scrapes.md#hourly-generation-by-fuel-type) | [eia_930_daily](domains/eia/dbt-views/eia-cleaned.md#eia_930_daily) | Hourly (~1-hr lag) | TBD |
| `eia_natural_gas_consumption_by_end_use_monthly` | Monthly state-level natural gas consumption by end-use sector (residential, commercial, industrial, electric power, etc.) | "How much natural gas did Texas consume for electric power last month vs residential?" | [EIA Scrapes](domains/eia/scrapes/eia-scrapes.md#natural-gas-consumption-by-end-use) | [eia_natural_gas_consumption_by_end_use_monthly](domains/eia/dbt-views/eia-cleaned.md#eia_natural_gas_consumption_by_end_use_monthly) | Monthly | TBD |
| `eia.weekly_underground_storage` | Weekly natural gas in underground storage by region | "How does this week's gas storage compare to last year?" | [EIA Scrapes](domains/eia/scrapes/eia-scrapes.md#weekly-natural-gas-underground-storage) | None (raw table) | Weekly (Thursday) | TBD |

---

## Utils -- Shared Date Dimensions

| Model / Table | Plain-English Purpose | Business Question Answered | Source Scrape(s) | Related dbt View(s) | Refresh Frequency | Owner |
|---|---|---|---|---|---|---|
| `utils_v1_dates_daily` | Daily date spine (2010 through current+7 years, excludes Feb 29) with season, EIA week, and NERC holiday flags | "What EIA storage week does this date fall in? Is it a NERC holiday?" | None (generated) | — | Live (view) | TBD |
| `utils_v1_dates_weekly` | Weekly aggregation by EIA storage week with holiday counts | "How many NERC holidays fall in this storage week?" | None (generated) | — | Live (view) | TBD |

> **Note:** A third model, `utils_v1_nerc_holidays`, is defined in `schema.yml` as a static NERC holiday lookup (2014-2028) but does not yet have a SQL implementation.

---

## Summary

| Domain | Schema | View Count | Status |
|--------|--------|------------|--------|
| NatGas (WM DataFeed) | `natgas_cleaned` | 4 | Noms, LNG, SALTS (Azure SQL) |
| Power (PJM) | `pjm_cleaned` | 21 | Fully cleaned |
| Meteologica | `meteologica_cleaned` | 9 | PJM forecasts, observations, normals, projections; other ISOs raw |
| WSI (Weather) | `wsi_cleaned` | 6 | Degree days + hourly temps cleaned |
| Genscape | `genscape_cleaned` | 2 | Fully cleaned |
| Positions | `positions_cleaned` | 8 | Fully cleaned |
| Trades | `trades_cleaned` | 6 | Fully cleaned |
| EIA | `eia_cleaned` | 3 | EIA-930 hourly + daily, NG consumption by end use; storage raw |
| ICE | `ice_python_cleaned` | 3 | BALMO, next-day gas hourly + daily |
| Utils | `dbt` | 2 | Date spines; NERC holidays pending |
| **Total** | | **64 views + 1 raw** | |

---

## Quick Reference

- **Views refresh on query** (live) unless marked TABLE
- **TABLE materializations:** `wdd_normals`, `marex_and_nav_positions_grouped` -- rebuild on dbt run
- **`forecast_rank` column:** rank 1 = most recent forecast
- **Period columns:** `flat` = all hours, `onpeak` = NERC business hours, `offpeak` = evenings/weekends/holidays
- **T+1** = data available next business day

## Next Steps

- [Summary](executive-summary.md) -- high-level overview of all sources and freshness
