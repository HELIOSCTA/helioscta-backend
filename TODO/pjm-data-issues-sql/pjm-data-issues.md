# PJM Data Issues

## Open Issues

- [ ] **Meteologica regional load forecast doesn't equal RTO total**
  - Source: `today.md`
  - The sum of regional load forecasts from Meteologica does not match the total RTO forecast. Could be an aggregation bug in the SQL view, a timezone mismatch, or a missing region.

## Diagnostics

### LOAD FORECAST (MW) - 2026-03-12 (Today)

- SQL: individual queries in `pjm_load_forecast_hourly.sql`, `meteologica_pjm_demand_forecast_hourly.sql`, `pjm_gridstatus_load_forecast_hourly.sql`
- Output: `pjm-data-issues-output.png`

### LOAD FORECAST (MW) - 2026-03-13 (Tomorrow)

- SQL: `pjm-data-issues-tomorrow.sql`
- Output: `pjm-data-issues-output-tomorrow.png` (run the SQL and capture output)

**Query structure:**
- 24 hourly rows (Hr 0-23) + 1 DAILY GWh summary row
- **Zonal columns** (17): Meteologica sub-regional demand forecasts from `meteologica_cleaned.meteologica_pjm_demand_forecast_hourly`, pivoted into `AE, AEP, APS, ATSI, BGE, COMED, DEOK, DPL, DOM, DUQ, JCPL, METED, PECO, PENELEC, PEPCO, PPL, PSEG`
- **PJM TOTAL**: Sum of 17 Meteologica zonal columns (hourly)
- **PJM**: RTO from `pjm_cleaned.pjm_load_forecast_hourly` (best morning vintage, `forecast_rank` = min after hour <= 10 filter)
- **Meteologica**: RTO from `meteologica_cleaned.meteologica_pjm_demand_forecast_hourly` (best morning vintage)
- **DIFF**: `PJM - Meteologica`

**Filters:**
- `run_date_mst = (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE`
- `forecast_date = run_date_mst + 1` (2026-03-13)
- Morning vintages: `EXTRACT(HOUR FROM forecast_execution_datetime) <= 10`
- Lowest `forecast_rank` from filtered set (per zone for Meteologica zones, global for PJM/Meteologica RTO)

**Meteologica zonal sum vs RTO note:**
The query includes a second diagnostic statement comparing the Meteologica 17-zone sum (`PJM TOTAL`) against the Meteologica RTO value for each hour. Key metrics reported:
- `max_hourly_abs_delta_mw`: largest absolute hourly mismatch between zonal sum and RTO
- `daily_gwh_delta`: total daily delta in GWh (zonal sum minus RTO, divided by 1000)
- `avg_hourly_delta_mw`: average hourly delta

If the delta is non-zero, it confirms the open issue: Meteologica's 17-zone sum does not reconstruct the published RTO total. Likely causes: missing zones (DAYTON, EKPC, RECO, UGI are in PJM but not in the 17-zone set), or Meteologica's RTO model is independently calibrated rather than being a strict sum of sub-regions.
