{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM Tie Flows Hourly (normalized)
-- 5-min data aggregated to hourly
-- Grain: 1 row per date Ã— hour Ã— tie_flow_name
---------------------------

WITH HOURLY AS (
    SELECT
        date
        ,hour_ending

        ,tie_flow_name
        ,AVG(actual_mw) AS actual_mw
        ,AVG(scheduled_mw) AS scheduled_mw

    FROM {{ ref('source_v1_pjm_five_min_tie_flows') }}
    GROUP BY date, hour_ending, tie_flow_name
)

SELECT
    date + (hour_ending || ' hours')::interval AS datetime,
    *
FROM HOURLY
ORDER BY date DESC, hour_ending DESC, tie_flow_name
