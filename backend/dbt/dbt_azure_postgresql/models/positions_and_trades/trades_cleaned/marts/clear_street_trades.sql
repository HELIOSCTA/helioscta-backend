{{
  config(
    materialized='incremental',
    unique_key='sftp_date',
    incremental_strategy='delete+insert'
  )
}}

-------------------------------------------------------------
-------------------------------------------------------------

WITH TRADES AS (
    SELECT * FROM {{ ref('staging_v2_clear_street_trades_2_product_codes') }}
    {% if is_incremental() %}
    WHERE sftp_date >= (SELECT MAX(sftp_date) - INTERVAL '14 days' FROM {{ this }})
    {% endif %}
)

SELECT * FROM TRADES
ORDER BY
  sftp_date DESC,
  sftp_upload_timestamp DESC,
  product_code_grouping,
  product_code_region