# dbt run (Azure PostgreSQL) - Scheduled Task Zombie Process Issue

## Problem

The `dbt run (Azure PostgreSQL)` scheduled task repeatedly stops running because zombie processes from a completed dbt run hold the stdout pipe open, preventing the Task Scheduler instance from terminating.

This has occurred on **Mar 17, 2026** and at least once before (same issue reported on consecutive days).

## Root Cause

The failure chain:

1. `runner_dbt_azure_postgresql.py` spawns `dbt run` via `subprocess.Popen` with `stdout=PIPE`.
2. dbt completes successfully (PASS=99, ERROR=0), but its **Snowplow telemetry flush** ("Flushing usage events") spawns a child process that doesn't fully exit on Windows.
3. That child process **inherits the stdout pipe handle**, so `for line in proc.stdout:` in `dbt_utils.py:131` **blocks forever** waiting for the pipe to close.
4. The Python runner hangs -> the `cmd.exe` from Task Scheduler stays alive -> `MultipleInstances IgnoreNew` **skips every subsequent trigger**.
5. The runner's PostgreSQL connection stays open, holding the **advisory lock**, so even manually-triggered runs fail with `RUN_SKIPPED: advisory lock held by another session`.

### Evidence (Mar 17 incident)

**Zombie processes (all started 12:30 PM, still alive 18+ hours later):**

| PID    | Process | CPU     | Working Set | Path                                      |
|--------|---------|---------|-------------|-------------------------------------------|
| 384776 | python  | 0.58s   | 12 KB       | runner_dbt_azure_postgresql.py (the runner)|
| 154216 | dbt     | 0.02s   | 12 KB       | dbt.exe subprocess                        |
| 389316 | python  | 8.16s   | 12 KB       | dbt child process (Snowplow?)             |

**Task Scheduler state:**
- `State: Running` (stuck)
- `LastTaskResult: 2147946720` (0x800710E0 = "An instance of the task is already running")

**Pipeline logs (logging.pipeline_runs):**
- Last success: `2026-03-17 18:29:42 UTC` (dbt_exit_code: 0) -- the run completed fine at the application level
- Today: `RUN_SKIPPED: advisory lock held by another session` -- new instances can't acquire the lock

**dbt.log last entries:**
```
14:09:13 [info] Completed successfully
14:09:13 [info] Done. PASS=99 WARN=0 ERROR=0 SKIP=0 TOTAL=99
14:09:13 [debug] Flushing usage events    <-- Snowplow telemetry, process hangs after this
```

## Immediate Fix (when this happens)

Kill the zombie processes to unblock the scheduled task:

```powershell
# Kill the zombie process tree
taskkill /T /F /PID <runner_python_pid>

# Verify task resumes
Get-ScheduledTask -TaskName "dbt run (Azure PostgreSQL)" -TaskPath "\helioscta-backend\dbt\" | Get-ScheduledTaskInfo
```

## Permanent Fix Status (Implemented Mar 18, 2026)

Production hardening has been implemented in the runner:

1. Replaced `stdout=PIPE`/`stderr=PIPE` capture with temp-file capture in `dbt_utils.run_dbt()`.
2. Disabled dbt telemetry in subprocess env (`DO_NOT_TRACK=1`, `DBT_DO_NOT_TRACK=1`).
3. Added Windows creation flags (`CREATE_NEW_PROCESS_GROUP`, `CREATE_NO_WINDOW`).
4. Added retry/backoff for retryable failures (`--max-attempts`, `--retry-backoff-seconds`).
5. Added retry for PostgreSQL lock-connection startup.
6. Made dbt invocation explicit with `--project-dir` and `--profiles-dir`.

Task Scheduler script also now includes:

1. Explicit runner args (`--timeout 1800 --max-attempts 3 --retry-backoff-seconds 30`).
2. `ExecutionTimeLimit` of 2 hours to prevent permanent stuck tasks.
3. Auto-restart policy (`RestartCount=3`, `RestartInterval=5 minutes`).

## Files Involved

- `backend/dbt/dbt_azure_postgresql/runner_dbt_azure_postgresql.py` -- the runner entry point
- `backend/dbt/dbt_azure_postgresql/dbt_utils.py` -- subprocess + retry + lock connection hardening
- `backend/schedulers/task_scheduler_azurepostgresql/dbt/dbt_run.ps1` -- Task Scheduler registration
- `documentation/docs/task-scheduling.md` -- operator behavior and CLI documentation

## Production Rollout Plan (Updated Mar 18, 2026)

### Phase 0 - Stabilization (Completed Mar 18, 2026)

- [x] Replace pipe-based dbt output capture to remove handle inheritance deadlock.
- [x] Disable dbt telemetry in subprocess environment.
- [x] Add runner retry/backoff and scheduler execution guards.
- [x] Document new scheduler and runner behavior.

### Phase 1 - Operational Visibility (Target: Mar 19, 2026)

- [ ] Add watchdog check for `logging.pipeline_runs` freshness (alert if no `RUN_SUCCESS` inside SLA window).
- [x] Alert on repeated `RUN_SKIPPED` events — runner now inspects `pg_stat_activity` to log lock holder PID, state, and duration on every skip.
- [ ] Add runbook section for responder actions by failure type:
  - lock contention
  - timeout
  - repeated retryable db failures

### Phase 2 - Resilience and Blast-Radius Reduction (Target: Mar 22, 2026)

- [x] Add preflight connectivity check — `dbt debug` runs before every `dbt run` with 60s timeout. Fails fast on bad profile/connection.
- [x] Parse `run_results.json` after dbt run — runner now logs per-model pass/error/warn/skip counts and treats model errors as failures even when dbt exits 0.
- [x] Remove compounding OS-level retries — scheduler no longer restarts on failure (Python runner handles all retry logic). Execution limit tightened from 2h to 1h.
- [ ] Split critical marts into dedicated high-priority selector and schedule.
- [ ] Keep full-model run as secondary reconciliation pass.

### Phase 3 - Data Quality and Security Hardening (Target: Mar 26, 2026)

- [ ] Add post-run `dbt test` for critical models and fail/alert on regression.
- [x] Move production credentials out of `profiles.yml` — now uses `{{ env_var() }}` for host, user, password, port. No more plaintext password in git.
- [ ] Validate secret rotation procedure end-to-end on scheduler host.

## Success Criteria

1. Zero stuck Task Scheduler instances for 7 consecutive days.
2. Zero orphan advisory-lock incidents for 7 consecutive days.
3. 99%+ successful scheduled executions over trailing 7 days.
4. Alert latency under 10 minutes for run freshness breach.

## Verification Checklist

- [ ] `Get-ScheduledTaskInfo` shows healthy recurring completion state.
- [ ] `logging.pipeline_runs` shows regular `RUN_SUCCESS` cadence.
- [ ] No sustained streaks of `RUN_SKIPPED` without corresponding completion.
- [ ] Timeout failures produce `RUN_TIMEOUT` metadata and recover automatically.
