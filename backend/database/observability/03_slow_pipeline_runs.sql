-- Historical slow pipeline runs from logging.pipeline_runs.
--
-- Two sections:
--   A) Per-pipeline duration stats over the last 7 days. The ratio of
--      max / median is the most useful column -- a pipeline that usually
--      finishes in 30s but has a max of 1200s is the interesting one,
--      even if 1200s isn't a huge number on its own.
--   B) The actual slow individual runs over the last 7 days (top 50 by
--      duration). Pair with section A to see whether a slow run was a
--      one-off or part of a trend.
--
-- event_timestamp is naive-MST (written by PipelineRunLogger via
-- backend.utils.file_utils.get_mst_timestamp()), so the cutoffs below
-- compare against the server clock in whatever tz the session is set to.
-- If the session is UTC, subtract 7 hours from `now()` to compensate, or
-- replace `now()` with an explicit MST literal.

-- ============================================================
-- A) Per-pipeline duration stats, last 7 days
-- ============================================================
SELECT
    pipeline_name,
    target_table,
    operation_type,
    COUNT(*)                                          AS runs,
    COUNT(*) FILTER (WHERE event_type = 'RUN_FAILURE') AS failures,
    ROUND(AVG(duration_seconds)::numeric, 1)          AS avg_sec,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duration_seconds)::numeric,
        1
    )                                                 AS median_sec,
    ROUND(
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_seconds)::numeric,
        1
    )                                                 AS p95_sec,
    MAX(duration_seconds)                             AS max_sec,
    SUM(rows_processed)                               AS total_rows
FROM logging.pipeline_runs
WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
  AND event_timestamp >= now() - interval '7 days'
  AND duration_seconds IS NOT NULL
GROUP BY pipeline_name, target_table, operation_type
HAVING MAX(duration_seconds) >= 60   -- ignore pipelines that never crack 1 min
ORDER BY max_sec DESC
LIMIT 50;


-- ============================================================
-- B) Individual slow runs, last 7 days
-- ============================================================
SELECT
    run_id,
    pipeline_name,
    target_table,
    operation_type,
    event_type,
    event_timestamp,
    duration_seconds,
    rows_processed,
    error_type,
    LEFT(COALESCE(error_message, ''), 200) AS error_message
FROM logging.pipeline_runs
WHERE event_type IN ('RUN_SUCCESS', 'RUN_FAILURE')
  AND event_timestamp >= now() - interval '7 days'
  AND duration_seconds IS NOT NULL
ORDER BY duration_seconds DESC NULLS LAST
LIMIT 50;
