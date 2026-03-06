/*
    VALIDATION v2: Gas Weighted HDD Daily Forecast — CONUS
    Pivoted summary matching WSI website layout.

    Sources: marts layer (wsi_cleaned.wdd_forecast_wsi, wsi_cleaned.wdd_forecast_models, wsi_cleaned.wdd_normals)
    - Latest 00Z run per model (CONUS, bias_corrected = false)
    - Differences row = current 00Z value minus previous 00Z value
    - 10-year normals row from wdd_normals mart
    - 15-day forecast window starting from CURRENT_DATE
*/

-------------------------------------------------------------
-- 1. UNION WSI + NWP model forecasts from marts
-------------------------------------------------------------

WITH forecast_union AS (
    -- WSI has no cycle column; it is effectively always 00Z
    SELECT forecast_execution_datetime, forecast_date, model, bias_corrected, region, NULL AS cycle, gas_hdd
    FROM wsi_cleaned.wdd_forecast_wsi
    UNION ALL
    SELECT forecast_execution_datetime, forecast_date, model, bias_corrected, region, cycle, gas_hdd
    FROM wsi_cleaned.wdd_forecast_models
),

-------------------------------------------------------------
-- 2. Filter to CONUS, unbiased, 00Z only
-------------------------------------------------------------

runs_00z AS (
    SELECT
        model,
        forecast_execution_datetime,
        forecast_date,
        ROUND(gas_hdd::NUMERIC, 1) AS gas_hdd
    FROM forecast_union
    WHERE region = 'CONUS'
      AND bias_corrected = 'false'
      AND (cycle = '00Z' OR cycle IS NULL)
),

-------------------------------------------------------------
-- 3. Latest 00Z execution per model
-------------------------------------------------------------

latest_exec AS (
    SELECT model, MAX(forecast_execution_datetime) AS max_exec
    FROM runs_00z
    GROUP BY model
),

-------------------------------------------------------------
-- 4. Current run and previous 00Z run
-------------------------------------------------------------

current_run AS (
    SELECT r.model, r.forecast_execution_datetime, r.forecast_date, r.gas_hdd
    FROM runs_00z r
    JOIN latest_exec l ON r.model = l.model AND r.forecast_execution_datetime = l.max_exec
),

prev_exec AS (
    SELECT r.model, MAX(r.forecast_execution_datetime) AS prev_exec_time
    FROM runs_00z r
    JOIN latest_exec l ON r.model = l.model AND r.forecast_execution_datetime < l.max_exec
    GROUP BY r.model
),

prev_run AS (
    SELECT r.model, r.forecast_date, r.gas_hdd AS prev_gas_hdd
    FROM runs_00z r
    JOIN prev_exec p ON r.model = p.model AND r.forecast_execution_datetime = p.prev_exec_time
),

-------------------------------------------------------------
-- 5. Join current + previous to compute differences
-------------------------------------------------------------

with_diff AS (
    SELECT
        c.model,
        c.forecast_execution_datetime,
        c.forecast_date,
        c.gas_hdd,
        ROUND(c.gas_hdd - p.prev_gas_hdd, 1) AS diff_24h
    FROM current_run c
    LEFT JOIN prev_run p ON c.model = p.model AND c.forecast_date = p.forecast_date
),

-------------------------------------------------------------
-- 6. PIVOT: forecast values row
-------------------------------------------------------------

forecast_pivot AS (
    SELECT
        model,
        'Forecast' AS row_type,
        forecast_execution_datetime,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 0  THEN gas_hdd END) AS day_01,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 1  THEN gas_hdd END) AS day_02,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 2  THEN gas_hdd END) AS day_03,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 3  THEN gas_hdd END) AS day_04,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 4  THEN gas_hdd END) AS day_05,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 5  THEN gas_hdd END) AS day_06,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 6  THEN gas_hdd END) AS day_07,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 7  THEN gas_hdd END) AS day_08,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 8  THEN gas_hdd END) AS day_09,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 9  THEN gas_hdd END) AS day_10,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 10 THEN gas_hdd END) AS day_11,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 11 THEN gas_hdd END) AS day_12,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 12 THEN gas_hdd END) AS day_13,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 13 THEN gas_hdd END) AS day_14,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 14 THEN gas_hdd END) AS day_15,
        ROUND(SUM(gas_hdd), 1) AS total
    FROM with_diff
    WHERE forecast_date >= CURRENT_DATE AND forecast_date < CURRENT_DATE + 15
    GROUP BY model, forecast_execution_datetime
),

-------------------------------------------------------------
-- 7. PIVOT: differences row (current 00Z minus previous 00Z)
-------------------------------------------------------------

diff_pivot AS (
    SELECT
        model,
        'Differences' AS row_type,
        forecast_execution_datetime,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 0  THEN diff_24h END) AS day_01,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 1  THEN diff_24h END) AS day_02,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 2  THEN diff_24h END) AS day_03,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 3  THEN diff_24h END) AS day_04,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 4  THEN diff_24h END) AS day_05,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 5  THEN diff_24h END) AS day_06,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 6  THEN diff_24h END) AS day_07,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 7  THEN diff_24h END) AS day_08,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 8  THEN diff_24h END) AS day_09,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 9  THEN diff_24h END) AS day_10,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 10 THEN diff_24h END) AS day_11,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 11 THEN diff_24h END) AS day_12,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 12 THEN diff_24h END) AS day_13,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 13 THEN diff_24h END) AS day_14,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 14 THEN diff_24h END) AS day_15,
        ROUND(SUM(diff_24h), 1) AS total
    FROM with_diff
    WHERE forecast_date >= CURRENT_DATE AND forecast_date < CURRENT_DATE + 15
    GROUP BY model, forecast_execution_datetime
),

-------------------------------------------------------------
-- 8. NORMALS: 10-year gas_hdd from wdd_normals mart
-------------------------------------------------------------

normals_pivot AS (
    SELECT
        'NORMAL_10YR' AS model,
        'Normals' AS row_type,
        NULL::TIMESTAMP AS forecast_execution_datetime,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 0,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_01,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 1,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_02,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 2,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_03,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 3,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_04,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 4,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_05,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 5,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_06,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 6,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_07,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 7,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_08,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 8,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_09,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 9,  'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_10,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 10, 'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_11,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 11, 'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_12,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 12, 'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_13,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 13, 'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_14,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 14, 'MM-DD') THEN ROUND(gas_hdd_10_yr_normal::NUMERIC, 1) END) AS day_15,
        ROUND(SUM(gas_hdd_10_yr_normal::NUMERIC), 1) AS total
    FROM wsi_cleaned.wdd_normals
    WHERE region = 'CONUS'
      AND mm_dd IN (
        TO_CHAR(CURRENT_DATE + 0,  'MM-DD'), TO_CHAR(CURRENT_DATE + 1,  'MM-DD'),
        TO_CHAR(CURRENT_DATE + 2,  'MM-DD'), TO_CHAR(CURRENT_DATE + 3,  'MM-DD'),
        TO_CHAR(CURRENT_DATE + 4,  'MM-DD'), TO_CHAR(CURRENT_DATE + 5,  'MM-DD'),
        TO_CHAR(CURRENT_DATE + 6,  'MM-DD'), TO_CHAR(CURRENT_DATE + 7,  'MM-DD'),
        TO_CHAR(CURRENT_DATE + 8,  'MM-DD'), TO_CHAR(CURRENT_DATE + 9,  'MM-DD'),
        TO_CHAR(CURRENT_DATE + 10, 'MM-DD'), TO_CHAR(CURRENT_DATE + 11, 'MM-DD'),
        TO_CHAR(CURRENT_DATE + 12, 'MM-DD'), TO_CHAR(CURRENT_DATE + 13, 'MM-DD'),
        TO_CHAR(CURRENT_DATE + 14, 'MM-DD')
    )
),

-------------------------------------------------------------
-- 9. FINAL: stack forecast + differences + normals
-------------------------------------------------------------

combined AS (
    SELECT * FROM forecast_pivot
    UNION ALL
    SELECT * FROM diff_pivot
    UNION ALL
    SELECT * FROM normals_pivot
)

SELECT
    model,
    row_type,
    forecast_execution_datetime,
    day_01, day_02, day_03, day_04, day_05,
    day_06, day_07, day_08, day_09, day_10,
    day_11, day_12, day_13, day_14, day_15,
    total
FROM combined
ORDER BY
    CASE model
        WHEN 'WSI'         THEN 1
        WHEN 'GFS_OP'      THEN 2
        WHEN 'GFS_ENS'     THEN 3
        WHEN 'ECMWF_OP'    THEN 4
        WHEN 'ECMWF_ENS'   THEN 5
        WHEN 'NORMAL_10YR' THEN 6
    END,
    CASE row_type
        WHEN 'Forecast'    THEN 1
        WHEN 'Differences' THEN 2
        WHEN 'Normals'     THEN 3
    END;
