{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- Hourly LMPs (normalized)
-- Grain: 1 row per date Ã— hour Ã— hub Ã— market
---------------------------

WITH DA AS (
    SELECT
        date
        ,hour_ending
        ,hub
        ,da_lmp_total
        ,da_lmp_system_energy_price
        ,da_lmp_congestion_price
        ,da_lmp_marginal_loss_price
    FROM {{ ref('source_v1_pjm_da_hrl_lmps') }}
),

RT AS (
    SELECT
        date
        ,hour_ending
        ,hub
        ,rt_lmp_total
        ,rt_lmp_system_energy_price
        ,rt_lmp_congestion_price
        ,rt_lmp_marginal_loss_price
    FROM {{ ref('staging_v1_pjm_lmps_rt_hourly') }}
),

--------------------------------
-- Pivot to DA / RT / DART rows
--------------------------------

DA_ROWS AS (
    SELECT
        date
        ,hour_ending
        ,hub
        ,'da' AS market
        ,da_lmp_total AS lmp_total
        ,da_lmp_system_energy_price AS lmp_system_energy_price
        ,da_lmp_congestion_price AS lmp_congestion_price
        ,da_lmp_marginal_loss_price AS lmp_marginal_loss_price
    FROM DA
),

RT_ROWS AS (
    SELECT
        date
        ,hour_ending
        ,hub
        ,'rt' AS market
        ,rt_lmp_total AS lmp_total
        ,rt_lmp_system_energy_price AS lmp_system_energy_price
        ,rt_lmp_congestion_price AS lmp_congestion_price
        ,rt_lmp_marginal_loss_price AS lmp_marginal_loss_price
    FROM RT
),

DART_ROWS AS (
    SELECT
        da.date
        ,da.hour_ending
        ,da.hub
        ,'dart' AS market
        ,(da.da_lmp_total - rt.rt_lmp_total) AS lmp_total
        ,(da.da_lmp_system_energy_price - rt.rt_lmp_system_energy_price) AS lmp_system_energy_price
        ,(da.da_lmp_congestion_price - rt.rt_lmp_congestion_price) AS lmp_congestion_price
        ,(da.da_lmp_marginal_loss_price - rt.rt_lmp_marginal_loss_price) AS lmp_marginal_loss_price
    FROM DA
    INNER JOIN RT ON da.date = rt.date AND da.hour_ending = rt.hour_ending AND da.hub = rt.hub
),

LMPS AS (
    SELECT * FROM DA_ROWS
    UNION ALL
    SELECT * FROM RT_ROWS
    UNION ALL
    SELECT * FROM DART_ROWS
)

SELECT
    date + (hour_ending || ' hours')::interval AS datetime,
    *
FROM LMPS
ORDER BY date DESC, hour_ending DESC, hub, market
