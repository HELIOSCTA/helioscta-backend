# helioscta-gas-frontend

Next.js 15 + TypeScript dashboard for HeliosCTA gas data. Lives under
`frontend/` in the `helioscta-backend` monorepo (imported 2026-05-13).

See [`CLAUDE.md`](./CLAUDE.md) for layout, conventions, and standards.

## Quick start

```bash
cd frontend
npm install
npm run dev
```

## Deploy

Pushes to `main` deploy to Vercel production; pushes to
`backend-cleanup` deploy preview URLs. Workflow:
[`.github/workflows/frontend-deploy.yml`](../.github/workflows/frontend-deploy.yml).
