

SELECT
    f.trade_date,
    f.symbol,
    cd.strip,
    cd.start_date,
    cd.end_date,
    MAX(f.value) FILTER (WHERE f.data_type = 'Settlement')    AS settlement,
    MAX(f.value) FILTER (WHERE f.data_type = 'Open')          AS open,
    MAX(f.value) FILTER (WHERE f.data_type = 'High')          AS high,
    MAX(f.value) FILTER (WHERE f.data_type = 'Low')           AS low,
    MAX(f.value) FILTER (WHERE f.data_type = 'Close')         AS close,
    MAX(f.value) FILTER (WHERE f.data_type = 'Last')          AS last,
    MAX(f.value) FILTER (WHERE f.data_type = 'Volume')        AS volume,
    MAX(f.value) FILTER (WHERE f.data_type = 'Open Interest') AS open_interest,
    MAX(f.value) FILTER (WHERE f.data_type = 'VWAP Close')    AS vwap_close,
    MAX(f.updated_at)                                         AS futures_updated_at,
    cd.updated_at                                             AS contract_dates_updated_at
FROM "helioscta"."ice_python"."future_contracts_v1_2025_dec_16" AS f
LEFT JOIN "helioscta"."ice_python"."contract_dates" AS cd
    ON cd.symbol     = f.symbol
   AND cd.trade_date = f.trade_date
-- All PMI futures (PJM Western Hub RT Peak, 1 MW).
-- Symbol grammar: `PMI <strip><yy>-IUS` (e.g. PMI K26-IUS = May 2026).
-- Pattern match is sufficient — ICE only emits PMI symbols in this shape.
WHERE f.symbol LIKE 'PMI %-IUS'
GROUP BY
    f.trade_date,
    f.symbol,
    cd.strip,
    cd.start_date,
    cd.end_date,
    cd.updated_at