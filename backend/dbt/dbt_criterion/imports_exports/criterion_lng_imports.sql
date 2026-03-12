--------------------------------------------------
-- US LNG IMPORTS (BY TERMINAL)
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (History & Short Term)
-- Units: MMcf/d (source units)
-- Grain: Daily, from 2020-01-01
-- Tickers: 5 (US total + 4 individual terminals)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLAG.LNGIMP.SUM.US.A,PLAG.LNGIMP.SUM.NEGWY.A,PLAG.LNGIMP.SUM.EVER.A,PLAG.LNGIMP.SUM.ELBA.A,PLAG.LNGIMP.SUM.COVE.A'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.US.A' THEN value END) AS us_total,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.EVER.A' THEN value END) AS everett,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.COVE.A' THEN value END) AS cove_point,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.ELBA.A' THEN value END) AS elba_island,
        AVG(CASE WHEN ticker = 'PLAG.LNGIMP.SUM.NEGWY.A' THEN value END) AS ne_gateway

    FROM DATA_SERIES
    WHERE date >= '2020-01-01'
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
