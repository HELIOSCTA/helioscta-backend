{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Ancillary Services Prices (normalized)
-- Grain: 1 row per date x hour x ancillary_service
---------------------------

WITH RAW AS (
    SELECT
        datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending
        ,ancillary_service
        ,unit
        ,value::NUMERIC AS value
        ,row_is_current::BOOLEAN AS row_is_current
        ,version_nbr
    FROM {{ source('pjm_v1', 'ancillary_services') }}
),

--------------------------------
-- Dedup: prefer current row, latest version
--------------------------------

RANKED AS (
    SELECT
        *
        ,ROW_NUMBER() OVER (
            PARTITION BY date, hour_ending, ancillary_service
            ORDER BY
                CASE WHEN row_is_current = TRUE THEN 0 ELSE 1 END
                ,version_nbr DESC
        ) AS rn
    FROM RAW
),

DEDUPED AS (
    SELECT
        date
        ,hour_ending
        ,ancillary_service
        ,unit
        ,value
    FROM RANKED
    WHERE rn = 1
)

SELECT * FROM DEDUPED
ORDER BY date DESC, hour_ending DESC, ancillary_service
