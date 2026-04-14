/**
 * Postgres client for the helioscta DB.
 *
 * Server-side only — this module imports `pg`, which is a CommonJS module
 * with a native binary fallback. It must NEVER be imported from a Client
 * Component. Next.js will throw a build error if you try.
 *
 * Connection pooling on Vercel:
 *   Vercel functions are short-lived and warm function instances are reused
 *   across invocations. We attach the pool to `globalThis` so a single pool
 *   survives Next.js hot reloads in dev AND warm reuse in production. Each
 *   cold-started function instance gets its own pool, which is fine at low
 *   query volume.
 *
 *   For higher volume, point DATABASE_URL at Azure Postgres's built-in
 *   PgBouncer endpoint (port 6432 on Flexible Server) so connections are
 *   pooled at the database side, not the application side.
 */

import { Pool, type QueryResult, type QueryResultRow } from "pg";

declare global {
  // eslint-disable-next-line no-var
  var __pgPool: Pool | undefined;
}

function makePool(): Pool {
  const host = process.env.AZURE_POSTGRESQL_DB_HOST;
  const port = process.env.AZURE_POSTGRESQL_DB_PORT;
  const user = process.env.AZURE_POSTGRESQL_DB_USER;
  const password = process.env.AZURE_POSTGRESQL_DB_PASSWORD;
  const database = process.env.AZURE_POSTGRESQL_DB_NAME ?? "helioscta";

  if (!host || !user || !password) {
    throw new Error(
      "Postgres config missing. Set AZURE_POSTGRESQL_DB_{HOST,USER,PASSWORD} " +
        "(and optionally _PORT and _NAME) in frontend/.env.local. These mirror " +
        "the keys in backend/.env.prod."
    );
  }

  return new Pool({
    host,
    port: port ? Number(port) : 5432,
    user,
    password,
    database,
    // Azure Postgres requires SSL. We do not verify the server cert here for
    // simplicity — the connection is still encrypted. For stricter prod
    // posture, set `ca: <azure-root-cert>` instead.
    ssl: { rejectUnauthorized: false },
    // Small pool — Vercel functions are short-lived and we want to release
    // back to Postgres quickly.
    max: 5,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 10_000,
  });
}

const pool: Pool = globalThis.__pgPool ?? makePool();

if (process.env.NODE_ENV !== "production") {
  globalThis.__pgPool = pool;
}

/**
 * Tagged-template SQL helper. Mimics the ergonomics of `@vercel/postgres` and
 * Neon's serverless driver: write SQL inline with `${param}` interpolation
 * and the helper builds a parameterised `pg` query under the hood — no
 * string concatenation, so injection-safe by construction.
 *
 * Usage:
 *
 *     const rows = await sql<{ id: number; name: string }>`
 *       SELECT id, name FROM things WHERE id = ${id}
 *     `;
 *
 * For queries with no parameters, just leave the `${...}` slots empty.
 */
export async function sql<T extends QueryResultRow = QueryResultRow>(
  strings: TemplateStringsArray,
  ...values: unknown[]
): Promise<T[]> {
  let text = strings[0];
  for (let i = 0; i < values.length; i++) {
    text += `$${i + 1}${strings[i + 1]}`;
  }
  const result: QueryResult<T> = await pool.query(text, values);
  return result.rows;
}
