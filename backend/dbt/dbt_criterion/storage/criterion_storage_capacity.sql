--------------------------------------------------
-- STORAGE CAPACITY & INVENTORY (BY FACILITY)
-- Database: Criterion PostgreSQL
-- Source: pipelines schema (nomination_points + metadata + regions)
--         + data_series PLST tickers for capacity forecasts
-- Units: Mcf (raw scheduled quantities) or Bcf for PLST tickers
-- Grain: Daily
-- Note: Combines pipelines schema storage inventory with PLST capacity data
--------------------------------------------------

-- OPTION 1: Facility-level inventory from pipelines schema
-- Uses storage_calc_flag to identify capacity/inventory records

WITH STORAGE_META AS (
    SELECT
        meta.metadata_id,
        meta.ticker,
        meta.metadata_desc,
        meta.rec_del_sign,
        rgn.eia_ng_regions,
        rgn.pipeline_name,
        rgn.storage_name,
        rgn.storage_calc_flag,
        meta.loc_name
    FROM pipelines.metadata meta
    INNER JOIN pipelines.regions rgn ON meta.metadata_id = rgn.metadata_id
    WHERE meta.ticker LIKE 'PLST.%'
       OR meta.ticker LIKE 'PLNM.%.6'
       OR rgn.storage_calc_flag IS NOT NULL
),

CAPACITY_FLOWS AS (
    SELECT
        noms.eff_gas_day,
        sm.eia_ng_regions,
        sm.pipeline_name,
        sm.storage_name,
        sm.ticker,
        sm.loc_name,
        SUM(noms.scheduled_quantity * sm.rec_del_sign) AS inventory_value
    FROM pipelines.nomination_points noms
    INNER JOIN STORAGE_META sm ON noms.metadata_id = sm.metadata_id
    WHERE noms.eff_gas_day >= '2020-01-01'
    GROUP BY
        noms.eff_gas_day,
        sm.eia_ng_regions,
        sm.pipeline_name,
        sm.storage_name,
        sm.ticker,
        sm.loc_name
)

SELECT
    eff_gas_day,
    eia_ng_regions,
    pipeline_name,
    storage_name,
    ticker,
    loc_name,
    inventory_value
FROM CAPACITY_FLOWS
ORDER BY eff_gas_day DESC, eia_ng_regions, storage_name
