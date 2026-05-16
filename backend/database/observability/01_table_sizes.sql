-- Biggest tables in the database by total size (table + indexes + toast).
-- Run as a starting point when investigating slow upserts: tables that are
-- huge on disk are usually also the ones whose writes / index maintenance
-- dominate runtime.
--
-- Columns:
--   total_size  - table + all indexes + toast
--   table_size  - heap only (the row data)
--   index_size  - sum of all indexes on the table
--   toast_size  - out-of-line storage for large values
--   row_estimate - planner's row estimate (cheap, may be stale; run ANALYZE
--                  on a specific table for a fresh number)

SELECT
    n.nspname                                              AS schema,
    c.relname                                              AS table,
    pg_size_pretty(pg_total_relation_size(c.oid))          AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))                AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))                 AS index_size,
    pg_size_pretty(
        COALESCE(pg_total_relation_size(c.reltoastrelid), 0)
    )                                                      AS toast_size,
    c.reltuples::bigint                                    AS row_estimate,
    pg_total_relation_size(c.oid)                          AS total_bytes
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'                       -- ordinary tables only
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 50;
