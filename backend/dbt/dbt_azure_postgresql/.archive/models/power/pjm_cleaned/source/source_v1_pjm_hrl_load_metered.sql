{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- RT Metered Hourly Load (normalized)
-- Grain: 1 row per date × hour × mkt_region × load_area
---------------------------

WITH METERED AS (
    SELECT
        datetime_beginning_ept::DATE AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending

        ,mkt_region
        ,load_area

        ,mw AS load_mw
        ,is_verified::BOOLEAN AS company_verified

    FROM {{ source('pjm_v1', 'hourly_load_metered') }}
    WHERE
        datetime_beginning_ept::DATE >= '2014-01-01'
),

--------------------------------
-- Dedup on company_verified
--------------------------------

COMPANY_VERIFIED AS (
    SELECT
        *
        ,ROW_NUMBER() OVER (
            PARTITION BY date, hour_ending, mkt_region, load_area
            ORDER BY
                CASE
                    WHEN company_verified = FALSE AND load_area = 'RTO' THEN 0
                    WHEN company_verified = TRUE THEN 1
                    WHEN company_verified = FALSE THEN 2
                    ELSE 999
                END
        ) AS rank_company_verified
    FROM METERED
),

DEDUPED AS (
    SELECT
        date
        ,hour_ending
        ,mkt_region
        ,load_area
        ,load_mw
    FROM COMPANY_VERIFIED
    WHERE rank_company_verified = 1
),

--------------------------------
-- Regional aggregation
--------------------------------

MIDATL AS (
    SELECT
        date, hour_ending, mkt_region
        ,'MIDATL' AS load_area
        ,SUM(load_mw) AS load_mw
    FROM DEDUPED
    WHERE mkt_region = 'MIDATL'
    GROUP BY date, hour_ending, mkt_region
),

WEST AS (
    SELECT
        date, hour_ending, mkt_region
        ,'WEST' AS load_area
        ,SUM(load_mw) AS load_mw
    FROM DEDUPED
    WHERE mkt_region = 'WEST'
    GROUP BY date, hour_ending, mkt_region
),

SOUTH AS (
    SELECT
        date, hour_ending, mkt_region
        ,'SOUTH' AS load_area
        ,SUM(load_mw) AS load_mw
    FROM DEDUPED
    WHERE mkt_region = 'SOUTH'
    GROUP BY date, hour_ending, mkt_region
),

FINAL AS (
    SELECT date, hour_ending, mkt_region, load_area, load_mw FROM DEDUPED
    UNION ALL
    SELECT * FROM MIDATL
    UNION ALL
    SELECT * FROM WEST
    UNION ALL
    SELECT * FROM SOUTH
)

SELECT * FROM FINAL
ORDER BY date DESC, hour_ending DESC, mkt_region, load_area
