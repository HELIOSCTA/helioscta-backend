{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- RT Metered Hourly Load
-- Grain: 1 row per date Ã— hour Ã— region
---------------------------

SELECT
    date + (hour_ending || ' hours')::interval AS datetime
    ,date
    ,hour_ending
    ,load_area AS region
    ,load_mw AS rt_load_mw
FROM {{ ref('source_v1_pjm_hrl_load_metered') }}
WHERE
    date >= '2014-01-01'
    AND load_area IN ('RTO', 'WEST', 'MIDATL', 'SOUTH')
