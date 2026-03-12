--------------------------------------------------
-- REGIONAL INDUSTRIAL DEMAND (ACTUAL + FORECAST)
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
        'FDSD.NGIND.US.SUM.A,FDSD.NGIND.NE.SUM.A,FDSD.NGIND.MW.SUM.A,FDSD.NGIND.ROX.SUM.A,FDSD.NGIND.ROX.SW.A,FDSD.NGIND.ROX.UPPER.A,FDSD.NGIND.SC.SUM.A,FDSD.NGIND.SE.SUM.A,FDSD.NGIND.SE.FL.A,FDSD.NGIND.SE.OTH.A,FDSD.NGIND.WST.CA.A,FDSD.NGIND.WST.PNW.A,FDSD.NGIND.US.SUM.F,FDSD.NGIND.NE.SUM.F,FDSD.NGIND.MW.SUM.F,FDSD.NGIND.ROX.SUM.F,FDSD.NGIND.ROX.SW.F,FDSD.NGIND.ROX.UPPER.F,FDSD.NGIND.SC.SUM.F,FDSD.NGIND.SE.SUM.F,FDSD.NGIND.SE.FL.F,FDSD.NGIND.SE.OTH.F,FDSD.NGIND.WST.PNW.F,FDSD.NGIND.WST.CA.F'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- US TOTAL (actual preferred, forecast fallback)
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.US.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.US.SUM.F' THEN value END)
        ) AS us_total,

        -- REGIONAL ACTUALS (with forecast fallback)
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.NE.SUM.F' THEN value END)
        ) AS northeast,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.MW.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.MW.SUM.F' THEN value END)
        ) AS midwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.SUM.F' THEN value END)
        ) AS rockies,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SC.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SC.SUM.F' THEN value END)
        ) AS south_central,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.SUM.F' THEN value END)
        ) AS southeast,

        -- SUB-REGIONAL ACTUALS (with forecast fallback)
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.SW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.SW.F' THEN value END)
        ) AS rockies_southwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.UPPER.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.ROX.UPPER.F' THEN value END)
        ) AS rockies_upper,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.FL.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.FL.F' THEN value END)
        ) AS southeast_florida,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.OTH.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.SE.OTH.F' THEN value END)
        ) AS southeast_other,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.WST.CA.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.WST.CA.F' THEN value END)
        ) AS west_california,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGIND.WST.PNW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGIND.WST.PNW.F' THEN value END)
        ) AS west_pacific_nw

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
