---------------------------------------------------------------
-- LOAD FORECAST (MW) - 2026-03-13
-- Tomorrow's forecast diagnostics for PJM data issue:
--   "Meteologica regional load forecast doesn't equal RTO total"
--
-- Zonal columns (17): Meteologica sub-regional demand forecasts
-- METEO PJM TOTAL:      Sum of 17 Meteologica zonal columns
-- METEO:                RTO from meteologica_cleaned.meteologica_pjm_demand_forecast_hourly
-- METEO REGIONAL DIFF:  METEO PJM TOTAL - METEO  (zonal sum vs RTO mismatch)
-- PJM ISO:              RTO from pjm_cleaned.pjm_load_forecast_hourly
-- METEO - PJM ISO DIFF: METEO - PJM ISO
--
-- Source mapping (display name <- Meteologica region code <- PJM zone taxonomy):
--   AE       <- MIDATL_AE   <- 'AE/MIDATL'
--   AEP      <- WEST_AEP    <- 'AEP'
--   APS      <- WEST_AP     <- 'AP'
--   ATSI     <- WEST_ATSI   <- 'ATSI'
--   BGE      <- MIDATL_BC   <- 'BG&E/MIDATL'
--   COMED    <- WEST_CE     <- 'COMED'
--   DEOK     <- WEST_DEOK   <- 'DEOK'
--   DPL      <- MIDATL_DPL  <- 'DP&L/MIDATL'
--   DOM      <- SOUTH_DOM   <- 'DOMINION'
--   DUQ      <- WEST_DUQ    <- 'DUQUESNE'
--   JCPL     <- MIDATL_JC   <- 'JCP&L/MIDATL'
--   METED    <- MIDATL_ME   <- 'METED/MIDATL'
--   PECO     <- MIDATL_PE   <- 'PECO/MIDATL'
--   PENELEC  <- MIDATL_PN   <- 'PENELEC/MIDATL'
--   PEPCO    <- MIDATL_PEP  <- 'PEPCO/MIDATL'
--   PPL      <- MIDATL_PL   <- 'PPL/MIDATL'
--   PSEG     <- MIDATL_PS   <- 'PSE&G/MIDATL'
--
-- Filters:
--   run_date_mst  = (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE
--   forecast_date = run_date_mst + 1
--   Morning vintages only: EXTRACT(HOUR FROM forecast_execution_datetime) <= 10
--   Lowest forecast_rank from filtered set (most recent morning vintage)
---------------------------------------------------------------

WITH run_params AS (
    SELECT
        (CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE AS run_date_mst
        ,(CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE + 1 AS target_date
),

---------------------------------------------------------------
-- Meteologica zonal forecasts (17 zones)
-- Pick the best morning vintage per zone
---------------------------------------------------------------

meteo_zones_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.region
        ,m.forecast_load_mw
        ,m.forecast_execution_datetime
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

-- Pivot zones to columns
zones_pivoted AS (
    SELECT
        hr
        ,MAX(CASE WHEN region = 'MIDATL_AE'  THEN forecast_load_mw END) AS ae
        ,MAX(CASE WHEN region = 'WEST_AEP'   THEN forecast_load_mw END) AS aep
        ,MAX(CASE WHEN region = 'WEST_AP'    THEN forecast_load_mw END) AS aps
        ,MAX(CASE WHEN region = 'WEST_ATSI'  THEN forecast_load_mw END) AS atsi
        ,MAX(CASE WHEN region = 'MIDATL_BC'  THEN forecast_load_mw END) AS bge
        ,MAX(CASE WHEN region = 'WEST_CE'    THEN forecast_load_mw END) AS comed
        ,MAX(CASE WHEN region = 'WEST_DEOK'  THEN forecast_load_mw END) AS deok
        ,MAX(CASE WHEN region = 'MIDATL_DPL' THEN forecast_load_mw END) AS dpl
        ,MAX(CASE WHEN region = 'SOUTH_DOM'  THEN forecast_load_mw END) AS dom
        ,MAX(CASE WHEN region = 'WEST_DUQ'   THEN forecast_load_mw END) AS duq
        ,MAX(CASE WHEN region = 'MIDATL_JC'  THEN forecast_load_mw END) AS jcpl
        ,MAX(CASE WHEN region = 'MIDATL_ME'  THEN forecast_load_mw END) AS meted
        ,MAX(CASE WHEN region = 'MIDATL_PE'  THEN forecast_load_mw END) AS peco
        ,MAX(CASE WHEN region = 'MIDATL_PN'  THEN forecast_load_mw END) AS penelec
        ,MAX(CASE WHEN region = 'MIDATL_PEP' THEN forecast_load_mw END) AS pepco
        ,MAX(CASE WHEN region = 'MIDATL_PL'  THEN forecast_load_mw END) AS ppl
        ,MAX(CASE WHEN region = 'MIDATL_PS'  THEN forecast_load_mw END) AS pseg
    FROM meteo_zones
    GROUP BY hr
),

---------------------------------------------------------------
-- Meteologica RTO (from meteologica_cleaned.meteologica_pjm_demand_forecast_hourly)
---------------------------------------------------------------

meteo_rto_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.forecast_load_mw AS meteo_mw
        ,m.forecast_execution_datetime AS meteo_rto_exec_dt
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
    SELECT hr, meteo_mw, meteo_rto_exec_dt
    FROM meteo_rto_ranked
    WHERE forecast_rank = min_rank
),

---------------------------------------------------------------
-- PJM RTO (from pjm_cleaned.pjm_load_forecast_hourly)
---------------------------------------------------------------

pjm_ranked AS (
    SELECT
        p.hour_ending - 1 AS hr
        ,p.forecast_load_mw AS pjm_mw
        ,p.forecast_execution_datetime AS pjm_exec_dt
        ,p.forecast_rank
        ,MIN(p.forecast_rank) OVER () AS min_rank
    FROM pjm_cleaned.pjm_load_forecast_hourly p
    CROSS JOIN run_params rp
    WHERE
        p.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM p.forecast_execution_datetime) <= 10
        AND p.forecast_date::DATE = rp.target_date
        AND p.region = 'RTO'
),

pjm AS (
    SELECT hr, pjm_mw, pjm_exec_dt
    FROM pjm_ranked
    WHERE forecast_rank = min_rank
),

---------------------------------------------------------------
-- Metadata: forecast execution datetimes used
---------------------------------------------------------------

meteo_zones_meta AS (
    SELECT
        MIN(forecast_execution_datetime) AS meteo_zones_exec_min
        ,MAX(forecast_execution_datetime) AS meteo_zones_exec_max
        ,COUNT(DISTINCT forecast_execution_datetime) AS meteo_zones_exec_count
    FROM meteo_zones_ranked
    WHERE forecast_rank = min_rank
),

meteo_rto_meta AS (
    SELECT DISTINCT meteo_rto_exec_dt
    FROM meteo_rto
    LIMIT 1
),

pjm_meta AS (
    SELECT DISTINCT pjm_exec_dt
    FROM pjm
    LIMIT 1
),

---------------------------------------------------------------
-- Combine: hourly rows
---------------------------------------------------------------

hourly AS (
    SELECT
        z.hr
        ,z.ae, z.aep, z.aps, z.atsi, z.bge, z.comed, z.deok, z.dpl
        ,z.dom, z.duq, z.jcpl, z.meted, z.peco, z.penelec, z.pepco, z.ppl, z.pseg
        ,COALESCE(z.ae,0) + COALESCE(z.aep,0) + COALESCE(z.aps,0) + COALESCE(z.atsi,0)
            + COALESCE(z.bge,0) + COALESCE(z.comed,0) + COALESCE(z.deok,0) + COALESCE(z.dpl,0)
            + COALESCE(z.dom,0) + COALESCE(z.duq,0) + COALESCE(z.jcpl,0) + COALESCE(z.meted,0)
            + COALESCE(z.peco,0) + COALESCE(z.penelec,0) + COALESCE(z.pepco,0) + COALESCE(z.ppl,0)
            + COALESCE(z.pseg,0) AS meteo_pjm_total
        ,mr.meteo_mw
        ,p.pjm_mw
    FROM zones_pivoted z
    LEFT JOIN meteo_rto mr ON z.hr = mr.hr
    LEFT JOIN pjm p ON z.hr = p.hr
)

---------------------------------------------------------------
-- Output 1: Metadata
---------------------------------------------------------------

SELECT
    'LOAD FORECAST (MW) - ' || rp.target_date::TEXT  AS "Title"
    ,rp.run_date_mst                                  AS "Run Date (MST)"
    ,rp.target_date                                   AS "Forecast Date"
    ,pm.pjm_exec_dt                                   AS "PJM ISO Forecast Execution (EPT)"
    ,rm.meteo_rto_exec_dt                              AS "Meteologica RTO Forecast Execution (EPT)"
    ,zm.meteo_zones_exec_min                           AS "Meteologica Zones Exec Min (EPT)"
    ,zm.meteo_zones_exec_max                           AS "Meteologica Zones Exec Max (EPT)"
    ,zm.meteo_zones_exec_count                         AS "Meteologica Zones Distinct Vintages"
FROM run_params rp
CROSS JOIN pjm_meta pm
CROSS JOIN meteo_rto_meta rm
CROSS JOIN meteo_zones_meta zm
;

---------------------------------------------------------------
-- Output 2: 24 hourly rows + DAILY GWh summary row
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

zones_pivoted AS (
    SELECT
        hr
        ,MAX(CASE WHEN region = 'MIDATL_AE'  THEN forecast_load_mw END) AS ae
        ,MAX(CASE WHEN region = 'WEST_AEP'   THEN forecast_load_mw END) AS aep
        ,MAX(CASE WHEN region = 'WEST_AP'    THEN forecast_load_mw END) AS aps
        ,MAX(CASE WHEN region = 'WEST_ATSI'  THEN forecast_load_mw END) AS atsi
        ,MAX(CASE WHEN region = 'MIDATL_BC'  THEN forecast_load_mw END) AS bge
        ,MAX(CASE WHEN region = 'WEST_CE'    THEN forecast_load_mw END) AS comed
        ,MAX(CASE WHEN region = 'WEST_DEOK'  THEN forecast_load_mw END) AS deok
        ,MAX(CASE WHEN region = 'MIDATL_DPL' THEN forecast_load_mw END) AS dpl
        ,MAX(CASE WHEN region = 'SOUTH_DOM'  THEN forecast_load_mw END) AS dom
        ,MAX(CASE WHEN region = 'WEST_DUQ'   THEN forecast_load_mw END) AS duq
        ,MAX(CASE WHEN region = 'MIDATL_JC'  THEN forecast_load_mw END) AS jcpl
        ,MAX(CASE WHEN region = 'MIDATL_ME'  THEN forecast_load_mw END) AS meted
        ,MAX(CASE WHEN region = 'MIDATL_PE'  THEN forecast_load_mw END) AS peco
        ,MAX(CASE WHEN region = 'MIDATL_PN'  THEN forecast_load_mw END) AS penelec
        ,MAX(CASE WHEN region = 'MIDATL_PEP' THEN forecast_load_mw END) AS pepco
        ,MAX(CASE WHEN region = 'MIDATL_PL'  THEN forecast_load_mw END) AS ppl
        ,MAX(CASE WHEN region = 'MIDATL_PS'  THEN forecast_load_mw END) AS pseg
    FROM meteo_zones
    GROUP BY hr
),

meteo_rto_ranked AS (
    SELECT
        m.hour_ending - 1 AS hr
        ,m.forecast_load_mw AS meteo_mw
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
    SELECT hr, meteo_mw
    FROM meteo_rto_ranked
    WHERE forecast_rank = min_rank
),

pjm_ranked AS (
    SELECT
        p.hour_ending - 1 AS hr
        ,p.forecast_load_mw AS pjm_mw
        ,p.forecast_rank
        ,MIN(p.forecast_rank) OVER () AS min_rank
    FROM pjm_cleaned.pjm_load_forecast_hourly p
    CROSS JOIN run_params rp
    WHERE
        p.forecast_execution_date::DATE = rp.run_date_mst
        AND EXTRACT(HOUR FROM p.forecast_execution_datetime) <= 10
        AND p.forecast_date::DATE = rp.target_date
        AND p.region = 'RTO'
),

pjm AS (
    SELECT hr, pjm_mw
    FROM pjm_ranked
    WHERE forecast_rank = min_rank
),

hourly AS (
    SELECT
        z.hr
        ,z.ae, z.aep, z.aps, z.atsi, z.bge, z.comed, z.deok, z.dpl
        ,z.dom, z.duq, z.jcpl, z.meted, z.peco, z.penelec, z.pepco, z.ppl, z.pseg
        ,COALESCE(z.ae,0) + COALESCE(z.aep,0) + COALESCE(z.aps,0) + COALESCE(z.atsi,0)
            + COALESCE(z.bge,0) + COALESCE(z.comed,0) + COALESCE(z.deok,0) + COALESCE(z.dpl,0)
            + COALESCE(z.dom,0) + COALESCE(z.duq,0) + COALESCE(z.jcpl,0) + COALESCE(z.meted,0)
            + COALESCE(z.peco,0) + COALESCE(z.penelec,0) + COALESCE(z.pepco,0) + COALESCE(z.ppl,0)
            + COALESCE(z.pseg,0) AS meteo_pjm_total
        ,mr.meteo_mw
        ,p.pjm_mw
    FROM zones_pivoted z
    LEFT JOIN meteo_rto mr ON z.hr = mr.hr
    LEFT JOIN pjm p ON z.hr = p.hr
)

SELECT "Hr", "Time",
       "AE", "AEP", "APS", "ATSI", "BGE", "COMED", "DEOK", "DPL",
       "DOM", "DUQ", "JCPL", "METED", "PECO", "PENELEC", "PEPCO", "PPL", "PSEG",
       "METEO PJM TOTAL", "METEO", "METEO REGIONAL DIFF", "PJM ISO", "METEO - PJM ISO DIFF"
FROM (

    -- Hourly rows (Hr 0-23)
    SELECT
        z.hr                                AS "Hr"
        ,LPAD(z.hr::TEXT, 2, '0') || ':00'  AS "Time"
        ,ROUND(z.ae)::NUMERIC               AS "AE"
        ,ROUND(z.aep)::NUMERIC              AS "AEP"
        ,ROUND(z.aps)::NUMERIC              AS "APS"
        ,ROUND(z.atsi)::NUMERIC             AS "ATSI"
        ,ROUND(z.bge)::NUMERIC              AS "BGE"
        ,ROUND(z.comed)::NUMERIC            AS "COMED"
        ,ROUND(z.deok)::NUMERIC             AS "DEOK"
        ,ROUND(z.dpl)::NUMERIC              AS "DPL"
        ,ROUND(z.dom)::NUMERIC              AS "DOM"
        ,ROUND(z.duq)::NUMERIC              AS "DUQ"
        ,ROUND(z.jcpl)::NUMERIC             AS "JCPL"
        ,ROUND(z.meted)::NUMERIC            AS "METED"
        ,ROUND(z.peco)::NUMERIC             AS "PECO"
        ,ROUND(z.penelec)::NUMERIC          AS "PENELEC"
        ,ROUND(z.pepco)::NUMERIC            AS "PEPCO"
        ,ROUND(z.ppl)::NUMERIC              AS "PPL"
        ,ROUND(z.pseg)::NUMERIC             AS "PSEG"
        ,ROUND(z.meteo_pjm_total)::NUMERIC  AS "METEO PJM TOTAL"
        ,ROUND(z.meteo_mw)::NUMERIC         AS "METEO"
        ,ROUND(z.meteo_pjm_total - z.meteo_mw)::NUMERIC  AS "METEO REGIONAL DIFF"
        ,ROUND(z.pjm_mw)::NUMERIC           AS "PJM ISO"
        ,ROUND(z.meteo_mw - z.pjm_mw)::NUMERIC  AS "METEO - PJM ISO DIFF"
    FROM hourly z

    UNION ALL

    -- DAILY GWh summary row
    SELECT
        NULL                                                          AS "Hr"
        ,'DAILY GWh'                                                   AS "Time"
        ,ROUND(SUM(ae)::NUMERIC / 1000, 1)                            AS "AE"
        ,ROUND(SUM(aep)::NUMERIC / 1000, 1)                           AS "AEP"
        ,ROUND(SUM(aps)::NUMERIC / 1000, 1)                           AS "APS"
        ,ROUND(SUM(atsi)::NUMERIC / 1000, 1)                          AS "ATSI"
        ,ROUND(SUM(bge)::NUMERIC / 1000, 1)                           AS "BGE"
        ,ROUND(SUM(comed)::NUMERIC / 1000, 1)                         AS "COMED"
        ,ROUND(SUM(deok)::NUMERIC / 1000, 1)                          AS "DEOK"
        ,ROUND(SUM(dpl)::NUMERIC / 1000, 1)                           AS "DPL"
        ,ROUND(SUM(dom)::NUMERIC / 1000, 1)                           AS "DOM"
        ,ROUND(SUM(duq)::NUMERIC / 1000, 1)                           AS "DUQ"
        ,ROUND(SUM(jcpl)::NUMERIC / 1000, 1)                          AS "JCPL"
        ,ROUND(SUM(meted)::NUMERIC / 1000, 1)                         AS "METED"
        ,ROUND(SUM(peco)::NUMERIC / 1000, 1)                          AS "PECO"
        ,ROUND(SUM(penelec)::NUMERIC / 1000, 1)                       AS "PENELEC"
        ,ROUND(SUM(pepco)::NUMERIC / 1000, 1)                         AS "PEPCO"
        ,ROUND(SUM(ppl)::NUMERIC / 1000, 1)                           AS "PPL"
        ,ROUND(SUM(pseg)::NUMERIC / 1000, 1)                          AS "PSEG"
        ,ROUND(SUM(meteo_pjm_total)::NUMERIC / 1000, 1)               AS "METEO PJM TOTAL"
        ,ROUND(SUM(meteo_mw)::NUMERIC / 1000, 1)                      AS "METEO"
        ,ROUND(SUM(meteo_pjm_total - meteo_mw)::NUMERIC / 1000, 1)    AS "METEO REGIONAL DIFF"
        ,ROUND(SUM(pjm_mw)::NUMERIC / 1000, 1)                        AS "PJM ISO"
        ,ROUND(SUM(meteo_mw - pjm_mw)::NUMERIC / 1000, 1)             AS "METEO - PJM ISO DIFF"
    FROM hourly

) sub
ORDER BY "Hr" NULLS LAST
;
