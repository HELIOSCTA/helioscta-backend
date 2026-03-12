---
slug: /
---

# HeliosCTA Docs

Documentation for all data pipelines, raw tables, and dbt views in the HeliosCTA backend.

**Start here:** Open the [Data Catalog](dbt-cleaned-catalog.md) to find any dataset by name, purpose, or source.

## Quick Navigation

| Where to go | When to use it |
|-------------|---------------|
| [Data Catalog](dbt-cleaned-catalog.md) | Find any dataset -- purpose, source, freshness, owner |
| [Summary](executive-summary.md) | One-page overview of all sources and data freshness |

## Domains

| Domain | What it covers |
|--------|---------------|
| [Power](domains/power/overview.md) | Load, LMPs, fuel mix, outages, forecasts across 7 ISOs |
| [Energy Aspects](domains/energy_aspects/overview.md) | Power generation, dispatch costs, prices, capacity forecasts |
| [Meteologica](domains/meteologica/overview.md) | Independent demand, generation, and price forecasts (374 scripts) |
| [Weather (WSI)](domains/wsi/overview.md) | Temperature forecasts, degree days, observations |
| [EIA](domains/eia/overview.md) | Government energy data -- generation mix, gas storage |
| [NatGas (WM DataFeed)](domains/natgas/overview.md) | Gas nominations, LNG terminal flows, salt cavern storage (Azure SQL) |
| [Genscape](domains/genscape/overview.md) | Natural gas production and pipeline data |
| [Positions & Trades](domains/positions-and-trades/overview.md) | Trading positions and trade confirmations |

## How Data Flows

```
External APIs / SFTP
      |
  Python Scrapes     _pull() -> _format() -> _upsert() -> main()
      |
  Raw Tables         Azure PostgreSQL
      |
  dbt Models         Source -> Staging -> Mart
      |
  Cleaned Views      pjm_cleaned, meteologica_cleaned, etc.
```

Pipeline health is tracked via `PipelineRunLogger` in the `pipeline_runs` table.

## Next Steps

- **New here?** Read the [Summary](executive-summary.md) first, then browse the [Data Catalog](dbt-cleaned-catalog.md).
- **Looking for a table?** Go directly to the [Data Catalog](dbt-cleaned-catalog.md).
