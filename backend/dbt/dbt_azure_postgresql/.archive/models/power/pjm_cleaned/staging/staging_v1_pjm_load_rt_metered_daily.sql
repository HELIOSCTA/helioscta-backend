{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- RT Metered Daily Load (holiday-aware OnPeak/OffPeak)
-- Grain: 1 row per date Ã— region Ã— period
---------------------------

WITH HOURLY AS (
    SELECT
        h.date
        ,h.hour_ending
        ,h.region
        ,h.rt_load_mw
        ,d.period
    FROM {{ ref('staging_v1_pjm_load_rt_metered_hourly') }} h
    INNER JOIN {{ ref('utils_v1_pjm_dates_hourly') }} d
        ON h.date = d.date
        AND h.hour_ending = d.hour_ending
),

FLAT AS (
    SELECT
        date
        ,region
        ,'flat' AS period
        ,AVG(rt_load_mw) AS rt_load_mw
    FROM HOURLY
    GROUP BY date, region
),

PEAK AS (
    SELECT
        date
        ,region
        ,'peak' AS period
        ,MAX(rt_load_mw) AS rt_load_mw
    FROM HOURLY
    GROUP BY date, region
),

ONPEAK AS (
    SELECT
        date
        ,region
        ,'onpeak' AS period
        ,AVG(rt_load_mw) AS rt_load_mw
    FROM HOURLY
    WHERE period = 'OnPeak'
    GROUP BY date, region
),

OFFPEAK AS (
    SELECT
        date
        ,region
        ,'offpeak' AS period
        ,AVG(rt_load_mw) AS rt_load_mw
    FROM HOURLY
    WHERE period = 'OffPeak'
    GROUP BY date, region
),

DAILY AS (
    SELECT * FROM FLAT
    UNION ALL
    SELECT * FROM PEAK
    UNION ALL
    SELECT * FROM ONPEAK
    UNION ALL
    SELECT * FROM OFFPEAK
)

SELECT * FROM DAILY
ORDER BY date DESC, region, period
