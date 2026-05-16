{{
  config(
    materialized='incremental',
    unique_key='observation_date',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['observation_datetime', 'region'], 'type': 'btree'},
    ]
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

SELECT * FROM {{ ref('staging_v1_meteologica_pjm_demand_observation') }}

{% if is_incremental() %}
WHERE observation_date >= (SELECT MAX(observation_date) - INTERVAL '14 days' FROM {{ this }})
{% endif %}
