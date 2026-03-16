{{
  config(
    materialized='incremental',
    unique_key='forecast_date',
    incremental_strategy='delete+insert'
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT * FROM {{ ref('staging_v1_meteologica_pjm_demand_forecast_hourly') }}

{% if is_incremental() %}
WHERE forecast_date >= (SELECT MAX(forecast_date) - INTERVAL '14 days' FROM {{ this }})
{% endif %}
