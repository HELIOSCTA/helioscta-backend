{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM Fuel Mix Hourly (normalized)
-- Grain: 1 row per date × hour
---------------------------

WITH HOURLY AS (
    SELECT
        interval_start_local::DATE AS date
        ,EXTRACT(HOUR FROM interval_start_local) + 1 AS hour_ending

        ,coal::NUMERIC AS coal
        ,gas::NUMERIC AS gas
        ,hydro::NUMERIC AS hydro
        ,multiple_fuels::NUMERIC AS multiple_fuels
        ,nuclear::NUMERIC AS nuclear
        ,oil::NUMERIC AS oil
        ,solar::NUMERIC AS solar
        ,storage::NUMERIC AS storage
        ,wind::NUMERIC AS wind
        ,other::NUMERIC AS other
        ,other_renewables::NUMERIC AS other_renewables

    FROM {{ source('gridstatus_v1', 'pjm_fuel_mix_hourly') }}
    WHERE
        EXTRACT(YEAR FROM interval_start_local) >= 2020
),

---------------------------
-- DERIVED COLUMNS
---------------------------

SUPPLY AS (
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

        ,(
            COALESCE(coal, 0)
            + COALESCE(gas, 0)
            + COALESCE(hydro, 0)
            + COALESCE(multiple_fuels, 0)
            + COALESCE(nuclear, 0)
            + COALESCE(oil, 0)
            + COALESCE(solar, 0)
            + COALESCE(storage, 0)
            + COALESCE(wind, 0)
            + COALESCE(other, 0)
            + COALESCE(other_renewables, 0)
        ) AS total

        ,(COALESCE(coal, 0) + COALESCE(gas, 0)) AS thermal
        ,(COALESCE(solar, 0) + COALESCE(wind, 0)) AS renewables

        ,CASE
            WHEN (COALESCE(coal, 0) + COALESCE(gas, 0)) > 0
            THEN gas / (COALESCE(coal, 0) + COALESCE(gas, 0))
        END AS gas_pct_thermal
        ,CASE
            WHEN (COALESCE(coal, 0) + COALESCE(gas, 0)) > 0
            THEN coal / (COALESCE(coal, 0) + COALESCE(gas, 0))
        END AS coal_pct_thermal

    FROM HOURLY
)

SELECT * FROM SUPPLY
ORDER BY date DESC, hour_ending DESC
