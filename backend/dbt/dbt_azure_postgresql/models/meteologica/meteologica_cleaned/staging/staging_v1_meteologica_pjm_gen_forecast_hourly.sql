{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Meteologica PJM Generation Forecast (Hourly)
-- UNIONs 17 raw tables (solar, wind, hydro × RTO + sub-regions), normalizes to EPT date + hour_ending,
-- filters to complete 24h forecasts, ranks by issue time (earliest first)
-- Grain: 1 row per forecast_rank × forecast_date × hour_ending × source × region
---------------------------

WITH UNIONED AS (

    ---------------------------
    -- Solar — RTO + 3 regions
    ---------------------------

    SELECT
        'solar' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_pv_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_pv_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_pv_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_pv_power_generation_forecast_hourly') }}

    UNION ALL

    ---------------------------
    -- Wind — RTO + 3 regions
    ---------------------------

    SELECT
        'wind' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_wind_power_generation_forecast_hourly') }}

    UNION ALL

    ---------------------------
    -- Wind — Utility-level (8 sub-regions)
    ---------------------------

    SELECT
        'wind' AS source
        ,'MIDATL_AE' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_ae_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'MIDATL_PL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_pl_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'MIDATL_PN' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_pn_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'SOUTH_DOM' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_dom_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST_AEP' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_aep_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST_AP' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_ap_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST_ATSI' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_atsi_wind_power_generation_forecast_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST_CE' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_ce_wind_power_generation_forecast_hourly') }}

    UNION ALL

    ---------------------------
    -- Hydro — RTO only
    ---------------------------

    SELECT
        'hydro' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,forecast_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_hydro_power_generation_forecast_hourly') }}

),

---------------------------
-- NORMALIZE TIMESTAMPS TO EPT
---------------------------

NORMALIZED AS (
    SELECT
        source
        ,region
        ,(issue_date::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York') AS forecast_execution_datetime
        ,(issue_date::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::DATE AS forecast_execution_date
        ,forecast_period_start::DATE AS forecast_date
        ,EXTRACT(HOUR FROM forecast_period_start)::INT + 1 AS hour_ending
        ,forecast_mw::NUMERIC AS forecast_mw
    FROM UNIONED
),

--------------------------------
-- Rank forecasts per (forecast_date, source, region) by issue time (earliest first)
--------------------------------

FORECAST_RANK AS (
    SELECT
        forecast_date
        ,source
        ,region
        ,forecast_execution_datetime

        ,DENSE_RANK() OVER (
            PARTITION BY forecast_date, source, region
            ORDER BY forecast_execution_datetime ASC
        ) AS forecast_rank

    FROM (
        SELECT DISTINCT forecast_execution_datetime, forecast_date, source, region
        FROM NORMALIZED
    ) sub
),

--------------------------------
--------------------------------

FINAL AS (
    SELECT
        r.forecast_rank

        ,n.forecast_execution_datetime
        ,n.forecast_execution_date

        ,(n.forecast_date + INTERVAL '1 hour' * (n.hour_ending - 1)) AS forecast_datetime
        ,n.forecast_date
        ,n.hour_ending

        ,n.source
        ,n.region
        ,n.forecast_mw AS forecast_generation_mw

    FROM NORMALIZED n
    JOIN FORECAST_RANK r
        ON n.forecast_execution_datetime = r.forecast_execution_datetime
        AND n.forecast_date = r.forecast_date
        AND n.source = r.source
        AND n.region = r.region
)

SELECT * FROM FINAL
ORDER BY forecast_date DESC, forecast_execution_datetime DESC, hour_ending, source, region


