{{
  config(
    materialized='view'
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT
    update_rank
    ,update_datetime
    ,update_date

    ,observation_date
    ,EXTRACT(HOUR FROM observation_datetime)::INT + 1 AS hour_ending

    ,region
    ,ROUND(AVG(observation_load_mw), 0) AS observation_load_mw

FROM {{ ref('meteologica_pjm_demand_observation_5min') }}

GROUP BY
    update_rank
    ,update_datetime
    ,update_date
    ,observation_date
    ,EXTRACT(HOUR FROM observation_datetime)::INT + 1
    ,region

ORDER BY observation_date DESC, update_datetime DESC, hour_ending, region
