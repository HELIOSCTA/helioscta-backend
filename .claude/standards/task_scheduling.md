# Task Scheduling

How to add or modify Windows Task Scheduler orchestration in
`backend/schedulers/task_scheduler_azurepostgresql/`.

## Use This Skill When

- Adding a new `.ps1` task registration script
- Changing cadence, task name, task path, or Python entrypoint for an existing scheduler
- Introducing a new `runs.py` entrypoint that must be scheduled

## Required Deliverables

For every new scheduled workflow:

1. A stable Python entrypoint exists under `backend/scrapes/`.
2. A matching PowerShell registration script exists under
   `backend/schedulers/task_scheduler_azurepostgresql/<domain>/`.
3. If the workflow supports an `all` command, keep a folder-level aggregate runner such as
   `eia/eia_all_scripts.ps1`.
4. At least one file under `documentation/docs/` is updated in the same change.
5. Bulk helper scripts are excluded from `register_all_tasks.ps1`.

## PowerShell Runner Pattern

- Keep PowerShell limited to Task Scheduler registration. Business logic belongs in Python.
- Define `$condaPath` and the Python entrypoint path up front.
- Use `New-ScheduledTaskAction` with `cmd.exe` so the Conda environment is activated before
  running Python or `dbt`.
- Register tasks under `\helioscta-backend\<Domain>\`.
- Use stable task names. Rename only when the operational meaning changes.
- Prefer one `.ps1` per scheduled entrypoint. If a folder exposes `python ... all`, keep a
  folder-level aggregate runner for that entrypoint.

## Documentation Requirement

Any new or modified `.ps1` must update at least one file under `documentation/docs/`.

Minimum documentation fields:

- PowerShell runner path
- Python entrypoint and CLI arguments
- Task Scheduler task name and task path
- Trigger or cadence, including timezone or "scheduler host local time"
- How operators register or remove the task

Preferred documentation targets:

- The relevant domain page under `documentation/docs/domains/<domain>/`
- `documentation/docs/task-scheduling.md` for repo-wide scheduler conventions or helper-script changes

## Implementation Checklist

1. Create or update the Python entrypoint under `backend/scrapes/...`.
2. Add or update the matching PowerShell runner under
   `backend/schedulers/task_scheduler_azurepostgresql/...`.
3. If you add a control script that should never be scheduled, update
   `register_all_tasks.ps1` so bulk registration skips it.
4. Update `documentation/docs/` in the same change.
5. Verify paths, task names, and trigger definitions match the intended runtime behavior.

## Canonical References

- Repo policy: `AGENTS.md`
- Operator reference: `documentation/docs/task-scheduling.md`
- Docs conventions: `.claude/standards/documentation.md`
