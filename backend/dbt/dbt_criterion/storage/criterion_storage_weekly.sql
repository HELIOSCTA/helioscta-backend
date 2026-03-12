--------------------------------------------------
-- STORAGE WEEKLY FLOWS (BY FACILITY, EIA WEEK)
-- Database: Criterion PostgreSQL
-- Source: pipelines schema (nomination_points + metadata + regions)
-- Units: MMcf (weekly sum of scheduled quantities)
-- Grain: Weekly by EIA storage week (Friday)
-- Note: Only includes records flagged as storage transfers (storage_calc_flag = 'T')
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
    WHERE rgn.storage_calc_flag = 'T'
),

DAILY_FLOWS AS (
    SELECT
        noms.eff_gas_day,
        sm.eia_ng_regions,
        sm.state_name,
        sm.storage_name,
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
        sm.ticker,
        sm.loc_name
),

WEEKLY_FLOWS AS (
    SELECT
        -- EIA storage week ends on Friday
        (eff_gas_day + (
            CASE
                WHEN EXTRACT(DOW FROM eff_gas_day)::INTEGER >= 5
                THEN 12 - EXTRACT(DOW FROM eff_gas_day)::INTEGER
                ELSE 5 - EXTRACT(DOW FROM eff_gas_day)::INTEGER
            END
        ) * INTERVAL '1 day')::DATE AS eia_storage_week,
        eia_ng_regions,
        state_name,
        storage_name,
        ticker,
        loc_name,
        SUM(net_flow) AS weekly_net_flow
    FROM DAILY_FLOWS
    GROUP BY
        (eff_gas_day + (
            CASE
                WHEN EXTRACT(DOW FROM eff_gas_day)::INTEGER >= 5
                THEN 12 - EXTRACT(DOW FROM eff_gas_day)::INTEGER
                ELSE 5 - EXTRACT(DOW FROM eff_gas_day)::INTEGER
            END
        ) * INTERVAL '1 day')::DATE,
        eia_ng_regions,
        state_name,
        storage_name,
        ticker,
        loc_name
)

SELECT * FROM WEEKLY_FLOWS
ORDER BY eia_storage_week DESC, eia_ng_regions, storage_name
