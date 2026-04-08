# AGENTS.md

This file provides guidance to Codex when working with code in this repository.

## Project

helioscta-backend - Backend service for HeliosCTA.

## Status

This project is in its initial scaffolding phase. No source code, build configuration, or tests exist yet. Update this file as the project takes shape.

## Skills

Project-specific conventions and preferences for Codex.

| Skill | Path | Description |
|-------|------|-------------|
| dbt Preferences | [.claude/standards/dbt-preferences.md](.claude/standards/dbt-preferences.md) | dbt project conventions: materialization, naming, documentation, testing standards |
| Python Script Preferences | [.claude/standards/python-script-preferences.md](.claude/standards/python-script-preferences.md) | Backend Python script structure, imports, and pipeline patterns |
| Logging | [.claude/standards/logging.md](.claude/standards/logging.md) | Logging and pipeline run tracking conventions |
| Task Scheduling | [.claude/standards/task_scheduling.md](.claude/standards/task_scheduling.md) | Windows Task Scheduler PowerShell runner conventions, bulk registration rules, and required docs updates |
| Scheduled vs Event-Driven | [.claude/standards/scheduled_vs_event_driven.md](.claude/standards/scheduled_vs_event_driven.md) | Prompt template and decision framework for API scrape orchestration |
| Documentation | [.claude/standards/documentation.md](.claude/standards/documentation.md) | Docusaurus site conventions: theme, nav structure, content templates, QA checklist |
| TODO Tracking | [.claude/standards/todo-preferences.md](.claude/standards/todo-preferences.md) | TODO directory structure, tags, and conventions for tracking work and bugs |

## API Orchestration Decision Standard

For all new or refactored API scripts, apply the library-wide decision criteria in
[.claude/standards/scheduled_vs_event_driven.md](.claude/standards/scheduled_vs_event_driven.md) before choosing scheduled, event-driven, or hybrid orchestration.

- Required: use the scoring rubric and decision rules in Section 8 of that document.
- Default policy: scheduled for external pulls unless freshness/arrival variability requires event-driven or hybrid.
- Current reference example: `backend/src/wsi/weighted_degree_day` is event-driven primary with scheduled reconciliation.

## Task Scheduler Standard

All new or modified Windows Task Scheduler scripts under `backend/schedulers/task_scheduler_azurepostgresql/` must follow
[.claude/standards/task_scheduling.md](.claude/standards/task_scheduling.md).

- Required: every scheduled Python entrypoint must have a matching `.ps1` registration script.
- Required: every new or modified `.ps1` must update at least one file under `documentation/docs/` in the same change.
- Required: bulk helper scripts such as `register_all_tasks.ps1` and `delete_all_tasks.ps1` must not be auto-registered as scheduled tasks.

## PJM Script Standard

All new PJM scripts must follow the canonical pattern established in [`backend/src/power/pjm/`](backend/src/power/pjm/). Do not refactor existing PJM scripts unless explicitly requested.

- Detailed standard: [.claude/standards/python-script-preferences.md](.claude/standards/python-script-preferences.md)
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
