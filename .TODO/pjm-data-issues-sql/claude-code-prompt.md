Use this repository as context and complete the PJM data issue in:
- `TODO/pjm-data-issues.md`
- `TODO/pjm-data-issues-sql/*.sql`

Objective:
- Produce the same style of output shown in `TODO/pjm-data-issues-sql/pjm-data-issues-output.png`, but for **tomorrow's forecast**.
- For this run, assume today is **2026-03-12** (America/Denver), so tomorrow's forecast date is **2026-03-13**.

Data logic requirements:
1. Build one SQL query that returns 24 hourly rows for `forecast_date = run_date_mst + 1` and one `DAILY GWh` summary row.
2. Use `run_date_mst = (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::date`.
3. Use morning forecast vintages only (`EXTRACT(HOUR FROM forecast_execution_datetime) <= 10` or equivalent for the source field).
4. Zonal columns must match this exact order:
   - `AE, AEP, APS, ATSI, BGE, COMED, DEOK, DPL, DOM, DUQ, JCPL, METED, PECO, PENELEC, PEPCO, PPL, PSEG`
5. Source mapping for zonal columns (from PJM 7-day load forecast raw table):
   - `AE <- 'AE/MIDATL'`
   - `AEP <- 'AEP'`
   - `APS <- 'AP'`
   - `ATSI <- 'ATSI'`
   - `BGE <- 'BG&E/MIDATL'`
   - `COMED <- 'COMED'`
   - `DEOK <- 'DEOK'`
   - `DPL <- 'DP&L/MIDATL'`
   - `DOM <- 'DOMINION'`
   - `DUQ <- 'DUQUESNE'`
   - `JCPL <- 'JCP&L/MIDATL'`
   - `METED <- 'METED/MIDATL'`
   - `PECO <- 'PECO/MIDATL'`
   - `PENELEC <- 'PENELEC/MIDATL'`
   - `PEPCO <- 'PEPCO/MIDATL'`
   - `PPL <- 'PPL/MIDATL'`
   - `PSEG <- 'PSE&G/MIDATL'`
6. Compute:
   - `PJM TOTAL` = sum of the 17 zonal columns above (hourly).
   - `PJM` = RTO hourly load from `pjm_cleaned.pjm_load_forecast_hourly` (`region = 'RTO'`, same run-date and hour<=10 filters, choose lowest `forecast_rank` from filtered set).
   - `Meteologica` = RTO hourly load from `meteologica_cleaned.meteologica_pjm_demand_forecast_hourly` (`region = 'RTO'`, same run-date and hour<=10 filters, choose lowest `forecast_rank` from filtered set).
   - `DIFF` = `PJM - Meteologica`.
7. Hour rows should show:
   - `Hr` as 0-23
   - `Time` as `00:00` ... `23:00`
8. `DAILY GWh` row:
   - Sum each MW column across 24 hours and divide by 1000.
   - Round to 1 decimal place.

Output requirements:
1. Print a final table with this exact column order:
   - `Hr, Time, AE, AEP, APS, ATSI, BGE, COMED, DEOK, DPL, DOM, DUQ, JCPL, METED, PECO, PENELEC, PEPCO, PPL, PSEG, PJM TOTAL, PJM, Meteologica, DIFF`
2. Title format:
   - `LOAD FORECAST (MW) - 2026-03-13`
3. Save:
   - SQL used to `TODO/pjm-data-issues-sql/pjm-data-issues-tomorrow.sql`
   - rendered output screenshot to `TODO/pjm-data-issues-sql/pjm-data-issues-output-tomorrow.png`
4. Also include a short note stating whether Meteologica zonal sum (`PJM TOTAL`) matches Meteologica RTO and by how much (hourly max absolute delta and daily GWh delta).

Execution notes:
- Prefer using existing SQL files in `TODO/pjm-data-issues-sql/` as reference patterns for filters and rank selection.
- Do not change dbt models for this task; this is a diagnostics/report output task.
