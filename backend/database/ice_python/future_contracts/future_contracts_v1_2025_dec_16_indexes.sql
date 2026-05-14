-- Indexes + table tuning for ice_python.future_contracts_v1_2025_dec_16.
--
-- Target query surface (8 endpoints in helioscta/spark-spread-viz):
--   spark-spreads, spark-analytics, contract-evolution,
--   historical-settlements, gas-calendar, gas-outright,
--   power-calendar, power-outright, debug-prices
--
-- Most endpoints share the shape:
--   WHERE data_type = '<field>'
--     AND symbol = $1   -- or = ANY($1::text[])
--     [AND trade_date BETWEEN ... ]
--   ORDER BY trade_date [ASC|DESC]
--
-- dbt marts that pivot all data_types for one symbol (e.g. pmi_k26_ius_wide)
-- have a different shape:
--   WHERE symbol = $1
--   GROUP BY trade_date, symbol, ...
--   -- 9× MAX(value) FILTER (WHERE data_type = '<lit>') in the SELECT
-- No data_type predicate in WHERE, so index #1 (data_type-leading) is
-- unusable — index #3 below handles this pivot pattern.
--
-- The existing PK (trade_date, symbol, data_type) leads on trade_date, so
-- both patterns fall back to a heap scan + filter + sort without these
-- indexes. The covering indexes below give index-only scans for every
-- endpoint and pivot mart above.
--
-- NOTE: CREATE INDEX CONCURRENTLY cannot run inside a transaction block,
-- so run this file with `psql -f` (not `BEGIN; \i ...; COMMIT;`).
-- All statements are idempotent — re-running is safe.


-- =========================================================================
-- Session settings — give the index builds room to finish cleanly
-- =========================================================================
-- maintenance_work_mem: a larger value lets the b-tree builder keep more of
-- the sort in memory instead of spilling to disk. 1GB is comfortable for a
-- ~3M-row index. Reduce if your Azure tier rejects it (some Burstable
-- tiers cap lower — Postgres will silently clamp on managed services).
SET maintenance_work_mem = '1GB';

-- statement_timeout: disable for this session so a long index build can't
-- be killed by a default per-connection cap.
SET statement_timeout = 0;


-- =========================================================================
-- 1. Generic field-keyed covering index
-- =========================================================================
-- Leading column matches the universal predicate (data_type = '<field>').
-- Subsequent columns match the symbol filter and the trade_date sort.
-- INCLUDE (value) makes this a covering index — no heap fetch needed for
-- the `SELECT symbol, trade_date, value` payload every endpoint returns.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fut_contracts_type_sym_date
ON ice_python.future_contracts_v1_2025_dec_16 (data_type, symbol, trade_date DESC)
INCLUDE (value);


-- =========================================================================
-- 2. Partial index for the dominant Settlement-only path (optional)
-- =========================================================================
-- 8 of 8 frontend endpoints filter data_type = 'Settlement'. A partial
-- index on that predicate is ~1/N the size of index #1 (where N = number
-- of data_type values) and the planner will prefer it whenever the
-- literal 'Settlement' appears in the WHERE clause.
--
-- Skip this if you migrate the preset to write 'Settle' and update the
-- frontend to match — index #1 alone is sufficient.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fut_contracts_settle_sym_date
ON ice_python.future_contracts_v1_2025_dec_16 (symbol, trade_date DESC)
INCLUDE (value)
WHERE data_type = 'Settlement';


-- =========================================================================
-- 3. Symbol-leading covering index for wide-pivot mart queries
-- =========================================================================
-- dbt mart pmi_k26_ius_wide (and future pivot marts that aggregate ALL
-- data_types for one symbol) filters only on symbol — data_type lives
-- inside FILTER (WHERE data_type = '<lit>') in the SELECT, not in WHERE.
-- That makes index #1 unusable and the planner falls back to a full
-- parallel seq scan: 3.26M rows / 38,773 buffers / ~41s on the
-- 2025-dec-16 snapshot to keep 2,085 rows for a single symbol.
--
-- Symbol-leading covering index with data_type + value + updated_at in
-- the INCLUDE payload gives an index-only scan for the pivot pattern.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fut_contracts_sym_date
ON ice_python.future_contracts_v1_2025_dec_16 (symbol, trade_date)
INCLUDE (data_type, value, updated_at);


-- =========================================================================
-- 4. Stats target — improves planner cardinality estimates
-- =========================================================================
-- symbol has ~200 distinct values; data_type has ~33 once full preset is
-- in. Default stats target (100) under-resolves these distributions, so
-- the planner mis-estimates row counts for range scans. 1000 is the
-- standard bump for high-cardinality dimensional columns.
ALTER TABLE ice_python.future_contracts_v1_2025_dec_16
    ALTER COLUMN symbol SET STATISTICS 1000;
ALTER TABLE ice_python.future_contracts_v1_2025_dec_16
    ALTER COLUMN data_type SET STATISTICS 1000;


-- =========================================================================
-- 5. Autovacuum tuning — table is write-heavy (upsert per scrape run)
-- =========================================================================
-- Default thresholds (20% / 10% of table size) let dead-tuple counts grow
-- enough between vacuums to slow index-only scans (visibility map gets
-- stale). Lower thresholds so autovacuum kicks in earlier on this hot
-- table without affecting global cluster defaults.
ALTER TABLE ice_python.future_contracts_v1_2025_dec_16 SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02
);


-- =========================================================================
-- 6. Refresh planner stats so the new indexes get picked up immediately
-- =========================================================================
ANALYZE ice_python.future_contracts_v1_2025_dec_16;


-- =========================================================================
-- Verification queries (run interactively after the indexes finish building)
-- =========================================================================
-- \d+ ice_python.future_contracts_v1_2025_dec_16
--
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT DISTINCT ON (symbol) symbol, value, trade_date
-- FROM ice_python.future_contracts_v1_2025_dec_16
-- WHERE data_type = 'Settlement'
--   AND symbol = ANY(ARRAY['PMI K26-IUS', 'HNG K26-IUS', 'TMT K26-IUS'])
-- ORDER BY symbol, trade_date DESC;
-- -- Expected: Index Only Scan on idx_fut_contracts_settle_sym_date.
--
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT symbol, value, trade_date
-- FROM ice_python.future_contracts_v1_2025_dec_16
-- WHERE data_type = 'VWAP Close'
--   AND symbol = ANY(ARRAY['PMI K26-IUS'])
--   AND trade_date >= CURRENT_DATE - INTERVAL '90 days';
-- -- Expected: Index Only Scan on idx_fut_contracts_type_sym_date.
--
-- -- Pivot-mart pattern (pmi_k26_ius_wide): symbol-only WHERE, FILTER per data_type.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT trade_date, symbol,
--        MAX(value) FILTER (WHERE data_type = 'Settlement') AS settlement,
--        MAX(value) FILTER (WHERE data_type = 'Volume')     AS volume
-- FROM ice_python.future_contracts_v1_2025_dec_16
-- WHERE symbol = 'PMI K26-IUS'
-- GROUP BY trade_date, symbol;
-- -- Expected: Index Only Scan on idx_fut_contracts_sym_date.
