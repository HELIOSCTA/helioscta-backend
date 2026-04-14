# helioscta-frontend

Postgres-direct monitoring dashboard for HeliosCTA. **Day 1** of the Vercel-stack
spike — one Server Component page that runs SQL against the `helioscta`
PostgreSQL database at request time and renders the result as a table. No
ingest layer, no NRDB, no Terraform.

## Stack

- **Next.js 15** (App Router) — Server Components run SQL on the server
- **TypeScript**
- **Tailwind CSS v4**
- **`pg`** (node-postgres) → Azure PostgreSQL
- Deployed to **Vercel**

## Local dev

1. Install dependencies (one-time):
   ```
   cd frontend
   npm install
   ```

2. Copy the env template and fill in the credentials:
   ```
   cp .env.local.example .env.local
   ```
   Edit `.env.local` and set the five `AZURE_POSTGRESQL_DB_*` keys. The exact
   same values live in `backend/.env.prod` — copy them over directly. SSL is
   handled in `lib/db.ts`; you do not need to add a connection-string flag.

3. Run the dev server:
   ```
   npm run dev
   ```

4. Open <http://localhost:3000>. Click into the Clear Street SFTP dashboard.
   You should see real rows from `clear_street.helios_transactions_v2_2026_feb_23`.

## Deploy to Vercel

1. Push this repo to GitHub.
2. In Vercel: **New Project** → import the repo → set **Root Directory** to
   `frontend`.
3. Add the five `AZURE_POSTGRESQL_DB_*` environment variables in the project
   settings (Settings → Environment Variables).
4. **Deploy.**

Open the Vercel-assigned URL on your phone, then in mobile Safari/Chrome:
**Share → Add to Home Screen**. The icon now opens the dashboard fullscreen.
That's the "mobile observability" experience for Day 1 — Day 2 will add a
proper PWA manifest, icons, and a real auth wall.

## Architecture

```
Browser ──▶ Next.js Server Component ──▶ pg.Pool ──▶ Azure Postgres
                                                          │
                                          clear_street.helios_transactions_v2_2026_feb_23
```

Every page load issues a fresh SQL query. No data is cached server-side
beyond the connection pool itself. This is the same model Grafana's Postgres
datasource uses, just rendered through a TypeScript component instead of a
JSON dashboard definition.

## What this is NOT (yet)

This is the Day 1 spike. The following are explicitly out of scope and will
be added in subsequent days only if the spike feels right:

- **Auth** (Day 2 — Clerk or NextAuth + Azure AD)
- **PWA manifest + service worker** for "Add to Home Screen" with native feel (Day 2)
- **Vercel Cron alert routes** (Day 3)
- **Pushover / ntfy push notification glue** (Day 3)
- More than one dashboard
- Charts beyond a plain table (Tremor / Recharts later)
- Connection pooling tuning via Azure Postgres's built-in PgBouncer endpoint

If the spike feels good after Day 3, the rest is incremental.

## Where this fits in the repo

| Path | Purpose |
|---|---|
| `backend/grafana/` | Legacy Grafana stack — still running, still the source of truth until cutover |
| `backend/monitoring/` | New Relic ingest stack from the abandoned NR migration — leave alone for now |
| `backend/newrelic/terraform/` | New Relic Terraform — leave alone |
| **`frontend/`** | **This Vercel spike — alternative to both of the above** |

The repo currently has *three* observability paths in flight. After Day 3 of
the Vercel spike you should pick one to keep and delete the other two.
