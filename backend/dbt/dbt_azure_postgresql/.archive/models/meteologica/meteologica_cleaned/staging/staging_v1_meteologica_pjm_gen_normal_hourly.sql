{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Meteologica PJM Generation Normal (Hourly)
-- UNIONs 9 raw tables (solar, wind, hydro x regions), normalizes to EPT date + hour_ending,
-- ranks by issue time (earliest first)
-- Grain: 1 row per update_rank x normal_date x hour_ending x source x region
---------------------------

WITH UNIONED AS (

    SELECT
        'solar' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_pv_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_pv_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_pv_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_pv_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_wind_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_wind_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_wind_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_wind_power_generation_normal_hourly') }}

    UNION ALL

    SELECT
        'hydro' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,normal_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_hydro_power_generation_normal_hourly') }}

),

---------------------------
-- NORMALIZE TIMESTAMPS TO EPT
---------------------------

NORMALIZED AS (
    SELECT
        source
        ,region
        ,(issue_date::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York') AS update_datetime
        ,(issue_date::TIMESTAMP AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::DATE AS update_date
        ,forecast_period_start::DATE AS normal_date
        ,EXTRACT(HOUR FROM forecast_period_start)::INT + 1 AS hour_ending
        ,normal_mw::NUMERIC AS normal_mw
    FROM UNIONED
),

--------------------------------
-- Rank updates per (normal_date, source, region) by issue time (earliest first)
--------------------------------

UPDATE_RANK AS (
    SELECT
        normal_date
        ,source
        ,region
        ,update_datetime

        ,DENSE_RANK() OVER (
            PARTITION BY normal_date, source, region
            ORDER BY update_datetime ASC
        ) AS update_rank

    FROM (
        SELECT DISTINCT update_datetime, normal_date, source, region
        FROM NORMALIZED
    ) sub
),

--------------------------------
--------------------------------

FINAL AS (
    SELECT
        r.update_rank

        ,n.update_datetime
        ,n.update_date

        ,(n.normal_date + INTERVAL '1 hour' * (n.hour_ending - 1)) AS normal_datetime
        ,n.normal_date
        ,n.hour_ending

        ,n.source
        ,n.region
        ,n.normal_mw AS normal_generation_mw

    FROM NORMALIZED n
    JOIN UPDATE_RANK r
        ON n.update_datetime = r.update_datetime
        AND n.normal_date = r.normal_date
        AND n.source = r.source
        AND n.region = r.region
)

SELECT * FROM FINAL
ORDER BY normal_date DESC, update_datetime DESC, hour_ending, source, region
