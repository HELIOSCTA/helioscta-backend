{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- DA LMPS (normalized)
-- Grain: 1 row per date × hour × hub
---------------------------

WITH DA_LMPS AS (
    SELECT
        DATE(datetime_beginning_ept) AS date
        ,EXTRACT(HOUR FROM datetime_beginning_ept) + 1 AS hour_ending

        ,pnode_name AS hub

        ,total_lmp_da AS da_lmp_total
        ,system_energy_price_da AS da_lmp_system_energy_price
        ,congestion_price_da AS da_lmp_congestion_price
        ,marginal_loss_price_da AS da_lmp_marginal_loss_price

    FROM {{source('pjm_v1', 'da_hrl_lmps')}}
    WHERE
        DATE(datetime_beginning_ept) >= '2014-01-01'
)

SELECT * FROM DA_LMPS
ORDER BY date DESC, hour_ending DESC, hub
