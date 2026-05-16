{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- DA Demand Bids (normalized)
-- Grain: 1 row per date × hour × load_area
---------------------------

WITH DA_BIDS AS (
    SELECT
        DATE(datetime_beginning_ept) AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending

        ,CASE
            WHEN area = 'PJM_RTO' THEN 'RTO'
            WHEN area = 'MID_ATLANTIC_REGION' THEN 'MIDATL'
            WHEN area = 'WESTERN_REGION' THEN 'WEST'
            ELSE NULL
        END AS mkt_region
        ,CASE
            WHEN area = 'PJM_RTO' THEN 'RTO'
            WHEN area = 'MID_ATLANTIC_REGION' THEN 'MIDATL'
            WHEN area = 'WESTERN_REGION' THEN 'WEST'
            ELSE NULL
        END AS load_area

        ,hrly_da_demand_bid AS da_load_mw

    FROM {{ source('pjm_v1', 'hrl_dmd_bids') }}
    WHERE
        EXTRACT(YEAR FROM datetime_beginning_ept) >= 2014
)

SELECT * FROM DA_BIDS
WHERE mkt_region IS NOT NULL
ORDER BY date DESC, hour_ending DESC, load_area
