{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Operational Reserves (normalized)
-- Grain: 1 row per date x hour x reserve_name
-- Source: 15-second updates, 15-day retention
---------------------------

WITH RAW AS (
    SELECT
        datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending
        ,reserve_name
        ,reserve_mw::NUMERIC AS reserve_mw
    FROM {{ source('pjm_v1', 'operational_reserves') }}
),

--------------------------------
-- Aggregate to hourly (source is sub-minute)
-- Average and min for the hour
--------------------------------

HOURLY AS (
    SELECT
        date
        ,hour_ending
        ,reserve_name
        ,AVG(reserve_mw) AS reserve_mw_avg
        ,MIN(reserve_mw) AS reserve_mw_min
    FROM RAW
    GROUP BY date, hour_ending, reserve_name
)

SELECT * FROM HOURLY
ORDER BY date DESC, hour_ending DESC, reserve_name
