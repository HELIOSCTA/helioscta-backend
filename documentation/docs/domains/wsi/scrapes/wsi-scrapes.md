# WSI Scrape Cards

## Weighted Degree Day Forecasts

Six scripts pull WDD forecasts from different weather models. All write to `wsi` schema.

### WSI Blended WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/weighted_degree_day/wsi_wdd_day_forecast_v2_2025_dec_17.py` |
| **Table** | `wsi.wsi_wdd_day_forecast_v2_2025_dec_17` |
| **Source** | WSI Trader API (`GetWeightedDegreeDayForecast`) |
| **Description** | WSI's proprietary blended model for population-weighted degree days |
| **Trigger** | Event-driven primary, scheduled reconciliation |
| **Freshness** | 2-4x daily |

### GFS Operational WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `gfs_op_wdd_day_forecast_v2_2025_dec_17.py` |
| **Table** | `wsi.gfs_op_wdd_day_forecast_v2_2025_dec_17` |
| **Description** | GFS operational (high-res) model degree day forecast |

### GFS Ensemble WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `gfs_ens_wdd_day_forecast_v2_2025_dec_17.py` |
| **Table** | `wsi.gfs_ens_wdd_day_forecast_v2_2025_dec_17` |
| **Description** | GFS ensemble mean degree day forecast (broader uncertainty range) |

### ECMWF Operational WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `ecmwf_op_wdd_day_forecast_v2_2025_dec_17.py` |
| **Table** | `wsi.ecmwf_op_wdd_day_forecast_v2_2025_dec_17` |
| **Description** | ECMWF operational (European model) degree day forecast |

### ECMWF Ensemble WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `ecmwf_ens_wdd_day_forecast_v2_2025_dec_17.py` |
| **Table** | `wsi.ecmwf_ens_wdd_day_forecast_v2_2025_dec_17` |
| **Description** | ECMWF ensemble mean degree day forecast |

### AIFS Ensemble WDD Forecast

| Field | Value |
|-------|-------|
| **Script** | `aifs_ens_wdd_day_forecast_v1_2026_feb_12.py` |
| **Table** | `wsi.aifs_ens_wdd_day_forecast_v1_2026_feb_12` |
| **Description** | AIFS (ECMWF's AI model) ensemble degree day forecast -- newest model |

---

## Hourly Forecasts

### Hourly Temperature Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/hourly_forecast/hourly_forecast_temp_v4_2025_jan_12.py` |
| **Table** | `wsi.hourly_forecast_temp_v4_2025_jan_12` |
| **Source** | WSI Trader API (`GetHourlyForecast`) |
| **Description** | Hourly temperature forecast by city |
| **Trigger** | Scheduled |
| **Freshness** | Multiple updates per day |

---

## Weighted Forecasts

### ISO-Level Temperature Forecast (Multiple Models)

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/weighted_forecast_iso/weighted_temp_daily_forecast_iso_models_v2_2026_jan_12.py` |
| **Table** | `wsi.weighted_temp_daily_forecast_iso_models_v2_2026_jan_12` |
| **Source** | WSI Trader API (`GetModelForecast`) |
| **Description** | Population-weighted temperature forecasts at ISO level from multiple weather models |

### ISO-Level Temperature Forecast (WSI Blend)

| Field | Value |
|-------|-------|
| **Script** | `weighted_temp_daily_forecast_iso_wsi_v2_2026_jan_12.py` |
| **Table** | `wsi.weighted_temp_daily_forecast_iso_wsi_v2_2026_jan_12` |
| **Description** | WSI's proprietary blended population-weighted temperature by ISO |

### City-Level Temperature Forecast

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/weighted_forecast_city/weighted_temp_daily_forecast_city_v2_2026_jan_12.py` |
| **Table** | `wsi.weighted_temp_daily_forecast_city_v2_2026_jan_12` |
| **Source** | WSI Trader API (`GetWsiForecastForDDModelCities`) |
| **Description** | Population-weighted temperature forecast at individual city level |

---

## Homepage Forecast Tables

Three scripts pull the WSI "homepage" city forecast tables in different formats:

| Script | Table | Data |
|--------|-------|------|
| `wsi_homepage_forecast_table_minmax_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_minmax_v1_2026_jan_12` | Min/max temperature by city |
| `wsi_homepage_forecast_table_hddcdd_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_hddcdd_v1_2026_jan_12` | HDD/CDD by city |
| `wsi_homepage_forecast_table_avg_v1_2026_jan_12.py` | `wsi.wsi_homepage_forecast_table_avg_v1_2026_jan_12` | Average temperature by city |

---

## Historical Observations

### Hourly Observed Temperature

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/historical_observations/hourly_observed_temp_v2_2025_07_22.py` |
| **Table** | `wsi.hourly_observed_temp_v2_20250722` |
| **Source** | WSI Trader API (`GetHistoricalObservations`) |
| **Description** | Actual observed hourly temperatures -- used as ground truth for forecast accuracy |

### Daily Observed WDD

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/historical_observations/daily_observed_wdd_v1_2026_mar_06.py` |
| **Table** | `wsi.daily_observed_wdd_v1_2026_mar_06` |
| **Description** | Actual observed daily weighted degree days |

---

## Natural Gas

### Daily Forecast BCF

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/natural_gas/daily_forecast_bcf_v1_2026_mar_06.py` |
| **Table** | `wsi.daily_forecast_bcf_v1_2026_mar_06` |
| **Description** | Daily natural gas demand forecast in BCF (Billion Cubic Feet) |

---

## Reference

### WSI Trader City IDs

| Field | Value |
|-------|-------|
| **Script** | `backend/scrapes/wsi/reference/wsitrader_cityids_v1_2026_jan_12.py` |
| **Description** | Loads WSI city ID reference data (not run on schedule) |
| **Note** | Reference only -- used by other WSI scripts for city lookups |
