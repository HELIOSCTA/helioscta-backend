# helioscta-backend

Repo for HeliosCTA's data scrapes and shared Python utilities. The
working tree on this branch (`backend-cleanup`) has been pared down to
the backend Python package; the previous dbt project, frontend,
modelling tree, docs site, MCP server, and Dagster/Prefect schedulers
have all been removed and live only in git history (or under
`.archive/` for the in-flight refactors).

## Layout

- `backend/` — the Python code path. Scrapes, shared utilities, and
  the Prefect worker image. See `backend/CLAUDE.md` for the sub-area
  map, runner pattern, pipeline-logging contract, and conventions.
  **Read it before editing anything under `backend/`.**
- `frontend/` — Next.js 15 + TypeScript dashboard, imported from the
  former `helioscta-gas-frontend` repo on 2026-05-13. Deploys to
  Vercel via `.github/workflows/frontend-deploy.yml`. See
  `frontend/CLAUDE.md` for layout, build commands, and styling /
  performance standards.
- `.archive/` — preserved-for-history snapshots of the old dbt and
  positions refactors. Not part of the runtime; don't import from it
  and don't take it as a model for new code.
- `.vendor-docs/` — vendored third-party docs (e.g. WSI / Genscape
  feed). Reference only.
- `.claude/` — Claude Code settings and skills for this repo. See
  `.claude/skills/python-script-args/SKILL.md` for the
  function-args-over-argparse convention that applies to every
  `python -m`-runnable script under `backend/scrapes/` and
  `backend/orchestration/`.

## Working in this repo

- Install the backend as an editable package so `from backend.…`
  imports resolve: `pip install -e backend` (or use the
  `environment.yml` / `requirements.txt` in `backend/`).
- All credentials are loaded from `backend/.env` via
  `backend/credentials.py`. There is also a legacy `backend/secrets.py`
  — prefer `credentials.py` for new code (see `backend/CLAUDE.md`).
- Scrape CLIs run as `python -m backend.scrapes.<source>.runs`; the
  runner pattern is documented in `backend/CLAUDE.md`.
- Frontend dev: `cd frontend && npm install` once, then
  `npm run dev` for the local Next.js server. `npm run lint` and
  `npm test` (Vitest) before pushing. See `frontend/CLAUDE.md` for
  the full set of commands and conventions.

## Pointers for agents

When working on a task inside this repo, the authoritative context
lives in:

1. `backend/CLAUDE.md` — code conventions, runner pattern,
   pipeline-logging contract, util boundaries, and notes on what's
   stale on this branch.
2. Any nearer `CLAUDE.md` or `README.md` inside the folder you're
   editing (e.g. a source-specific `gas_ebbs/README.md`) — these
   override the broader files when they conflict.

If you find a convention here that contradicts what the code actually
does, the code wins — flag the drift and update this file.
