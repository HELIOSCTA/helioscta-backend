{{
  config(
    materialized='incremental',
    unique_key='forecast_execution_date',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['forecast_execution_date', 'forecast_date', 'hour_ending', 'region'], 'unique': true, 'type': 'btree'},
      {'columns': ['forecast_date'], 'type': 'btree'},
    ]
  )
}}

WITH source AS (
    SELECT
        evaluated_at_datetime_ept AS forecast_execution_datetime,
        evaluated_at_datetime_ept::DATE AS forecast_execution_date,
        forecast_datetime_beginning_ept::DATE AS forecast_date,
        EXTRACT(HOUR FROM forecast_datetime_beginning_ept)::INT + 1 AS hour_ending,
        CASE forecast_area
            WHEN 'RTO_COMBINED' THEN 'RTO'
            WHEN 'MID_ATLANTIC_REGION' THEN 'MIDATL'
            WHEN 'WESTERN_REGION' THEN 'WEST'
            WHEN 'SOUTHERN_REGION' THEN 'SOUTH'
            ELSE forecast_area
        END AS region,
        forecast_load_mw
    FROM {{ source('pjm_v1', 'seven_day_load_forecast_v1_2025_08_13') }}
    WHERE forecast_area IN ('RTO_COMBINED', 'MID_ATLANTIC_REGION', 'WESTERN_REGION', 'SOUTHERN_REGION')
    {% if is_incremental() %}
    AND evaluated_at_datetime_ept::DATE >= (SELECT MAX(forecast_execution_date) - INTERVAL '14 days' FROM {{ this }})
    {% endif %}
),

forecast_rank AS (
    SELECT
        forecast_execution_datetime,
        forecast_date,
        DENSE_RANK() OVER (
            PARTITION BY forecast_date
            ORDER BY forecast_execution_datetime ASC
        ) AS forecast_rank
    FROM (
        SELECT DISTINCT forecast_execution_datetime, forecast_date
        FROM source
    ) sub
),

forecasts AS (
    SELECT
        ROW_NUMBER() OVER (
            PARTITION BY s.forecast_execution_date, s.forecast_date, s.hour_ending, s.region
            ORDER BY s.forecast_execution_datetime DESC
        ) AS rn,
        s.forecast_execution_date,
        s.forecast_execution_datetime,
        (s.forecast_date + INTERVAL '1 hour' * (s.hour_ending - 1)) AS forecast_datetime,
        s.forecast_date,
        s.hour_ending,
        r.forecast_rank,
        s.region,
        s.forecast_load_mw
    FROM source s
    JOIN forecast_rank r
        ON s.forecast_execution_datetime = r.forecast_execution_datetime
        AND s.forecast_date = r.forecast_date
)

SELECT
    forecast_execution_date,
    forecast_execution_datetime,
    forecast_datetime,
    forecast_date,
    hour_ending,
    forecast_rank,
    region,
    forecast_load_mw
FROM forecasts
WHERE rn = 1
