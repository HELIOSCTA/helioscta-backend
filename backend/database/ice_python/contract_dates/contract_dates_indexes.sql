-- Indexes + table tuning for ice_python.contract_dates.
--
-- Schema reminder (matches ice_contract_dates_utils.ensure_contract_dates_table):
--   trade_date DATE NOT NULL
--   symbol     VARCHAR NOT NULL
--   strip      VARCHAR
--   start_date DATE
--   end_date   DATE
--   created_at TIMESTAMP DEFAULT now()
--   updated_at TIMESTAMP DEFAULT now()
--   PRIMARY KEY (trade_date, symbol)
--
-- Expected access patterns (no frontend wired yet, so this is forward-
-- looking but covers the standard snapshot-table query surface):
--   1. Latest snapshot for one symbol
--        WHERE symbol = $1 ORDER BY trade_date DESC LIMIT 1
--   2. Latest snapshot for a symbol list
--        SELECT DISTINCT ON (symbol) ... WHERE symbol = ANY($1)
--        ORDER BY symbol, trade_date DESC
--   3. History of one symbol
--        WHERE symbol = $1 ORDER BY trade_date
--
-- The PK leads on trade_date, so all three fall back to seq scan + sort.
-- The covering index below gives index-only scans for all three.
--
-- NOTE: CREATE INDEX CONCURRENTLY cannot run inside a transaction block,
-- so run this file with `psql -f` (not `BEGIN; \i ...; COMMIT;`).
-- All statements are idempotent — re-running is safe.


-- =========================================================================
-- Session settings — give the index build room to finish cleanly
-- =========================================================================
-- See backend/database/ice_python/future_contracts/.../future_contracts_v1_2025_dec_16_indexes.sql
-- for the same rationale.
SET maintenance_work_mem = '1GB';
SET statement_timeout = 0;


-- =========================================================================
-- 1. Symbol-keyed covering index
-- =========================================================================
-- Leading column matches the universal predicate (symbol = $1 or = ANY($1)).
-- Trailing trade_date DESC matches the "latest" sort.
-- INCLUDE pulls the value columns into the index leaves so the planner can
-- return them without a heap fetch — index-only scans for patterns 1, 2, 3.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_contract_dates_sym_date
ON ice_python.contract_dates (symbol, trade_date DESC)
INCLUDE (strip, start_date, end_date);


-- =========================================================================
-- 2. Stats target — improves planner cardinality estimates
-- =========================================================================
-- symbol cardinality is high (a few thousand once the full futures +
-- short-term registry is in). Default stats target (100) under-resolves
-- the distribution and the planner mis-estimates how many rows match a
-- specific symbol. 1000 is the standard bump for high-cardinality
-- dimensional columns.
ALTER TABLE ice_python.contract_dates
    ALTER COLUMN symbol SET STATISTICS 1000;


-- =========================================================================
-- 3. Autovacuum tuning — daily upserts make this a hot write table
-- =========================================================================
-- Default thresholds (20% / 10% of table size) let dead-tuple counts grow
-- enough between vacuums to slow index-only scans (visibility map gets
-- stale). Lower thresholds so autovacuum kicks in earlier on this hot
-- table without affecting global cluster defaults.
ALTER TABLE ice_python.contract_dates SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);


-- =========================================================================
-- 4. Refresh planner stats so the new index gets picked up immediately
-- =========================================================================
ANALYZE ice_python.contract_dates;


-- =========================================================================
-- Verification queries (run interactively after the index finishes building)
-- =========================================================================
-- \d+ ice_python.contract_dates
--
-- -- Pattern 1: latest snapshot for one symbol.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT symbol, trade_date, strip, start_date, end_date
-- FROM ice_python.contract_dates
-- WHERE symbol = 'PMI K26-IUS'
-- ORDER BY trade_date DESC
-- LIMIT 1;
-- -- Expected: Index Only Scan on idx_contract_dates_sym_date.
--
-- -- Pattern 2: latest snapshot per symbol for a list.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT DISTINCT ON (symbol)
--        symbol, trade_date, strip, start_date, end_date
-- FROM ice_python.contract_dates
-- WHERE symbol = ANY(ARRAY['PMI K26-IUS', 'HNG K26-IUS', 'TMT K26-IUS'])
-- ORDER BY symbol, trade_date DESC;
-- -- Expected: Index Only Scan on idx_contract_dates_sym_date.
--
-- -- Pattern 3: full history for one symbol.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT trade_date, strip, start_date, end_date
-- FROM ice_python.contract_dates
-- WHERE symbol = 'PMI K26-IUS'
-- ORDER BY trade_date;
-- -- Expected: Index Only Scan on idx_contract_dates_sym_date.
