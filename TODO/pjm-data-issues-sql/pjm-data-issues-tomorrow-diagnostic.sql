---------------------------------------------------------------
-- Meteologica Zonal Sum vs RTO Diagnostic
-- Answers: does the 17-zone sum (PJM TOTAL) match Meteologica RTO?
--
-- Reports:
--   max_hourly_abs_delta_mw  - largest absolute hourly mismatch
--   daily_gwh_delta          - total daily delta in GWh (zonal sum - RTO)
--   avg_hourly_delta_mw      - average hourly delta
---------------------------------------------------------------

WITH run_params AS (
    SELECT
        (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE AS run_date_mst
        ,(CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE + 1 AS target_date
),

meteo_zones_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.region
        ,m.forecast_load_mw
        ,m.forecast_rank
        ,MIN(m.forecast_rank) OVER (PARTITION BY m.region) AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_hourly m
    CROSS JOIN run_params rp
    WHERE
        m.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM m.forecast_execution_datetime) <= 10
        AND m.forecast_date::DATE = rp.target_date
        AND m.region IN (
            'MIDATL_AE', 'WEST_AEP', 'WEST_AP', 'WEST_ATSI', 'MIDATL_BC',
            'WEST_CE', 'WEST_DEOK', 'MIDATL_DPL', 'SOUTH_DOM', 'WEST_DUQ',
            'MIDATL_JC', 'MIDATL_ME', 'MIDATL_PE', 'MIDATL_PN',
            'MIDATL_PEP', 'MIDATL_PL', 'MIDATL_PS'
        )
),

meteo_zones AS (
    SELECT hr, region, forecast_load_mw
    FROM meteo_zones_ranked
    WHERE forecast_rank = min_rank
),

zonal_sum AS (
    SELECT hr, SUM(forecast_load_mw) AS zonal_total
    FROM meteo_zones
    GROUP BY hr
),

meteo_rto_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.forecast_load_mw AS rto_mw
        ,m.forecast_rank
        ,MIN(m.forecast_rank) OVER () AS min_rank
    FROM meteologica_cleaned.meteologica_pjm_demand_forecast_hourly m
    CROSS JOIN run_params rp
    WHERE
        m.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM m.forecast_execution_datetime) <= 10
        AND m.forecast_date::DATE = rp.target_date
        AND m.region = 'RTO'
),

meteo_rto AS (
    SELECT hr, rto_mw
    FROM meteo_rto_ranked
    WHERE forecast_rank = min_rank
),

comparison AS (
    SELECT
        z.hr
        ,ROUND(z.zonal_total)::INT AS zonal_sum_mw
        ,ROUND(r.rto_mw)::INT AS rto_mw
        ,ROUND(z.zonal_total - r.rto_mw)::INT AS delta_mw
    FROM zonal_sum z
    JOIN meteo_rto r ON z.hr = r.hr
)

SELECT
    'Meteologica Zonal Sum vs RTO' AS diagnostic
    ,MAX(ABS(delta_mw)) AS max_hourly_abs_delta_mw
    ,ROUND(SUM(delta_mw)::NUMERIC / 1000, 1) AS daily_gwh_delta
    ,ROUND(AVG(delta_mw)::NUMERIC) AS avg_hourly_delta_mw
FROM comparison
;
