# dbt Preferences

## Project Overview

- **Project**: `dbt_azure_postgresql`
- **Profile**: `dbt_azure_postgresql`
- **Database**: PostgreSQL on Azure (`heliosctadb.postgres.database.azure.com`, database `helioscta`)
- **Default schema**: `dbt` (overridden per domain)
- **Threads**: 4
- **No external packages** — only core dbt features

## Directory & Schema Conventions

### Domain Directories

Use stable cleaned naming for all new domain work:

```
models/{domain}/{domain}_cleaned/
```

Examples:

- `models/genscape/genscape_cleaned/`
- `models/power/power_cleaned/` (new work)

Rules:

- The domain folder should always end with `_cleaned`.
- Do not create new version/date-stamped domain directories.
- Existing versioned directories are legacy and should only be changed when explicitly requested.
- Schema name should match the cleaned directory name (e.g., `genscape_cleaned`).

### Layer Structure Within Each Domain

```
{domain_directory}/
  sources.yml          -- source definitions (with descriptions + freshness when applicable)
  docs/                -- dbt documentation blocks (.md files)
    overview.md        -- high-level domain overview
    sources.md         -- source table documentation
    staging.md         -- staging model documentation
    marts.md           -- mart model documentation (optional but recommended)
    columns.md         -- reusable column-level documentation
  source/              -- raw source extracts (EPHEMERAL)
    schema.yml         -- model + column descriptions and tests
  staging/             -- transformations (EPHEMERAL)
    schema.yml         -- model + column descriptions and tests
  marts/               -- business-ready outputs (VIEW)
    schema.yml         -- model + column descriptions and tests
  queries/             -- ad-hoc analysis (EPHEMERAL, optional)
  utils/               -- reference/utility models (EPHEMERAL, optional)
```

### Legacy Persisted Utilities

Some older utility models may still exist as persisted database objects. Treat these as legacy exceptions.

Rule for new work: do not introduce new persisted non-mart models.

## File Naming

| Layer   | Pattern                                                  | Example                                              |
| ------- | -------------------------------------------------------- | ---------------------------------------------------- |
| Source  | `source_{version}_{source_name}.sql`                     | `source_v2_daily_pipeline_production.sql`             |
| Staging | `staging_{version}_{entity}[_{step_number}_{step}].sql`  | `staging_v2_genscape_gas_production_forecast.sql`     |
| Marts   | `{domain}_{entity}.sql`                                  | `genscape_daily_pipeline_production.sql`              |
| Query   | `query_{version}_{analysis_name}.sql`                    | `query_v1_pjm_da_hrl_lmps_act_vs_fcst.sql`           |
| Utils   | `utils_{version}_{name}.sql`                             | `utils_v1_nerc_holidays.sql`                          |

Multi-step staging models use numbered suffixes: `_1_combined`, `_2_forward_fill`, `_3_add_cols`, `_4_exchange_codes`.

## Materialization Strategy

| Layer          | Materialization | Rationale                                  |
| -------------- | --------------- | ------------------------------------------ |
| Source         | `ephemeral`     | No DB clutter, reusable CTEs               |
| Staging        | `ephemeral`     | Intermediate transforms, no tables         |
| **Marts**      | **`view`**      | **Only layer exposed to the database**     |
| Utils          | `ephemeral`     | Helper transforms, not persisted           |
| Queries        | `ephemeral`     | Ad-hoc analysis, not persisted             |

**Rule: Only models in the `marts/` folder are materialized as database objects (views). All non-mart models must be `ephemeral`.** This keeps the database clean and predictable for downstream consumers.

Use folder-level or model-level configs so that `source/`, `staging/`, `queries/`, and `utils/` resolve to `ephemeral`, and `marts/` resolves to `view`.

## Config Block Style

Always at the top of every model file:

```sql
{{
  config(
    materialized='ephemeral'
  )
}}
```

Mart models:

```sql
{{
  config(
    materialized='view'
  )
}}
```

With optional schema override:

```sql
{{
  config(
    materialized='view',
    schema='custom_cleaned'
  )
}}
```

## SQL Style

### CTE Structure

Every model follows the CTE pattern with section headers:

```sql
{{
  config(
    materialized='ephemeral'
  )
}}

---------------------------
-- SECTION DESCRIPTION
---------------------------

WITH cte_name_1 AS (
    SELECT
        column_a,
        column_b
    FROM {{ source('source_name', 'table_name') }}
),

cte_name_2 AS (
    SELECT
        column_a,
        column_b
    FROM cte_name_1
),

FINAL AS (
    SELECT * FROM cte_name_2
)

SELECT * FROM FINAL
ORDER BY ...
```

### Formatting Rules

- **CTE names**: UPPER_SNAKE_CASE (e.g., `MAREX`, `NAV`, `FINAL`)
- **Column aliases**: lowercase snake_case for source columns, descriptive names for computed columns
- **Type casting**: Explicit PostgreSQL `::TYPE` syntax — never implicit coercions
  - `marex_date_from_sftp::DATE as sftp_date`
  - `dpqty::INTEGER as qty`
  - `ROUND(dpstrik::NUMERIC, 3) as strike_price`
- **Section separators**: `---------------------------` comment blocks between logical sections
- **Commas**: Trailing commas after every column (except last)
- **CASE statements**: Multi-line with aligned WHEN clauses
- **UNION**: Always `UNION ALL` (not `UNION`)
- **NULL safety for composites**: Wrap sub-regions in `COALESCE(..., 0)` before summing to prevent NULL propagation

### Jinja Patterns

- **References**: `{{ ref('model_name') }}` for dbt models
- **Sources**: `{{ source('source_name', 'table_name') }}` for raw tables
- **Variables**: `{% set var_name = value %}` for configurable constants (e.g., on-peak hours)
- **Documentation**: `{{ doc("doc_block_name") }}` for reusable descriptions

```jinja2
{% set onpeak_start = 8 %}
{% set onpeak_end = 23 %}

WHERE hour_ending BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
```

## Sources Configuration

Each domain has its own `sources.yml` with descriptions:

```yaml
version: 2

sources:
  - name: genscape_v2
    schema: genscape
    description: '{{ doc("genscape_overview") }}'
    tables:
      - name: gas_production_forecast_v2_2025_09_23
        description: '{{ doc("genscape_source") }}'
      - name: daily_pipeline_production
        description: '{{ doc("genscape_daily_pipeline_production_source") }}'
```

- **Source name**: `{system}_{version}` (e.g., `genscape_v2`, `pjm_v1`)
- **Schema**: Actual database schema (e.g., `genscape`, `pjm`, `clear_street`)
- **Table name**: Exact raw table name including version and date stamp
- **Descriptions**: Required on both the source group and each table, using `{{ doc() }}` blocks

## Documentation Standards

**Documentation is required for all models and all columns.**

### Documentation Structure

Each domain must include a `docs/` folder with:

| File | Purpose |
|------|---------|
| `overview.md` | High-level domain overview: data sources, pipeline architecture, geographic/dimensional hierarchy, metrics, revision tracking |
| `sources.md` | Raw source table documentation: column inventory, primary keys, ingestion details |
| `staging.md` | Staging model documentation: grain, key transformations, output column reference |
| `marts.md` | Mart model documentation: business grain, consumer-facing metrics, and usage guidance |
| `columns.md` | Reusable column-level `{% docs %}` blocks referenced via `{{ doc() }}` in schema.yml |

### Doc Block Convention

Use `{% docs block_name %}` / `{% enddocs %}` in markdown files:

```markdown
{% docs genscape_col_date %}
The forecast target date, derived from the `month` field in the raw data.
{% enddocs %}
```

Reference in `schema.yml`:

```yaml
columns:
  - name: date
    description: '{{ doc("genscape_col_date") }}'
```

### Schema YAML Files

Each layer folder (`source/`, `staging/`, `marts/`) must have a `schema.yml` with:

1. **Model-level description** for every model
2. **Column-level description** for every column (using `{{ doc() }}` blocks or inline strings)
3. **Tests** where applicable (see Testing section)

## Testing Standards

Tests must be added where applicable. Every `schema.yml` should include relevant tests.

### Required Tests

| Test | When to Use |
|------|-------------|
| `not_null` | Primary key columns, date columns, dimension columns |
| `unique` | Natural keys, surrogate keys |
| `accepted_values` | Categorical/enum columns (e.g., region names, item types) |
| `relationships` | Foreign key references between models |

### Example

```yaml
models:
  - name: source_v2_genscape_gas_production_forecast
    columns:
      - name: region
        tests:
          - not_null
          - accepted_values:
              values: ['Lower 48', 'Gulf of Mexico - Deepwater', ...]
      - name: date
        tests:
          - not_null
```

### Source Freshness (when relevant)

Add `loaded_at_field` and `freshness` blocks to sources that are updated on a known schedule:

```yaml
sources:
  - name: pjm_v1
    tables:
      - name: da_hrl_lmps
        loaded_at_field: updated_at
        freshness:
          warn_after: { count: 24, period: hour }
          error_after: { count: 48, period: hour }
```

## Common Business Logic Patterns

### Revision Tracking

For data sources with multiple reports per observation date, add revision tracking in the **staging** layer (not the source layer):

```sql
WITH source AS (
    SELECT * FROM {{ ref('source_v2_daily_pipeline_production') }}
),
revisions AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY date ORDER BY report_date) as revision
    FROM source
),
max_revisions AS (
    SELECT *,
        MAX(revision) OVER (PARTITION BY date) AS max_revision
    FROM revisions
)
SELECT * FROM max_revisions
```

- `revision = 1` is the oldest report; `revision = max_revision` is the latest
- Partition by the observation grain (e.g., `date`), order by the report date

### Hourly Models — `datetime` Column

Every hourly staging/query model that has `date` and `hour_ending` must include a combined `datetime` as the **first column**:

```sql
date + (hour_ending || ' hours')::interval AS datetime
```

For simple SELECTs, add it directly. For CTE-based models ending with `SELECT * FROM CTE`, use:

```sql
SELECT
    date + (hour_ending || ' hours')::interval AS datetime,
    *
FROM CTE
```

Forecast models that already have `forecast_datetime` are excluded from this convention.

### Lookup Joins

Account names, product codes, and exchange codes are resolved via LEFT JOIN to lookup tables in the `dbt` schema:

```sql
LEFT JOIN {{ ref('source_v1_positions_and_trades_accounts_lookup') }} AS accounts
    ON raw.account_code = accounts.account_code
```

### Forward Fill (Window Functions)

For filling nulls from earlier rows:

```sql
SUM(CASE WHEN field IS NOT NULL THEN 1 ELSE 0 END) OVER (
    PARTITION BY key_cols ORDER BY date_col
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS ignore_nulls_group,

MAX(field) OVER (
    PARTITION BY key_cols, ignore_nulls_group
) AS field_filled
```

### On-Peak / Off-Peak Aggregations

Define periods with Jinja variables, then UNION ALL flat/onpeak/offpeak:

```sql
{% set onpeak_start = 8 %}
{% set onpeak_end = 23 %}

-- FLAT (all hours)
SELECT 'FLAT' AS period, ... FROM hourly_data
UNION ALL
-- ONPEAK (hours 8-23)
SELECT 'ONPEAK' AS period, ... FROM hourly_data
WHERE hour_ending BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
UNION ALL
-- OFFPEAK
SELECT 'OFFPEAK' AS period, ... FROM hourly_data
WHERE hour_ending NOT BETWEEN {{ onpeak_start }} AND {{ onpeak_end }}
```

### Inline Lookup Tables (VALUES)

For small static mappings:

```sql
futures_month_lookup AS (
    SELECT * FROM (VALUES
        (1, 'Jan', 'F'),
        (2, 'Feb', 'G'),
        (3, 'Mar', 'H')
    ) AS t(month_number, month_name, contract_code)
)
```

### Time Zone Handling

Always explicit PostgreSQL time zone conversion:

```sql
(CURRENT_TIMESTAMP AT TIME ZONE 'MST')::DATE
datetime_col AT TIME ZONE 'US/Eastern'
```

## Macros

### `generate_schema_name.sql`

Routes models to their configured schema (not prefixed with target schema):

```jinja2
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

### Index Creation (`create_source_indexes.sql`)

- Run manually: `dbt run-operation create_source_indexes`
- Not run during `dbt run`
- ISO-specific index macros in `macros/create_indexes/power/iso/{iso}/{iso}.sql`
- Uses `CREATE INDEX IF NOT EXISTS` pattern

### PostgreSQL Triggers (`postgres_triggers/`)

- Triggered on every `dbt run` via `on-run-end` hook in `dbt_project.yml`
- `setup_postgres_triggers.sql` orchestrates ISO-specific trigger macros
- Triggers use `pg_notify` for LISTEN/NOTIFY event-driven architecture
- Statement-level triggers fire on INSERT when data completeness conditions are met

## Seeds

CSV seed files go in `seeds/{versioned_directory}/` with schema config in `dbt_project.yml`:

```yaml
seeds:
  dbt_azure_postgresql:
    dbt_wsi_temps_v1_2026_feb_25:
      +schema: dbt_wsi_temps_v1_2026_feb_25
```

## Data Flow Pattern

```
Raw Source Tables (system schemas: genscape, pjm, marex, etc.)
  |
  v
source/ (EPHEMERAL) -- extract, cast, normalize, compute composites
  |
  v
staging/ (EPHEMERAL) -- revision tracking, multi-step transforms
  |
  v
marts/ (VIEW) -- business-ready outputs, only layer in the database
```

