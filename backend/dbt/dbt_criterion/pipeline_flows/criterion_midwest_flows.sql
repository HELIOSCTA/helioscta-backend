--------------------------------------------------
-- MIDWEST PIPELINE FLOW AGGREGATIONS
-- Database: Criterion PostgreSQL
-- Source: Pipeline Flow Aggregations Catalog (Midwest)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 33 (NE→MW, ESC→MW, WSC→MW, MW→SC, ROX→MW, MW→NE)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.NE2MW.076.ANRSE.A,PLAG.NE2MW.099.TCO.A,PLAG.NE2MW.101.CROSSR.A,PLAG.NE2MW.065.ETNG.A,PLAG.NE2MW.375.NEX.A,PLAG.NE2MW.093.PEPL.A,PLAG.NE2MW.058.REX.A,PLAG.NE2MW.337.ROV.A,PLAG.NE2MW.073.TET24.A,PLAG.NE2MW.073.TET30.A,PLAG.NE2MW.054.TGP.A,PLAG.NE2MW.114.TGT.A,PLAG.MW2NE.093.PEPL.A,PLAG.ESC2MW.049.NGPLGC.A,PLAG.ESC2MW.114.TGT.A,PLAG.ESC2MW.138.MRT.A,PLAG.ESC2MW.097.TRUNK.A,PLAG.ESC2MW.154.SSC.A,PLAG.ESC2MW.073.TET24.A,PLAG.ESC2MW.059.TIGT.A,PLAG.ESC2MW.122.AMAT.A,PLAG.WSC2MW.049.NGPLAM.A,PLAG.WSC2MW.134.NNG.A,PLAG.WSC2MW.093.PEPL.A,PLAG.WSC2MW.076.ANRSW.A,PLAG.MW2SC.049.NPGLGC.A,PLAG.MW2SC.100.CGT.A,PLAG.MW2SC.076.ANRSE.A,PLAG.MW2SC.137.EGT.A,PLAG.MW2SC.054.TGP.A,PLAG.MW2SC.097.TRUNK.A,PLAG.MW2SC.073.TET30.A,PLAG.ROX2MW.132.ALIAN.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- NORTHEAST → MIDWEST (inflows from Appalachia)
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.076.ANRSE.A' THEN value END) AS ne_anr_se_mainline,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.099.TCO.A' THEN value END) AS ne_columbia_gas,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.101.CROSSR.A' THEN value END) AS ne_crossroads,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.065.ETNG.A' THEN value END) AS ne_etng,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.375.NEX.A' THEN value END) AS ne_nexus,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.093.PEPL.A' THEN value END) AS ne_pepl,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.058.REX.A' THEN value END) AS ne_rex,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.337.ROV.A' THEN value END) AS ne_rover,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET24.A' THEN value END) AS ne_tetco_24,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET30.A' THEN value END) AS ne_tetco_30,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.054.TGP.A' THEN value END) AS ne_tgp,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.114.TGT.A' THEN value END) AS ne_texas_gas,

        -- MIDWEST → NORTHEAST (reverse)
        AVG(CASE WHEN ticker = 'PLAG.MW2NE.093.PEPL.A' THEN value END) AS mw_to_ne_pepl,

        -- EAST SOUTH CENTRAL → MIDWEST
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.049.NGPLGC.A' THEN value END) AS esc_ngpl_gulf_coast,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.114.TGT.A' THEN value END) AS esc_texas_gas,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.138.MRT.A' THEN value END) AS esc_miss_river_trans,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.097.TRUNK.A' THEN value END) AS esc_trunkline,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.154.SSC.A' THEN value END) AS esc_southern_star,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.073.TET24.A' THEN value END) AS esc_tetco_24,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.059.TIGT.A' THEN value END) AS esc_tallgrass,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.122.AMAT.A' THEN value END) AS esc_amid_alatenn,

        -- WEST SOUTH CENTRAL → MIDWEST
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.049.NGPLAM.A' THEN value END) AS wsc_ngpl_amarillo,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.134.NNG.A' THEN value END) AS wsc_northern_natural,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.093.PEPL.A' THEN value END) AS wsc_pepl,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.076.ANRSW.A' THEN value END) AS wsc_anr_sw_mainline,

        -- MIDWEST → SOUTH CENTRAL
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.049.NPGLGC.A' THEN value END) AS mw_ngpl_gulf_coast,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.100.CGT.A' THEN value END) AS mw_columbia_gulf,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.076.ANRSE.A' THEN value END) AS mw_anr_se_mainline,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.137.EGT.A' THEN value END) AS mw_enable_gas,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.054.TGP.A' THEN value END) AS mw_tgp,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.097.TRUNK.A' THEN value END) AS mw_trunkline,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.073.TET30.A' THEN value END) AS mw_tetco_30,

        -- ROCKIES → MIDWEST
        AVG(CASE WHEN ticker = 'PLAG.ROX2MW.132.ALIAN.A' THEN value END) AS rox_alliance

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
