{{
  config(
    materialized='incremental',
    unique_key='normal_date',
    incremental_strategy='delete+insert'
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT * FROM {{ ref('staging_v1_meteologica_pjm_gen_normal_hourly') }}

{% if is_incremental() %}
WHERE normal_date >= (SELECT MAX(normal_date) - INTERVAL '14 days' FROM {{ this }})
{% endif %}
