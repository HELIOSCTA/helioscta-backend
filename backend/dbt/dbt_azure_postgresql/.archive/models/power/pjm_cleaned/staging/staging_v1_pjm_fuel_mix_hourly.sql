{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM Fuel Mix Hourly
-- Grain: 1 row per date Ã— hour
---------------------------

WITH HOURLY AS (
    SELECT
        date
        ,hour_ending

        ,coal
        ,gas
        ,hydro
        ,multiple_fuels
        ,nuclear
        ,oil
        ,solar
        ,storage
        ,wind
        ,other
        ,other_renewables

        ,total
        ,thermal
        ,renewables
        ,gas_pct_thermal
        ,coal_pct_thermal

    FROM {{ ref('source_v1_gridstatus_pjm_fuel_mix_hourly') }}
)

SELECT
    date + (hour_ending || ' hours')::interval AS datetime,
    *
FROM HOURLY
ORDER BY date DESC, hour_ending DESC
