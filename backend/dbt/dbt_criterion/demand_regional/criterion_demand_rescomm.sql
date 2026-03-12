--------------------------------------------------
-- REGIONAL RESIDENTIAL/COMMERCIAL DEMAND (ACTUAL + FORECAST)
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
        'FDSD.NGRSCM.US.SUM.A,FDSD.NGRSCM.NE.SUM.A,FDSD.NGRSCM.MW.SUM.A,FDSD.NGRSCM.ROX.SUM.A,FDSD.NGRSCM.ROX.SW.A,FDSD.NGRSCM.ROX.UPPER.A,FDSD.NGRSCM.SC.SUM.A,FDSD.NGRSCM.SE.SUM.A,FDSD.NGRSCM.SE.FL.A,FDSD.NGRSCM.SE.OTH.A,FDSD.NGRSCM.WST.CA.A,FDSD.NGRSCM.WST.PNW.A,FDSD.NGRSCM.US.SUM.F,FDSD.NGRSCM.NE.SUM.F,FDSD.NGRSCM.MW.SUM.F,FDSD.NGRSCM.ROX.SUM.F,FDSD.NGRSCM.ROX.SW.F,FDSD.NGRSCM.ROX.UPPER.F,FDSD.NGRSCM.SC.SUM.F,FDSD.NGRSCM.SE.SUM.F,FDSD.NGRSCM.SE.FL.F,FDSD.NGRSCM.SE.OTH.F,FDSD.NGRSCM.WST.CA.F,FDSD.NGRSCM.WST.PNW.F'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- US TOTAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.US.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.US.SUM.F' THEN value END)
        ) AS us_total,

        -- REGIONAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.NE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.NE.SUM.F' THEN value END)
        ) AS northeast,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.MW.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.MW.SUM.F' THEN value END)
        ) AS midwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.SUM.F' THEN value END)
        ) AS rockies,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SC.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SC.SUM.F' THEN value END)
        ) AS south_central,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.SUM.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.SUM.F' THEN value END)
        ) AS southeast,

        -- SUB-REGIONAL
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.SW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.SW.F' THEN value END)
        ) AS rockies_southwest,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.UPPER.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.ROX.UPPER.F' THEN value END)
        ) AS rockies_upper,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.FL.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.FL.F' THEN value END)
        ) AS southeast_florida,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.OTH.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.SE.OTH.F' THEN value END)
        ) AS southeast_other,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.WST.CA.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.WST.CA.F' THEN value END)
        ) AS west_california,
        COALESCE(
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.WST.PNW.A' THEN value END),
            AVG(CASE WHEN ticker = 'FDSD.NGRSCM.WST.PNW.F' THEN value END)
        ) AS west_pacific_nw

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
