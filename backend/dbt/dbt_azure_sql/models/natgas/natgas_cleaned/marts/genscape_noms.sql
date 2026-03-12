{{
  config(
    materialized='view',
    schema='natgas_cleaned'
  )
}}

---------------------------
-- ENRICHED GAS NOMINATIONS
---------------------------

WITH NOMS AS (
    SELECT * FROM {{ ref('source_v1_genscape_noms') }}
),

---------------------------
-- FINAL
---------------------------

FINAL AS (
    SELECT * FROM NOMS
)

SELECT * FROM FINAL
