{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Dispatched Reserves (normalized)
-- Grain: 1 row per date x hour x area x reserve_type
-- Source: 5-minute updates, 30-day retention
---------------------------

WITH RAW AS (
    SELECT
        datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending
        ,area
        ,reserve_type
        ,reserve_quantity::NUMERIC AS reserve_quantity_mw
        ,reserve_requirement::NUMERIC AS reserve_requirement_mw
        ,reliability_requirement::NUMERIC AS reliability_requirement_mw
        ,extended_requirement::NUMERIC AS extended_requirement_mw
        ,mw_adjustment::NUMERIC AS mw_adjustment
        ,market_clearing_price::NUMERIC AS market_clearing_price
        ,shortage_indicator::BOOLEAN AS shortage_indicator
    FROM {{ source('pjm_v1', 'dispatched_reserves') }}
),

--------------------------------
-- Aggregate to hourly (source is 5-min)
-- Take the average for MW values, MAX for clearing price,
-- TRUE if shortage fired in ANY 5-min interval
--------------------------------

HOURLY AS (
    SELECT
        date
        ,hour_ending
        ,area
        ,reserve_type
        ,AVG(reserve_quantity_mw) AS reserve_quantity_mw
        ,AVG(reserve_requirement_mw) AS reserve_requirement_mw
        ,AVG(reliability_requirement_mw) AS reliability_requirement_mw
        ,AVG(extended_requirement_mw) AS extended_requirement_mw
        ,AVG(mw_adjustment) AS mw_adjustment
        ,MAX(market_clearing_price) AS market_clearing_price
        ,BOOL_OR(shortage_indicator) AS shortage_indicator
    FROM RAW
    GROUP BY date, hour_ending, area, reserve_type
)

SELECT * FROM HOURLY
ORDER BY date DESC, hour_ending DESC, area, reserve_type
