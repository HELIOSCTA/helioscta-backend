--------------------------------------------------
-- STORAGE DAILY FLOWS (BY FACILITY)
-- Database: Criterion PostgreSQL
-- Source: pipelines schema (nomination_points + metadata + regions)
-- Units: MMcf/d (raw scheduled quantities)
-- Grain: Daily by eff_gas_day
-- Note: Uses pipelines schema directly, not data_series tickers
--------------------------------------------------

WITH STORAGE_META AS (
    SELECT
        meta.metadata_id,
        meta.ticker,
        meta.metadata_desc,
        meta.rec_del_sign,
        rgn.eia_ng_regions,
        rgn.state_name,
        rgn.storage_name,
        rgn.storage_calc_flag,
        meta.loc_name
    FROM pipelines.metadata meta
    INNER JOIN pipelines.regions rgn ON meta.metadata_id = rgn.metadata_id
    WHERE rgn.storage_calc_flag IS NOT NULL
),

STORAGE_FLOWS AS (
    SELECT
        noms.eff_gas_day,
        sm.eia_ng_regions,
        sm.state_name,
        sm.storage_name,
        sm.storage_calc_flag,
        sm.ticker,
        sm.loc_name,
        SUM(noms.scheduled_quantity * sm.rec_del_sign) AS net_flow
    FROM pipelines.nomination_points noms
    INNER JOIN STORAGE_META sm ON noms.metadata_id = sm.metadata_id
    WHERE noms.eff_gas_day >= '2020-01-01'
    GROUP BY
        noms.eff_gas_day,
        sm.eia_ng_regions,
        sm.state_name,
        sm.storage_name,
        sm.storage_calc_flag,
        sm.ticker,
        sm.loc_name
)

SELECT
    eff_gas_day,
    eia_ng_regions,
    state_name,
    storage_name,
    storage_calc_flag,
    ticker,
    loc_name,
    net_flow
FROM STORAGE_FLOWS
ORDER BY eff_gas_day DESC, eia_ng_regions, storage_name
