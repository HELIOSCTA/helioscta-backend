{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM Tie Flows Daily (normalized)
-- Grain: 1 row per date Ã— tie_flow_name Ã— period
---------------------------

{% set onpeak_start = 8 %}
{% set onpeak_end = 23 %}

WITH HOURLY AS (
    SELECT * FROM {{ ref('staging_v1_pjm_tie_flows_hourly') }}
),

---------------------------
-- FLAT (all hours)
---------------------------

FLAT AS (
    SELECT
        date
        ,tie_flow_name
        ,'flat' AS period
        ,AVG(actual_mw) AS actual_mw
        ,AVG(scheduled_mw) AS scheduled_mw
    FROM HOURLY
    GROUP BY date, tie_flow_name
),

---------------------------
-- ONPEAK (hours 8-23)
---------------------------

ONPEAK AS (
    SELECT
        date
        ,tie_flow_name
        ,'onpeak' AS period
        ,AVG(actual_mw) AS actual_mw
        ,AVG(scheduled_mw) AS scheduled_mw
    FROM HOURLY
    WHERE hour_ending BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
    GROUP BY date, tie_flow_name
),

---------------------------
-- OFFPEAK (hours 1-7, 24)
---------------------------

OFFPEAK AS (
    SELECT
        date
        ,tie_flow_name
        ,'offpeak' AS period
        ,AVG(actual_mw) AS actual_mw
        ,AVG(scheduled_mw) AS scheduled_mw
    FROM HOURLY
    WHERE hour_ending NOT BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
    GROUP BY date, tie_flow_name
),

---------------------------
-- UNION ALL PERIODS
---------------------------

DAILY AS (
    SELECT * FROM FLAT
    UNION ALL
    SELECT * FROM ONPEAK
    UNION ALL
    SELECT * FROM OFFPEAK
)

SELECT * FROM DAILY
ORDER BY date DESC, tie_flow_name, period
