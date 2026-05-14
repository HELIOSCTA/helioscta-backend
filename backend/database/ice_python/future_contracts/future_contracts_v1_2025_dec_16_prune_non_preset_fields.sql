-- One-time cleanup: drop rows whose data_type isn't in FUTURE_CONTRACTS_FIELDS.
--
-- Why this exists: a few test runs on 2026-05-13 pulled the full 33-field
-- ICE catalog before the preset was narrowed to the 9 fields we actually
-- want. The non-preset rows are useless to the frontend and inflate the
-- table.
--
-- Run order:
--   1. future_contracts_v1_2025_dec_16_fix_settle_label.sql  (migrate Settle → Settlement)
--   2. THIS FILE                                              (drop the rest)
--   3. future_contracts_v1_2025_dec_16_indexes.sql            (build indexes)
--
-- The keep-list below must stay in sync with FUTURE_CONTRACTS_FIELDS in
-- backend/scrapes/ice_python/fields/presets.py. If you change that preset,
-- re-run this file. (The catalog itself can hold more field names — only
-- the preset is the source of truth for what the futures table stores.)

BEGIN;

-- ---------------------------------------------------------------------------
-- Define the keep-list as a CTE so the planner inlines it and the comment
-- block above explicitly cites the Python source of truth.
-- ---------------------------------------------------------------------------
WITH preset_fields(data_type) AS (
    VALUES
        ('Settlement'),
        ('Open'),
        ('High'),
        ('Low'),
        ('Close'),
        ('Last'),
        ('Volume'),
        ('Open Interest'),
        ('VWAP Close')
)

-- Preview: row counts per data_type, flagged keep vs drop.
SELECT
    f.data_type,
    COUNT(*) AS rows,
    CASE WHEN p.data_type IS NULL THEN 'DROP' ELSE 'keep' END AS action
FROM ice_python.future_contracts_v1_2025_dec_16 f
LEFT JOIN preset_fields p ON p.data_type = f.data_type
GROUP BY f.data_type, p.data_type
ORDER BY action DESC, rows DESC;


-- ---------------------------------------------------------------------------
-- Delete non-preset rows.
-- ---------------------------------------------------------------------------
DELETE FROM ice_python.future_contracts_v1_2025_dec_16
WHERE data_type NOT IN (
    'Settlement', 'Open', 'High', 'Low', 'Close',
    'Last', 'Volume', 'Open Interest', 'VWAP Close'
);


-- ---------------------------------------------------------------------------
-- Verify: only preset data_types should remain.
-- ---------------------------------------------------------------------------
SELECT data_type, COUNT(*) AS rows
FROM ice_python.future_contracts_v1_2025_dec_16
GROUP BY data_type
ORDER BY data_type;

-- Reclaim space. (Bare VACUUM works inside a transaction; VACUUM FULL does
-- not — run that separately if you also want to shrink the relation file
-- on disk.)
-- VACUUM ANALYZE ice_python.future_contracts_v1_2025_dec_16;

-- If counts look right, commit. Otherwise ROLLBACK.
COMMIT;

-- After commit (outside the transaction), optionally reclaim disk:
-- VACUUM FULL ice_python.future_contracts_v1_2025_dec_16;
-- ANALYZE ice_python.future_contracts_v1_2025_dec_16;
