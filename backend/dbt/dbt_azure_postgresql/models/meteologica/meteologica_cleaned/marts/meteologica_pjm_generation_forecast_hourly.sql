{{
  config(
    materialized='incremental',
    unique_key='forecast_date',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['region', 'source', 'forecast_date', 'forecast_rank'], 'type': 'btree'},
      {'columns': ['region', 'source', 'forecast_execution_datetime'], 'type': 'btree'},
    ]
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT * FROM {{ ref('staging_v1_meteologica_pjm_gen_forecast_hourly') }}

{% if is_incremental() %}
WHERE forecast_date >= (SELECT MAX(forecast_date) - INTERVAL '14 days' FROM {{ this }})
{% endif %}
