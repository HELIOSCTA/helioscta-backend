# frontend/

Next.js 15 + TypeScript app for HeliosCTA's gas dashboard. Originally
lived in its own repo (`helioscta-gas-frontend`) and was imported here
on 2026-05-13 so backend contracts and frontend consumers can be edited
in lockstep. Deployed to Vercel via `.github/workflows/frontend-deploy.yml`.

## Layout

- `app/` — App Router pages and API handlers (`app/api/**/route.ts`).
- `components/` — reusable React components (PascalCase, e.g.
  `CashPricingMatrix.tsx`).
- `lib/` — shared utilities, data fetchers, server helpers.
- `auth.ts`, `middleware.ts` — NextAuth setup and route middleware.
- `vercel.json` — Vercel function limits and region pin (`iad1`).

## Data access

The frontend reads **only from Postgres** — there is no HTTP call to the
backend Python service. Page loaders and `app/api/**/route.ts` handlers
query the database directly via the connection pool in `lib/`. The
backend's job is to land data in Postgres (scrapes → `logging` /
domain schemas → `backend/views/` materialisations); the frontend's
job is to read it.

Implication for cross-cutting changes: when a backend view's column
list, name, or schema changes, grep `frontend/` for the table/view
name before merging — there's no API layer that would surface the
break.

## Build, test, and development

- `cd frontend && npm install` — install deps.
- `cd frontend && npm run dev` — Next.js dev server.
- `cd frontend && npm run build && npm run start` — production build.
- `cd frontend && npm run lint` / `npm run lint:fix` — ESLint
  (`next/core-web-vitals`, `next/typescript`).
- `cd frontend && npm test` — Vitest.

## Coding conventions

- Strict TypeScript settings; ESLint config is `next/core-web-vitals` +
  `next/typescript`.
- 2-space indentation.
- React components in PascalCase.
- Route handlers named `route.ts` inside feature folders under `app/api/`.

## Testing

There is no broad test suite yet — at minimum run lint and a manual UI
+ API smoke check on the pages you touched.

## Commits

- Format: `<area>: <imperative summary>` (e.g. `frontend: add watchlist
  filter chips`).
- PRs should include: purpose, affected paths, env/migration changes,
  validation steps, and screenshots for UI updates.

## Security and configuration

- Never commit secrets from `.env` or `frontend/.env.local`. The
  repo-root `.gitignore` covers `frontend/.env*`; the inner
  `frontend/.gitignore` covers the same paths from inside `frontend/`.
- Keep credentials in local env files or CI/CD secrets; use
  placeholders in docs/scripts.

## Deploy

CI/CD lives at `.github/workflows/frontend-deploy.yml` in the repo
root. Pushes to `main` deploy to Vercel production; pushes to
`backend-cleanup` (and any other branch matching the workflow) deploy
preview URLs. Vercel project IDs are stored in repo secrets — see the
workflow header for the list.
