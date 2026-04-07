{{
  config(
    materialized='incremental',
    unique_key=['date', 'hour_ending', 'tie_flow_name'],
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
  )
}}

SELECT * FROM {{ ref('staging_v1_pjm_tie_flows_hourly') }}

{% if is_incremental() %}
WHERE date >= (CURRENT_DATE - INTERVAL '10 days')
{% endif %}
