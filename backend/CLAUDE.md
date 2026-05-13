# backend/

Python scrapes, shared utilities, and the Prefect worker image. This
branch (`backend-cleanup`) is mid-refactor: the previous dbt project,
MCP server, schedulers, and modelling tree have been removed; only the
scrapes + utils + Prefect runtime remain.

## Sub-areas

- `backend/scrapes/` — source-keyed scrape scripts. One folder per
  external source (currently `ice_python/`; other folders like `eia/`,
  `energy_aspects/`, `gas_ebbs/`, `ercot/`, `pjm/`, `meteologica/` are
  staged renames from the old `backend/src/` tree and may land back in
  the working copy as the cleanup progresses). Each script exposes
  some combination of `_pull()`, `_format()`, `_upsert()`, and/or
  `main()` so the shared runner can dispatch it.
- `backend/mcp_server/` — FastAPI app exposing structured views over
  `logging.pipeline_runs` to the `/pipeline-health` slash command. Six
  endpoints (failures_recent / runs_summary / runs_throughput /
  runs_duration / schedule_cadence / notifications_recent), mounted as
  MCP at `/mcp` via `FastApiMCP`. Run with
  `uvicorn backend.mcp_server.main:app --reload` or let the PreToolUse
  hook auto-restart on next `mcp__backend-views__*` tool call. See
  `backend/mcp_server/README.md`.
- `backend/utils/` — the only sanctioned boundary to external systems.
  Always go through these wrappers; don't import the raw SDKs from
  scrape code:
  - `azure_postgresql_utils` — Azure Postgres reads/writes
    (`upsert_to_azure_postgresql` is the primary entry-point).
  - `azure_sql_utils` — Azure SQL Server (Genscape feed and similar
    SQL-Server-only sources). Distinct from Postgres; don't mix.
  - `azure_blob_storage_utils` — blob reads/writes for the parquet
    cache and any model-cache publishing.
  - `azure_email_utils` — Outlook/Graph email send + attachment fetch.
  - `slack_utils` — Slack notifications (uses `SLACK_*` env vars).
  - `file_utils` — paths, MST timestamping
    (`get_mst_timestamp()` is the canonical clock for log rows).
  - `logging_utils` — log-file plumbing; pairs with
    `pipeline_run_logger`.
  - `pipeline_run_logger.PipelineRunLogger` — every pipeline lifecycle
    event (start/success/failure/notification/stage) is appended to
    `logging.pipeline_runs` in Azure Postgres. Prefer the context-
    manager form. See "Pipeline run logging" below.
  - `runner_utils` — `RunnerConfig` + adapters that power the
    `python -m <pkg>.runs` CLIs (see "Runner pattern" below).
- Top-level config files (`backend/` root):
  - `settings.py` — paths and cache config; loads `.env` if present.
    Some constants (`DBT_PROJECT_DIR`, `MODELLING_CACHE_DIR`) point at
    directories that no longer exist on this branch — don't add new
    callers that depend on them.
  - `credentials.py` — the authoritative env loader (Azure Postgres +
    Azure SQL + Outlook + Slack + Blob storage + all source APIs).
    Loads `backend/.env`. Import constants directly:
    `from backend import credentials` or
    `from backend.credentials import SOME_CONSTANT`.
  - `setup.py` — installs the tree as the `backend` package
    (`pip install -e backend`). Required so `from backend.utils …`
    works from anywhere.
  - `requirements.txt` / `environment.yml` — pip and conda manifests.
  - `Dockerfile.prefect` + `docker-compose.yml` — Prefect 3.6 server +
    worker. **Heads up:** the compose worker still tries to deploy
    yaml files from `/app/schedulers/prefect`, which doesn't exist on
    this branch. The worker boots but deploys nothing until that path
    (or this command) is restored.

## Runner pattern

Scrape entry-points use a single shared runner so a directory of
scripts can be listed, selected, and executed from one CLI:

- Each scrape module exposes some of `_pull()`, `_format(df[, meta])`,
  `_upsert(df)`, or `main()`. `runner_utils.detect_adapter` picks the
  right call sequence by introspection — you don't register anything.
- A `runs.py` next to a folder of scripts builds a `RunnerConfig`
  (project root, discover function, display callbacks) and calls
  `runner_main(config)`. Existing examples:
  `backend/scrapes/eia/runs.py`,
  `backend/scrapes/energy_aspects/timeseries/runs.py`. Copy one of
  these when adding a new source group; don't reinvent the CLI.
- Invocation: `python -m backend.scrapes.<source>.runs` (then `--list`,
  `all`, a number list, or interactive prompt).

## Pipeline run logging

Every script that writes to or reads from a target table should wrap
its work in `PipelineRunLogger`:

```python
from backend.utils.pipeline_run_logger import PipelineRunLogger

with PipelineRunLogger(
    pipeline_name="eia_weekly_underground_storage",
    source="helioscta_api_scrapes",
    target_table="natural_gas.weekly_underground_storage",
    operation_type="upsert",   # or "consume" when reading
    log_file_path=logger.log_file_path,
) as run:
    df = _pull()
    _upsert(df)
    run.log_rows_processed(len(df))
```

- `operation_type` must be `"upsert"` or `"consume"` (validated in
  `__init__`), and `target_table` is required whenever
  `operation_type` is set. Don't pass arbitrary strings.
- Timestamps are MST-naive via `file_utils.get_mst_timestamp()` — do
  not pass tz-aware datetimes through `_write_event`.
- The context manager auto-logs success on clean exit and failure on
  exception. Only call `run.success()` / `run.failure()` manually if
  you're not using `with`.

## Conventions

- **One folder per source under `scrapes/`.** Mirror the path used by
  the source's API (`eia/`, `energy_aspects/timeseries/`, `gas_ebbs/`,
  …). Don't create sibling folders like `*_cleaned/` or
  `*_modelling/`; cleaning belongs downstream of this repo now that
  dbt is gone from the tree.
- **All side effects go through `backend/utils/`.** No `psycopg2`,
  `pyodbc`, `azure.storage.blob`, or `slack_sdk` imports outside
  `utils/`. If a wrapper is missing what you need, extend the wrapper
  rather than bypassing it from a scrape.
- **Imports always start at `backend.`** — the package is installed
  editable via `setup.py`. `from backend.utils import …` works from
  anywhere; relative imports do not (the runner imports modules by
  dotted name and bypasses `__main__`).
- **Credentials come from env vars via `backend.credentials`.** Don't
  re-read `os.getenv` in scrape modules — import the constant from
  `credentials.py` and add it there if missing.
- **Don't reach into `.archive/`.** It holds the old dbt + positions
  refactor and is not part of the runtime; it exists for history only.
- **Function args over argparse.** Any `python -m`-runnable script
  under `scrapes/` or `orchestration/` exposes parameters as kwargs
  on `main(...)` with module-level `DEFAULT_*` constants — not
  `argparse.ArgumentParser`. Why: Task Scheduler `.ps1` registrations
  never pass flags, `runner_utils` already owns argv parsing for the
  runner pattern, and function-arg scripts compose cleanly when called
  from `backend/orchestration/` or a notebook. Full rule:
  `.claude/skills/python-script-args/SKILL.md`. The dispatcher in
  `backend/utils/runner_utils.py` is the one sanctioned exception.
