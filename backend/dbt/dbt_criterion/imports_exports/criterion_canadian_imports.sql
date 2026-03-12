--------------------------------------------------
-- CANADIAN IMPORTS & US EXPORTS TO CANADA (BY ENTRY/EXIT POINT)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (History & Short Term + CAD)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 30 (regional aggregates + individual border points)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.CN2US.SUM.NET.A,PLAG.CN2US.SUM.CN2MW.A,PLAG.CN2US.SUM.CN2NE.A,PLAG.US2CN.SUM.MW2CN.A,PLAG.US2CN.SUM.NE2CN.A,PLAG.CN2US.107.Sumas.A,PLAG.CN2US.107.SIPI.A,PLAG.CN2US.079.Kings.A,PLAG.CN2US.132.Bordr.A,PLAG.CN2US.080.Emers.A,PLAG.CN2US.083.PortM.A,PLAG.CN2US.083.Saska.A,PLAG.CN2US.127.Emers.A,PLAG.CN2US.081.Wadd.A,PLAG.CN2US.067.Bruns.A,PLAG.CN2US.027.Pitts.A,PLAG.CN2US.086.Napier.A,PLAG.CN2US.086.Cornw.A,PLAG.CN2US.086.Philip.A,PLAG.US2CN.076.Coru.A,PLAG.US2CN.007.Union.A,PLAG.US2CN.080.SSM.A,PLAG.US2CN.080.STCL.A,PLAG.US2CN.375.STCL.A,PLAG.US2CN.093.Union.A,PLAG.US2CN.074.MichC.A,PLAG.US2CN.118.STCL.A,PLAG.US2CN.149.ManIsl.A,PLAG.US2CN.139.Chipp.A,PLAG.US2CN.067.Bville.A,PLAG.US2CN.054.Niagra.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- AGGREGATES
        AVG(CASE WHEN ticker = 'PLAG.CN2US.SUM.NET.A' THEN value END) AS net_canadian_imports,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.SUM.CN2MW.A' THEN value END) AS midwest_imports,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.SUM.CN2NE.A' THEN value END) AS northeast_imports,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.SUM.MW2CN.A' THEN value END) AS midwest_exports,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.SUM.NE2CN.A' THEN value END) AS northeast_exports,

        -- NORTHWEST BORDER POINTS (imports)
        AVG(CASE WHEN ticker = 'PLAG.CN2US.107.Sumas.A' THEN value END) AS sumas,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.107.SIPI.A' THEN value END) AS sipi,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.079.Kings.A' THEN value END) AS kingsgate,

        -- MIDWEST BORDER POINTS (imports)
        AVG(CASE WHEN ticker = 'PLAG.CN2US.132.Bordr.A' THEN value END) AS border_usa,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.080.Emers.A' THEN value END) AS glgt_emerson,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.083.PortM.A' THEN value END) AS nbpl_port_of_morgan,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.083.Saska.A' THEN value END) AS nbpl_saskana,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.127.Emers.A' THEN value END) AS viking_emerson,

        -- NORTHEAST BORDER POINTS (imports)
        AVG(CASE WHEN ticker = 'PLAG.CN2US.081.Wadd.A' THEN value END) AS iroquois_waddington,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.067.Bruns.A' THEN value END) AS maritimes_brunswick,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.027.Pitts.A' THEN value END) AS pngts_pittsburg,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.Napier.A' THEN value END) AS transcanada_napierville,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.Cornw.A' THEN value END) AS transcanada_cornwall,
        AVG(CASE WHEN ticker = 'PLAG.CN2US.086.Philip.A' THEN value END) AS transcanada_philipsburg,

        -- US EXPORTS TO CANADA
        AVG(CASE WHEN ticker = 'PLAG.US2CN.076.Coru.A' THEN value END) AS anr_corunna,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.007.Union.A' THEN value END) AS bluewater_union,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.080.SSM.A' THEN value END) AS glgt_sault_ste_marie,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.080.STCL.A' THEN value END) AS glgt_st_clair,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.375.STCL.A' THEN value END) AS nexus_st_clair,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.093.Union.A' THEN value END) AS pepl_union,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.074.MichC.A' THEN value END) AS union_michcon,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.118.STCL.A' THEN value END) AS vector_st_clair,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.149.ManIsl.A' THEN value END) AS wbi_many_islands,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.139.Chipp.A' THEN value END) AS empire_chippawa,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.067.Bville.A' THEN value END) AS maritimes_baileyville,
        AVG(CASE WHEN ticker = 'PLAG.US2CN.054.Niagra.A' THEN value END) AS tgp_niagra

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
