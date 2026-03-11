{% docs meteologica_pjm_overview %}

# Meteologica PJM Forecast Models

This dbt module transforms raw Meteologica xTraders API forecasts for PJM into analysis-ready
mart views for the HeliosCTA power trading desk.

## Data Source

| Source | Description | Ingestion |
|--------|-------------|-----------|
| **Meteologica xTraders API** | Third-party weather-driven forecasts for demand, generation (solar/wind/hydro), and DA prices | Scheduled Python scripts (`backend/src/meteologica/`) |

## API Accounts

Meteologica uses two xTraders API accounts:

| Account | Username | Content Count | Use |
|---------|----------|---------------|-----|
| **L48** | `helios_cta_us48` | 37 contents | US48 aggregate forecasts |
| **ISO** | `helios_cta` | 2,710 contents | ISO-level forecasts (PJM, ERCOT, MISO, etc.) |

PJM forecasts use the **ISO** account.

## Forecast Categories

| Category | Source Tables | Regions / Hubs | Key Column |
|----------|--------------|----------------|------------|
| **Demand** | 36 | RTO + 3 macro regions + 32 utility-level sub-regions | `forecast_load_mw` |
| **Generation** | 17 | Solar (4), Wind (12), Hydro (1) | `forecast_generation_mw` |
| **DA Prices** | 13 | SYSTEM + 12 pricing hubs | `forecast_da_price` |

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
source/          Raw API tables in `meteologica` schema (66 tables)
    |
staging/         UNION + normalize + rank (EPHEMERAL, 3 models)
    |
marts/           Analysis-ready views (VIEW, 3 models)
```

## Update Cadence

Meteologica publishes forecast updates **2-4 times per day** per content. Each update produces
a multi-day forward forecast horizon. All vintages are retained and ranked by recency via
`DENSE_RANK` on `forecast_execution_datetime`.

## Timezone Handling

Raw Meteologica data (`issue_date`, `forecast_period_start`) is stored in **EPT**
(Eastern Prevailing Time). Staging models extract date and hour components directly —
no timezone conversion is needed.

All columns in the final views are in EPT:
- `forecast_date` / `hour_ending` — EPT

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
