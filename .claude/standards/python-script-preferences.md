# Python Script Preferences

> **Canonical reference implementation:** [`backend/scrapes/power/pjm/`](../backend/scrapes/power/pjm/) — all new PJM scripts must follow this pattern (e.g., `da_hrl_lmps.py`).

## Imports (every file)

When refactoring existing scripts, update old-style imports to this format:

| Old (legacy) | New (preferred) |
|---|---|
| `from helioscta_api_scrapes.utils import azure_postgresql` | `from backend.utils import azure_postgresql_utils as azure_postgresql` |
| `from helioscta_api_scrapes.utils import logging_utils` | `from backend.utils import logging_utils` |
| `from helioscta_api_scrapes.utils import slack_utils` | Remove (see "No Slack" below) |
| `from helioscta_api_scrapes import settings` | `from backend import secrets` |
| `from helioscta_api_scrapes.src.cloud.wsi import utils` | `from backend.scrapes.wsi import utils` |

```python
from backend import secrets
from backend.utils import (
    azure_postgresql_utils as azure_postgresql,
    logging_utils,
    pipeline_run_logger,
)
```

## Logger (every file)

```python
API_SCRAPE_NAME = "descriptive_name"

logger = logging_utils.init_logging(
    name=API_SCRAPE_NAME,
    log_dir=Path(__file__).parent / "logs",
    log_to_file=True,
    delete_if_no_errors=True,
)
```

## PipelineRunLogger (every file, in main)

```python
run = pipeline_run_logger.PipelineRunLogger(
    pipeline_name=API_SCRAPE_NAME,
    source="power",
    target_table=f"gridstatus.{API_SCRAPE_NAME}",
    operation_type="upsert",
    log_file_path=logger.log_file_path,
)
run.start()
# ... on success:
run.success(rows_processed=len(df))
# ... on failure:
run.failure(error=e)
```

## Standard Functions

Every script follows this pattern:

- `_pull()` — fetch data from API/source
- `_format()` — rename columns, cast dtypes, reorder
- `_upsert()` — upsert to Azure PostgreSQL
- `main()` — orchestrates `_pull` -> `_format` -> `_upsert`, wrapped in try/except/finally

## Upsert Pattern

```python
def _upsert(
    df: pd.DataFrame,
    database: str = "helioscta",
    schema: str = "gridstatus",
    table_name: str = API_SCRAPE_NAME,
):
    primary_keys = [col for col in PRIMARY_KEY_CANDIDATES if col in df.columns]
    data_types = azure_postgresql.get_table_dtypes(database=database, schema=schema, table_name=table_name)
    azure_postgresql.upsert_to_azure_postgresql(
        database=database, schema=schema, table_name=table_name,
        df=df, columns=df.columns.tolist(),
        data_types=data_types, primary_key=primary_keys,
    )
```

## File Naming Conventions

| File type | Required name | Example |
|-----------|--------------|---------|
| Runner | `runs.py` (plural, **not** `run.py`) | `backend/scrapes/power/ercot/runs.py` |
| Flows | `flows.py` | `backend/prefect_orchestration/power/ercot/flows.py` |
| API helpers / utilities | `{source}_api_utils.py` | `ercot_api_utils.py`, `genscape_api_utils.py` |
| General utilities | `{source}_utils.py` or `{domain}_utils.py` | `wsi_utils.py`, `ice_utils.py` |

### Rules

- **All runner files must be `runs.py`** — never `run.py`. Existing `run.py` files should be renamed to `runs.py` when touched.
- **All utility/helper files must end with `_utils`** — never bare `utils.py`. Prefix with the source or domain name (e.g., `ercot_api_utils.py`, not `utils.py`).
- **API helper modules** specifically use the pattern `{source}_api_utils.py` (e.g., `ercot_api_utils.py`, `genscape_api_utils.py`).

## Folder Orchestration Files

Every source subfolder in `backend/scrapes/` should include:

- `runs.py` - manual runner that always calls each script's `main()` function

Prefect `flows.py` wrappers live in the matching path under `backend/prefect_orchestration/` (not `backend/scrapes/`):

- `backend/prefect_orchestration/<domain>/flows.py` - Prefect flow wrappers (using lazy `importlib` loading to call scripts in `backend/scrapes/`)

Use `backend/prefect_orchestration/power/ercot/flows.py` as the canonical structure for flows.

### `runs.py` must use `run_script_main_only`

Runners must always call `main()` — never `_pull()` directly. Set `adapter=run_script_main_only` in the `RunnerConfig` so the runner exercises the full production path (date windows, multi-entity loops, logging, pipeline tracking).

```python
from backend.utils.runner_utils import RunnerConfig, runner_main, run_script_main_only

config = RunnerConfig(
    name="ERCOT",
    project_root=PROJECT_ROOT,
    discover=discover_scripts,
    display=display_menu,
    display_name=lambda p: p.name,
    adapter=run_script_main_only,
)
runner_main(config)
```

Do **not** rely on `detect_adapter()` auto-detection, which may pick `run_script_pull_upsert` and bypass `main()` entirely — skipping date-range loops, multi-entity iteration, and pipeline run logging.

### WSI structure

Each WSI domain subfolder (e.g. `weighted_degree_day/`) has its own `runs.py`.
Prefect wrappers are in `backend/prefect_orchestration/wsi/<domain>/flows.py`.
A top-level `backend/scrapes/wsi/runs.py` also exists to run all scripts across subfolders.

## No Prefect in Scripts

Do not add `from prefect import flow` or `@flow` decorators to individual scripts. Scripts must be pure Python. Prefect wrappers live in `backend/prefect_orchestration/` (not `backend/scrapes/`), using lazy `importlib` loading to call back into `backend/scrapes/`. See `.markdowns/Mar-03/runners_without_prefect.md`.

## No Slack

Do not include `slack_utils` imports or Slack notification code. Use `PipelineRunLogger` for failure tracking instead.
