{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- PJM Fuel Mix Daily (normalized)
-- Grain: 1 row per date Ã— period
---------------------------

{% set onpeak_start = 8 %}
{% set onpeak_end = 23 %}

WITH HOURLY AS (
    SELECT * FROM {{ ref('staging_v1_pjm_fuel_mix_hourly') }}
),

---------------------------
-- FLAT (all hours)
---------------------------

FLAT AS (
    SELECT
        date
        ,'flat' AS period
        ,AVG(coal) AS coal
        ,AVG(gas) AS gas
        ,AVG(hydro) AS hydro
        ,AVG(multiple_fuels) AS multiple_fuels
        ,AVG(nuclear) AS nuclear
        ,AVG(oil) AS oil
        ,AVG(solar) AS solar
        ,AVG(storage) AS storage
        ,AVG(wind) AS wind
        ,AVG(other) AS other
        ,AVG(other_renewables) AS other_renewables
        ,AVG(total) AS total
        ,AVG(thermal) AS thermal
        ,AVG(renewables) AS renewables
        ,AVG(gas_pct_thermal) AS gas_pct_thermal
        ,AVG(coal_pct_thermal) AS coal_pct_thermal
    FROM HOURLY
    GROUP BY date
),

---------------------------
-- PEAK (max across all hours)
---------------------------

PEAK AS (
    SELECT
        date
        ,'peak' AS period
        ,MAX(coal) AS coal
        ,MAX(gas) AS gas
        ,MAX(hydro) AS hydro
        ,MAX(multiple_fuels) AS multiple_fuels
        ,MAX(nuclear) AS nuclear
        ,MAX(oil) AS oil
        ,MAX(solar) AS solar
        ,MAX(storage) AS storage
        ,MAX(wind) AS wind
        ,MAX(other) AS other
        ,MAX(other_renewables) AS other_renewables
        ,MAX(total) AS total
        ,MAX(thermal) AS thermal
        ,MAX(renewables) AS renewables
        ,MAX(gas_pct_thermal) AS gas_pct_thermal
        ,MAX(coal_pct_thermal) AS coal_pct_thermal
    FROM HOURLY
    GROUP BY date
),

---------------------------
-- ONPEAK (hours 8-23)
---------------------------

ONPEAK AS (
    SELECT
        date
        ,'onpeak' AS period
        ,AVG(coal) AS coal
        ,AVG(gas) AS gas
        ,AVG(hydro) AS hydro
        ,AVG(multiple_fuels) AS multiple_fuels
        ,AVG(nuclear) AS nuclear
        ,AVG(oil) AS oil
        ,AVG(solar) AS solar
        ,AVG(storage) AS storage
        ,AVG(wind) AS wind
        ,AVG(other) AS other
        ,AVG(other_renewables) AS other_renewables
        ,AVG(total) AS total
        ,AVG(thermal) AS thermal
        ,AVG(renewables) AS renewables
        ,AVG(gas_pct_thermal) AS gas_pct_thermal
        ,AVG(coal_pct_thermal) AS coal_pct_thermal
    FROM HOURLY
    WHERE hour_ending BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
    GROUP BY date
),

---------------------------
-- OFFPEAK (hours 1-7, 24)
---------------------------

OFFPEAK AS (
    SELECT
        date
        ,'offpeak' AS period
        ,AVG(coal) AS coal
        ,AVG(gas) AS gas
        ,AVG(hydro) AS hydro
        ,AVG(multiple_fuels) AS multiple_fuels
        ,AVG(nuclear) AS nuclear
        ,AVG(oil) AS oil
        ,AVG(solar) AS solar
        ,AVG(storage) AS storage
        ,AVG(wind) AS wind
        ,AVG(other) AS other
        ,AVG(other_renewables) AS other_renewables
        ,AVG(total) AS total
        ,AVG(thermal) AS thermal
        ,AVG(renewables) AS renewables
        ,AVG(gas_pct_thermal) AS gas_pct_thermal
        ,AVG(coal_pct_thermal) AS coal_pct_thermal
    FROM HOURLY
    WHERE hour_ending NOT BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
    GROUP BY date
),

---------------------------
-- UNION ALL PERIODS
---------------------------

DAILY AS (
    SELECT * FROM FLAT
    UNION ALL
    SELECT * FROM PEAK
    UNION ALL
    SELECT * FROM ONPEAK
    UNION ALL
    SELECT * FROM OFFPEAK
)

SELECT * FROM DAILY
ORDER BY date DESC, period
