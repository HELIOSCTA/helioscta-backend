--------------------------------------------------
-- SOUTHEAST PIPELINE FLOW AGGREGATIONS
-- Database: Criterion PostgreSQL
-- Source: Pipeline Flow Aggregations Catalog (Southeast)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 13 (SC→SE, SE→SC, NE→SE, LNG)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.SC2SE.109.TRCO.A,PLAG.SC2SE.091.FGT.A,PLAG.SC2SE.053.SNG.A,PLAG.SC2SE.112.GLFSTH.A,PLAG.SC2SE.047.MIDCON.A,PLAG.SC2SE.071.SESH.A,PLAG.SC2SE.106.GLFSTR.A,PLAG.SC2SE.111.GLFCRS.A,PLAG.SC2SE.122.AMAT.A,PLAG.SC2SE.033.SOPINE.A,PLAG.SE2SC.033.SOPINE.A,PLAG.NE2SE.109.TRCO.A,PLAG.LNGEXP.SUM.ELBA.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- SOUTH CENTRAL → SOUTHEAST
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.109.TRCO.A' THEN value END) AS transco_cs90,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.091.FGT.A' THEN value END) AS florida_gas_transmission,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.053.SNG.A' THEN value END) AS southern_natural_gas,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.112.GLFSTH.A' THEN value END) AS gulf_south,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.047.MIDCON.A' THEN value END) AS midcon_express,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.071.SESH.A' THEN value END) AS se_supply_header,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.106.GLFSTR.A' THEN value END) AS gulfstream,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.111.GLFCRS.A' THEN value END) AS gulf_crossing,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.122.AMAT.A' THEN value END) AS amid_alatenn,
        AVG(CASE WHEN ticker = 'PLAG.SC2SE.033.SOPINE.A' THEN value END) AS southern_pines_eastbound,

        -- SOUTHEAST → SOUTH CENTRAL (reverse)
        AVG(CASE WHEN ticker = 'PLAG.SE2SC.033.SOPINE.A' THEN value END) AS southern_pines_westbound,

        -- NORTHEAST → SOUTHEAST
        AVG(CASE WHEN ticker = 'PLAG.NE2SE.109.TRCO.A' THEN value END) AS transco_cs160,

        -- LNG
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.ELBA.A' THEN value END) AS elba_lng

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
