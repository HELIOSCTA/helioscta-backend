# WM NatGas DataFeed: dbt Migration & Scheduler Setup Plan

**Date:** 2026-03-12
**Status:** Planning
**References:**
- Legacy dbt code: `.refactor/dbt_azure_sql/`
- Vendor docs/scripts: `.vendor-docs/wm_natgasdatafeed_import/`
- dbt conventions: `.SKILLS/dbt-preferences.md`
- Scheduler conventions: `.SKILLS/task_scheduling.md`
- Orchestration rubric: `.SKILLS/scheduled_vs_event_driven.md` (Section 8)
- Scheduler target folder: `schedulers/task_scheduler_azuresql/`
- Existing scheduler conventions: `schedulers/task_scheduler_azurepostgresql/`

---

## 1) Current-State Inventory

### Legacy Models (`.refactor/dbt_azure_sql/`) -- Grouped by Domain

| Domain | Schema (Legacy) | Models | Layer | Materialization | Source DB |
|--------|----------------|--------|-------|-----------------|-----------|
| **Utilities** | `dbt` | `source_v1_nerc_holidays` | source | `table` | -- (hardcoded VALUES) |
| **Utilities** | `dbt` | `sources_v1_gas_day_daily` | source | `table` | -- (generated series) |
| **LNG** | `lng_v1_2026_jan_02` | `source_v1_lng_noms` | source | `view` | `natgas.nominations` + inline lookups |
| **LNG** | `lng_v1_2026_jan_02` | `staging_v1_lng_facilities` | staging | `view` | refs `source_v1_lng_noms` |
| **Noms** | `noms_v1_2026_jan_02` | `source_v1_genscape_noms` | source | `view` | `natgas_v1.*` (6 tables) |
| **SALTS** | `salts_v1_2026_jan_08` | `source_v1_salts_refence_table` | source | `table` | -- (hardcoded VALUES) |
| **SALTS** | `salts_v1_2026_jan_08` | `source_v1_salts_inventories_refence_table` | source | `table` | -- (hardcoded VALUES) |
| **SALTS** | `salts_v1_2026_jan_08` | `staging_v1_salts_noms` | staging | `view` | refs source lookup |
| **SALTS** | `salts_v1_2026_jan_08` | `staging_v1_salts_inventories` | staging | `view` | refs source lookup |
| **SALTS** | `salts_v1_2026_jan_08` | `marts_v1_salt_facilities_bcf` | mart | `view` | refs staging |
| **SALTS** | `salts_v1_2026_jan_08` | `marts_v1_salt_inventories` | mart | `view` | refs staging |

**Upstream Raw Tables** (from `natgas` schema in GenscapeDataFeed Azure SQL):
- `nominations`, `nomination_cycles`, `no_notice`, `location_role`, `location_extended`, `pipelines`
- Plus 26+ additional tables from WM NatGas DataFeed (gas_burn, gas_quality, all_cycles, pipeline_inventory, LNG tables, intrastate storage, mexico exports, springrock production)

### Gaps vs dbt Preferences

| Gap | Details |
|-----|---------|
| **Date-stamped schemas** | `lng_v1_2026_jan_02`, `noms_v1_2026_jan_02`, `salts_v1_2026_jan_08` violate stable `_cleaned` naming |
| **Source/staging materialized as views** | Preferences require `ephemeral` for all non-mart layers |
| **Reference tables materialized as `table`** | `source_v1_nerc_holidays`, `source_v1_salts_refence_table` -- should be `ephemeral` or moved to `utils/` |
| **No `docs/` folder** | Zero documentation blocks, no `schema.yml` files (except one bare `sources.yml`) |
| **No tests** | No `not_null`, `unique`, or `accepted_values` tests anywhere |
| **Missing `marts/` for LNG and Noms** | LNG and Noms domains stop at staging -- no business-ready output layer |
| **Separate dbt project** | Legacy lives in standalone `.refactor/dbt_azure_sql/` outside the main dbt project |
| **SQL Server syntax** | Legacy uses T-SQL patterns (cross-joins for date generation, `FORMAT()`, `CAST` without `::`) -- must convert to PostgreSQL if target changes |
| **Naming inconsistencies** | `sources_v1_gas_day_daily` (plural prefix), `salts_refence_table` (typo "refence" -> "reference") |
| **Config block style** | Some models lack the standard `{{ config(...) }}` Jinja block |

---

## 2) Target-State Design

### Database Target Decision

The WM NatGas DataFeed currently loads into **Azure SQL Server** (`GenscapeDataFeed.natgas`). The existing dbt project (`dbt_azure_postgresql`) already has both targets in `profiles.yml`:
- `azure_postgres` -> `heliosctadb.postgres.database.azure.com` (primary)
- `azure_sql` -> `heliosazuresql.database.windows.net` (GenscapeDataFeed)

**Recommendation**: Keep dbt models targeting Azure SQL for now since that's where the raw WM data lives. Create the cleaned domain structure under the existing dbt project using the `azure_sql` target. A future phase can replicate marts to PostgreSQL if needed.

### Proposed Folder Tree

```
backend/dbt/dbt_azure_postgresql/
  models/
    natgas/
      natgas_cleaned/
        sources.yml                          -- WM NatGas DataFeed source definitions
        docs/
          overview.md                        -- Domain overview: WM feed, pipeline arch, hierarchy
          sources.md                         -- Raw table documentation
          staging.md                         -- Staging model documentation
          marts.md                           -- Mart model documentation
          columns.md                         -- Reusable column doc blocks
        utils/
          schema.yml
          utils_v1_nerc_holidays.sql         -- NERC holidays (ephemeral, VALUES-based)
          utils_v1_gas_day_daily.sql         -- Gas day date spine (ephemeral, generated)
        source/
          schema.yml
          source_v1_genscape_noms.sql        -- Nominations + enrichment
          source_v1_lng_noms.sql             -- LNG facility nominations
          source_v1_salts_noms.sql           -- SALTS nominations reference
          source_v1_salts_inventories.sql    -- SALTS inventory reference
          source_v1_gas_burn.sql             -- (future) gas burn hourly
          source_v1_gas_quality.sql          -- (future) gas quality daily
          source_v1_all_cycles.sql           -- (future) all nomination cycles
          source_v1_pipeline_inventory.sql   -- (future) pipeline inventory weekly
        staging/
          schema.yml
          staging_v1_genscape_noms.sql       -- Noms staging (if transforms needed)
          staging_v1_lng_facilities.sql      -- LNG terminal/pipeline staging
          staging_v1_salts_noms.sql          -- SALTS noms with facility lookups
          staging_v1_salts_inventories.sql   -- SALTS inventory with facility lookups
        marts/
          schema.yml
          natgas_genscape_noms.sql           -- Business-ready nominations
          natgas_lng_facilities.sql          -- Business-ready LNG facilities
          natgas_salt_facilities_bcf.sql     -- SALTS daily facility aggregations
          natgas_salt_inventories.sql        -- SALTS inventory & capacity metrics
```

### Model Naming & Schema Strategy

| Element | Convention | Example |
|---------|-----------|---------|
| **Domain folder** | `natgas/natgas_cleaned/` | Stable, no dates |
| **Schema** | `natgas_cleaned` | Via `config(schema='natgas_cleaned')` on marts |
| **Source name** | `natgas_v1` | In `sources.yml` |
| **Source layer** | `source_v1_{entity}.sql` | `source_v1_genscape_noms.sql` |
| **Staging layer** | `staging_v1_{entity}.sql` | `staging_v1_salts_noms.sql` |
| **Marts layer** | `natgas_{entity}.sql` | `natgas_salt_facilities_bcf.sql` |
| **Utils** | `utils_v1_{name}.sql` | `utils_v1_nerc_holidays.sql` |

### View Exposure Strategy

- **Only marts are materialized** as views in the `natgas_cleaned` schema
- All source, staging, and utils models are `ephemeral`
- **Stable mart names** are the public interface: `natgas_salt_facilities_bcf`, `natgas_salt_inventories`, `natgas_genscape_noms`, `natgas_lng_facilities`
- Old versioned views (`salts_v1_2026_jan_08.*`, `lng_v1_2026_jan_02.*`, `noms_v1_2026_jan_02.*`) are kept alive during transition via `CREATE VIEW ... AS SELECT * FROM natgas_cleaned.{new_mart}` aliases, then dropped after cutover confirmation

---

## 3) Migration Mapping

| Current Object | Target Model | Target Schema | Materialization | Migration Action |
|----------------|-------------|---------------|-----------------|-----------------|
| `dbt.source_v1_nerc_holidays` | `utils_v1_nerc_holidays` | -- (ephemeral) | `ephemeral` | **Replace** -- convert T-SQL VALUES to PostgreSQL-compatible, move to `utils/` |
| `dbt.sources_v1_gas_day_daily` | `utils_v1_gas_day_daily` | -- (ephemeral) | `ephemeral` | **Replace** -- rewrite date generator using `generate_series()` (PostgreSQL), move to `utils/` |
| `noms_v1_2026_jan_02.source_v1_genscape_noms` | `source_v1_genscape_noms` | -- (ephemeral) | `ephemeral` | **Replace** -- convert to ephemeral, add schema.yml + docs |
| `lng_v1_2026_jan_02.source_v1_lng_noms` | `source_v1_lng_noms` | -- (ephemeral) | `ephemeral` | **Replace** -- convert to ephemeral, add schema.yml + docs |
| `lng_v1_2026_jan_02.staging_v1_lng_facilities` | `staging_v1_lng_facilities` | -- (ephemeral) | `ephemeral` | **Replace** -- convert to ephemeral, add schema.yml + docs |
| `salts_v1_2026_jan_08.source_v1_salts_refence_table` | `source_v1_salts_noms` | -- (ephemeral) | `ephemeral` | **Replace** -- fix typo, merge lookup into ephemeral source, add docs |
| `salts_v1_2026_jan_08.source_v1_salts_inventories_refence_table` | `source_v1_salts_inventories` | -- (ephemeral) | `ephemeral` | **Replace** -- merge lookup into ephemeral source, add docs |
| `salts_v1_2026_jan_08.staging_v1_salts_noms` | `staging_v1_salts_noms` | -- (ephemeral) | `ephemeral` | **Replace** -- convert to ephemeral |
| `salts_v1_2026_jan_08.staging_v1_salts_inventories` | `staging_v1_salts_inventories` | -- (ephemeral) | `ephemeral` | **Replace** -- convert to ephemeral |
| `salts_v1_2026_jan_08.marts_v1_salt_facilities_bcf` | `natgas_salt_facilities_bcf` | `natgas_cleaned` | `view` | **Replace** -- rename to stable mart name, add docs + tests |
| `salts_v1_2026_jan_08.marts_v1_salt_inventories` | `natgas_salt_inventories` | `natgas_cleaned` | `view` | **Replace** -- rename to stable mart name, add docs + tests |
| *(new)* | `natgas_genscape_noms` | `natgas_cleaned` | `view` | **Create** -- new mart wrapping noms staging |
| *(new)* | `natgas_lng_facilities` | `natgas_cleaned` | `view` | **Create** -- new mart wrapping LNG staging |
| `noms_v1_2026_jan_02.*` views | -- | -- | -- | **Deprecate** -- alias -> drop after cutover |
| `lng_v1_2026_jan_02.*` views | -- | -- | -- | **Deprecate** -- alias -> drop after cutover |
| `salts_v1_2026_jan_08.*` views | -- | -- | -- | **Deprecate** -- alias -> drop after cutover |

---

## 4) Phased Execution Plan

### Phase 0: Preparation (no database changes)

**Steps:**
1. Create `natgas_cleaned/` directory tree with empty scaffold (folders, empty `.yml` skeletons)
2. Write `docs/` files: `overview.md`, `sources.md`, `staging.md`, `marts.md`, `columns.md`
3. Write `sources.yml` defining `natgas_v1` source with all WM tables and descriptions
4. Convert T-SQL syntax to PostgreSQL for all model SQL (if targeting PostgreSQL) or validate SQL Server compatibility (if keeping azure_sql target)
5. Update `dbt_project.yml` with natgas_cleaned schema routing and materialization defaults

**Validation:**
- `dbt parse` succeeds with no errors
- Directory structure matches dbt-preferences.md

**Rollback:** Delete the new folder -- no database objects created.

### Phase 1: Utils + Source Layer

**Steps:**
1. Implement `utils_v1_nerc_holidays.sql` and `utils_v1_gas_day_daily.sql` as ephemeral
2. Implement all `source/` models as ephemeral with `schema.yml` and doc references
3. Add `not_null` and `accepted_values` tests to source schema.yml

**Validation:**
- `dbt compile` succeeds -- ephemeral CTEs resolve
- `dbt test --select tag:source` passes

**Rollback:** Remove source files -- no database objects created (ephemeral only).

### Phase 2: Staging Layer

**Steps:**
1. Implement all `staging/` models as ephemeral
2. Add `schema.yml` with column descriptions and tests
3. Wire staging models to source layer via `{{ ref() }}`

**Validation:**
- `dbt compile` succeeds
- `dbt test --select tag:staging` passes

**Rollback:** Remove staging files -- still ephemeral only.

### Phase 3: Marts Layer (New Views Created)

**Steps:**
1. Implement all `marts/` models as `view` with `schema='natgas_cleaned'`
2. Add `schema.yml` with full column docs, `not_null`/`unique` tests
3. Run `dbt run --select models/natgas/natgas_cleaned/marts/`
4. Verify views exist in `natgas_cleaned` schema

**Validation:**
- `dbt run` creates views in `natgas_cleaned` schema
- `dbt test --select models/natgas/natgas_cleaned/` -- all tests pass
- Row counts match legacy views
- Spot-check 5-10 rows per mart against legacy equivalents

**Rollback:** `DROP SCHEMA natgas_cleaned CASCADE` -- removes all new views; legacy views untouched.

### Phase 4: Backward Compatibility Aliases

**Steps:**
1. Create alias views in legacy schemas pointing to new marts:
   ```sql
   CREATE VIEW salts_v1_2026_jan_08.marts_v1_salt_facilities_bcf AS
     SELECT * FROM natgas_cleaned.natgas_salt_facilities_bcf;
   ```
2. Notify downstream consumers of deprecation timeline
3. Add `freshness` checks to sources.yml for actively-loaded tables

**Validation:**
- Legacy schema queries return identical results to new marts
- No downstream breakage reported

**Rollback:** Drop alias views, restore original legacy views from `.refactor/`.

### Phase 5: Cutover & Cleanup

**Steps:**
1. After 2-week parallel run with no issues, drop alias views
2. Drop legacy schemas (`salts_v1_2026_jan_08`, `lng_v1_2026_jan_02`, `noms_v1_2026_jan_02`)
3. Move `.refactor/dbt_azure_sql/` to `.archive/dbt_azure_sql/` for reference
4. Update all documentation

**Validation:**
- No queries reference old schema names
- `dbt docs generate` produces clean catalog

**Rollback:** Restore alias views from Phase 4 script.

---

## 5) Scheduling Plan

### 5.1 Orchestration Mode Decision -- Scored Matrix

**Context for WM NatGas DataFeed:**
- **Source type**: External vendor API (Genscape/WM REST API)
- **Publish-time behavior**: Fixed windows -- metadata hourly, deltas hourly, baselines on-demand
- **Freshness SLA**: Hourly data within 1 hour; daily data within 6 hours
- **Backfill need**: Baseline re-import for historical recovery
- **Downstream fan-out**: dbt models, internal analytics
- **API limits**: Standard rate limits, batch pagination (100K rows)
- **Failure impact**: Medium -- trading analytics delayed but not blocked

| Criterion | Scheduled | Event-Driven | Hybrid |
|-----------|:---------:|:------------:|:------:|
| Freshness/latency fit | **4** -- hourly cron matches hourly publishes | 3 -- no push notification from WM API | 4 |
| Publish-time predictability | **5** -- WM publishes on known hourly/daily cadence | 2 -- no event signal from vendor | 4 |
| Reliability and retry behavior | **4** -- simple cron + lookback window handles retries | 3 -- polling without push signal is fragile | 4 |
| Backfill/recovery capability | **5** -- baseline mode + date-range parameters built into API | 2 -- event-driven can't replay vendor data | 4 |
| Operational complexity | **5** -- Task Scheduler .ps1, same as all other domains | 2 -- requires listener infra for no benefit | 3 |
| Cost and API-rate-limit safety | **4** -- predictable call volume on known schedule | 3 -- polling wastes calls when nothing changed | 4 |
| Observability and on-call burden | **4** -- PipelineRunLogger + standard log pattern | 3 -- long-running listener harder to monitor | 4 |
| **Total** | **31** | **18** | **27** |

**Hard rule applies**: Upstream only supports pull and has a reliable fixed publish window with strict quotas -> **Scheduled**.

**Recommendation: Scheduled** -- The WM NatGas DataFeed is a pull-only REST API with deterministic hourly/daily publish cadence. There is no push mechanism, no webhook, and no `pg_notify` trigger on the vendor side. Scheduled mode is the clear winner.

### 5.2 Proposed Python Entrypoints

Following the standard from `.SKILLS/python-script-preferences.md` and the existing `backend/src/gas_ebbs/` pattern:

```
backend/src/natgas/
  __init__.py
  runs.py                    -- CLI runner: --list, all, numbered selection
  flows.py                   -- Orchestration (imports from individual scripts)
  wm_natgas_metadata.py      -- _pull(), _format(), _upsert(), main() for metadata
  wm_natgas_delta.py         -- _pull(), _format(), _upsert(), main() for hourly deltas
  wm_natgas_baseline.py      -- _pull(), _format(), _upsert(), main() for baseline loads
```

Each script follows the canonical pattern:
- `from backend import secrets`
- `from backend.utils import azure_postgresql_utils as azure_postgresql, logging_utils, pipeline_run_logger`
- Standard `_pull()` / `_format()` / `_upsert()` / `main()` with try/except/finally
- `PipelineRunLogger` for tracking (no Slack)

**Note**: Since the WM feed targets Azure SQL Server (not PostgreSQL), the upsert utility may need an `azure_sql_utils` variant or the existing PowerShell importer can be wrapped.

### 5.3 Matching .ps1 Registration Scripts

```
schedulers/task_scheduler_azuresql/
  natgas/
    wm_natgas_metadata.ps1       -- Hourly at :05
    wm_natgas_delta.ps1          -- Hourly at :10 and :45
    wm_natgas_baseline.ps1       -- Manual/on-demand (NOT auto-registered)
  register_all_tasks.ps1         -- Registers metadata + delta only
  delete_all_tasks.ps1           -- Removes all natgas tasks
```

**Task Scheduler registration:**

| Script | Task Name | Task Path | Trigger | Notes |
|--------|-----------|-----------|---------|-------|
| `wm_natgas_metadata.ps1` | WM NatGas Metadata | `\helioscta-backend\NatGas\` | Hourly at :05 (00:05-23:05) | Reference data: locations, pipelines, plants |
| `wm_natgas_delta.ps1` | WM NatGas Delta | `\helioscta-backend\NatGas\` | Hourly at :10 and :45 | gas_burn, nominations, no_notice, gas_quality, all_cycles |
| `wm_natgas_baseline.ps1` | -- | -- | Manual only | Full historical reload; excluded from `register_all_tasks.ps1` |

### 5.4 Cadence, Ordering, Retries, and Reconciliation

**Cadence** (matching vendor's existing schedule):

| Source Type | Cadence | Offset | Tables |
|-------------|---------|--------|--------|
| Metadata | Every 1h | :05 past hour | location_extended, location_role, pipelines, plants, nomination_cycles, scheduling_cycles |
| Delta (hourly) | Every 1h | :10, :45 past hour | gas_burn, no_notice, nominations, gas_quality, all_cycles, pipeline_inventory + proprietary |
| Baseline | On-demand | Manual trigger | All tables (full reload) |

**Ordering:**
1. Metadata runs first (:05) -- ensures reference tables are current before delta loads join against them
2. Delta runs at :10 and :45 -- two passes to catch late-arriving data within each hour
3. dbt runs after delta completes -- existing dbt scheduler (04:00, 05:00, 18:00) already covers this; add natgas models to dbt run scope

**Retry Design:**
- Each Python entrypoint: `PipelineRunLogger` tracks success/failure
- On failure: log, mark failure in pipeline_run_logger, exit non-zero
- Task Scheduler: configure "If the task fails, restart every 5 minutes, up to 3 attempts" in the .ps1 settings block
- No infinite retry -- 3 attempts max, then wait for next scheduled run

**Reconciliation / Backfill:**
- Delta scripts use `load_status.last_insert_date` as the start time for the next pull -- this is inherently self-healing (gaps are covered on next run)
- For larger gaps (outage > 24h): manually run `wm_natgas_baseline.py` for the affected source type
- Weekly reconciliation: a separate script (or `runs.py reconcile`) compares `load_status` against expected hourly cadence and logs gaps

---

## 6) Documentation & Operational Updates

### Exact Docs Files to Create/Update

| File | Action | Content |
|------|--------|---------|
| `documentation/docs/domains/natgas/overview.md` | **Create** | Domain overview: WM feed architecture, data domains (noms, LNG, SALTS, gas_burn, etc.), scheduling design |
| `documentation/docs/domains/natgas/dbt-views/natgas-cleaned.md` | **Create** | Mart catalog: each view name, grain, columns, refresh cadence |
| `documentation/docs/domains/natgas/scrapes/wm-natgas-scrapes.md` | **Create** | Script inventory, API details (no creds), entrypoint docs |
| `documentation/docs/task-scheduling.md` | **Update** | Add natgas section: task names, paths, cadence, registration/removal commands |
| `documentation/docs/dbt-cleaned-catalog.md` | **Update** | Add natgas_cleaned domain entry with mart list |

### Operator Procedures

**To register natgas scheduled tasks:**
```powershell
# Run as admin on scheduler host
.\schedulers\task_scheduler_azuresql\natgas\wm_natgas_metadata.ps1
.\schedulers\task_scheduler_azuresql\natgas\wm_natgas_delta.ps1
# Do NOT register wm_natgas_baseline.ps1 -- manual only
```

**To remove natgas tasks:**
```powershell
.\schedulers\task_scheduler_azuresql\delete_all_tasks.ps1
# Or individually:
Unregister-ScheduledTask -TaskName "WM NatGas Metadata" -TaskPath "\helioscta-backend\NatGas\" -Confirm:$false
Unregister-ScheduledTask -TaskName "WM NatGas Delta" -TaskPath "\helioscta-backend\NatGas\" -Confirm:$false
```

**To run a baseline backfill:**
```bash
conda activate helioscta-backend
python backend/src/natgas/wm_natgas_baseline.py --source gas_burn
```

**To include natgas models in dbt run:**
- Add `models/natgas/` to the dbt run scope in the existing dbt scheduler
- Or create a separate `schedulers/task_scheduler_azuresql/dbt/dbt_run_azuresql.ps1` for Azure SQL target

---

## 7) Risks, Assumptions, Open Questions

### Assumptions

| # | Assumption |
|---|-----------|
| A1 | WM NatGas raw data stays in Azure SQL (`GenscapeDataFeed.natgas`) -- no plan to replicate to PostgreSQL in this phase |
| A2 | The existing PowerShell importer (`gasdatafeed_import.ps1`) is the primary ingestion mechanism and will be wrapped/called by Python entrypoints (not rewritten) |
| A3 | The `azure_sql` target in `profiles.yml` is available and configured for dbt to run models against Azure SQL |
| A4 | Downstream consumers of legacy date-stamped views are known and can be notified of deprecation |
| A5 | The 3 legacy domains (LNG, Noms, SALTS) are the priority; additional WM tables (gas_burn, gas_quality, all_cycles, etc.) are future phases |
| A6 | dbt adapter for SQL Server (`dbt-sqlserver`) is installed and compatible with the current dbt version |

### Top Risks and Mitigations

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | **SQL dialect mismatch** -- Legacy models use T-SQL; PostgreSQL dbt project expects PostgreSQL syntax | High -- models won't compile | If targeting Azure SQL: keep T-SQL syntax. If targeting PostgreSQL: full syntax rewrite required (Phase 0 decision) |
| R2 | **Dual-database dbt project complexity** -- Running one dbt project against two different databases | Medium -- operational confusion | Consider a separate `dbt_azure_sql` project under `backend/dbt/` with its own `dbt_project.yml` and profile, clearly separated from the PostgreSQL project |
| R3 | **Vendor API credential management** -- Current `gasdatafeed_import.json` contains plaintext credentials | High -- security exposure | Migrate credentials to `backend/secrets.py` pattern (env vars); never commit JSON config with creds |
| R4 | **Backward compatibility aliases break** -- Downstream queries use `SELECT *` which may fail if column order changes | Medium -- query failures | Explicit column lists in alias views; parallel testing period |
| R5 | **PowerShell importer -> Python wrapper mismatch** -- The existing PS1 importer has complex merge/batch logic that's hard to replicate in Python | Medium -- data integrity | Option A: Keep PS1 as-is, invoke from Python via `subprocess`. Option B: Rewrite in Python with full test coverage. Recommend Option A for Phase 1 |
| R6 | **Missing dbt-sqlserver adapter** -- May not be installed or compatible | High -- blocks all dbt work on Azure SQL | Verify adapter version before starting Phase 0 |

### Open Questions (Blocking Implementation)

| # | Question | Decision Needed By | Impact |
|---|---------|-------------------|--------|
| Q1 | **Target database for dbt natgas models**: Keep in Azure SQL (where raw data lives) or replicate/transform into PostgreSQL? | Phase 0 | Determines SQL dialect, project structure, and whether a separate dbt project is needed |
| Q2 | **Python wrapper vs PowerShell-only**: Should the Python entrypoints wrap the existing `gasdatafeed_import.ps1` via subprocess, or should we rewrite the import logic in Python? | Phase 0 | Affects `backend/src/natgas/` script design and testing approach |
| Q3 | **Scope of initial migration**: Just the 3 legacy domains (LNG, Noms, SALTS), or also build source/staging models for the remaining 26+ WM tables (gas_burn, gas_quality, etc.)? | Phase 1 | Significantly changes the size of Phase 1-3 |
| Q4 | **Who are the downstream consumers** of the legacy date-stamped views? Are there dashboards, notebooks, or other dbt models referencing `salts_v1_2026_jan_08.*`? | Phase 4 | Determines alias strategy and cutover timeline |
| Q5 | **dbt-sqlserver version**: What version of dbt-sqlserver is installed? Is it compatible with dbt-core used by the PostgreSQL project? | Phase 0 | May require separate virtual environments or dbt version pinning |
| Q6 | **Separate dbt project or single project**: Should `natgas_cleaned` live under the existing `dbt_azure_postgresql` project (using the `azure_sql` target) or in a new `backend/dbt/dbt_azure_sql/` project? | Phase 0 | Affects folder structure, CI/CD, and `dbt run` scoping |
