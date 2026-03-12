--------------------------------------------------
-- LONG-TERM STORAGE FORECASTS
-- Database: Criterion PostgreSQL
-- Source: Natural Gas S&D Catalog (Long Term)
-- Units: Bcf (source units)
-- Grain: Daily forecast horizon
-- Tickers: 18 (PLST storage forecasts by region + early/seasonal)
--------------------------------------------------

WITH DATA_SERIES AS (
    SELECT
        date,
        ticker,
        AVG(value) AS value
    FROM data_series.fin_json_to_excel_tickers(
        'PLST.STGFCST.L48.F,PLST.STGFCST.EL48.F,PLST.STGFCST.EAST.F,PLST.STGFCST.EEAST.F,PLST.STGFCST.MIDW.F,PLST.STGFCST.EMIDW.F,PLST.STGFCST.SC.F,PLST.STGFCST.ESC.F,PLST.STGFCST.MTN.F,PLST.STGFCST.EMTN.F,PLST.STGFCST.PAC.F,PLST.STGFCST.EPAC.F,PLST.STGFCST.SALT.F,PLST.STGFCST.ESALT.F,PLST.STGFCST.NSLT.F,PLST.STGFCST.ENSLT.F,PLST.STGFCST.L48SMR.F,PLST.STGFCST.L48WTR.F'
    )
    GROUP BY date, ticker
),

FINAL AS (
    SELECT
        date,

        -- L48 TOTAL
        AVG(CASE WHEN ticker = 'PLST.STGFCST.L48.F' THEN value END) AS l48_storage,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EL48.F' THEN value END) AS l48_storage_early,

        -- REGIONAL
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EAST.F' THEN value END) AS east,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EEAST.F' THEN value END) AS east_early,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.MIDW.F' THEN value END) AS midwest,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EMIDW.F' THEN value END) AS midwest_early,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.SC.F' THEN value END) AS south_central,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.ESC.F' THEN value END) AS south_central_early,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.MTN.F' THEN value END) AS mountain,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EMTN.F' THEN value END) AS mountain_early,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.PAC.F' THEN value END) AS pacific,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.EPAC.F' THEN value END) AS pacific_early,

        -- SALT vs NON-SALT
        AVG(CASE WHEN ticker = 'PLST.STGFCST.SALT.F' THEN value END) AS salt,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.ESALT.F' THEN value END) AS salt_early,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.NSLT.F' THEN value END) AS non_salt,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.ENSLT.F' THEN value END) AS non_salt_early,

        -- END-OF-SEASON TARGETS
        AVG(CASE WHEN ticker = 'PLST.STGFCST.L48SMR.F' THEN value END) AS summer_eos,
        AVG(CASE WHEN ticker = 'PLST.STGFCST.L48WTR.F' THEN value END) AS winter_eos

    FROM DATA_SERIES
    GROUP BY date
)

SELECT * FROM FINAL
ORDER BY date DESC
