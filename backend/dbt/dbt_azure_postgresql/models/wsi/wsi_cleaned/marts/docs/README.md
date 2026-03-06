# wsi_cleaned marts

## Purpose

Consumer-facing views and tables for WSI weather-driven weighted degree day (WDD) data: observed actuals, 10/30-year normals, NWP model forecasts (GFS/ECMWF), and WSI proprietary forecasts. Used by the HeliosCTA desk for gas-weather analysis and heating/cooling demand modeling.

## Grain

| Model | Grain |
|-------|-------|
| `wdd_observed` | `date x region` |
| `wdd_normals` | `mm_dd x region` (calendar-day normals) |
| `wdd_forecast_models` | `forecast_date x region x model x cycle x forecast_rank` |
| `wdd_forecast_wsi` | `forecast_date x region x forecast_rank` |

## Source Relations

| Source | Upstream Model |
|--------|---------------|
| WSI daily observed WDD | `source_v1_daily_observed_wdd` |
| WSI WDD observed (30-year history) | `source_v1_daily_observed_wdd` (filtered to 30 years) |
| WSI WDD forecasts | `staging_v1_wdd_forecast_2_complete` |

## Key Columns

| Column | Description |
|--------|-------------|
| `date` / `forecast_date` | Observation or forecast target date |
| `mm_dd` | Calendar month-day for normals (e.g., `01_15`) |
| `region` | Geographic region |
| `gas_hdd` | Gas heating degree days |
| `population_cdd` | Population-weighted cooling degree days |
| `tdd` | Total degree days (`gas_hdd + population_cdd`) |
| `gas_hdd_normal_10yr` / `gas_hdd_normal_30yr` | 10- and 30-year HDD normals |
| `model` | NWP model name: `GFS_OP`, `GFS_ENS`, `ECMWF_OP`, `ECMWF_ENS` |
| `cycle` | Model run cycle: `00Z` or `12Z` (forecast_models only) |
| `forecast_rank` | Recency rank (1 = most recent vintage) |
| `forecast_label` | Human-readable label: `Current Forecast`, `12hrs Ago`, `24hrs Ago`, `Friday 12z` |
| `forecast_execution_datetime` | When the forecast model was run |

## Transformation Notes

- `wdd_observed` is a **view** directly over the source observed WDD table.
- `wdd_normals` is a **table** that computes 10-year and 30-year rolling normals from observed history. Feb 29 values are folded into Feb 28 for statistical stability. Includes `avg`, `min`, `max`, `stddev`, and year count metadata per WDD type.
- `wdd_forecast_models` is a **view** filtering to NWP models (GFS/ECMWF) with 00Z/12Z cycles, ranked by execution time via `DENSE_RANK`.
- `wdd_forecast_wsi` is a **view** filtering to WSI proprietary forecasts (no cycle column), ranked by execution time via `DENSE_RANK`.
- Forecast labels assign: rank 1 = `Current Forecast`, rank 2 = `12hrs Ago` (models) or `24hrs Ago` (WSI), etc.

## Data Quality Checks

- `not_null` on `date`, `region`, and all 7 WDD type columns for observed data.
- `not_null` on `mm_dd`, `region` for normals.
- `not_null` on `forecast_date`, `region`, `model`, `forecast_rank` for forecast models.
- `accepted_values` on `model`: `['GFS_OP', 'GFS_ENS', 'ECMWF_OP', 'ECMWF_ENS']` for forecast_models.
- Schema tests defined in `schema.yml` for all 4 mart models.
