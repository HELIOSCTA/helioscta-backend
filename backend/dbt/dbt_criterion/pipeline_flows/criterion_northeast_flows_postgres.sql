--------------------------------------------------
-- NORTHEAST PIPELINE FLOW AGGREGATIONS
-- Database: Criterion PostgreSQL
-- Source: Pipeline Flow Aggregations Catalog (Northeast)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 27 (NE→MW, MW→NE, Canadian cross-border, LNG imp/exp, NE→SE)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.NE2MW.076.ANRSE.A,PLAG.NE2MW.099.TCO.A,PLAG.NE2MW.101.CROSSR.A,PLAG.NE2MW.065.ETNG.A,PLAG.NE2MW.375.NEX.A,PLAG.NE2MW.093.PEPL.A,PLAG.NE2MW.058.REX.A,PLAG.NE2MW.337.ROV.A,PLAG.NE2MW.073.TET24.A,PLAG.NE2MW.073.TET30.A,PLAG.NE2MW.054.TGP.A,PLAG.NE2MW.114.TGT.A,PLAG.MW2NE.093.PEPL.A,PLAG.CN2US.081.WADD.A,PLAG.US2CN.139.CHIPP.A,PLAG.US2CN.067.BVILLE.A,PLAG.US2CN.054.NIAGRA.A,PLAG.CN2US.067.BRUNS.A,PLAG.CN2US.027.PITTS.A,PLAG.CN2US.086.NAPIER.A,PLAG.CN2US.086.CORNW.A,PLAG.CN2US.086.PHILIP.A,PLAG.LNGIMP.SUM.EVER.A,PLAG.LNGIMP.SUM.COVE.A,PLAG.LNGIMP.SUM.NEGWY.A,PLAG.LNGEXP.SUM.COVE.A,PLAG.NE2SE.109.TRCO.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- NORTHEAST → MIDWEST
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.076.ANRSE.A' THEN value END) AS anr_se_mainline,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.099.TCO.A' THEN value END) AS columbia_gas,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.101.CROSSR.A' THEN value END) AS crossroads,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.065.ETNG.A' THEN value END) AS etng,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.375.NEX.A' THEN value END) AS nexus,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.093.PEPL.A' THEN value END) AS pepl_ne_to_mw,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.058.REX.A' THEN value END) AS rex,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.337.ROV.A' THEN value END) AS rover,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET24.A' THEN value END) AS tetco_24,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.073.TET30.A' THEN value END) AS tetco_30,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.054.TGP.A' THEN value END) AS tgp,
        AVG(CASE WHEN ticker = 'PLAG.NE2MW.114.TGT.A' THEN value END) AS texas_gas,

        -- MIDWEST → NORTHEAST (reverse)
        AVG(CASE WHEN ticker = 'PLAG.MW2NE.093.PEPL.A' THEN value END) AS pepl_mw_to_ne,

        -- NE CANADIAN CROSS-BORDER
        AVG(CASE WHEN ticker = 'PLAG.CN2US.081.WADD.A' THEN value END) AS iroquois_waddington,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.067.BRUNS.A' THEN value END) AS maritimes_brunswick,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.027.PITTS.A' THEN value END) AS pngts_pittsburg,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.NAPIER.A' THEN value END) AS transcanada_napierville,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.CORNW.A' THEN value END) AS transcanada_cornwall,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.PHILIP.A' THEN value END) AS transcanada_philipsburg,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.139.CHIPP.A' THEN value END) AS empire_chippawa,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.067.BVILLE.A' THEN value END) AS maritimes_baileyville,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.054.NIAGRA.A' THEN value END) AS tgp_niagra,

        -- LNG
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.EVER.A' THEN value END) AS lng_import_everett,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.COVE.A' THEN value END) AS lng_import_cove_point,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.NEGWY.A' THEN value END) AS lng_import_ne_gateway,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.COVE.A' THEN value END) AS lng_export_cove_point,

        -- NORTHEAST → SOUTHEAST
        AVG(CASE WHEN ticker = 'PLAG.NE2SE.109.TRCO.A' THEN value END) AS transco_cs160

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
