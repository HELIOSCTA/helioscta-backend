# observability/

Ad-hoc SQL for poking at Azure Postgres performance. Paste into any SQL
editor connected to the `helioscta` database; no Python wrapper.

Suggested order when investigating a "why is X slow" question:

1. **`01_table_sizes.sql`** — which tables actually have weight on disk?
   Slow upserts usually live on top of one of the biggest few.
2. **`02_in_flight_queries.sql`** — anything stuck *right now*? Long
   `query_age` + non-empty `blocked_by` = lock contention; long
   `query_age` + null `wait_event` = the query itself is doing real
   work.
3. **`03_slow_pipeline_runs.sql`** — over the last 7 days, which
   pipelines have outlier durations, and which individual runs were the
   worst? Pair section A (per-pipeline stats) with section B (individual
   runs) to tell one-offs from trends.

Notes:

- `logging.pipeline_runs.event_timestamp` is naive-MST (written by
  `backend.utils.pipeline_run_logger.PipelineRunLogger` via
  `file_utils.get_mst_timestamp()`). If your SQL session is UTC, the
  `now() - interval '7 days'` cutoff in `03_*.sql` is 7 hours too late
  — subtract `interval '7 hours'` from `now()` to compensate, or use a
  literal MST timestamp.
- dbt-specific filtering isn't wired in yet — when you tell me the
  convention (tag, `source` value, or `pipeline_name` prefix), I'll add
  a section to `03_*.sql` that splits dbt runs out from scrape upserts.
