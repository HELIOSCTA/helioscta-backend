{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM 7-Day Load Forecast Daily (holiday-aware OnPeak/OffPeak)
-- Grain: 1 row per forecast_rank Ã— forecast_date Ã— region Ã— period
---------------------------

WITH HOURLY AS (
    SELECT
        h.forecast_rank
        ,h.forecast_date
        ,h.hour_ending
        ,h.region
        ,h.forecast_load_mw
        ,d.period
    FROM {{ ref('staging_v1_pjm_load_forecast_hourly') }} h
    INNER JOIN {{ ref('utils_v1_pjm_dates_hourly') }} d
        ON h.forecast_date = d.date
        AND h.hour_ending = d.hour_ending
),

FLAT AS (
    SELECT
        forecast_rank
        ,forecast_date
        ,region
        ,'flat' AS period
        ,AVG(forecast_load_mw) AS forecast_load_mw
    FROM HOURLY
    GROUP BY forecast_rank, forecast_date, region
),

PEAK AS (
    SELECT
        forecast_rank
        ,forecast_date
        ,region
        ,'peak' AS period
        ,MAX(forecast_load_mw) AS forecast_load_mw
    FROM HOURLY
    GROUP BY forecast_rank, forecast_date, region
),

ONPEAK AS (
    SELECT
        forecast_rank
        ,forecast_date
        ,region
        ,'onpeak' AS period
        ,AVG(forecast_load_mw) AS forecast_load_mw
    FROM HOURLY
    WHERE period = 'OnPeak'
    GROUP BY forecast_rank, forecast_date, region
),

OFFPEAK AS (
    SELECT
        forecast_rank
        ,forecast_date
        ,region
        ,'offpeak' AS period
        ,AVG(forecast_load_mw) AS forecast_load_mw
    FROM HOURLY
    WHERE period = 'OffPeak'
    GROUP BY forecast_rank, forecast_date, region
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
ORDER BY forecast_date DESC, forecast_rank, region, period
