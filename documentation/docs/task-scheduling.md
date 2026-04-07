# Task Scheduling

Repo-wide conventions for Windows Task Scheduler orchestration. All scheduled
tasks are registered via PowerShell scripts under
`schedulers/task_scheduler_azurepostgresql/`.

---

## dbt run (Azure PostgreSQL)

Refreshes all dbt views on the `helioscta` Azure PostgreSQL database.

| Field | Value |
|-------|-------|
| PowerShell runner | `schedulers/task_scheduler_azurepostgresql/dbt/dbt_run.ps1` |
| Python entrypoint | `backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py` |
| CLI arguments | `--select <selector>`, `--dry-run`, `--timeout <seconds>`, `--max-attempts <n>`, `--retry-backoff-seconds <seconds>` |
| Task Scheduler name | `dbt run (Azure PostgreSQL)` |
| Task Scheduler path | `\helioscta-backend\dbt\` |
| Cadence | Every 10 minutes (repetition interval), scheduler host local time |
| Overlap protection | OS-level `MultipleInstances = IgnoreNew` + PostgreSQL advisory lock |
| Retry behavior | Retryable dbt failures are retried (default `max_attempts=3`, linear backoff `30s * attempt`) |
| Timeout | Per-attempt timeout is 30 minutes by default (`--timeout`); Task Scheduler execution time limit is 2 hours |
| Telemetry | dbt anonymous telemetry disabled in runner subprocess (`DO_NOT_TRACK=1`, `DBT_DO_NOT_TRACK=1`) |
| Logging | `logging.pipeline_runs` table via `PipelineRunLogger` |
| Log files | `backend/dbt/dbt_azure_postgresql/logs/` |

### How to register

Run the PowerShell script in an elevated session:

```powershell
.\schedulers\task_scheduler_azurepostgresql\dbt\dbt_run.ps1
```

### How to remove

```powershell
Unregister-ScheduledTask -TaskName "dbt run (Azure PostgreSQL)" -TaskPath "\helioscta-backend\dbt\" -Confirm:$false
```

### Migration from old tasks

The previous `.ps1` registered 7 per-day tasks. Remove orphans before
registering the new single task:

```powershell
$days = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
foreach ($day in $days) {
    Unregister-ScheduledTask `
        -TaskName "dbt run (Azure PostgreSQL) ($day)" `
        -TaskPath "\helioscta-backend\dbt\" `
        -Confirm:$false -ErrorAction SilentlyContinue
}
```

### Run status events

Events written to `logging.pipeline_runs`:

| Event | Meaning |
|-------|---------|
| `RUN_SUCCESS` | dbt exited 0 |
| `RUN_FAILURE` | dbt exited non-zero or unexpected exception |
| `WARNING` (message: `RUN_SKIPPED`) | Advisory lock held — another run in progress |
| `RUN_FAILURE` (metadata: `RUN_TIMEOUT`) | dbt exceeded timeout, process tree killed |

### Manual execution

```bash
# Full run
python backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py

# Selective run (PJM models only)
python backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py --select tag:pjm

# Dry run (log command without executing)
python backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py --dry-run

# Increase retry budget for unstable windows
python backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py --max-attempts 5 --retry-backoff-seconds 20
```
