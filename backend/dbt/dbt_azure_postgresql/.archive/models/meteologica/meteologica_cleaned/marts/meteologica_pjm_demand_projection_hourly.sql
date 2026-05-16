{{
  config(
    materialized='incremental',
    unique_key='projection_date',
    incremental_strategy='delete+insert'
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT * FROM {{ ref('staging_v1_meteologica_pjm_demand_projection_hourly') }}

{% if is_incremental() %}
WHERE projection_date >= (SELECT MAX(projection_date) - INTERVAL '14 days' FROM {{ this }})
{% endif %}
