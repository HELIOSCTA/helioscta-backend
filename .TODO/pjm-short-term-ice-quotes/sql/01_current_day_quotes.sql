-- =============================================================================
-- 01_current_day_quotes.sql
-- Current-day PJM ICE intraday quotes, pivoted to wide format.
-- =============================================================================
--
-- Assumptions:
--   - ice_python.intraday_quotes stores data in long format:
--       PK = (trade_date, snapshot_at, data_type, symbol)
--       data_type IN ('Open','High','Low','Bid','Ask','Last',
--                      'Volume','VWAP','Settle','Recent Settlement')
--   - ice_python.contract_dates:
--       PK = (trade_date, symbol)
--       columns: strip, start_date, end_date
--   - PJM power symbols: PDP D0-IUS, PDP D1-IUS, PDA D1-IUS, PJL D1-IUS,
--     PDP W0-IUS, PDP W1-IUS .. W4-IUS, PMI %-IUS
--   - Gas symbols: XGF D1-IPG, HHD B0-IUS, HNG %-IUS,
--     XZR D1-IPG, YFF D1-IPG  (included for completeness)
-- =============================================================================

WITH pjm_symbols AS (
    -- Enumerate the PJM short-term symbols shown in the image.
    -- Includes both power and gas products.
    SELECT symbol, sort_order, product_label
    FROM (VALUES
        ('PDP D0-IUS',  1, 'Bal Day'),
        ('PDP D1-IUS',  2, 'RT Next Day'),
        ('PDA D1-IUS',  3, 'DA Next Day'),
        ('PJL D1-IUS',  4, 'Off-Peak Next Day'),
        ('PDP W0-IUS',  5, 'Bal Week'),
        ('PDP W1-IUS',  6, 'W1'),
        ('PDP W2-IUS',  7, 'W2'),
        ('PDP W3-IUS',  8, 'W3'),
        ('PDP W4-IUS',  9, 'W4')
    ) AS t(symbol, sort_order, product_label)
),

-- Also pick up monthly power (PMI) and gas symbols present today.
-- These have variable strip codes, so match by prefix.
dynamic_symbols AS (
    SELECT DISTINCT iq.symbol
    FROM ice_python.intraday_quotes iq
    WHERE iq.trade_date = CURRENT_DATE
      AND iq.symbol NOT IN (SELECT symbol FROM pjm_symbols)
      AND (
          iq.symbol LIKE 'PMI %-IUS'     -- PJM monthly power
          OR iq.symbol LIKE 'XGF %-IPG'  -- Hub Cash gas
          OR iq.symbol LIKE 'HHD %-IUS'  -- Hub Balmo gas
          OR iq.symbol LIKE 'HNG %-IUS'  -- Hub Prompt gas
          OR iq.symbol LIKE 'XZR %-IPG'  -- M3 Cash gas
          OR iq.symbol LIKE 'YFF %-IPG'  -- Z5 Cash gas
      )
),

all_symbols AS (
    SELECT symbol, sort_order, product_label
    FROM pjm_symbols

    UNION ALL

    -- Assign sort orders for dynamic symbols by product prefix.
    SELECT
        ds.symbol,
        CASE
            WHEN ds.symbol LIKE 'PMI%'  THEN 10
            WHEN ds.symbol LIKE 'XGF%'  THEN 20
            WHEN ds.symbol LIKE 'HHD%'  THEN 21
            WHEN ds.symbol LIKE 'HNG%'  THEN 22
            WHEN ds.symbol LIKE 'XZR%'  THEN 30
            WHEN ds.symbol LIKE 'YFF%'  THEN 40
            ELSE 99
        END AS sort_order,
        CASE
            WHEN ds.symbol LIKE 'PMI%'  THEN 'Monthly'
            WHEN ds.symbol LIKE 'XGF%'  THEN 'Hub Cash'
            WHEN ds.symbol LIKE 'HHD%'  THEN 'Hub Balmo'
            WHEN ds.symbol LIKE 'HNG%'  THEN 'Hub Prompt'
            WHEN ds.symbol LIKE 'XZR%'  THEN 'M3 Cash'
            WHEN ds.symbol LIKE 'YFF%'  THEN 'Z5 Cash'
            ELSE ds.symbol
        END AS product_label
    FROM dynamic_symbols ds
),

-- Rank snapshots per symbol; pick the latest one per symbol.
ranked AS (
    SELECT
        iq.trade_date,
        iq.snapshot_at,
        iq.symbol,
        iq.data_type,
        iq.value,
        DENSE_RANK() OVER (
            PARTITION BY iq.symbol
            ORDER BY iq.snapshot_at DESC
        ) AS snapshot_rank
    FROM ice_python.intraday_quotes iq
    WHERE iq.trade_date = CURRENT_DATE
      AND iq.symbol IN (SELECT symbol FROM all_symbols)
),

latest_quotes AS (
    SELECT trade_date, snapshot_at, symbol, data_type, value
    FROM ranked
    WHERE snapshot_rank = 1
),

-- Pivot long-format quotes into one row per symbol.
pivoted AS (
    SELECT
        lq.symbol,
        lq.snapshot_at                                              AS quote_time,
        lq.trade_date                                               AS quote_date,
        MAX(CASE WHEN lq.data_type = 'Open'              THEN lq.value END) AS "open",
        MAX(CASE WHEN lq.data_type = 'High'              THEN lq.value END) AS "high",
        MAX(CASE WHEN lq.data_type = 'Low'               THEN lq.value END) AS "low",
        MAX(CASE WHEN lq.data_type = 'Bid'               THEN lq.value END) AS bid,
        MAX(CASE WHEN lq.data_type = 'Ask'               THEN lq.value END) AS ask,
        MAX(CASE WHEN lq.data_type = 'Last'              THEN lq.value END) AS "last",
        MAX(CASE WHEN lq.data_type = 'Volume'            THEN lq.value END) AS volume,
        MAX(CASE WHEN lq.data_type = 'VWAP'             THEN lq.value END) AS vwap,
        MAX(CASE WHEN lq.data_type = 'Settle'            THEN lq.value END) AS settle,
        MAX(CASE WHEN lq.data_type = 'Recent Settlement' THEN lq.value END) AS recent_settlement
    FROM latest_quotes lq
    GROUP BY lq.symbol, lq.snapshot_at, lq.trade_date
)

SELECT
    p.symbol,
    s.product_label,
    cd.strip,
    cd.start_date,
    cd.end_date,
    p.quote_time,
    p.quote_date,
    p."open",
    p."high",
    p."low",
    p.bid,
    p.ask,
    p."last",
    p.volume,
    p.vwap,
    p.settle,
    p.recent_settlement
FROM pivoted p
JOIN all_symbols s      ON s.symbol = p.symbol
LEFT JOIN ice_python.contract_dates cd
    ON cd.trade_date = p.quote_date
   AND cd.symbol     = p.symbol
ORDER BY
    s.sort_order,
    p.symbol;
