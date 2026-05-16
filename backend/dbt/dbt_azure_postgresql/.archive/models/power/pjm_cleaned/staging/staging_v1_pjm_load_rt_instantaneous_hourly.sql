{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- RT Instantaneous Hourly Load (5-min averaged to hourly)
-- Grain: 1 row per date Ã— hour Ã— region
---------------------------

SELECT
    date + (hour_ending || ' hours')::interval AS datetime
    ,date
    ,hour_ending
    ,load_area AS region
    ,AVG(load_mw) AS rt_load_mw
FROM {{ ref('source_v1_pjm_five_min_load') }}
WHERE
    load_area IN ('RTO', 'WEST', 'MIDATL', 'SOUTH')
GROUP BY date, hour_ending, load_area
