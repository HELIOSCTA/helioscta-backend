/*
    VALIDATION v2: Gas Weighted HDD Daily Forecast - CONUS
    Pivoted summary matching validate_forecast_gas_hdd.sql output layout.

    - Latest 00Z run per model (CONUS, bias_corrected = false)
    - Differences row = current 00Z value minus prior 00Z value from exactly 24h earlier
      for the same model + forecast_date
    - If prior 00Z is missing, diff remains NULL
    - 10-year normals row from wsi_cleaned.wdd_normals
    - 15-day forecast window starting from CURRENT_DATE
*/

WITH forecast_union AS (
    -- WSI run timestamp is normalized to daily 00Z.
    SELECT
        DATE_TRUNC('day', forecast_execution_datetime) AS run_datetime_utc,
        forecast_date::DATE AS forecast_date,
        model,
        bias_corrected,
        region,
        '00Z'::TEXT AS cycle,
        gas_hdd
    FROM wsi_cleaned.wdd_forecast_wsi

    UNION ALL

    SELECT
        forecast_execution_datetime AS run_datetime_utc,
        forecast_date::DATE AS forecast_date,
        model,
        bias_corrected,
        region,
        cycle,
        gas_hdd
    FROM wsi_cleaned.wdd_forecast_models
),

runs_00z AS (
    SELECT
        model,
        run_datetime_utc,
        forecast_date,
        ROUND(gas_hdd::NUMERIC, 1) AS gas_hdd
    FROM forecast_union
    WHERE region = 'CONUS'
      AND LOWER(bias_corrected::TEXT) = 'false'
      AND UPPER(cycle) = '00Z'
      AND EXTRACT(HOUR FROM run_datetime_utc) = 0
),

run_dedup AS (
    SELECT
        model,
        run_datetime_utc,
        forecast_date,
        gas_hdd,
        ROW_NUMBER() OVER (
            PARTITION BY model, run_datetime_utc, forecast_date
            ORDER BY run_datetime_utc DESC
        ) AS rn
    FROM runs_00z
),

runs_00z_unique AS (
    SELECT model, run_datetime_utc, forecast_date, gas_hdd
    FROM run_dedup
    WHERE rn = 1
),

latest_run AS (
    SELECT model, MAX(run_datetime_utc) AS run_datetime_utc
    FROM runs_00z_unique
    GROUP BY model
),

current_vs_prev AS (
    SELECT
        cur.model,
        cur.run_datetime_utc,
        cur.forecast_date,
        cur.gas_hdd,
        prev.run_datetime_utc AS prev_run_datetime_utc,
        prev.gas_hdd AS prev_gas_hdd,
        CASE
            WHEN prev.run_datetime_utc IS NULL THEN NULL
            ELSE ROUND(cur.gas_hdd - prev.gas_hdd, 1)
        END AS diff_24h
    FROM runs_00z_unique cur
    LEFT JOIN runs_00z_unique prev
      ON prev.model = cur.model
     AND prev.forecast_date = cur.forecast_date
     AND prev.run_datetime_utc = cur.run_datetime_utc - INTERVAL '24 hours'
),

latest_with_diff AS (
    SELECT c.*
    FROM current_vs_prev c
    JOIN latest_run l
      ON c.model = l.model
     AND c.run_datetime_utc = l.run_datetime_utc
),

forecast_pivot AS (
    SELECT
        model,
        'Forecast' AS row_type,
        run_datetime_utc AT TIME ZONE 'UTC' AS init_time,
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
    FROM latest_with_diff
    WHERE forecast_date >= CURRENT_DATE
      AND forecast_date < CURRENT_DATE + 15
    GROUP BY model, run_datetime_utc
),

diff_pivot AS (
    SELECT
        model,
        'Differences' AS row_type,
        run_datetime_utc AT TIME ZONE 'UTC' AS init_time,
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
    FROM latest_with_diff
    WHERE forecast_date >= CURRENT_DATE
      AND forecast_date < CURRENT_DATE + 15
    GROUP BY model, run_datetime_utc
),

normals_pivot AS (
    SELECT
        'NORMAL_10YR' AS model,
        'Normals' AS row_type,
        NULL::TIMESTAMP AS init_time,
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
    init_time,
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
