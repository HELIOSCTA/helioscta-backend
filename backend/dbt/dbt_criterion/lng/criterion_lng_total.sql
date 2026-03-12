--------------------------------------------------
-- LNG AGGREGATE TOTALS (EXPORTS + IMPORTS)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog
-- Units: Bcf/d (source MMcf/d / 1000)
-- Grain: Daily, from 2020-01-01
-- Tickers: 12 (US totals + by-facility exports + by-terminal imports)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.LNGEXP.SUM.US.A,PLAG.LNGIMP.SUM.US.A,PLAG.LNGEXP.SUM.SPL.A,PLAG.LNGEXP.SUM.CALCP.A,PLAG.LNGEXP.SUM.CCL.A,PLAG.LNGEXP.SUM.CAMER.A,PLAG.LNGEXP.SUM.FLNG.A,PLAG.LNGEXP.SUM.COVE.A,PLAG.LNGEXP.SUM.ELBA.A,PLAG.LNGEXP.SUM.PLQ.A,PLAG.LNGEXP.SUM.GP.A,PLAG.LNGEXP.IMPLIED.CCL.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- TOTALS (Bcf/d)
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.US.A' THEN value / 1000 END) AS total_exports,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.US.A' THEN value / 1000 END) AS total_imports,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.US.A' THEN value / 1000 END)
            - COALESCE(AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.US.A' THEN value / 1000 END), 0)
            AS net_exports,

        -- EXPORT FACILITIES (Bcf/d)
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.SPL.A' THEN value / 1000 END) AS sabine_pass,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.CALCP.A' THEN value / 1000 END) AS calcasieu_pass,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.IMPLIED.CCL.A' THEN value / 1000 END) AS corpus_christi,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.CAMER.A' THEN value / 1000 END) AS cameron,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.FLNG.A' THEN value / 1000 END) AS freeport,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.COVE.A' THEN value / 1000 END) AS cove_point,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.ELBA.A' THEN value / 1000 END) AS elba_island,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.PLQ.A' THEN value / 1000 END) AS plaquemines,
        AVG(CASE WHEN ticker = 'PLAG.LNGEXP.SUM.GP.A' THEN value / 1000 END) AS golden_pass

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
