--------------------------------------------------
-- CRITERION METADATA LOOKUP
-- Database: Criterion PostgreSQL (dda.criterionrsch.com)
-- Description: Explore available tickers by commodity, region, or keyword
--------------------------------------------------

SELECT
    ticker,
    metadata_desc,
    cmdty_class,
    sub_cmdty_desc,
    asset_name,
    country_name,
    region_name,
    state_name,
    province_name,
    status,
    series_desc,
    series_id,
    table_name,
    series_type,
    sub_region

FROM data_series.financial_metadata

-- FILTER EXAMPLES (uncomment one):
-- WHERE ticker LIKE 'FDSD.NGPR%'           -- All production tickers
-- WHERE ticker LIKE 'FDSD.NGPWR%'          -- All power demand tickers
-- WHERE ticker LIKE 'FDSD.NGRSCM%'         -- All rescomm demand tickers
-- WHERE ticker LIKE 'FDSD.NGIND%'          -- All industrial demand tickers
-- WHERE ticker LIKE 'PLAG.LNGEXP%'         -- All LNG export tickers
-- WHERE ticker LIKE 'PLAG.LNGIMP%'         -- All LNG import tickers
-- WHERE ticker LIKE 'PLAG.CN2US%'          -- Canadian imports
-- WHERE ticker LIKE 'PLAG.US2MX%'          -- Mexican exports
-- WHERE ticker LIKE 'PLAG.SC2SE%'          -- South Central to Southeast pipeline flows
-- WHERE ticker LIKE 'LTSD%'                -- Long-term forecasts
-- WHERE cmdty_class = 'Natural Gas'
-- WHERE region_name = 'South Central'

ORDER BY ticker, region_name, state_name
