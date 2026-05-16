{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM 5-Min Tie Flows (normalized)
-- Grain: 1 row per 5-min timestamp × tie_flow_name
---------------------------

WITH FIVE_MIN AS (
    SELECT
        datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending

        ,tie_flow_name
        ,actual_mw::NUMERIC AS actual_mw
        ,scheduled_mw::NUMERIC AS scheduled_mw

    FROM {{ source('pjm_v1', 'five_min_tie_flows') }}
    WHERE
        EXTRACT(YEAR FROM datetime_beginning_ept) >= 2020
)

SELECT * FROM FIVE_MIN
ORDER BY date DESC, hour_ending DESC, tie_flow_name
