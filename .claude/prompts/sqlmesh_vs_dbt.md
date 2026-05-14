# SQLMesh vs DBT: Moving to Local-First Transformations

## The problem

DBT-built views and tables clutter the production warehouse. The goal is to:

1. Move away from DBT entirely.
2. Develop and test transformations locally, not against a production schema.
3. Keep Postgres as the production target (this stack is Azure PostgreSQL, with real-time-ish dashboards reading at request time — DuckDB/Parquet is not a viable production read path here).

## Recommended stack

**DuckDB + SQLMesh + pytest**, deploying SQL to Postgres in production.

- **DuckDB** is the local engine. Single binary, no server, reads Parquet/CSV/Postgres directly. SQL dialect is close enough to Postgres that the same model usually runs in both with no changes. This is what makes "test locally" actually fast — milliseconds, no network.
- **SQLMesh** is the transformation framework. The same model files run against DuckDB locally and Postgres in production via its adapter system. It provides DBT's shape (models, dependencies, tests, incremental materialization, lineage) but is Python-native and was built around local-first development.
- **pytest** runs the tests. SQLMesh has its own audit/test syntax, but plain pytest tests can also load fixtures into DuckDB, run a model, and assert on the output.

Together this covers every DBT capability worth keeping.

## Why SQLMesh and not the alternatives

| Option | Verdict |
|---|---|
| Plain Python + `psycopg` | Fine for <10 models. Painful past that — you'll re-derive DBT badly. |
| Ibis | Pleasant if the team likes DataFrame APIs, but rewriting DBT SQL into Ibis Python is significant work, and you lose the "SQL is portable, anyone can read it" property. Skip unless team strongly prefers Python. |
| Dagster | Orchestrator, not a transformation framework. Use only if you also need scheduling/retries/observability. Overkill otherwise. |
| **SQLMesh** | **DBT-shaped, Python-native, virtual environments, column-level lineage, runs against DuckDB locally and Postgres in prod from the same model files. Lowest-friction migration from DBT.** |

## What "test locally" looks like

The flow that makes this worth the switch:

1. Drop a Parquet/CSV sample of each source table into a `fixtures/` directory (or point DuckDB at a Postgres connection to pull a sample once).
2. Write the model as `models/marts/salt_facilities.sql` — plain SQL, with `@model` config at the top.
3. Run `sqlmesh plan dev` — builds the model in a virtual environment against DuckDB locally. Milliseconds.
4. Add an audit: `audits: [not_null(columns=[facility_id]), unique(columns=[facility_id, date])]`.
5. `sqlmesh test` runs unit tests with YAML-defined input/output fixtures. No warehouse needed.
6. When happy, `sqlmesh plan prod` shows the diff and applies it to Postgres.

Contrast with DBT, where "test locally" typically means "run against a dev schema in the actual warehouse." That's the friction this eliminates.

## Migration shape

For a small DBT project (<30 models), porting is mostly mechanical:

- `models/*.sql` files copy over almost verbatim.
- `{{ ref('foo') }}` becomes `@foo` or just `foo` in SQLMesh's syntax.
- `schema.yml` tests become SQLMesh audits.
- `dbt_project.yml` becomes `config.py`.

Budget roughly a day for a small project, a week for a medium one. Run both in parallel for a release or two, then cut over.

## Caveat

DuckDB and Postgres SQL dialects are similar but not identical. Window functions, date arithmetic, and JSON operations occasionally differ. SQLMesh handles most of this via its transpiler (SQLGlot), but expect a few cases where a model runs locally and fails in prod. The fix is usually one line. Don't be surprised by it.

## Recommended next step

Pick one DBT model — ideally a mart the frontend already reads (e.g., one of the `salts_v1_*.marts_v1_*` tables referenced in `sql_salt/salt.sql`) — and port it to SQLMesh + DuckDB in an afternoon. Within four hours you'll know whether the stack fits the team. If it does, the rest is mechanical. If it doesn't, half a day was spent learning cheaply.

## Pre-migration audit (do this first)

Before porting anything, inventory what's actually in the warehouse and what the app actually reads.

```sql
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname LIKE 'dbt%'
   OR schemaname LIKE 'salts%'
   OR schemaname LIKE '%_v1%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

Then grep this repo for every reference to those schemas. Typical finding: half the objects are sub-1MB staging views nobody reads — drop those, don't port them. The kill list is usually smaller than expected.

## What to keep vs drop

Most DBT projects have three layers. The right disposition of each:

- **Sources/staging (`stg_*`)** — thin renames and type casts. Often pure clutter. Convert to `VIEW` or delete and query raw directly.
- **Intermediate (`int_*`)** — joins and prep, usually only consumed by marts. Materialize as `VIEW` or inline into the mart.
- **Marts (`fct_*`, `dim_*`, `mart_*`)** — actual business logic. Keep as tables; they earn their cost.

Only the marts need to be ported to SQLMesh. Sources and intermediates are candidates for deletion.
