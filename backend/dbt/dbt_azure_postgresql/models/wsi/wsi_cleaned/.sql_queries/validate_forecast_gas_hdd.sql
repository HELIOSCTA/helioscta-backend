/*
    VALIDATION: Gas Weighted HDD Daily Forecast — CONUS
    Pivoted summary matching WSI website layout.

    - Latest 00Z run per model (CONUS, bias_corrected = false)
    - Differences row = current 00Z value minus previous run (12h comparator: latest prior 00Z/12Z)
    - 10-year normals row from observed data
    - 15-day forecast window starting from CURRENT_DATE
*/

-------------------------------------------------------------
-- 1. UNION all model tables
-------------------------------------------------------------

WITH forecast_union AS (
    SELECT init_time, period_start AS forecast_date, model, site_id, bias_corrected, gas_hdd, updated_at
    FROM wsi.wsi_wdd_day_forecast_v2_2025_dec_17
    UNION ALL
    SELECT init_time, period_start AS forecast_date, model, site_id, bias_corrected, gas_hdd, updated_at
    FROM wsi.gfs_op_wdd_day_forecast_v2_2025_dec_17
    UNION ALL
    SELECT init_time, period_start AS forecast_date, model, site_id, bias_corrected, gas_hdd, updated_at
    FROM wsi.gfs_ens_wdd_day_forecast_v2_2025_dec_17
    UNION ALL
    SELECT init_time, period_start AS forecast_date, model, site_id, bias_corrected, gas_hdd, updated_at
    FROM wsi.ecmwf_op_wdd_day_forecast_v2_2025_dec_17
    UNION ALL
    SELECT init_time, period_start AS forecast_date, model, site_id, bias_corrected, gas_hdd, updated_at
    FROM wsi.ecmwf_ens_wdd_day_forecast_v2_2025_dec_17
),

forecast_dedup AS (
    SELECT init_time, forecast_date, model, site_id, bias_corrected, gas_hdd
    FROM (
        SELECT
            init_time,
            forecast_date,
            model,
            site_id,
            bias_corrected,
            gas_hdd,
            ROW_NUMBER() OVER (
                PARTITION BY model, site_id, bias_corrected, init_time, forecast_date
                ORDER BY updated_at DESC
            ) AS forecast_revision
        FROM forecast_union
    ) t
    WHERE forecast_revision = 1
),

-------------------------------------------------------------
-- 2. Filter to CONUS, unbiased, 00Z only
-------------------------------------------------------------

runs_00z AS (
    SELECT
        model,
        init_time,
        forecast_date,
        ROUND(gas_hdd::NUMERIC, 1) AS gas_hdd
    FROM forecast_dedup
    WHERE site_id = 'CONUS'
      AND bias_corrected = 'false'
      AND EXTRACT(HOUR FROM init_time) = 0
),

runs_00z_12z AS (
    SELECT
        model,
        init_time,
        forecast_date,
        ROUND(gas_hdd::NUMERIC, 1) AS gas_hdd
    FROM forecast_dedup
    WHERE site_id = 'CONUS'
      AND bias_corrected = 'false'
      AND EXTRACT(HOUR FROM init_time) IN (0, 12)
),

-------------------------------------------------------------
-- 3. Latest 00Z init_time per model
-------------------------------------------------------------

latest_init AS (
    SELECT model, MAX(init_time) AS max_init_time
    FROM runs_00z
    GROUP BY model
),

-------------------------------------------------------------
-- 4. Current run (latest 00Z) and previous run (00Z/12Z comparator)
-------------------------------------------------------------

current_run AS (
    SELECT r.model, r.init_time, r.forecast_date, r.gas_hdd
    FROM runs_00z r
    JOIN latest_init l ON r.model = l.model AND r.init_time = l.max_init_time
),

prev_init AS (
    -- latest prior run per model using 00Z/12Z cycles
    SELECT r.model, MAX(r.init_time) AS prev_init_time
    FROM runs_00z_12z r
    JOIN latest_init l ON r.model = l.model AND r.init_time < l.max_init_time
    GROUP BY r.model
),

prev_run AS (
    SELECT r.model, r.forecast_date, r.gas_hdd AS prev_gas_hdd
    FROM runs_00z_12z r
    JOIN prev_init p ON r.model = p.model AND r.init_time = p.prev_init_time
),

-------------------------------------------------------------
-- 5. Join current + previous to compute differences
-------------------------------------------------------------

with_diff AS (
    SELECT
        c.model,
        c.init_time,
        c.forecast_date,
        c.gas_hdd,
        ROUND(c.gas_hdd - p.prev_gas_hdd, 1) AS diff_prev
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
        init_time,
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
    GROUP BY model, init_time
),

-------------------------------------------------------------
-- 7. PIVOT: differences row (current 00Z minus previous comparator run)
-------------------------------------------------------------

diff_pivot AS (
    SELECT
        model,
        'Differences' AS row_type,
        init_time,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 0  THEN diff_prev END) AS day_01,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 1  THEN diff_prev END) AS day_02,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 2  THEN diff_prev END) AS day_03,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 3  THEN diff_prev END) AS day_04,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 4  THEN diff_prev END) AS day_05,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 5  THEN diff_prev END) AS day_06,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 6  THEN diff_prev END) AS day_07,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 7  THEN diff_prev END) AS day_08,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 8  THEN diff_prev END) AS day_09,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 9  THEN diff_prev END) AS day_10,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 10 THEN diff_prev END) AS day_11,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 11 THEN diff_prev END) AS day_12,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 12 THEN diff_prev END) AS day_13,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 13 THEN diff_prev END) AS day_14,
        MAX(CASE WHEN forecast_date = CURRENT_DATE + 14 THEN diff_prev END) AS day_15,
        ROUND(SUM(diff_prev), 1) AS total
    FROM with_diff
    WHERE forecast_date >= CURRENT_DATE AND forecast_date < CURRENT_DATE + 15
    GROUP BY model, init_time
),

-------------------------------------------------------------
-- 8. NORMALS: 10-year avg gas_hdd by calendar day
-------------------------------------------------------------

normals AS (
    SELECT
        CASE
            WHEN EXTRACT(MONTH FROM date) = 2 AND EXTRACT(DAY FROM date) = 29
            THEN '02-28'
            ELSE TO_CHAR(date, 'MM-DD')
        END AS mm_dd,
        ROUND(AVG(conus::NUMERIC), 1) AS gas_hdd_normal
    FROM wsi.daily_observed_wdd
    WHERE UPPER(data_type) = 'GAS_HDD'
      AND EXTRACT(YEAR FROM date) BETWEEN EXTRACT(YEAR FROM CURRENT_DATE) - 10
                                       AND EXTRACT(YEAR FROM CURRENT_DATE) - 1
    GROUP BY 1
),

normals_pivot AS (
    SELECT
        'NORMAL_10YR' AS model,
        'Normals' AS row_type,
        NULL::TIMESTAMP AS init_time,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 0,  'MM-DD') THEN gas_hdd_normal END) AS day_01,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 1,  'MM-DD') THEN gas_hdd_normal END) AS day_02,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 2,  'MM-DD') THEN gas_hdd_normal END) AS day_03,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 3,  'MM-DD') THEN gas_hdd_normal END) AS day_04,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 4,  'MM-DD') THEN gas_hdd_normal END) AS day_05,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 5,  'MM-DD') THEN gas_hdd_normal END) AS day_06,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 6,  'MM-DD') THEN gas_hdd_normal END) AS day_07,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 7,  'MM-DD') THEN gas_hdd_normal END) AS day_08,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 8,  'MM-DD') THEN gas_hdd_normal END) AS day_09,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 9,  'MM-DD') THEN gas_hdd_normal END) AS day_10,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 10, 'MM-DD') THEN gas_hdd_normal END) AS day_11,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 11, 'MM-DD') THEN gas_hdd_normal END) AS day_12,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 12, 'MM-DD') THEN gas_hdd_normal END) AS day_13,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 13, 'MM-DD') THEN gas_hdd_normal END) AS day_14,
        MAX(CASE WHEN mm_dd = TO_CHAR(CURRENT_DATE + 14, 'MM-DD') THEN gas_hdd_normal END) AS day_15,
        ROUND(SUM(gas_hdd_normal), 1) AS total
    FROM normals
    WHERE mm_dd IN (
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

