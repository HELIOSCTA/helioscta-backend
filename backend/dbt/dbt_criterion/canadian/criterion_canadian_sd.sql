--------------------------------------------------
-- CANADIAN SUPPLY & DEMAND
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (CAD)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 40 (commercial, residential, industrial, oil sands, production)
-- Provinces: AB, BC, MAN, NS, ONT, QUE, SK + Canada total
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'FDSD.NGCOM.AB.SUM.A,FDSD.NGCOM.BC.SUM.A,FDSD.NGCOM.MAN.SUM.A,FDSD.NGCOM.NS.SUM.A,FDSD.NGCOM.ONT.SUM.A,FDSD.NGCOM.QUE.SUM.A,FDSD.NGCOM.SK.SUM.A,FDSD.NGCOM.CAD.SUM.A,FDSD.NGCOM.AB.SUM.F,FDSD.NGCOM.BC.SUM.F,FDSD.NGCOM.MAN.SUM.F,FDSD.NGCOM.NS.SUM.F,FDSD.NGCOM.ONT.SUM.F,FDSD.NGCOM.QUE.SUM.F,FDSD.NGCOM.SK.SUM.F,FDSD.NGCOM.CAD.SUM.F,FDSD.NGRES.AB.SUM.A,FDSD.NGRES.BC.SUM.A,FDSD.NGRES.MAN.SUM.A,FDSD.NGRES.NS.SUM.A,FDSD.NGRES.ONT.SUM.A,FDSD.NGRES.QUE.SUM.A,FDSD.NGRES.SK.SUM.A,FDSD.NGRES.CAD.SUM.A,FDSD.NGRES.AB.SUM.F,FDSD.NGRES.BC.SUM.F,FDSD.NGRES.MAN.SUM.F,FDSD.NGRES.NS.SUM.F,FDSD.NGRES.ONT.SUM.F,FDSD.NGRES.QUE.SUM.F,FDSD.NGRES.SK.SUM.F,FDSD.NGRES.CAD.SUM.F,FDSD.NGIND.CAD.SUM.A,FDSD.NGIND.CAD.SUM.F,FDSD.NGOSD.AB.SUM.A,FDSD.NGOSD.CAD.SUM.A,FDSD.NGOSD.AB.SUM.F,FDSD.NGOSD.CAD.SUM.F,FDSD.NGPR.CAD.ABBC.A,FDSD.NGPR.CAD.SK.A,FDSD.NGPR.CAD.OTH.A,FDSD.NGPR.CAD.SUM.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- COMMERCIAL DEMAND (actual preferred, forecast fallback)
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.CAD.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.CAD.SUM.F' THEN value END)
        ) AS commercial_canada,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.AB.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.AB.SUM.F' THEN value END)
        ) AS commercial_alberta,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.BC.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.BC.SUM.F' THEN value END)
        ) AS commercial_bc,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.ONT.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.ONT.SUM.F' THEN value END)
        ) AS commercial_ontario,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.QUE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.QUE.SUM.F' THEN value END)
        ) AS commercial_quebec,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.SK.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.SK.SUM.F' THEN value END)
        ) AS commercial_sask,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.MAN.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.MAN.SUM.F' THEN value END)
        ) AS commercial_manitoba,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.NS.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGCOM.NS.SUM.F' THEN value END)
        ) AS commercial_nova_scotia,

        -- RESIDENTIAL DEMAND
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.CAD.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.CAD.SUM.F' THEN value END)
        ) AS residential_canada,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.AB.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.AB.SUM.F' THEN value END)
        ) AS residential_alberta,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.BC.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.BC.SUM.F' THEN value END)
        ) AS residential_bc,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.ONT.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.ONT.SUM.F' THEN value END)
        ) AS residential_ontario,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.QUE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.QUE.SUM.F' THEN value END)
        ) AS residential_quebec,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.SK.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.SK.SUM.F' THEN value END)
        ) AS residential_sask,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.MAN.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.MAN.SUM.F' THEN value END)
        ) AS residential_manitoba,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRES.NS.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRES.NS.SUM.F' THEN value END)
        ) AS residential_nova_scotia,

        -- INDUSTRIAL + OIL SANDS
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.CAD.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.CAD.SUM.F' THEN value END)
        ) AS industrial_canada,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGOSD.CAD.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGOSD.CAD.SUM.F' THEN value END)
        ) AS oil_sands_canada,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGOSD.AB.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGOSD.AB.SUM.F' THEN value END)
        ) AS oil_sands_alberta,

        -- PRODUCTION
        AVG(CASE WHEN ticker = 'FDSD.NGPR.CAD.SUM.A' THEN value END) AS production_canada,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.CAD.ABBC.A' THEN value END) AS production_ab_bc,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.CAD.SK.A' THEN value END) AS production_sask,
        AVG(CASE WHEN ticker = 'FDSD.NGPR.CAD.OTH.A' THEN value END) AS production_other

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
