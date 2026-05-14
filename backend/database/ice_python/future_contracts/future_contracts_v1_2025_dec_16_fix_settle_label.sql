-- One-time migration: relabel stray 'Settle' rows to 'Settlement' in the
-- futures table. These were written during testing on 2026-05-13 when
-- FUTURE_CONTRACTS_FIELDS still used the SETTLE constant. The catalog has
-- since been split (SETTLE vs SETTLEMENT) so future scrape runs land
-- correctly under 'Settlement'.
--
-- Balmo, next-day-gas, and intraday-quotes use 'Settle' legitimately, but
-- those rows live in OTHER tables (balmo_v1_*, next_day_gas_*). The futures
-- table has no legitimate 'Settle' rows.
--
-- Safety: PK is (trade_date, symbol, data_type), so if any (trade_date,
-- symbol) already has a 'Settlement' row, the UPDATE will collide. The
-- INSERT-on-conflict-DO-NOTHING + DELETE pattern below handles that case
-- by preferring the existing 'Settlement' row (older / canonical).

BEGIN;

-- Preview: confirm row counts before the change.
SELECT 'before' AS phase,
       COUNT(*) FILTER (WHERE data_type = 'Settle')     AS settle_rows,
       COUNT(*) FILTER (WHERE data_type = 'Settlement') AS settlement_rows
FROM ice_python.future_contracts_v1_2025_dec_16;

-- Step 1. Promote any 'Settle' rows that have NO matching 'Settlement' row
-- yet — straight UPDATE (cheap, no conflict).
UPDATE ice_python.future_contracts_v1_2025_dec_16 AS s
SET data_type = 'Settlement'
WHERE s.data_type = 'Settle'
  AND NOT EXISTS (
    SELECT 1
    FROM ice_python.future_contracts_v1_2025_dec_16 AS x
    WHERE x.trade_date = s.trade_date
      AND x.symbol = s.symbol
      AND x.data_type = 'Settlement'
  );

-- Step 2. Drop any leftover 'Settle' rows that DID conflict (i.e. a
-- 'Settlement' row already existed for the same trade_date+symbol). We
-- keep the older 'Settlement' value, not the newer 'Settle' value.
DELETE FROM ice_python.future_contracts_v1_2025_dec_16
WHERE data_type = 'Settle';

-- Verify.
SELECT 'after' AS phase,
       COUNT(*) FILTER (WHERE data_type = 'Settle')     AS settle_rows,
       COUNT(*) FILTER (WHERE data_type = 'Settlement') AS settlement_rows
FROM ice_python.future_contracts_v1_2025_dec_16;

-- Inspect the catalog of data_types after the fix.
SELECT data_type, COUNT(*) AS rows
FROM ice_python.future_contracts_v1_2025_dec_16
GROUP BY data_type
ORDER BY data_type;

-- If everything looks right, commit. Otherwise ROLLBACK.
COMMIT;
