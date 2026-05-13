---
description: Generate a backend pipeline-health digest — what failed, what's slow, what's running hard, and what's stale in logging.pipeline_runs. Read-only.
---

# Pipeline health

Generate a digest of `logging.pipeline_runs` activity for an inspection
window (default last 24h). Surfaces failures (with log tails), stale /
missing-run pipelines, slow outliers, and the top-N hottest pipelines.
Intended to run throughout the day while pipelines are firing.

## Inputs

Accept optional arguments from the slash-command body (free-form):

- `hours=<N>` — override the hourly window. Default 24.
- `cadence_days=<N>` — override the cadence lookback. Default 14.

If the user types `/pipeline-health hours=6 cadence_days=7`, parse and
pass through. Otherwise use defaults.

## MCP server

The `backend-views` MCP server runs locally on port 8000. Health is
auto-managed by `.claude/hooks/mcp_health_check.py` — a PreToolUse
hook scoped to `mcp__backend-views__*`. It pings `/openapi.json` and
only triggers `backend.mcp_server.ensure_running` if the server is
unreachable. Steady state is a single ~50ms localhost GET.

If the hook reports a restart failure, the tool call is blocked with
the failure stderr surfaced. STOP and point the user at
`backend/mcp_server/logs/server.log` — do not synthesize a digest from
stale data and do not call view builders directly via Python.

## Workflow

1. **Delegate to the `pipeline-failure-analyst` agent.** Pass the
   parsed `hours` and `cadence_days` arguments through. The agent:
   - Calls all six `mcp__backend-views__*` endpoints in `format=json`.
   - Filters per the rules in its system prompt (every failed
     pipeline, every stale pipeline, top-5 slow if p95 > 60s, top-5
     hottest by run count).
   - Cross-references notifications to mark silent failures.
   - Returns the per-section digest markdown verbatim.

2. **Persist the raw output.** Save under
   `backend/mcp_server/runs/pipeline_health/<YYYY-MM-DD>_<HH-MM>.md`
   using the MST `as_of` timestamp the agent reports. Overwrite if a
   run within the same minute already exists. Gitignored.

3. **Render in the terminal.** Print the digest verbatim. Do not
   wrap it in `<details>` or add a preface — the structure is the UI.

## When to use which window

| Situation | hours | cadence_days |
|---|---:|---:|
| Mid-morning rolling check | 6 | 14 |
| End-of-day audit | 24 | 14 |
| Post-incident triage | 1-2 | 7 |
| Weekly retro | 168 | 30 |

## Caveats to surface in the digest

- **DA scrape timing.** Some pipelines fire on irregular cadences
  (DA market open / close); a "stale" flag on those during off-hours
  is expected — read the bucket label before alerting.
- **MST timestamps.** Everything in the table is naive MST. Don't
  translate to UTC and don't claim wall-clock 24h on a 24-hour window.
- **First 24h after deploy.** If pipeline_run_logger was just added to
  a script, that pipeline will appear stale until it has accumulated
  cadence history (`min_runs_for_cadence=3`).
