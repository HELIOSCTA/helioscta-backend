# Migration Plan — `.refactor/dbt_criterion_postgresql` → `criterion_cleaned`

> Generated: 2026-03-12

## Goal

Migrate 6 active-candidate SQL files from the legacy `.refactor/dbt_criterion_postgresql/` directory into a properly structured `criterion_cleaned` dbt domain following project conventions in `.SKILLS/dbt-preferences.md`.

## Target Structure

```
backend/dbt/dbt_azure_postgresql/models/criterion/criterion_cleaned/
├── sources.yml
├── docs/
│   ├── overview.md
│   ├── sources.md
│   ├── staging.md
│   ├── columns.md
├── source/
│   ├── schema.yml
│   ├── source_v1_criterion_data_series.sql          -- ticker flattening wrapper
│   └── source_v1_criterion_pipeline_nominations.sql  -- pipeline nominations extract
├── staging/
│   ├── schema.yml
│   ├── staging_v1_criterion_l48_supply_demand_daily.sql
│   ├── staging_v1_criterion_lng_facilities_daily.sql
│   ├── staging_v1_criterion_lng_total_daily.sql
│   ├── staging_v1_criterion_freeport_lng_daily.sql
│   └── staging_v1_criterion_production_regional_daily.sql
├── utils/
│   └── utils_v1_criterion_dates_daily.sql            -- NERC holidays + date dimension
└── marts/
    ├── schema.yml
    ├── criterion_l48_supply_demand_daily.sql
    ├── criterion_lng_facilities_daily.sql
    ├── criterion_lng_total_daily.sql
    ├── criterion_freeport_lng_daily.sql
    ├── criterion_production_regional_daily.sql
    └── criterion_dates_daily.sql
```

## Phase 1: Scaffolding (no DB required)

### 1.1 Add Criterion to `dbt_project.yml`

```yaml
    # ── Criterion ──────────────────────────────────────────────────────────────
    criterion:
      criterion_cleaned:
        +schema: criterion_cleaned
        +materialized: ephemeral
        source:
          +materialized: ephemeral
        staging:
          +materialized: ephemeral
        utils:
          +materialized: ephemeral
        marts:
          +materialized: view
```

### 1.2 Create `sources.yml`

Define two source groups:
- `criterion_data_series_v1` → schema: `data_series`, tables: `financial_metadata`
- `criterion_pipelines_v1` → schema: `pipelines`, tables: `nomination_points`, `metadata`, `regions`

### 1.3 Create documentation files

- `docs/overview.md` — domain overview (from data_catalogue.md §1)
- `docs/sources.md` — source table docs (from data_catalogue.md §1-2)
- `docs/staging.md` — staging model docs (from data_catalogue.md §4)
- `docs/columns.md` — reusable column doc blocks

## Phase 2: Port PostgreSQL Models (4 files)

These files already use PostgreSQL syntax and can be adapted directly:

| Legacy File | New File | Key Changes |
|-------------|----------|-------------|
| `source_v1_criterion_freeport.sql` | `source/source_v1_criterion_pipeline_nominations.sql` + `staging/staging_v1_criterion_freeport_lng_daily.sql` | Split into source extract + staging transform. Replace hard-coded ticker arrays with Jinja variables. Add `{{ source() }}` refs. |
| `source_v1_criterion_lng_facilities.sql` | `staging/staging_v1_criterion_lng_facilities_daily.sql` | Convert `FLATTEN_JSON_TICKERS` → `fin_json_to_excel_tickers`. Add config block. Replace date functions. |
| `source_v1_criterion_lng_total.sql` | `staging/staging_v1_criterion_lng_total_daily.sql` | Same as above. Consider parameterizing the 7-day window. |
| `source_v1_criterion_prod.sql` | `staging/staging_v1_criterion_production_regional_daily.sql` | Direct port — already PG syntax. Add config block + `{{ source() }}` refs. |

## Phase 3: Port Snowflake-Only Models (2 files)

These require Snowflake → PostgreSQL translation:

| Legacy File | New File | Translation Required |
|-------------|----------|---------------------|
| `criterion_l48_supply_demand.sql` | `staging/staging_v1_criterion_l48_supply_demand_daily.sql` | `FLATTEN_JSON_TICKERS()` → `fin_json_to_excel_tickers()`. `DATEADD(DAY, ...)` → `interval` arithmetic. `CONVERT_TIMEZONE('America/Denver', ...)` → `AT TIME ZONE 'MST'`. `CURRENT_TIMESTAMP()` → `CURRENT_TIMESTAMP`. |
| `criterion_l48_supply_demand_dates.sql` | `utils/utils_v1_criterion_dates_daily.sql` | `GENERATOR(ROWCOUNT=>10000)` + `SEQ4()` → `generate_series()`. `DAYOFWEEK()` → `EXTRACT(DOW FROM ...)`. `MONTHNAME()` → `TO_CHAR(date, 'Month')`. `DAYOFWEEKISO()` → `EXTRACT(ISODOW FROM ...)`. Remove `FLATTEN` syntax. |

### Snowflake → PostgreSQL Translation Cheat Sheet

| Snowflake | PostgreSQL |
|-----------|-----------|
| `DATEADD(DAY, n, date)` | `date + n * INTERVAL '1 day'` |
| `CONVERT_TIMEZONE('America/Denver', ts)` | `ts AT TIME ZONE 'America/Denver'` |
| `CURRENT_TIMESTAMP()` | `CURRENT_TIMESTAMP` |
| `GENERATOR(ROWCOUNT => N)` + `SEQ4()` | `generate_series(0, N-1)` |
| `DAYOFWEEK(date)` | `EXTRACT(DOW FROM date)` |
| `DAYOFWEEKISO(date)` | `EXTRACT(ISODOW FROM date)` |
| `MONTHNAME(date)` | `TO_CHAR(date, 'Month')` |
| `FLATTEN_JSON_TICKERS(ARRAY[...])` | `fin_json_to_excel_tickers(ARRAY[...])` |

## Phase 4: Mart Models

Each mart is a thin wrapper:
```sql
{{
  config(
    materialized='view'
  )
}}

SELECT * FROM {{ ref('staging_v1_criterion_l48_supply_demand_daily') }}
ORDER BY date DESC
```

Mart models may add:
- Column renaming for consumer clarity
- Final ORDER BY
- Additional filtering (e.g., date >= '2020-01-01')

## Phase 5: Schema & Tests

Add to `staging/schema.yml` and `marts/schema.yml`:
- Model-level descriptions
- Column-level descriptions (via `{{ doc() }}` blocks)
- Tests: `not_null` on date columns, `accepted_values` on region columns

## Phase 6: DB Introspection (Expands Catalogue)

With MCP database access, run the introspection queries from `data_catalogue.md` §8 to:
1. Discover additional schemas/tables beyond `data_series` and `pipelines`
2. Get full column inventories for `pipelines.metadata` and `pipelines.regions`
3. Map Excel model domains to available tickers/tables
4. Identify storage, Canadian, and pipeline flow data sources

## Files to Drop (Not Migrated)

| File | Reason |
|------|--------|
| `.data_series/Criterion Metadata.sql` | Ad-hoc exploratory query, not a model |
| `sources_v1_dates_daily.sql` | Superseded by full date dimension |
| `source_v1_criterion_lng_facilities.sql` (Snowflake) | PG version exists |
| `source_v1_criterion_prod.sql` (Snowflake) | PG version exists |

## Execution Order

```
1. Phase 1 (scaffolding)        — no dependencies
2. Phase 2 (PG ports)           — depends on Phase 1
3. Phase 3 (SF→PG translation)  — depends on Phase 1
4. Phase 4 (marts)              — depends on Phases 2+3
5. Phase 5 (schema/tests)       — depends on Phase 4
6. Phase 6 (DB introspection)   — independent, can run in parallel
```

Phases 2 and 3 can run in parallel. Phase 6 can start at any time and will feed back into the data catalogue and potentially create new models.
