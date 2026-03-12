--------------------------------------------------
-- REGIONAL POWER / GAS BURN DEMAND (ACTUAL + FORECAST)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (History & Short Term)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 22 (11 actual + 11 forecast)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'FDSD.NGPWR.US.SUM.A,FDSD.NGPWR.NE.SUM.A,FDSD.NGPWR.MW.SUM.A,FDSD.NGPWR.ROX.SUM.A,FDSD.NGPWR.ROX.SW.A,FDSD.NGPWR.ROX.UPPER.A,FDSD.NGPWR.SC.SUM.A,FDSD.NGPWR.SE.SUM.A,FDSD.NGPWR.SE.FL.A,FDSD.NGPWR.SE.OTH.A,FDSD.NGPWR.WST.CA.A,FDSD.NGPWR.WST.PNW.A,FDSD.NGPWR.US.SUM.F,FDSD.NGPWR.NE.SUM.F,FDSD.NGPWR.MW.SUM.F,FDSD.NGPWR.ROX.SUM.F,FDSD.NGPWR.ROX.SW.F,FDSD.NGPWR.ROX.UPPER.F,FDSD.NGPWR.SC.SUM.F,FDSD.NGPWR.SE.SUM.F,FDSD.NGPWR.SE.FL.F,FDSD.NGPWR.SE.OTH.F,FDSD.NGPWR.WST.CA.F,FDSD.NGPWR.WST.PNW.F'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- US TOTAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.US.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.US.SUM.F' THEN value END)
        ) AS us_total,

        -- REGIONAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.NE.SUM.F' THEN value END)
        ) AS northeast,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.MW.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.MW.SUM.F' THEN value END)
        ) AS midwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.SUM.F' THEN value END)
        ) AS rockies,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SC.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SC.SUM.F' THEN value END)
        ) AS south_central,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.SUM.F' THEN value END)
        ) AS southeast,

        -- SUB-REGIONAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.SW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.SW.F' THEN value END)
        ) AS rockies_southwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.UPPER.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.ROX.UPPER.F' THEN value END)
        ) AS rockies_upper,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.FL.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.FL.F' THEN value END)
        ) AS southeast_florida,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.OTH.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.SE.OTH.F' THEN value END)
        ) AS southeast_other,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.WST.CA.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.WST.CA.F' THEN value END)
        ) AS west_california,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.WST.PNW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGPWR.WST.PNW.F' THEN value END)
        ) AS west_pacific_nw

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
