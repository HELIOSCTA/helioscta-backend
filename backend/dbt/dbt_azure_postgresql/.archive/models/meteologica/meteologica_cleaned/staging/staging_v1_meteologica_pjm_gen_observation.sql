{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Meteologica PJM Generation Observation
-- UNIONs 9 raw tables (solar, wind, hydro x regions), normalizes to EPT date + hour_ending,
-- ranks by issue time (earliest first)
-- Grain: 1 row per update_rank x observation_date x hour_ending x source x region
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
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_pv_power_generation_observation') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_pv_power_generation_observation') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_pv_power_generation_observation') }}

    UNION ALL

    SELECT
        'solar' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_pv_power_generation_observation') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_wind_power_generation_observation') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'WEST' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_west_wind_power_generation_observation') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'MIDATL' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_midatlantic_wind_power_generation_observation') }}

    UNION ALL

    SELECT
        'wind' AS source
        ,'SOUTH' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_south_wind_power_generation_observation') }}

    UNION ALL

    SELECT
        'hydro' AS source
        ,'RTO' AS region
        ,content_id
        ,update_id
        ,issue_date
        ,forecast_period_start
        ,forecast_period_end
        ,observation_mw
    FROM {{ source('meteologica_pjm_v1', 'usa_pjm_hydro_power_generation_observation') }}

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
        ,forecast_period_start::DATE AS observation_date
        ,EXTRACT(HOUR FROM forecast_period_start)::INT + 1 AS hour_ending
        ,observation_mw::NUMERIC AS observation_mw
    FROM UNIONED
),

--------------------------------
-- Rank updates per (observation_date, source, region) by issue time (earliest first)
--------------------------------

UPDATE_RANK AS (
    SELECT
        observation_date
        ,source
        ,region
        ,update_datetime

        ,DENSE_RANK() OVER (
            PARTITION BY observation_date, source, region
            ORDER BY update_datetime ASC
        ) AS update_rank

    FROM (
        SELECT DISTINCT update_datetime, observation_date, source, region
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

        ,(n.observation_date + INTERVAL '1 hour' * (n.hour_ending - 1)) AS observation_datetime
        ,n.observation_date
        ,n.hour_ending

        ,n.source
        ,n.region
        ,n.observation_mw AS observation_generation_mw

    FROM NORMALIZED n
    JOIN UPDATE_RANK r
        ON n.update_datetime = r.update_datetime
        AND n.observation_date = r.observation_date
        AND n.source = r.source
        AND n.region = r.region
)

SELECT * FROM FINAL
ORDER BY observation_date DESC, update_datetime DESC, hour_ending, source, region
