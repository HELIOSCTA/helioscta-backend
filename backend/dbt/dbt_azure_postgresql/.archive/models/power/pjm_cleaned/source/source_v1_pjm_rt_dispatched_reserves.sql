{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Real-Time Dispatched Reserves (normalized)
-- Grain: 1 row per date x hour x area x reserve_type
-- Source: daily on business days, indefinite retention
---------------------------

WITH RAW AS (
    SELECT
        mkt_day::DATE AS mkt_day
        ,datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending
        ,area
        ,reserve_type
        ,total_reserve_mw::NUMERIC AS total_reserve_mw
        ,reserve_reqmt_mw::NUMERIC AS reserve_requirement_mw
        ,reliability_reqmt_mw::NUMERIC AS reliability_requirement_mw
        ,extended_reqmt_mw::NUMERIC AS extended_requirement_mw
        ,additional_extended_reqmt_mw::NUMERIC AS additional_extended_requirement_mw
        ,deficit_mw::NUMERIC AS deficit_mw
    FROM {{ source('pjm_v1', 'real_time_dispatched_reserves') }}
)

SELECT * FROM RAW
ORDER BY date DESC, hour_ending DESC, area, reserve_type
