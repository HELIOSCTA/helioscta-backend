{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM 2-Day Wind Forecast (all revisions)
-- Ranked by issue time (earliest first)
-- Grain: 1 row per forecast_execution_datetime × forecast_date × hour_ending
---------------------------

WITH FORECAST AS (
    SELECT
        forecast_execution_datetime
        ,forecast_execution_date
        ,forecast_date
        ,hour_ending
        ,wind_forecast
    FROM {{ ref('source_v1_gridstatus_pjm_wind_forecast_hourly') }}
),

---------------------------
-- RANK FORECASTS BY ISSUE TIME (EARLIEST FIRST, per forecast_date)
---------------------------

FORECAST_RANK AS (
    SELECT
        forecast_execution_datetime
        ,forecast_date

        ,DENSE_RANK() OVER (
            PARTITION BY forecast_date
            ORDER BY forecast_execution_datetime ASC
        ) AS forecast_rank

    FROM (
        SELECT DISTINCT forecast_execution_datetime, forecast_date
        FROM FORECAST
    ) sub
),

---------------------------
-- FINAL
---------------------------

FINAL AS (
    SELECT
        r.forecast_rank

        ,f.forecast_execution_datetime
        ,f.forecast_execution_date

        ,(f.forecast_date + INTERVAL '1 hour' * (f.hour_ending - 1)) AS forecast_datetime
        ,f.forecast_date
        ,f.hour_ending

        ,f.wind_forecast

    FROM FORECAST f
    JOIN FORECAST_RANK r
        ON f.forecast_execution_datetime = r.forecast_execution_datetime
        AND f.forecast_date = r.forecast_date
)

SELECT * FROM FINAL
ORDER BY forecast_date DESC, forecast_execution_datetime DESC, hour_ending


