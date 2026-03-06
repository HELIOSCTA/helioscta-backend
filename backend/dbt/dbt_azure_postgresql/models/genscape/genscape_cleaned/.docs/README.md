# genscape_cleaned marts

## Purpose

Consumer-facing views for Genscape (Wood Mackenzie) natural gas data: monthly gas production forecasts by region and daily pipeline production estimates. Used by the HeliosCTA trading desk for gas supply analysis and production trend tracking.

## Grain

| Model | Grain |
|-------|-------|
| `genscape_gas_production_forecast` | `date x region x revision` |
| `genscape_daily_pipeline_production` | `date x revision` (22 regional columns per row) |

## Source Relations

| Source | Upstream Staging Model |
|--------|----------------------|
| Genscape Gas Production Forecast | `staging_v2_genscape_gas_production_forecast` |
| Genscape Daily Pipeline Production | `staging_v2_daily_pipeline_production` |

## Key Columns

### Gas Production Forecast

| Column | Description |
|--------|-------------|
| `date` | Target production month |
| `region` | Geographic tier (22 tiers aggregated from 67 raw regions) |
| `revision` / `max_revision` | Forecast revision tracking (1 = oldest) |
| `report_date` | When the forecast was issued |
| `production` | Forecasted gas production |
| `dry_gas_production_yoy` | Year-over-year percentage change |
| `oil_rig_count` / `gas_rig_count` | Operational rig counts |

### Daily Pipeline Production

| Column | Description |
|--------|-------------|
| `date` | Production date |
| `revision` / `max_revision` | Report revision tracking (1 = oldest) |
| `report_date` | When the production estimate was reported |
| `lower_48` through `western_canada` | Regional production in MMCF/d (22 columns) |
| `permian_flare_counts` / `permian_flare_volume` | Permian flaring metrics |

## Transformation Notes

- Both marts are materialized as **views** (`SELECT * FROM staging`).
- Gas production forecast staging pivots raw item/value pairs into typed metric columns and aggregates 67 raw regions into 22 geographic tiers.
- Daily pipeline production staging computes 5 composite aggregate regions (gulf_coast, mid_con, permian, rockies, east) from sub-regional columns and adds revision tracking via `ROW_NUMBER`.
- All production values are in MMCF/d (million cubic feet per day).

## Data Quality Checks

- No `schema.yml` currently exists for the genscape marts directory.
- Data quality is enforced at the staging layer through type casting and composite region computation.
- Revision tracking ensures multiple forecast/report vintages are preserved and identifiable.
