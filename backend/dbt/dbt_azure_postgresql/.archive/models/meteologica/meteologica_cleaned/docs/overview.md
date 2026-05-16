{% docs meteologica_pjm_overview %}

# Meteologica PJM Models

This dbt module transforms raw Meteologica xTraders API data for PJM into analysis-ready
mart views for the HeliosCTA power trading desk. Covers forecasts, observations, projections,
and climatological normals.

## Data Source

| Source | Description | Ingestion |
|--------|-------------|-----------|
| **Meteologica xTraders API** | Third-party weather-driven forecasts, observations, projections, and normals for demand, generation (solar/wind/hydro), and DA prices | Scheduled Python scripts (`backend/src/meteologica/`) |

## API Accounts

Meteologica uses two xTraders API accounts:

| Account | Username | Content Count | Use |
|---------|----------|---------------|-----|
| **L48** | `helios_cta_us48` | 37 contents | US48 aggregate forecasts |
| **ISO** | `helios_cta` | 2,710 contents | ISO-level forecasts (PJM, ERCOT, MISO, etc.) |

PJM forecasts use the **ISO** account.

## Data Categories

### Forecasts

| Category | Source Tables | Regions / Hubs | Key Column |
|----------|--------------|----------------|------------|
| **Demand** | 36 | RTO + 3 macro regions + 32 utility-level sub-regions | `forecast_load_mw` |
| **Demand (ECMWF-ENS)** | 36 | Same 36 regions as deterministic demand | `forecast_load_average_mw`, `forecast_load_bottom_mw`, `forecast_load_top_mw`, `ens_00_mw`–`ens_50_mw` |
| **Generation** | 17 | Solar (4), Wind (12), Hydro (1) | `forecast_generation_mw` |
| **DA Prices** | 13 | SYSTEM + 12 pricing hubs | `forecast_da_price` |

### Observations

| Category | Source Tables | Regions / Hubs | Key Column |
|----------|--------------|----------------|------------|
| **Demand** | 36 | Same 36 regions as demand forecasts | `observation_load_mw` |
| **Generation** | 9 | Solar (4), Wind (3), Hydro (1), + 1 additional | `observation_generation_mw` |
| **DA Prices** | 13 | SYSTEM + 12 pricing hubs | `observation_da_price` |

### Projections

| Category | Source Tables | Regions / Hubs | Key Column |
|----------|--------------|----------------|------------|
| **Demand** | 33 | RTO + 32 utility-level sub-regions (no MIDATL/SOUTH/WEST macro aggregates) | `projection_load_mw` |

### Normals

| Category | Source Tables | Regions / Hubs | Key Column |
|----------|--------------|----------------|------------|
| **Generation** | 9 | Solar (4: RTO, MIDATL, WEST, SOUTH), Wind (4: RTO, WEST, MIDATL, SOUTH), Hydro (1: RTO) | `normal_generation_mw` |

## Regional Breakdown

### Demand Regions (36)

Demand forecasts cover PJM's full regional hierarchy:

- **RTO** — full PJM footprint
- **MIDATL** — Mid-Atlantic aggregate
- **SOUTH** — Southern aggregate
- **WEST** — Western aggregate

Plus 32 utility-level sub-regions:

| Parent | Sub-regions |
|--------|-------------|
| **MIDATL** (17) | AE, BC, DPL, DPL_DPLCO, DPL_EASTON, JC, ME, PE, PEP, PEP_PEPCO, PEP_SMECO, PL, PL_PLCO, PL_UGI, PN, PS, RECO |
| **SOUTH** (1) | DOM |
| **WEST** (14) | AEP, AEP_AEPAPT, AEP_AEPIMP, AEP_AEPKPT, AEP_AEPOPT, AP, ATSI, ATSI_OE, ATSI_PAPWR, CE, DAY, DEOK, DUQ, EKPC |

### Generation Regions

Generation wind forecasts include 8 utility-level sub-regions: MIDATL_AE, MIDATL_PL,
MIDATL_PN, SOUTH_DOM, WEST_AEP, WEST_AP, WEST_ATSI, WEST_CE.

## Pipeline Architecture

```
source/          Raw API tables in `meteologica` schema (~200 tables)
    |
staging/         UNION + normalize + rank (EPHEMERAL, 9 models)
    |
marts/           Analysis-ready views (VIEW, 9 models)
```

## Update Cadence

Meteologica publishes forecast updates **2-4 times per day** per content. Each update produces
a multi-day forward forecast horizon. All vintages are retained and ranked by issue time
(earliest first) via `DENSE_RANK` on `forecast_execution_datetime` (forecasts) or
`update_datetime` (observations, projections, normals).

## Timezone Handling

Raw Meteologica data (`issue_date`, `forecast_period_start`) is stored in **EPT**
(Eastern Prevailing Time). Staging models extract date and hour components directly —
no timezone conversion is needed.

All columns in the final views are in EPT:
- `forecast_date` / `observation_date` / `projection_date` / `normal_date` / `hour_ending` — EPT

## Known Issues

### No Completeness Filter

Unlike the PJM load forecast model (`staging_v1_pjm_load_forecast_hourly`), which filters to
vintages with exactly 24 hours per forecast_date, the Meteologica models do **not** enforce a
completeness filter.

**Why:** Meteologica publishes forecasts that don't always cover full 24-hour blocks per
forecast date. The API delivers forecasts starting from the current hour forward, so the first
forecast date in a vintage is typically partial (e.g., hours 18-24 only). Applying a
`hour_count = 24` filter silently drops entire regions (observed: RTO and MIDATL were
completely filtered out while SOUTH and WEST passed).

**Impact:** `forecast_rank = 1` may reference a vintage with fewer than 24 hours for the
first and last forecast dates in its horizon. Downstream queries that assume 24 hours per
forecast_date should handle this gracefully.

### Raw Columns Stored as VARCHAR

The `issue_date` column in raw Meteologica tables is stored as `VARCHAR`, not `TIMESTAMP`.
Staging models cast explicitly with `issue_date::TIMESTAMP`.
The `forecast_period_start` column is natively `TIMESTAMP`.

{% enddocs %}
