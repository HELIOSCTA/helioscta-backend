-- =============================================================================
-- Script 1: Current Day ICE Quotes
-- =============================================================================
-- Replicates the left side of the PJM short-term ICE quotes spreadsheet.
-- Pulls the most recent intraday snapshot for today and pivots data_types
-- into columns: Open, High, Low, Bid, Ask, Last, Volume, VWAP, Settle,
-- Recent Settlement. Joined with contract_dates for strip metadata.
--
-- Sources:
--   ice_python.intraday_quotes  (PK: trade_date, snapshot_at, data_type, symbol)
--   ice_python.contract_dates   (PK: trade_date, symbol)
-- =============================================================================

WITH latest_snapshot AS (
    -- Get the most recent snapshot_at for each symbol on today's trade date
    SELECT
        symbol,
        MAX(snapshot_at) AS max_snapshot_at
    FROM ice_python.intraday_quotes
    WHERE trade_date = CURRENT_DATE
    GROUP BY symbol
),

latest_quotes AS (
    -- Pull all data_type values for each symbol at the latest snapshot
    SELECT
        iq.symbol,
        iq.data_type,
        iq.value
    FROM ice_python.intraday_quotes iq
    INNER JOIN latest_snapshot ls
        ON iq.symbol = ls.symbol
        AND iq.snapshot_at = ls.max_snapshot_at
    WHERE iq.trade_date = CURRENT_DATE
),

pivoted AS (
    -- Pivot long-format rows into one row per symbol with columns for each field
    SELECT
        symbol,
        MAX(CASE WHEN data_type = 'Open' THEN value END)              AS "Open",
        MAX(CASE WHEN data_type = 'High' THEN value END)              AS "High",
        MAX(CASE WHEN data_type = 'Low' THEN value END)               AS "Low",
        MAX(CASE WHEN data_type = 'Bid' THEN value END)               AS "Bid",
        MAX(CASE WHEN data_type = 'Ask' THEN value END)               AS "Ask",
        MAX(CASE WHEN data_type = 'Last' THEN value END)              AS "Last",
        MAX(CASE WHEN data_type = 'Volume' THEN value END)            AS "Volume",
        MAX(CASE WHEN data_type = 'VWAP' THEN value END)              AS "VWAP",
        MAX(CASE WHEN data_type = 'Settle' THEN value END)            AS "Settle",
        MAX(CASE WHEN data_type = 'Recent Settlement' THEN value END) AS "Recent Settlement"
    FROM latest_quotes
    GROUP BY symbol
)

SELECT
    p.symbol,
    cd.strip,
    cd.start_date,
    cd.end_date,
    p."Open",
    p."High",
    p."Low",
    p."Bid",
    p."Ask",
    p."Last",
    p."Volume",
    p."VWAP",
    p."Settle",
    p."Recent Settlement"
FROM pivoted p
LEFT JOIN ice_python.contract_dates cd
    ON cd.symbol = p.symbol
    AND cd.trade_date = CURRENT_DATE
WHERE p.symbol IN (
    -- PJM Power Daily
    'PDP D0-IUS',   -- Bal Day
    'PDP D1-IUS',   -- RT Next Day
    'PDA D1-IUS',   -- DA Next Day
    'PJL D1-IUS',   -- Off-Peak Next Day
    -- PJM Power Weekly
    'PDP W0-IUS',   -- Bal Week
    'PDP W1-IUS',   -- Week 1
    'PDP W2-IUS',   -- Week 2
    'PDP W3-IUS',   -- Week 3
    'PDP W4-IUS',   -- Week 4
    -- PJM Power Monthly (PMI front month - adjust symbol as needed)
    'PMI H26-IUS',  -- Mar 2026 (H = March, 26 = 2026)
    -- Gas: Henry Hub
    'XGF D1-IPG',   -- Hub Cash (Next Day)
    'HHD B0-IUS',   -- Hub Balmo
    'HNG H26-IUS',  -- Hub Prompt (Mar 2026 futures)
    -- Gas: Tetco M3
    'XZR D1-IPG',   -- M3 Cash (Next Day)
    -- Gas: Transco Zone 5 South
    'YFF D1-IPG'    -- Z5 Cash (Next Day)
)
ORDER BY
    CASE
        -- PJM Power Daily
        WHEN p.symbol = 'PDP D0-IUS' THEN 1
        WHEN p.symbol = 'PDP D1-IUS' THEN 2
        WHEN p.symbol = 'PDA D1-IUS' THEN 3
        WHEN p.symbol = 'PJL D1-IUS' THEN 4
        -- PJM Power Weekly
        WHEN p.symbol = 'PDP W0-IUS' THEN 10
        WHEN p.symbol = 'PDP W1-IUS' THEN 11
        WHEN p.symbol = 'PDP W2-IUS' THEN 12
        WHEN p.symbol = 'PDP W3-IUS' THEN 13
        WHEN p.symbol = 'PDP W4-IUS' THEN 14
        -- PJM Power Monthly
        WHEN p.symbol LIKE 'PMI%' THEN 20
        -- Gas: Henry Hub
        WHEN p.symbol = 'XGF D1-IPG' THEN 30
        WHEN p.symbol = 'HHD B0-IUS' THEN 31
        WHEN p.symbol LIKE 'HNG%' THEN 32
        -- Gas: Tetco M3
        WHEN p.symbol = 'XZR D1-IPG' THEN 40
        -- Gas: Transco Z5 South
        WHEN p.symbol = 'YFF D1-IPG' THEN 50
        ELSE 99
    END;
