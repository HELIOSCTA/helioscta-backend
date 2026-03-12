# Summary

One-page overview of what HeliosCTA ingests, how it flows, and how fresh it is. For individual datasets, see the [Data Catalog](dbt-cleaned-catalog.md).

## What We Collect

| Category | Sources | Approx. Tables |
|----------|---------|----------------|
| **Power Markets** -- load, LMPs, fuel mix, outages, forecasts | PJM API, GridStatus, GridStatusIO | ~70+ across 7 ISOs |
| **Power Forecasts** -- demand, generation, DA price forecasts | Meteologica xTraders API | ~374 |
| **Weather** -- temp forecasts, HDD/CDD, observations | WSI Trader API | ~15 |
| **Natural Gas** -- production forecasts, pipeline flows, storage | Genscape API, EIA API | ~4 |
| **NatGas DataFeed** -- nominations, LNG terminals, salt storage | WM DataFeed (Azure SQL) | ~6 raw |
| **EIA** -- hourly generation by fuel type, gas storage | EIA Open Data API | ~2 |
| **ICE** -- next-day gas, BALMO swaps, NG & power futures | ICE Python API | ~3 |
| **Positions & Trades** -- daily positions, trade confirmations | SFTP (Marex, NAV, Clear Street) | ~8 |

## Data Flow

1. **Scrape scripts** pull from APIs/SFTP on schedule (Prefect).
2. **Raw tables** land in Azure PostgreSQL (`pjm.da_hrl_lmps`, `eia.fuel_type_hrl_gen_test`, etc.).
3. **dbt views** clean and reshape raw data into analysis-ready marts (`pjm_cleaned.pjm_lmps_hourly`, etc.).
4. **Event-driven pipelines** (PJM DA LMPs) react to database notifications for near-real-time processing.

## Data Freshness

| Data | Freshness | Cadence |
|------|-----------|---------|
| RT load / LMPs | 5-15 min lag | Every 5 min |
| DA prices / load | By ~1 PM day-ahead | Daily |
| Weather forecasts (WSI) | Multiple model runs/day | 2-4x daily |
| Meteologica forecasts | New model runs throughout day | Multiple daily |
| Positions (NAV/Marex) | End-of-day files | T+1 |
| Trades (Clear Street) | Intraday + end-of-day | Intraday + T+1 |
| EIA generation mix | ~1 hour lag | Hourly |
| ICE gas/power derivatives | End-of-day settle | Daily |
| NatGas nominations (WM) | 20-40 min lag | Every 20/30/40 min |
| Gas storage | Weekly (Thursday) | Weekly |

## dbt View Summary

| Schema | Views | Coverage |
|--------|-------|----------|
| `natgas_cleaned` | 4 | Gas nominations, LNG terminals, salt storage (Azure SQL) |
| `pjm_cleaned` | 21 | PJM load, LMPs, fuel mix, outages, forecasts |
| `meteologica_cleaned` | 3 | PJM demand, generation, DA price forecasts |
| `wsi_cleaned` | 4 | Degree day observations, normals, forecasts |
| `genscape_cleaned` | 2 | Gas production forecast + daily pipeline |
| `positions_cleaned` | 8 | Combined Marex + NAV positions |
| `trades_cleaned` | 6 | Clear Street + Marex trade confirmations |
| `eia_cleaned` | 2 | EIA-930 hourly + daily generation |
| `ice_python_cleaned` | 3 | BALMO, next-day gas hourly + daily |
| **Total** | **53** | |

## Next Steps

- [Data Catalog](dbt-cleaned-catalog.md) -- find any specific dataset
