# meteologica_cleaned marts

## Purpose

Consumer-facing views for Meteologica xTraders API PJM forecasts covering demand, generation (solar/wind/hydro), and day-ahead prices. Each mart exposes ranked forecast vintages with EPT-converted timestamps for downstream analysis.

## Grain

| Model | Grain |
|-------|-------|
| `meteologica_pjm_demand_forecast_hourly` | `forecast_date x hour_ending x region x forecast_rank` |
| `meteologica_pjm_generation_forecast_hourly` | `forecast_date x hour_ending x region x generation_type x forecast_rank` |
| `meteologica_pjm_da_price_forecast_hourly` | `forecast_date x hour_ending x hub x forecast_rank` |

## Source Relations

| Source | Upstream Staging Model |
|--------|----------------------|
| Meteologica xTraders API (ISO account) | `staging_v1_meteologica_pjm_demand_forecast_hourly` |
| Meteologica xTraders API (ISO account) | `staging_v1_meteologica_pjm_gen_forecast_hourly` |
| Meteologica xTraders API (ISO account) | `staging_v1_meteologica_pjm_da_price_forecast_hourly` |

## Key Columns

| Column | Description |
|--------|-------------|
| `forecast_date` | Target forecast date (EPT) |
| `hour_ending` | Hour ending 1-24 (EPT) |
| `date_utc` / `hour_ending_utc` | UTC reference timestamps |
| `forecast_execution_datetime` | When the forecast model was run |
| `forecast_rank` | Recency rank (1 = most recent vintage) via `DENSE_RANK` |
| `region` | PJM region or utility-level sub-region (36 demand, 17 generation) |
| `hub` | PJM pricing hub (13 hubs for DA price forecasts) |
| `forecast_load_mw` | Forecasted demand in megawatts |
| `forecast_generation_mw` | Forecasted generation in megawatts |
| `forecast_da_price` | Forecasted day-ahead price ($/MWh) |

## Transformation Notes

- All marts are materialized as **views** (`SELECT * FROM staging`).
- Staging UNIONs 66 raw Meteologica source tables, normalizes timestamps UTC to EPT, and ranks vintages by `DENSE_RANK` on `forecast_execution_datetime`.
- Demand forecasts cover RTO + 3 macro regions + 32 utility sub-regions.
- Generation forecasts span solar (4 regions), wind (12 regions), and hydro (1 region).
- DA price forecasts cover SYSTEM + 12 pricing hubs.
- No completeness filter applied: `forecast_rank = 1` may reference a vintage with fewer than 24 hours for the first/last forecast dates in its horizon.

## Data Quality Checks

- `not_null` on `forecast_rank`, `forecast_date`, `hour_ending`, `region`/`hub`, and forecast value columns.
- `accepted_values` on `forecast_rank`: `[1, 2, 3, 4, 5]`.
- Schema tests defined in `schema.yml` for all 3 mart models.
