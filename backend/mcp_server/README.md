# mcp_server

FastAPI + MCP entry point for serving structured views over
`logging.pipeline_runs` (the table that
`backend.utils.pipeline_run_logger.PipelineRunLogger` writes to).
Powers the `/pipeline-health` slash command and the
`pipeline-failure-analyst` agent.

## Run

From the repo root:

```bash
uvicorn backend.mcp_server.main:app --reload
```

Or let `.claude/hooks/mcp_health_check.py` start it on demand — the
hook fires before any `mcp__backend-views__*` tool call.

Each view is `GET /views/<name>?format=md|json`. MCP transport is
mounted via `FastApiMCP(app).mount_http()` at `/mcp`.

## Endpoints

| Endpoint | Purpose | Key params |
|---|---|---|
| `/views/failures_recent` | RUN_FAILURE events grouped by pipeline, with error preview + log tail | `lookback_hours`, `log_preview_lines` |
| `/views/runs_summary` | Per-pipeline roll-up: counts, last status, durations, rows | `lookback_hours` |
| `/views/runs_throughput` | "What is running hard?" — rank by runs / rows / files | `lookback_hours`, `top_n`, `sort_by` |
| `/views/runs_duration` | p50 / p95 / max / mean of duration_seconds | `lookback_hours`, `top_n`, `min_runs`, `sort_by` |
| `/views/schedule_cadence` | Observed inter-run gap + staleness flag | `lookback_days`, `stale_multiplier`, `min_runs_for_cadence` |
| `/views/notifications_recent` | SLACK_SENT / EMAIL_SENT events | `lookback_hours` |

## Required environment variables

Loaded from `backend/.env` by `backend/credentials.py`
(`backend.settings` triggers the load on import):

- `AZURE_POSTGRESQL_DB_HOST`
- `AZURE_POSTGRESQL_DB_USER`
- `AZURE_POSTGRESQL_DB_PASSWORD`
- `AZURE_POSTGRESQL_DB_PORT`
- `AZURE_POSTGRESQL_DB_NAME` (defaults to `helioscta`)

## Layout

```
backend/mcp_server/
├── main.py                  — FastAPI app + endpoint wiring + MCP mount
├── ensure_running.py        — kill-and-respawn pre-flight
├── data/
│   └── pipeline_runs.py     — SQL pulls (one helper per endpoint family)
├── views/
│   ├── pipeline_runs.py     — view-model builders (aggregation + ranking)
│   └── markdown_formatters.py — `format=md` renderers
├── logs/                    — uvicorn stdout/stderr (gitignored)
└── runs/pipeline_health/    — saved digests (gitignored)
```

## Adding a new view

1. Add a `pull_*` helper in `data/pipeline_runs.py`. Compute the time
   cutoff with `_mst_cutoff(hours)` to keep the naive-MST contract.
2. Add a `build_*_view_model` in `views/pipeline_runs.py`. Return a
   dict — keep keys snake_case and stable; the agent contract is the
   JSON shape.
3. Add a `format_*` renderer in `views/markdown_formatters.py`.
4. Wire an endpoint in `main.py` (copy an existing one — the shape
   is uniform).
5. Restart uvicorn (or let the hook do it on next tool call).
6. Update the agent's `tools:` list in
   `.claude/agents/pipeline-failure-analyst.md` if you want it
   available to the digest.

## Reused infra (not re-implemented)

- `backend.utils.azure_postgresql_utils.pull_from_db` — Postgres pull
- `backend.utils.file_utils.get_mst_timestamp` — the canonical clock
- `backend.settings` / `backend.credentials` — env loading
