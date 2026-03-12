--------------------------------------------------
-- SOUTH CENTRAL PIPELINE FLOW AGGREGATIONS
-- Database: Criterion PostgreSQL
-- Source: Pipeline Flow Aggregations Catalog (South Central)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 24 (SC→SE, ESC→MW, WSC→MW, MW→SC, ROX→SC, SE→SC)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.SC2SE.109.TRCO.A,PLAG.SC2SE.091.FGT.A,PLAG.SC2SE.053.SNG.A,PLAG.SC2SE.112.GLFSTH.A,PLAG.SC2SE.047.MIDCON.A,PLAG.SC2SE.071.SESH.A,PLAG.SC2SE.106.GLFSTR.A,PLAG.SC2SE.111.GLFCRS.A,PLAG.SC2SE.122.AMAT.A,PLAG.SC2SE.033.SOPINE.A,PLAG.SE2SC.033.SOPINE.A,PLAG.ESC2MW.049.NGPLGC.A,PLAG.ESC2MW.114.TGT.A,PLAG.ESC2MW.138.MRT.A,PLAG.ESC2MW.097.TRUNK.A,PLAG.ESC2MW.154.SSC.A,PLAG.ESC2MW.073.TET24.A,PLAG.ESC2MW.059.TIGT.A,PLAG.ESC2MW.122.AMAT.A,PLAG.WSC2MW.049.NGPLAM.A,PLAG.WSC2MW.134.NNG.A,PLAG.WSC2MW.093.PEPL.A,PLAG.WSC2MW.076.ANRSW.A,PLAG.MW2SC.049.NPGLGC.A,PLAG.MW2SC.100.CGT.A,PLAG.MW2SC.076.ANRSE.A,PLAG.MW2SC.137.EGT.A,PLAG.MW2SC.054.TGP.A,PLAG.MW2SC.097.TRUNK.A,PLAG.MW2SC.073.TET30.A,PLAG.ROX2SC.042.EPNG.A,PLAG.ROX2SC.096.TWST.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- SC → SE (outflows to Southeast)
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.109.TRCO.A' THEN value END) AS sc_se_transco,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.091.FGT.A' THEN value END) AS sc_se_fgt,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.053.SNG.A' THEN value END) AS sc_se_sng,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.112.GLFSTH.A' THEN value END) AS sc_se_gulf_south,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.047.MIDCON.A' THEN value END) AS sc_se_midcon,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.071.SESH.A' THEN value END) AS sc_se_sesh,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.106.GLFSTR.A' THEN value END) AS sc_se_gulfstream,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.111.GLFCRS.A' THEN value END) AS sc_se_gulf_crossing,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.122.AMAT.A' THEN value END) AS sc_se_amid_alatenn,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.033.SOPINE.A' THEN value END) AS sc_se_southern_pines,

        -- SE → SC (reverse)
        AVG(CASE WHEN ticker = 'PLAG.SE2SC.033.SOPINE.A' THEN value END) AS se_sc_southern_pines,

        -- ESC → MW (East South Central outflows to Midwest)
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.049.NGPLGC.A' THEN value END) AS esc_mw_ngpl_gc,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.114.TGT.A' THEN value END) AS esc_mw_texas_gas,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.138.MRT.A' THEN value END) AS esc_mw_miss_river,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.097.TRUNK.A' THEN value END) AS esc_mw_trunkline,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.154.SSC.A' THEN value END) AS esc_mw_southern_star,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.073.TET24.A' THEN value END) AS esc_mw_tetco_24,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.059.TIGT.A' THEN value END) AS esc_mw_tallgrass,
        AVG(CASE WHEN ticker = 'PLAG.ESC2MW.122.AMAT.A' THEN value END) AS esc_mw_amid_alatenn,

        -- WSC → MW (West South Central outflows to Midwest)
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.049.NGPLAM.A' THEN value END) AS wsc_mw_ngpl_amarillo,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.134.NNG.A' THEN value END) AS wsc_mw_northern_natural,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.093.PEPL.A' THEN value END) AS wsc_mw_pepl,
        AVG(CASE WHEN ticker = 'PLAG.WSC2MW.076.ANRSW.A' THEN value END) AS wsc_mw_anr_sw,

        -- MW → SC (inflows from Midwest)
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.049.NPGLGC.A' THEN value END) AS mw_sc_ngpl_gc,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.100.CGT.A' THEN value END) AS mw_sc_columbia_gulf,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.076.ANRSE.A' THEN value END) AS mw_sc_anr_se,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.137.EGT.A' THEN value END) AS mw_sc_enable_gas,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.054.TGP.A' THEN value END) AS mw_sc_tgp,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.097.TRUNK.A' THEN value END) AS mw_sc_trunkline,
        AVG(CASE WHEN ticker = 'PLAG.MW2SC.073.TET30.A' THEN value END) AS mw_sc_tetco_30,

        -- ROCKIES → SC
        AVG(CASE WHEN ticker = 'PLAG.ROX2SC.042.EPNG.A' THEN value END) AS rox_sc_el_paso,
        AVG(CASE WHEN ticker = 'PLAG.ROX2SC.096.TWST.A' THEN value END) AS rox_sc_transwestern

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
