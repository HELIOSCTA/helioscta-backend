# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Project

helioscta-backend - Backend service for HeliosCTA.

## Status

This project is in its initial scaffolding phase. No source code, build configuration, or tests exist yet. Update this file as the project takes shape.

## PJM Script Standard

All new PJM scripts must follow the canonical pattern established in [`backend/src/power/pjm/`](backend/src/power/pjm/). Do not refactor existing PJM scripts unless explicitly requested.

- Canonical examples: [`backend/src/power/pjm/`](backend/src/power/pjm/) (e.g., `da_hrl_lmps.py`)

### Required pattern for new scripts

1. Functions: `_pull()`, `_format()`, `_upsert()`, `main()` with try/except/finally orchestration.
2. Logging: `logging_utils.init_logging(...)` with per-script `logs/` directory.
3. Run tracking: `pipeline_run_logger.PipelineRunLogger(...)` with `start()` / `success()` / `failure()`.
4. Folder orchestration files: every data subfolder must include `runs.py` in `backend/src/`. Prefect `flows.py` wrappers live in the matching path under `backend/prefect_orchestration/` (e.g. `backend/prefect_orchestration/power/pjm/flows.py`).
5. WSI scope rule: each WSI domain subfolder (e.g. `backend/src/wsi/weighted_degree_day/`) has its own `runs.py`. Prefect wrappers are in `backend/prefect_orchestration/wsi/<domain>/flows.py`. A top-level `backend/src/wsi/runs.py` also exists to run all scripts across subfolders.
6. File naming: runner files must be `runs.py` (plural, not `run.py`), utility/helper files must end with `_utils` suffix (e.g., `ercot_api_utils.py`, not `utils.py`).
6. No Prefect decorators in individual scripts - Prefect wrappers only in `backend/prefect_orchestration/*/flows.py`.
7. No Slack integration code - use `PipelineRunLogger` for failure tracking.
