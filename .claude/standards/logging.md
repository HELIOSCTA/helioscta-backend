# Logging Conventions

## Pipeline Run Logger

All pipeline observability is centralized in `backend/utils/pipeline_run_logger.py`.
Events are written to the `logging.pipeline_runs` table as an **append-only** event log.

### Database table: `logging.pipeline_runs`

| Column | Type | Description |
|---|---|---|
| `run_id` | VARCHAR | UUID4, generated per run |
| `pipeline_name` | VARCHAR | e.g. `helios_transactions_v2_2026_feb_23` |
| `event_type` | VARCHAR | `RUN_SUCCESS`, `RUN_FAILURE`, `SLACK_SENT`, `EMAIL_SENT`, `STAGE_END`, `WARNING` |
| `event_timestamp` | TIMESTAMPTZ | When this event occurred (MST) |
| `duration_seconds` | FLOAT | Populated on RUN_SUCCESS / RUN_FAILURE |
| `status` | VARCHAR | `success`, `failure`, `sent`, `warning` |
| `error_type` | VARCHAR | e.g. `ConnectionError` |
| `error_message` | TEXT | Full exception string |
| `log_file_content` | TEXT | Full log file text (on failure) |
| `rows_processed` | INTEGER | Rows upserted/processed |
| `files_processed` | INTEGER | Files downloaded/processed |
| `source` | VARCHAR | e.g. `helioscta_api_scrapes` |
| `priority` | VARCHAR | `critical`, `high`, `medium`, `low` |
| `tags` | VARCHAR | e.g. `trades,clear_street` |
| `hostname` | VARCHAR | `socket.gethostname()` |
| `notification_channel` | VARCHAR | `slack` or `email` |
| `notification_recipient` | VARCHAR | Channel name or email address |
| `metadata` | TEXT | JSON string for ad-hoc data |
| `target_table` | VARCHAR | The DB table the pipeline interacts with. For `"upsert"` pipelines: the table being written to (e.g. `clear_street.helios_transactions_v2_2026_feb_23`). For `"consume"` pipelines: the table being read from (e.g. `trades_v1_2026_feb_02.marts_v1_clear_street_trades`). |
| `operation_type` | VARCHAR | `"upsert"` (writes/inserts data into a DB table) or `"consume"` (reads data and sends it downstream — email, SFTP, etc.) |

**Primary Key:** `(run_id, event_type, event_timestamp)` — append-only, each event is unique.

### Usage pattern

```python
from backend.utils import pipeline_run_logger

run = pipeline_run_logger.PipelineRunLogger(
    pipeline_name=API_SCRAPE_NAME,
    source=LOGGING_SOURCE,
    priority=LOGGING_PRIORITY,
    tags=LOGGING_TAGS,
    log_file_path=logger.log_file_path,
    target_table=LOGGING_TARGET_TABLE,       # upsert: table written to; consume: table read from
    operation_type=LOGGING_OPERATION_TYPE,    # "upsert" or "consume"
)

try:
    run.start()

    # ... pipeline work ...
    run.log_files_processed(len(filepaths))
    run.log_rows_processed(len(df))

    run.success()

except Exception as e:
    run.failure(error=e, log_file_path=logger.log_file_path)

    # Track notification
    slack_utils.send_pipeline_failure_with_log(...)
    run.log_notification(channel="slack", recipient=SLACK_CHANNEL)

    raise
```

### Context manager usage

```python
with pipeline_run_logger.PipelineRunLogger(
    pipeline_name="my_pipeline",
    source="helioscta_api_scrapes",
    priority="high",
    tags="trades",
) as run:
    run.log_rows_processed(100)
    # success() called automatically on clean exit
    # failure() called automatically if exception raised
```

### Stage tracking

```python
run.log_stage(stage_name="pull_sftp", rows=0, files=5, duration_seconds=12.3)
run.log_stage(stage_name="upsert_db", rows=500, files=1, duration_seconds=3.1)
```

### Backward compatibility

`pipeline_run_logger.upsert_error_log()` has the same signature as the old
`db_error_handler.upsert_error_log()` and writes a RUN_FAILURE event.

## Deprecated: `db_error_handler.py`

`backend/utils/db_error_handler.py` is deprecated. It logged to `logging.error_logs`
and had the following limitations:
- No concept of a "run" — successful pipelines were invisible
- No duration tracking or row/file counts
- Overwrote repeated identical errors (upsert on `pipeline_name + error_message`)
- Bug: referenced `azure_postgresql.upsert_to_azure_postgresql()` instead of `azure_postgresql_utils`

Use `pipeline_run_logger` for all new pipelines.

## Console / file logging

`backend/utils/logging_utils.py` provides `PipelineLogger` for console + file logging
with colors, icons, Prefect integration, and automatic log file cleanup.

```python
logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)
```

Access the log file path via `logger.log_file_path` — pass this to
`PipelineRunLogger` so failure events can capture the full log content.
