{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- DA Hourly Load (normalized)
-- Grain: 1 row per date Ã— hour Ã— region
---------------------------

WITH DA_BIDS AS (
    SELECT
        date
        ,hour_ending
        ,mkt_region
        ,load_area
        ,da_load_mw
    FROM {{ ref('source_v1_pjm_hrl_dmd_bids') }}
),

--------------------------------
-- SOUTH = RTO - MIDATL - WEST
--------------------------------

SOUTH AS (
    SELECT
        date
        ,hour_ending
        ,'SOUTH' AS mkt_region
        ,'SOUTH' AS load_area
        ,(
            AVG(CASE WHEN load_area = 'RTO' THEN da_load_mw END)
            - AVG(CASE WHEN load_area = 'MIDATL' THEN da_load_mw END)
            - AVG(CASE WHEN load_area = 'WEST' THEN da_load_mw END)
        ) AS da_load_mw
    FROM DA_BIDS
    GROUP BY date, hour_ending
),

FINAL AS (
    SELECT
        date
        ,hour_ending
        ,load_area AS region
        ,da_load_mw
    FROM DA_BIDS

    UNION ALL

    SELECT
        date
        ,hour_ending
        ,load_area AS region
        ,da_load_mw
    FROM SOUTH
)

SELECT
    date + (hour_ending || ' hours')::interval AS datetime,
    *
FROM FINAL
ORDER BY date DESC, hour_ending DESC, region
