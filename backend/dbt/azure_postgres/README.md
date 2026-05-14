# backend/dbt/azure_postgres/

dbt project used **in compile-only mode** against Azure Postgres.
The job of this project is to template + validate mart SQL and emit
rendered, executable Postgres. We do not `dbt run`.

## What it's for

- **`{{ source(...) }}` resolution** — catches typos in source table
  names at compile time, before SQL ever hits the warehouse.
- **One canonical source declaration** — `models/sources.yml`.
- **`dbt parse`** — fast, offline Jinja + YAML validation.
- **`dbt compile`** — renders a model to executable SQL in
  `target/compiled/helioscta_marts/models/...`. Hits Postgres once to
  warm the relation cache, then offline.

## What it isn't

- A materialization manager. Compiled views/tables are applied to
  Postgres manually (paste the compiled output, wrap in
  `CREATE OR REPLACE VIEW`).
- A migration tool. Schema migrations live in
  `backend/database/<source>/` as plain `.sql`.

## Setup (one time)

### 1. Install dbt

`dbt-core` and `dbt-postgres` are declared in the
`transformations (local-only)` section of `backend/requirements.txt`
(stripped out of `Dockerfile.prefect`).

```powershell
pip install -e backend
pip install -r backend/requirements.txt
```

### 2. Create the read-only Postgres role

The script `create_dbt_readonly_role.sql` in this folder creates
`dbt_readonly` and grants USAGE + SELECT on every user schema in the
database (loops over `information_schema.schemata`, idempotent,
re-runnable when new schemas land). The password is hardcoded; both
this file and `profiles.yml` are gitignored.

```powershell
psql "host=heliosctadb.postgres.database.azure.com dbname=helioscta user=<admin> sslmode=require" `
     -v ON_ERROR_STOP=1 `
     -f backend/dbt/azure_postgres/create_dbt_readonly_role.sql
```

### 3. Verify the connection

```powershell
dbt debug --project-dir backend/dbt/azure_postgres `
          --profiles-dir backend/dbt/azure_postgres
```

## Commands

All run from the repo root.

```powershell
# Parse + Jinja-validate. Zero queries against Postgres. Fastest.
dbt parse --project-dir backend/dbt/azure_postgres `
          --profiles-dir backend/dbt/azure_postgres

# Compile one model. Hits information_schema once, then offline.
dbt compile --project-dir backend/dbt/azure_postgres `
            --profiles-dir backend/dbt/azure_postgres `
            --select pmi_k26_ius_wide

# Compiled output lands here:
#   backend/dbt/azure_postgres/target/compiled/helioscta_marts/
#       models/ice_python/pmi_k26_ius_wide.sql

# Spot-check against prod (runs SELECT … LIMIT 10).
dbt show --project-dir backend/dbt/azure_postgres `
         --profiles-dir backend/dbt/azure_postgres `
         --select pmi_k26_ius_wide --limit 10
```

The compiled `.sql` is plain Postgres — paste it into your client and
apply as `CREATE OR REPLACE VIEW <schema>.<name> AS <compiled>` when
the shape looks right.

### What you should never do

```powershell
# Don't. The read-only role will reject it, but mistakes happen.
dbt run   --project-dir backend/dbt/azure_postgres --profiles-dir backend/dbt/azure_postgres
dbt build --project-dir backend/dbt/azure_postgres --profiles-dir backend/dbt/azure_postgres
```

To move to materializations later, add a separate `prod_write` target
with a role that has CREATE/INSERT — don't escalate `dbt_readonly`.

## Layout

```
backend/dbt/azure_postgres/
├── dbt_project.yml                  project config, paths, default materialization
├── profiles.yml                     [gitignored] hardcoded readonly creds
├── create_dbt_readonly_role.sql     [gitignored] one-time role + grants script
├── README.md                        this file
├── .gitignore                       inner ignore (target/, dbt_packages/, logs/)
├── models/
│   ├── sources.yml                  canonical declaration of source tables
│   └── ice_python/                  one folder per UNDERLYING SCHEMA
│       └── pmi_k26_ius_wide.sql     PMI K26-IUS wide view
├── target/                          [gitignored] compiled SQL output
└── logs/                            [gitignored] dbt CLI logs
```

### Model layout convention

Models are organized **by source schema**, not by layer (no
`staging/`, `intermediate/`, `marts/`). Each subdirectory under
`models/` mirrors a Postgres source schema and contains the views
that draw from it. When a new source needs marts, add a folder
(`eia/`, `pjm/`, …) and a matching block under `models:` in
`dbt_project.yml` so dbt knows where to land compiled DDL.
