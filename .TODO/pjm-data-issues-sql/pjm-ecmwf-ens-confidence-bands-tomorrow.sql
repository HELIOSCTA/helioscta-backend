---------------------------------------------------------------
-- ECMWF-ENS CONFIDENCE BANDS vs METEO DETERMINISTIC vs PJM ISO
-- Tomorrow's forecast comparison for PJM RTO
--
-- Columns:
--   ENS BOTTOM:      ECMWF-ENS ensemble minimum (MW)
--   ENS AVG:         ECMWF-ENS ensemble average (MW)
--   ENS TOP:         ECMWF-ENS ensemble maximum (MW)
--   ENS SPREAD:      ENS TOP - ENS BOTTOM (confidence band width)
--   METEO:           Meteologica deterministic RTO forecast (MW)
--   PJM ISO:         PJM ISO RTO forecast (MW)
--   METEO vs AVG:    METEO - ENS AVG (how far deterministic is from ensemble mean)
--   PJM vs AVG:      PJM ISO - ENS AVG
--   METEO IN BAND:   Whether METEO falls within ENS BOTTOM..ENS TOP
--   PJM IN BAND:     Whether PJM ISO falls within ENS BOTTOM..ENS TOP
--
-- Filters:
--   run_date_mst  = (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE
--   forecast_date = run_date_mst + 1
--   Morning vintages only: EXTRACT(HOUR FROM forecast_execution_datetime) <= 10
--   Lowest forecast_rank from filtered set (most recent morning vintage)
---------------------------------------------------------------

WITH run_params AS (
    SELECT
        (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE AS run_date_mst
        ,(CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE + 1 AS target_date
),

---------------------------------------------------------------
-- ECMWF-ENS RTO (ensemble confidence bands)
---------------------------------------------------------------

ens_ranked AS (
    SELECT
        e.hour_ending - 1 AS hr
        ,e.forecast_load_average_mw AS ens_avg
        ,e.forecast_load_bottom_mw AS ens_bottom
        ,e.forecast_load_top_mw AS ens_top
        ,e.forecast_execution_datetime AS ens_exec_dt
        ,e.forecast_rank
        ,MIN(e.forecast_rank) OVER () AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_ecmwf_ens_hourly e
    CROSS JOIN run_params rp
    WHERE
        e.forecast_execution_date::DATE = rp.run_date_mst
        AND e.forecast_date::DATE = rp.target_date
        AND e.region = 'RTO'
),

ens AS (
    SELECT hr, ens_avg, ens_bottom, ens_top, ens_exec_dt
    FROM ens_ranked
    WHERE forecast_rank = min_rank
),

---------------------------------------------------------------
-- Meteologica Deterministic RTO
---------------------------------------------------------------

meteo_rto_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.forecast_load_mw AS meteo_mw
        ,m.forecast_execution_datetime AS meteo_exec_dt
        ,m.forecast_rank
        ,MIN(m.forecast_rank) OVER () AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_hourly m
    CROSS JOIN run_params rp
    WHERE
        m.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM m.forecast_execution_datetime) <= 10
        AND m.forecast_date::DATE = rp.target_date
        AND m.region = 'RTO'
),

meteo_rto AS (
    SELECT hr, meteo_mw, meteo_exec_dt
    FROM meteo_rto_ranked
    WHERE forecast_rank = min_rank
),

---------------------------------------------------------------
-- PJM ISO RTO
---------------------------------------------------------------

pjm_ranked AS (
    SELECT
        p.hour_ending - 1 AS hr
        ,p.forecast_load_mw AS pjm_mw
        ,p.forecast_execution_datetime AS pjm_exec_dt
        ,p.forecast_rank
        ,MIN(p.forecast_rank) OVER () AS min_rank
    FROM pjm_cleaned.pjm_load_forecast_hourly p
    CROSS JOIN run_params rp
    WHERE
        p.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM p.forecast_execution_datetime) <= 10
        AND p.forecast_date::DATE = rp.target_date
        AND p.region = 'RTO'
),

pjm AS (
    SELECT hr, pjm_mw, pjm_exec_dt
    FROM pjm_ranked
    WHERE forecast_rank = min_rank
),

---------------------------------------------------------------
-- Metadata: forecast execution datetimes used
---------------------------------------------------------------

ens_meta AS (
    SELECT DISTINCT ens_exec_dt FROM ens LIMIT 1
),

meteo_meta AS (
    SELECT DISTINCT meteo_exec_dt FROM meteo_rto LIMIT 1
),

pjm_meta AS (
    SELECT DISTINCT pjm_exec_dt FROM pjm LIMIT 1
)

---------------------------------------------------------------
-- Output 1: Metadata
---------------------------------------------------------------

SELECT
    'ECMWF-ENS CONFIDENCE BANDS - ' || rp.target_date::TEXT AS "Title"
    ,rp.run_date_mst                                         AS "Run Date (MST)"
    ,rp.target_date                                          AS "Forecast Date"
    ,em.ens_exec_dt                                          AS "ENS Forecast Execution (EPT)"
    ,mm.meteo_exec_dt                                        AS "Meteo Deterministic Execution (EPT)"
    ,pm.pjm_exec_dt                                          AS "PJM ISO Forecast Execution (EPT)"
FROM run_params rp
LEFT JOIN ens_meta em ON TRUE
LEFT JOIN meteo_meta mm ON TRUE
LEFT JOIN pjm_meta pm ON TRUE
;

---------------------------------------------------------------
-- Output 2: 24 hourly rows + DAILY GWh summary row
---------------------------------------------------------------

WITH run_params AS (
    SELECT
        (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE AS run_date_mst
        ,(CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE + 1 AS target_date
),

ens_ranked AS (
    SELECT
        e.hour_ending - 1 AS hr
        ,e.forecast_load_average_mw AS ens_avg
        ,e.forecast_load_bottom_mw AS ens_bottom
        ,e.forecast_load_top_mw AS ens_top
        ,e.forecast_rank
        ,MIN(e.forecast_rank) OVER () AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_ecmwf_ens_hourly e
    CROSS JOIN run_params rp
    WHERE
        e.forecast_execution_date::DATE = rp.run_date_mst
        AND e.forecast_date::DATE = rp.target_date
        AND e.region = 'RTO'
),

ens AS (
    SELECT hr, ens_avg, ens_bottom, ens_top
    FROM ens_ranked
    WHERE forecast_rank = min_rank
),

meteo_rto_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.forecast_load_mw AS meteo_mw
        ,m.forecast_rank
        ,MIN(m.forecast_rank) OVER () AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_hourly m
    CROSS JOIN run_params rp
    WHERE
        m.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM m.forecast_execution_datetime) <= 10
        AND m.forecast_date::DATE = rp.target_date
        AND m.region = 'RTO'
),

meteo_rto AS (
    SELECT hr, meteo_mw
    FROM meteo_rto_ranked
    WHERE forecast_rank = min_rank
),

pjm_ranked AS (
    SELECT
        p.hour_ending - 1 AS hr
        ,p.forecast_load_mw AS pjm_mw
        ,p.forecast_rank
        ,MIN(p.forecast_rank) OVER () AS min_rank
    FROM pjm_cleaned.pjm_load_forecast_hourly p
    CROSS JOIN run_params rp
    WHERE
        p.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM p.forecast_execution_datetime) <= 10
        AND p.forecast_date::DATE = rp.target_date
        AND p.region = 'RTO'
),

pjm AS (
    SELECT hr, pjm_mw
    FROM pjm_ranked
    WHERE forecast_rank = min_rank
),

hours AS (
    SELECT generate_series(0, 23) AS hr
),

hourly AS (
    SELECT
        h.hr
        ,e.ens_bottom
        ,e.ens_avg
        ,e.ens_top
        ,e.ens_top - e.ens_bottom AS ens_spread
        ,mr.meteo_mw
        ,p.pjm_mw
    FROM hours h
    LEFT JOIN ens e ON h.hr = e.hr
    LEFT JOIN meteo_rto mr ON h.hr = mr.hr
    LEFT JOIN pjm p ON h.hr = p.hr
)

SELECT "Hr", "Time",
       "ENS BOTTOM", "ENS AVG", "ENS TOP", "ENS SPREAD",
       "METEO", "PJM ISO",
       "METEO vs AVG", "PJM vs AVG",
       "METEO IN BAND", "PJM IN BAND"
FROM (

    -- Hourly rows (Hr 0-23)
    SELECT
        h.hr                                              AS "Hr"
        ,LPAD(h.hr::TEXT, 2, '0') || ':00'                AS "Time"
        ,ROUND(h.ens_bottom)::NUMERIC                     AS "ENS BOTTOM"
        ,ROUND(h.ens_avg)::NUMERIC                        AS "ENS AVG"
        ,ROUND(h.ens_top)::NUMERIC                        AS "ENS TOP"
        ,ROUND(h.ens_spread)::NUMERIC                     AS "ENS SPREAD"
        ,ROUND(h.meteo_mw)::NUMERIC                       AS "METEO"
        ,ROUND(h.pjm_mw)::NUMERIC                         AS "PJM ISO"
        ,ROUND(h.meteo_mw - h.ens_avg)::NUMERIC           AS "METEO vs AVG"
        ,ROUND(h.pjm_mw - h.ens_avg)::NUMERIC             AS "PJM vs AVG"
        ,CASE
            WHEN h.meteo_mw BETWEEN h.ens_bottom AND h.ens_top THEN 'YES'
            WHEN h.meteo_mw < h.ens_bottom THEN 'BELOW'
            WHEN h.meteo_mw > h.ens_top THEN 'ABOVE'
         END                                               AS "METEO IN BAND"
        ,CASE
            WHEN h.pjm_mw BETWEEN h.ens_bottom AND h.ens_top THEN 'YES'
            WHEN h.pjm_mw < h.ens_bottom THEN 'BELOW'
            WHEN h.pjm_mw > h.ens_top THEN 'ABOVE'
         END                                               AS "PJM IN BAND"
    FROM hourly h

    UNION ALL

    -- DAILY GWh summary row
    SELECT
        NULL                                                       AS "Hr"
        ,'DAILY GWh'                                               AS "Time"
        ,ROUND(SUM(ens_bottom)::NUMERIC / 1000, 1)                 AS "ENS BOTTOM"
        ,ROUND(SUM(ens_avg)::NUMERIC / 1000, 1)                    AS "ENS AVG"
        ,ROUND(SUM(ens_top)::NUMERIC / 1000, 1)                    AS "ENS TOP"
        ,ROUND(SUM(ens_spread)::NUMERIC / 1000, 1)                 AS "ENS SPREAD"
        ,ROUND(SUM(meteo_mw)::NUMERIC / 1000, 1)                  AS "METEO"
        ,ROUND(SUM(pjm_mw)::NUMERIC / 1000, 1)                    AS "PJM ISO"
        ,ROUND(SUM(meteo_mw - ens_avg)::NUMERIC / 1000, 1)        AS "METEO vs AVG"
        ,ROUND(SUM(pjm_mw - ens_avg)::NUMERIC / 1000, 1)          AS "PJM vs AVG"
        ,ROUND(100.0 * SUM(CASE WHEN meteo_mw BETWEEN ens_bottom AND ens_top THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0)::TEXT || '%'
                                                                   AS "METEO IN BAND"
        ,ROUND(100.0 * SUM(CASE WHEN pjm_mw BETWEEN ens_bottom AND ens_top THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0)::TEXT || '%'
                                                                   AS "PJM IN BAND"
    FROM hourly

) sub
ORDER BY "Hr" NULLS LAST
;
