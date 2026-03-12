{% docs meteologica_pjm_demand_forecast %}

## Demand Forecast

Hourly demand (load) forecasts for PJM by region, from Meteologica's weather-driven model.

### Data Source
- Meteologica xTraders API — 36 raw tables (RTO + 3 macro regions + 32 utility-level sub-regions)

### Key Transformations
- UNIONs 36 region-specific tables with a `region` label
- Converts `issue_date` (VARCHAR, UTC) to `forecast_execution_datetime` (TIMESTAMP, EPT)
- Extracts `forecast_date` + `hour_ending` from `forecast_period_start` (already EPT)
- Ranks vintages by recency via `DENSE_RANK()` partitioned by `(forecast_date, region)`
- No completeness filter — partial vintages are retained (see overview for rationale)

### Model

| Layer | Model | Materialization |
|-------|-------|-----------------|
| Staging | `staging_v1_meteologica_pjm_demand_forecast_hourly` | ephemeral |
| Mart | `meteologica_pjm_demand_forecast_hourly` | view |

**Grain:** forecast_rank x forecast_date x hour_ending x region

### Column Mapping (raw -> staging)

| Raw Column | Staging Column |
|------------|---------------|
| `issue_date` | `forecast_execution_datetime`, `forecast_execution_date` |
| `forecast_period_start` | `forecast_date`, `hour_ending`, `forecast_datetime` |
| `forecast_mw` | `forecast_load_mw` |

{% enddocs %}


{% docs meteologica_pjm_demand_forecast_ecmwf_ens %}

## ECMWF-ENS Demand Forecast

Hourly ensemble demand (load) forecasts for PJM by region, from Meteologica's ECMWF-ENS model.
Provides 51 individual ensemble members (ENS00–ENS50) plus summary statistics (Average, Bottom, Top)
for quantifying forecast uncertainty.

### Data Source
- Meteologica xTraders API — 36 raw tables (RTO + 3 macro regions + 32 utility-level sub-regions)
- Content IDs: 2724–2759

### Key Transformations
- UNIONs 36 region-specific tables with a `region` label
- Converts `issue_date` (VARCHAR, UTC) to `forecast_execution_datetime` (TIMESTAMP, EPT)
- Extracts `forecast_date` + `hour_ending` from `forecast_period_start` (already EPT)
- Casts all 54 MW columns (3 summary + 51 ensemble) from VARCHAR to NUMERIC
- Ranks vintages by recency via `DENSE_RANK()` partitioned by `(forecast_date, region)`
- No completeness filter — partial vintages are retained (see overview for rationale)

### Model

| Layer | Model | Materialization |
|-------|-------|-----------------|
| Staging | `staging_v1_meteo_pjm_demand_fcst_ecmwf_ens_hourly` | ephemeral |
| Mart | `meteologica_pjm_demand_forecast_ecmwf_ens_hourly` | view |

**Grain:** forecast_rank x forecast_date x hour_ending x region

### Column Mapping (raw -> staging)

| Raw Column | Staging Column |
|------------|---------------|
| `issue_date` | `forecast_execution_datetime`, `forecast_execution_date` |
| `forecast_period_start` | `forecast_date`, `hour_ending`, `forecast_datetime` |
| `average_mw` | `forecast_load_average_mw` |
| `bottom_mw` | `forecast_load_bottom_mw` |
| `top_mw` | `forecast_load_top_mw` |
| `ens_00_mw` ... `ens_50_mw` | `ens_00_mw` ... `ens_50_mw` (passed through) |

{% enddocs %}


{% docs meteologica_pjm_generation_forecast %}

## Generation Forecast

Hourly generation forecasts for PJM by source type and region, from Meteologica's
weather-driven model.

### Data Source
- Meteologica xTraders API — 17 raw tables:
  - **Solar (4):** RTO, MIDATL, SOUTH, WEST
  - **Wind — regional (4):** RTO, MIDATL, SOUTH, WEST
  - **Wind — utility-level (8):** MIDATL_AE, MIDATL_PL, MIDATL_PN, SOUTH_DOM, WEST_AEP, WEST_AP, WEST_ATSI, WEST_CE
  - **Hydro (1):** RTO only

### Key Transformations
- UNIONs 17 tables with `source` (solar/wind/hydro) and `region` labels
- Same timestamp normalization and ranking as the demand model
- Ranked by `DENSE_RANK()` partitioned by `(forecast_date, source, region)`

### Model

| Layer | Model | Materialization |
|-------|-------|-----------------|
| Staging | `staging_v1_meteologica_pjm_generation_forecast_hourly` | ephemeral |
| Mart | `meteologica_pjm_generation_forecast_hourly` | view |

**Grain:** forecast_rank x forecast_date x hour_ending x source x region

### Column Mapping (raw -> staging)

| Raw Column | Staging Column |
|------------|---------------|
| `issue_date` | `forecast_execution_datetime`, `forecast_execution_date` |
| `forecast_period_start` | `forecast_date`, `hour_ending`, `forecast_datetime` |
| `forecast_mw` | `forecast_generation_mw` |

{% enddocs %}


{% docs meteologica_pjm_da_price_forecast %}

## Day-Ahead Price Forecast

Hourly DA electricity price forecasts for PJM by pricing hub, from Meteologica's model.

### Data Source
- Meteologica xTraders API — 13 raw tables (SYSTEM + 12 pricing hubs)

### Pricing Hubs
`SYSTEM`, `AEP DAYTON`, `AEP GEN`, `ATSI GEN`, `CHICAGO GEN`, `CHICAGO`, `DOMINION`,
`EASTERN`, `NEW JERSEY`, `N ILLINOIS`, `OHIO`, `WESTERN`, `WEST INT`

### Key Transformations
- UNIONs 13 hub-specific tables with a `hub` label
- Same timestamp normalization and ranking as the demand model
- Ranked by `DENSE_RANK()` partitioned by `(forecast_date, hub)`

### Model

| Layer | Model | Materialization |
|-------|-------|-----------------|
| Staging | `staging_v1_meteologica_pjm_da_price_forecast_hourly` | ephemeral |
| Mart | `meteologica_pjm_da_price_forecast_hourly` | view |

**Grain:** forecast_rank x forecast_date x hour_ending x hub

### Column Mapping (raw -> staging)

| Raw Column | Staging Column |
|------------|---------------|
| `issue_date` | `forecast_execution_datetime`, `forecast_execution_date` |
| `forecast_period_start` | `forecast_date`, `hour_ending`, `forecast_datetime` |
| `day_ahead_price` | `forecast_da_price` |

{% enddocs %}
