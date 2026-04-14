# Design Document: Event-Driven vs Scheduled Scrapes

**Date:** 2026-02-25
**Status:** Draft

---

## Table of Contents

1. [Claude Prompt Template for Scheduled vs Event-Driven API Scrapes](#claude-prompt-template-for-scheduled-vs-event-driven-api-scrapes)
2. [Teammate 1: Scheduled vs Event-Driven Python Script Analysis](#teammate-1-scheduled-vs-event-driven-python-script-analysis)
3. [Teammate 2: PostgreSQL Trigger Analysis](#teammate-2-postgresql-trigger-analysis)
4. [Teammate 3: Event-Driven Implementation Plan](#teammate-3-event-driven-implementation-plan)

---

## Claude Prompt Template for Scheduled vs Event-Driven API Scrapes

Use this prompt when you want Claude to produce a concrete architecture decision instead of a generic pros/cons list.

```text
You are a senior data engineer designing data-ingestion orchestration.

Your task: decide whether this API scrape should be:
1) Scheduled
2) Event-driven
3) Hybrid (scheduled ingest + event-driven downstream)

Evaluate using the context below and return an implementation-ready recommendation.

Context:
- API/source: <describe source and endpoint behavior>
- Expected publish pattern: <fixed time / variable / unknown>
- Business SLA/SLO: <latency and freshness requirements>
- Data volume and cost constraints: <records/day, API quotas, cost sensitivity>
- Failure tolerance: <acceptable delay, data loss tolerance>
- Backfill requirements: <none / occasional / frequent>
- Downstream dependencies: <what is triggered by this data>
- Existing platform constraints: <Prefect, PostgreSQL, dbt, infra limits>

Instructions:
1. Build a decision matrix comparing Scheduled vs Event-driven vs Hybrid.
2. Score each option (1-5) for these criteria:
   - Freshness/latency fit
   - Publish-time predictability
   - Reliability and retry behavior
   - Backfill/recovery capability
   - Operational complexity
   - Cost and API-rate-limit safety
   - Observability and on-call burden
3. Recommend exactly one primary approach.
4. Provide an architecture design for the recommended approach:
   - Trigger mechanism
   - Retry + backoff policy
   - Idempotency/deduplication strategy
   - Backfill strategy
   - Monitoring/alerting
   - Failure modes and mitigations
5. Include a fallback plan (what to do if assumptions fail).

Output format (use these exact section headers):
## Recommendation
## Decision Matrix
## Proposed Design
## Risks and Mitigations
## Fallback Plan
## Open Questions

Rules:
- Do not give generic advice; tie every claim to the provided context.
- If critical data is missing, state assumptions explicitly.
- If confidence is below 80%, list the minimum additional data needed to finalize.
```

---

## Teammate 1: Scheduled vs Event-Driven Python Script Analysis

### File Locations

- **Scheduled script:** `scripts/da_hrl_lmps_scheduled.py`
- **Event-driven script:** `scripts/da_hrl_lmps_event_driven.py`
- **Scheduled Prefect deployment YAML:** `scripts/prefect_da_hrl_lmps_event_scheduled.yaml`
- **Event-driven Prefect deployment YAML:** `scripts/prefect_da_hrl_lmps_event_driven.yaml`
- **PostgreSQL trigger function:** `scripts/pjm_da_hrl_lmps.sql`

---

### 1. Scheduled Script (`da_hrl_lmps_scheduled.py`)

#### 1.1 Overall Structure and Flow

The scheduled script follows a **batch-loop** pattern. It is a single Prefect flow that iterates over a date range (defaulting to the past 7 days through tomorrow), pulls data one day at a time from the PJM API, and upserts each day's data into Azure PostgreSQL.

**Structural components:**
1. **Imports and constants** -- standard library, `requests`, `pandas`, Prefect, and internal utilities (`azure_postgresql`, `logging_utils`, `slack_utils`, `settings`).
2. **`_pull(start_date, end_date)`** -- Constructs the PJM API URL inline (including a hardcoded subscription key), makes a single `requests.get()`, reads the CSV response into a DataFrame, strips BOM characters from column names, and converts datetime columns.
3. **`_upsert(df, schema, table_name, primary_key)`** -- Infers SQL data types from the DataFrame and calls an internal `upsert_to_azure_postgresql` utility.
4. **`main(start_date, end_date, delta)` (Prefect `@flow`)** -- The orchestration entry point. Loops day-by-day from `start_date` to `end_date`, calling `_pull` then `_upsert` for each day.

#### 1.2 How Data Fetching Is Triggered

- **Cron schedule:** The Prefect deployment YAML schedules the flow at `cron: "0 14-16 * * *"` in `America/Edmonton`, meaning it runs at the top of the hour at 2 PM, 3 PM, and 4 PM Edmonton time every day.
- **Retries at the Prefect level:** The `@flow` decorator includes `retries=2, retry_delay_seconds=60`, so if the entire flow raises an exception, Prefect will retry the whole flow up to 2 additional times with a 60-second delay.
- **Date range defaulting:** By default the flow looks back 7 days and forward 1 day, providing an automatic "backfill" window on every run.
- **No API-level retry/polling logic:** The `_pull` function makes exactly one HTTP request. If the API returns an empty or bad response, there is no in-script retry -- it relies entirely on Prefect-level retries.

#### 1.3 How Data Is Processed and Stored

- Data transformation is embedded directly inside `_pull()`: BOM stripping and datetime parsing happen immediately after CSV parsing.
- The `_upsert` function performs a PostgreSQL upsert using an inferred schema. The primary key is `['datetime_beginning_utc', 'pnode_id', 'pnode_name', 'row_is_current', 'version_nbr']`.
- Each day in the loop is independently pulled and upserted, so a failure mid-loop loses progress on remaining days but committed upserts for earlier days persist.

#### 1.4 Error Handling Patterns

- A broad `try/except/finally` wraps the entire date loop.
- On exception: logs the error via `logger.exception`, sends a Slack notification with the log file attachment via `slack_utils.send_pipeline_failure_with_log`, then re-raises.
- The `finally` block calls `logging_utils.close_logging()` to flush and close file handles.
- The Prefect `retries=2` provides flow-level retry.
- **No granular error handling:** If day 4 of 8 fails, the entire flow fails and retries from the beginning (day 1 again), re-upserting days 1-3 redundantly.

#### 1.5 Key Observations

- The PJM API subscription key is **hardcoded** directly in the URL string inside `_pull()`. This is a security concern.
- Imports `settings` from `helioscta_api_scrapes` but only uses it for `SLACK_CHANNEL_NAME`, not for the API key.
- The `_pull` function both fetches AND transforms data (coupling two responsibilities).
- Multiple runs per day (3 cron triggers at 14, 15, 16) provides redundancy but also wastes API calls and compute for the same data.

---

### 2. Event-Driven Script (`da_hrl_lmps_event_driven.py`)

#### 2.1 Overall Structure and Flow

The event-driven script follows a **single-date polling** pattern. Instead of looping over a date range, it targets exactly one day (tomorrow by default) and repeatedly polls the PJM API until data appears, up to a deadline.

**Structural components:**
1. **Imports and constants** -- Same core libraries plus `time` and `ZoneInfo` (for timezone-aware deadline logic). Imports `settings` from a deeper, more specific module path.
2. **`_get_rate_limit()`** -- Returns a configurable polling interval (currently 0.5 seconds). Documents PJM's rate limits: 600/min for members, 6/min for non-members.
3. **`_build_url(start_date, end_date)`** -- Constructs the API URL using `settings.PJM_API_KEY` rather than a hardcoded key.
4. **`_spam_api(url, rate_limit, deadline_hour, timezone)`** -- The core differentiator. Repeatedly polls the API in a `while` loop until either a non-empty response is received or the current hour reaches `deadline_hour` (15:00 MST / America/Denver). Calls `response.raise_for_status()` to catch HTTP errors.
5. **`_pull(response)`** -- Accepts an already-fetched `requests.Response` and parses the CSV into a DataFrame. Does NOT perform any transformation (single responsibility).
6. **`_format(df)`** -- Separate function for data cleaning: BOM stripping and datetime parsing with an explicit format string (`'%m/%d/%Y %I:%M:%S %p'`).
7. **`_upsert(df, schema, table_name, primary_key)`** -- Identical in structure to the scheduled version.
8. **`main(start_date, end_date)` (Prefect `@flow`)** -- Linear pipeline: build URL, get rate limit, poll API, pull data, format data, upsert data. No date loop.

#### 2.2 How Data Fetching Is Triggered

- **Cron schedule:** The Prefect deployment YAML uses `cron: "0 10 * * *"` in `America/Edmonton`, meaning it runs once per day at 10:00 AM Edmonton time.
- **Starts early, polls until data arrives:** PJM publishes DA HRL LMPs between 12:00-1:30 PM EPT (10:00-11:30 AM MST). The script starts at 10 AM Edmonton and will keep polling until 3 PM Denver time (`deadline_hour=15`).
- **No Prefect-level retries:** The `@flow` decorator has no `retries` parameter (defaults to 0). The script relies on its own internal polling loop (`_spam_api`) rather than Prefect retries.
- **Single-day target:** Defaults to tomorrow's date only (`datetime.now() + relativedelta(days=1)`), not a rolling backfill window.

#### 2.3 How Data Is Processed and Stored

- Data processing is separated into distinct phases: `_pull()` for parsing and `_format()` for cleaning/type conversion. This is cleaner separation of concerns.
- The explicit datetime format string (`'%m/%d/%Y %I:%M:%S %p'`) in `_format()` is more precise than the scheduled version's default `pd.to_datetime()` inference, which can be fragile.
- The same `_upsert` function and primary key structure is used, ensuring data compatibility.

#### 2.4 Error Handling Patterns

- Same `try/except/finally` structure as the scheduled version.
- On exception: logs via `logger.exception` and re-raises. **Does NOT send a Slack notification** -- the `slack_utils` module is not imported at all.
- The `_spam_api` function has its own error handling: it calls `response.raise_for_status()` on each attempt (will raise `HTTPError` for 4xx/5xx), and raises `RuntimeError` if the deadline is reached without data.
- Logging is closed in the `finally` block.

#### 2.5 Key Observations

- API key is properly externalized to `settings.PJM_API_KEY` rather than hardcoded.
- The `_spam_api` function is essentially a "poll until ready" pattern -- it starts before data is expected and keeps checking. This gives the script an event-driven *feel* even though the trigger is still a cron schedule.
- The rate limit of 0.5 seconds (2 requests/second) is well within PJM's member limit (600/min = 10/sec) but far exceeds the non-member limit (6/min = 0.1/sec).
- No backfill capability: if the script fails or misses a day, there is no built-in mechanism to re-fetch historical data without manual intervention.

---

### 3. Comparative Analysis

#### 3.1 Triggering Mechanism

| Aspect | Scheduled | Event-Driven |
|--------|-----------|--------------|
| Cron expression | `0 14-16 * * *` (3x/day) | `0 10 * * *` (1x/day) |
| Timezone | America/Edmonton | America/Edmonton |
| Runs per day | 3 | 1 |
| Date range | Rolling 7-day lookback + 1 day forward | Tomorrow only |
| Retry strategy | Prefect-level (`retries=2`, 60s delay) | In-script polling loop with deadline |

#### 3.2 API Interaction

| Aspect | Scheduled | Event-Driven |
|--------|-----------|--------------|
| API key management | Hardcoded in URL string | Externalized via `settings.PJM_API_KEY` |
| Request pattern | Single request per day-chunk | Repeated polling until non-empty response |
| Rate limiting | None | 0.5s between polls (`_get_rate_limit()`) |
| HTTP error handling | None (no `raise_for_status()`) | `response.raise_for_status()` on every attempt |
| Deadline awareness | None | Timezone-aware deadline (15:00 MST) |
| Empty response handling | None (will parse empty CSV) | Retries until non-empty or deadline |

#### 3.3 Data Processing

| Aspect | Scheduled | Event-Driven |
|--------|-----------|--------------|
| Fetch + transform coupling | Combined in `_pull()` | Separated: `_pull()` + `_format()` |
| Datetime parsing | Implicit `pd.to_datetime()` | Explicit format `'%m/%d/%Y %I:%M:%S %p'` |
| BOM cleanup | In `_pull()` | In `_format()` |
| URL construction | Inline in `_pull()` | Dedicated `_build_url()` function |

#### 3.4 Error Handling and Observability

| Aspect | Scheduled | Event-Driven |
|--------|-----------|--------------|
| Exception logging | `logger.exception()` | `logger.exception()` |
| Slack notifications | Yes (`slack_utils.send_pipeline_failure_with_log`) | No |
| Prefect retries | 2 retries, 60s delay | None |
| In-script retries | None | Polling loop with deadline |
| Logging cleanup | `finally: close_logging()` | `finally: close_logging()` |

---

### 4. Pros and Cons

#### 4.1 Scheduled Pattern

**Pros:**
- **Simplicity:** Straightforward loop-over-dates logic. Easy to understand and debug.
- **Built-in backfill:** The 7-day rolling lookback automatically repairs gaps from previous failed runs.
- **Redundancy through multiple runs:** Running 3 times per day increases the chance of catching late-published data.
- **Slack alerting:** Failure notifications are sent directly to Slack.
- **Prefect-level retries:** Automatic retry on transient failures.

**Cons:**
- **Hardcoded API key:** Security vulnerability and makes key rotation difficult.
- **No HTTP error checking:** Does not call `response.raise_for_status()`.
- **No empty response handling:** Empty CSV body will cause confusing downstream errors.
- **Wasteful:** Multiple daily runs re-fetch and re-upsert already-ingested data.
- **Coupled `_pull()` function:** Mixes HTTP fetching, CSV parsing, and data transformation.
- **Coarse error granularity:** A failure on any single day causes the entire flow to retry from scratch.
- **Implicit datetime parsing:** Relies on pandas' auto-detection which can silently produce wrong results.

#### 4.2 Event-Driven Pattern

**Pros:**
- **Externalized API key:** Uses `settings.PJM_API_KEY`, following security best practices.
- **Robust HTTP handling:** Calls `response.raise_for_status()` on every request.
- **Empty response resilience:** Polling loop handles the case where data has not yet been published.
- **Deadline awareness:** Timezone-aware deadline prevents infinite polling.
- **Clean separation of concerns:** Distinct functions for URL building, API interaction, CSV parsing, data transformation, and database writing.
- **Explicit datetime format:** Eliminates ambiguity and prevents silent misparses.
- **Rate limit awareness:** Explicit rate limiting with documentation of PJM's policies.
- **Single efficient run:** Minimizes redundant API calls.

**Cons:**
- **No backfill capability:** Targets only tomorrow. Missed days require manual intervention.
- **No Slack notifications:** Failures are logged but not communicated to the team.
- **No Prefect-level retries:** Infrastructure failures have no automatic retry.
- **Aggressive polling rate:** 0.5 seconds between requests could violate non-member rate limits.
- **Long-running flow:** May run for several hours, consuming a worker slot.
- **Misleading name:** The script is actually a poll-until-ready pattern, not truly event-driven.

---

### 5. Architectural Observations

#### 5.1 The True Event-Driven Component Is the Database Trigger

The PostgreSQL trigger function (`pjm.trigger_function_da_hrl_lmps()`) is the actual event-driven mechanism. It uses `pg_notify` to broadcast a notification when a complete day's worth of WESTERN HUB data has been inserted. Neither Python script acts as a `pg_notify` listener. The "event-driven" Python script is better described as a "polling-with-deadline" pattern that feeds the database, which then generates the true event.

#### 5.2 Recommended Hybrid Approach

A production-ready system would combine elements from both scripts:
1. **From the event-driven script:** Clean function separation, externalized API key, HTTP error checking, explicit datetime formats, rate limiting.
2. **From the scheduled script:** Rolling backfill window, Slack alerting, Prefect retries.
3. **From the database trigger:** True event-driven downstream notification via `pg_notify`.

#### 5.3 Summary Table

| Dimension | Scheduled | Event-Driven |
|-----------|-----------|--------------|
| Trigger | Cron (3x/day) | Cron (1x/day) + internal polling |
| Date scope | 7-day lookback + 1 day | Tomorrow only |
| API key | Hardcoded | Externalized |
| HTTP errors | Not checked | `raise_for_status()` |
| Empty responses | Not handled | Polling with deadline |
| Code structure | 3 functions (coupled) | 6 functions (decoupled) |
| Error alerting | Slack + log | Log only |
| Prefect retries | 2 retries, 60s | None |
| Backfill | Automatic (7-day window) | None |
| Security | Poor (hardcoded key) | Good (settings-based) |
| Testability | Low (coupled functions) | High (separated concerns) |
| Resource efficiency | Low (redundant re-fetches) | High (single targeted fetch) |
| True event-driven? | No | No (polling pattern); DB trigger is the true event |

---

## Teammate 2: PostgreSQL Trigger Analysis

### 1. Table Schema and Structure

The table `pjm.da_hrl_lmps` resides in the `pjm` schema on Azure PostgreSQL (`helioscta`).

**Data columns** (sourced from PJM API):

| Column | Inferred Type | Description |
|---|---|---|
| `datetime_beginning_utc` | TIMESTAMP | Hour start in UTC |
| `datetime_beginning_ept` | TIMESTAMP | Hour start in Eastern Prevailing Time |
| `pnode_id` | INTEGER | Pricing node identifier |
| `pnode_name` | VARCHAR | Pricing node name (e.g., "WESTERN HUB") |
| `voltage` | VARCHAR | Voltage level |
| `equipment` | VARCHAR | Equipment type |
| `type` | VARCHAR | LMP type (e.g., "hub") |
| `zone` | VARCHAR | Zone name |
| `system_energy_price_da` | FLOAT | Day-ahead system energy price component |
| `total_lmp_da` | FLOAT | Total day-ahead LMP |
| `congestion_price_da` | FLOAT | Day-ahead congestion price component |
| `marginal_loss_price_da` | FLOAT | Day-ahead marginal loss price component |
| `row_is_current` | VARCHAR/BOOLEAN | PJM versioning flag |
| `version_nbr` | INTEGER | PJM version number |

**System columns** (auto-managed by the upsert utility):

| Column | Type | Description |
|---|---|---|
| `created_at` | TIMESTAMPTZ | Row creation timestamp, defaults to `CURRENT_TIMESTAMP AT TIME ZONE 'America/Edmonton'` |
| `updated_at` | TIMESTAMPTZ | Row last-modified timestamp, defaults to `CURRENT_TIMESTAMP AT TIME ZONE 'America/Edmonton'` |

**Primary key:** `(datetime_beginning_utc, pnode_id, pnode_name, row_is_current, version_nbr)`

**Grain:** One row per hour per pricing node per version.

### 2. Trigger Function Logic

The trigger function `pjm.trigger_function_da_hrl_lmps()` implements a **conditional notification** pattern. It does not simply fire on every insert -- it performs a data completeness check before emitting any notification.

**Step-by-step logic:**

1. **Query the table** for rows matching all of the following criteria:
   - `datetime_beginning_ept::date` equals **tomorrow** relative to the current MST timestamp
   - `pnode_name = 'WESTERN HUB'` -- filters to only the Western Hub pricing node
   - `created_at = updated_at` -- ensures the rows are **fresh inserts**, not re-upserts

2. **Group** the results by `(datetime_beginning_ept::date, type)` and apply a `HAVING COUNT(*) = 24` filter, requiring exactly 24 rows per group. This enforces that a **complete 24-hour day** of LMP data exists.

3. **For each qualifying group**, build a JSON payload and issue `pg_notify`.

4. **Return NULL** -- appropriate for an `AFTER` trigger that does not modify the row.

The trigger acts as a **data completeness gate**: it only fires the notification when a full day of tomorrow's WESTERN HUB LMP data has arrived as fresh inserts.

### 3. NOTIFY/LISTEN Pattern

**Channel name:** `notifications_pjm_da_hrl_lmps`

**Payload format:**

```json
{
    "table": "da_hrl_lmps",
    "operation": "INSERT",
    "da_date": "2026-02-26",
    "type": "hub",
    "row_count": 24,
    "pnode_count": 1,
    "hour_count": 24,
    "min_datetime": "2026-02-26 00:00:00",
    "max_datetime": "2026-02-26 23:00:00"
}
```

The notification is emitted via `PERFORM pg_notify('notifications_pjm_da_hrl_lmps', payload::text)`. A listener would issue `LISTEN notifications_pjm_da_hrl_lmps` on its PostgreSQL connection to receive these notifications asynchronously.

### 4. Trigger Firing Mechanism

```sql
CREATE TRIGGER trigger_pjm_da_hrl_lmps
AFTER INSERT ON pjm.da_hrl_lmps
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION pjm.trigger_function_da_hrl_lmps();
```

Key characteristics:
- **Timing:** `AFTER INSERT` -- fires after the insert statement has completed and rows are visible
- **Granularity:** `FOR EACH STATEMENT` -- fires once per INSERT statement, not once per row
- **Transition table:** `REFERENCING NEW TABLE AS new_rows` -- captures all inserted rows (though the trigger function queries the main table directly instead of `new_rows`)
- **Events:** INSERT only -- does not fire on UPDATE or DELETE
- **Idempotent drop/create:** `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`

### 5. dbt Macro Wrapping

The SQL file is wrapped in a dbt Jinja macro:

```sql
{% macro pjm_da_hrl_lmps() %}
...
{% endmacro %}
```

This means the trigger is deployed via `dbt run-operation pjm_da_hrl_lmps`, making trigger creation part of the managed dbt lifecycle.

### 6. Best Practices Observed

1. **Completeness gate:** Validates a full 24-hour dataset exists before firing, preventing downstream consumers from processing partial data.
2. **Fresh-insert guard (`created_at = updated_at`):** Avoids firing duplicate notifications when the scheduled scraper re-processes existing data.
3. **Statement-level trigger:** Avoids the performance penalty of firing once per row. In a batch insert of hundreds of rows, fires exactly once.
4. **Rich JSON payload:** Carries enough metadata for downstream consumers to make routing decisions without querying the database.
5. **Idempotent DDL:** Safe to re-run.
6. **dbt macro wrapping:** Version-controlled and deployed alongside data models.

### 7. Concerns and Risks

1. **Transition table `new_rows` is declared but unused.** The function queries `pjm.da_hrl_lmps` directly instead of `new_rows`. This performs a filtered table scan on every insert statement. Consider adding an index on `(datetime_beginning_ept, pnode_name, created_at, updated_at)` if not already present.

2. **Timezone handling inconsistency.** The trigger uses `'MST'` (fixed UTC-7, no DST), while the upsert utility uses `'America/Edmonton'` (observes DST). During summer months (MDT), this will be 1 hour off. Could cause the trigger to compute "tomorrow" incorrectly during summer.

3. **Exactly-24-hours assumption.** During DST transitions, PJM's EPT timeline has 23 hours (spring forward) or 25 hours (fall back). On those two days per year, the trigger's `HAVING COUNT(*) = 24` check will behave incorrectly.

4. **Potential for duplicate notifications.** If another insert occurs for the same date with `created_at = updated_at`, the trigger could fire again. Downstream consumers should be idempotent.

5. **pg_notify payload size limit.** PostgreSQL limits payloads to 8,000 bytes. Current payload is well within this limit but worth noting.

6. **No corresponding LISTEN implementation.** The trigger is defined but no listener process exists in the codebase yet.

7. **Single-node filtering.** Only checks `'WESTERN HUB'` completeness. Other pricing nodes would need additional triggers or an extended trigger function.

---

## Teammate 3: Event-Driven Implementation Plan

### 1. Architecture Overview

The system has two execution paradigms for data pipelines:

**Scheduled scripts** run on a fixed cron/timer schedule. They poll external APIs at predetermined times, pull data for a date range, and upsert it into Azure PostgreSQL.

**Event-driven scripts** react to data arriving in the database. The end-to-end flow:

```
[Scheduled Scrape]
      |
      v
[Azure PostgreSQL: INSERT/UPSERT into raw table]
      |
      v
[PostgreSQL AFTER INSERT trigger fires]
      |  -- validates completeness conditions (e.g., 24 rows for WESTERN HUB)
      |  -- validates freshness conditions (e.g., created_at = updated_at)
      |
      v
[pg_notify('notifications_{schema}_{table}', JSON payload)]
      |
      v
[Python Listener Service: long-running process with persistent connection]
      |  -- LISTEN on one or more notification channels
      |  -- deserializes JSON payload
      |  -- invokes the appropriate downstream handler
      |
      v
[Downstream Handler: dbt run, additional API scrape, Slack alert, etc.]
```

---

### 2. Pattern Definition

#### Scheduled Script Pattern (existing)

```
1. Define API_SCRAPE_NAME, logger, settings
2. _pull()    -- call external API with date range parameters
3. _format()  -- clean column names, parse datetimes, cast dtypes
4. _upsert()  -- write to Azure PostgreSQL
5. @flow main() -- orchestrate pull/format/upsert in a loop, with retries + Slack on error
6. if __name__ == "__main__": main()
```

#### Event-Driven Handler Pattern (new)

```python
EVENT_NAME = "da_hrl_lmps"
TRIGGER_CHANNEL = "notifications_pjm_da_hrl_lmps"

def handle_event(payload: dict) -> None:
    """
    Called by the listener service when a notification arrives.

    Args:
        payload: JSON payload from pg_notify, containing:
            - table: source table name
            - operation: INSERT/UPDATE
            - da_date: the date that is now complete
            - row_count, pnode_count, hour_count, etc.
    """
    da_date = payload["da_date"]
    # ... downstream logic: call another API, run dbt, send alert
```

This separates the "what to do" (handler) from the "when to do it" (listener + trigger).

---

### 3. Trigger Design

#### 3.1 Naming Conventions

```
Trigger function:  {schema}.trigger_function_{table_name}()
Trigger:           trigger_{schema}_{table_name}
Channel:           notifications_{schema}_{table_name}
```

#### 3.2 Statement-Level Triggers, Not Row-Level

Use `FOR EACH STATEMENT` with `REFERENCING NEW TABLE AS new_rows`. A single INSERT of 24 rows fires the trigger once, not 24 times.

#### 3.3 Completeness Conditions

Every trigger function must encode a "completeness check" that prevents premature notifications. The existing example checks:
- `datetime_beginning_ept::date = tomorrow`
- `pnode_name = 'WESTERN HUB'`
- `created_at = updated_at` (fresh inserts only)
- `HAVING COUNT(*) = 24` (all 24 hours present)

#### 3.4 Standard Payload Fields

Always include:

```json
{
    "table": "<table_name>",
    "schema": "<schema_name>",
    "operation": "<INSERT|UPDATE>",
    "triggered_at": "<current_timestamp>",
    "event_type": "<domain-specific event name>"
}
```

Plus domain-specific fields (vary per trigger).

#### 3.5 Template for New Triggers

```sql
{% macro {schema}_{table_name}() %}

CREATE OR REPLACE FUNCTION {schema}.trigger_function_{table_name}()
RETURNS TRIGGER AS $$
DECLARE
    payload JSON;
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT
            <grouping_columns>,
            COUNT(*) as row_count
        FROM {schema}.{table_name}
        WHERE
            <freshness_condition>       -- e.g., created_at = updated_at
            AND <date_condition>         -- e.g., date_col = tomorrow
            AND <filter_condition>       -- e.g., specific node/type
        GROUP BY <grouping_columns>
        HAVING <completeness_condition>  -- e.g., COUNT(*) = expected_count
    LOOP
        payload := json_build_object(
            'schema', '{schema}',
            'table', TG_TABLE_NAME,
            'operation', TG_OP,
            'triggered_at', NOW()::text
            -- domain-specific fields from rec
        );
        PERFORM pg_notify('notifications_{schema}_{table_name}', payload::text);
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_{schema}_{table_name} ON {schema}.{table_name};

CREATE TRIGGER trigger_{schema}_{table_name}
AFTER INSERT ON {schema}.{table_name}
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT
EXECUTE FUNCTION {schema}.trigger_function_{table_name}();

{% endmacro %}
```

---

### 4. Listener Service Design

#### 4.1 Core Architecture

A single long-running Python process per environment that:
1. Opens a persistent `psycopg2` connection to Azure PostgreSQL
2. Issues `LISTEN` for all registered channels
3. Polls for notifications in a loop
4. Dispatches to the correct handler function based on channel name

#### 4.2 Proposed Implementation

```python
# backend/scrapes/listeners/pg_listener.py

import json
import select
import psycopg2
import psycopg2.extensions
from typing import Callable

class PostgreSQLListener:
    """
    Long-running listener that consumes pg_notify notifications
    and dispatches them to registered handler functions.
    """

    def __init__(self, dsn: str):
        self.dsn = dsn
        self.handlers: dict[str, Callable[[dict], None]] = {}
        self.conn = None

    def register(self, channel: str, handler: Callable[[dict], None]):
        """Register a handler for a notification channel."""
        self.handlers[channel] = handler

    def connect(self):
        """Establish connection and subscribe to all registered channels."""
        self.conn = psycopg2.connect(self.dsn)
        self.conn.set_isolation_level(
            psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT
        )
        cursor = self.conn.cursor()
        for channel in self.handlers:
            cursor.execute(f"LISTEN {channel};")

    def run(self, poll_timeout: float = 5.0):
        """Main event loop."""
        self.connect()
        while True:
            if select.select([self.conn], [], [], poll_timeout) == ([], [], []):
                continue  # Timeout -- no notifications
            self.conn.poll()
            while self.conn.notifies:
                notify = self.conn.notifies.pop(0)
                channel = notify.channel
                payload = json.loads(notify.payload)
                handler = self.handlers.get(channel)
                if handler:
                    try:
                        handler(payload)
                    except Exception as e:
                        handle_error(channel, payload, e)
                else:
                    logger.warning(f"No handler for channel: {channel}")
```

#### 4.3 Handler Registration

```python
# backend/scrapes/listeners/main.py

from backend.scrapes.listeners.pg_listener import PostgreSQLListener
from backend.scrapes.power.event_driven.pjm.da_hrl_lmps import handle_event as handle_da_hrl_lmps

def main():
    listener = PostgreSQLListener(dsn=build_dsn())
    listener.register("notifications_pjm_da_hrl_lmps", handle_da_hrl_lmps)
    listener.run()
```

#### 4.4 Connection Resilience

- Wrap `run()` in an outer retry loop with exponential backoff
- On `psycopg2.OperationalError`, reconnect and re-issue all `LISTEN` commands
- Log reconnection events and send Slack alerts if reconnection fails after N attempts

---

### 5. Error Handling & Retry Strategy

#### 5.1 Three Levels of Failure

| Level | What Fails | Strategy |
|-------|-----------|----------|
| **Trigger** | SQL trigger function raises | PostgreSQL rolls back the INSERT. Scheduled scrape's retries will re-attempt. |
| **Listener** | Connection drops, process crashes | Outer retry loop reconnects. Missed notifications recovered via catch-up scan. |
| **Handler** | Downstream logic fails | Retry within handler up to N times. On exhaustion, log, Slack alert, write to dead-letter table. |

#### 5.2 Handler Retry Pattern

```python
import time
from functools import wraps

def retry_handler(max_retries: int = 3, backoff_base: float = 30.0):
    def decorator(func):
        @wraps(func)
        def wrapper(payload: dict):
            for attempt in range(1, max_retries + 1):
                try:
                    return func(payload)
                except Exception as e:
                    if attempt == max_retries:
                        raise
                    wait = backoff_base * (2 ** (attempt - 1))
                    logger.warning(
                        f"Handler failed (attempt {attempt}/{max_retries}), "
                        f"retrying in {wait}s: {e}"
                    )
                    time.sleep(wait)
        return wrapper
    return decorator
```

#### 5.3 Catch-Up / Missed Event Recovery

Since `pg_notify` does not persist messages, missed events must be recoverable.

**Recommended: Event Log Table**

```sql
CREATE TABLE events.event_log (
    id SERIAL PRIMARY KEY,
    channel TEXT NOT NULL,
    payload JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',  -- pending | processing | completed | failed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    error_message TEXT,
    retry_count INT DEFAULT 0
);
```

Modify every trigger function to INSERT into `events.event_log` in addition to calling `pg_notify`. The listener marks rows as `processing` on receipt, `completed` on success, `failed` on exhaustion. A periodic catch-up job queries for `status = 'pending'` older than X minutes and reprocesses them.

#### 5.4 Dead-Letter Handling

Failed events (after all retries exhausted) should:
1. Be written to `events.event_log` with `status = 'failed'` and `error_message`
2. Trigger a Slack alert using existing `slack_utils.send_pipeline_failure_with_log()`
3. Be manually replayable via CLI: `python -m backend.scrapes.listeners.replay --event-id 123`

---

### 6. Monitoring & Observability

#### 6.1 Listener Health

- **Heartbeat**: Every N minutes, write a heartbeat row to `events.listener_heartbeat` table
- **Metrics**: Events received per channel per hour, success vs failure rate, average handler execution time, listener uptime/reconnection count

#### 6.2 Trigger Health

- Periodically verify all expected triggers exist via `SELECT * FROM pg_trigger`
- Query `events.event_log` grouped by channel, status, date to identify backlogs

#### 6.3 Logging Standards

- Use existing `logging_utils.init_logging()` pattern
- Listener logs should NOT delete on no errors (long-running process)
- Each handler invocation should log: channel, payload summary, duration, outcome

#### 6.4 Slack Integration

- **Handler failure**: `slack_utils.send_pipeline_failure_with_log()`
- **Listener reconnection**: Warning-level Slack message
- **Missed event detected**: Alert when catch-up finds unprocessed events

---

### 7. Migration Path: Converting Scheduled to Event-Driven

**Step 1:** Identify the trigger condition -- what data landing means this script should run.

**Step 2:** Write the trigger SQL as a dbt macro following the template. Deploy with `dbt run-operation`.

**Step 3:** Write the handler function -- extract downstream logic into `handle_event(payload)`.

**Step 4:** Register the handler in the listener's registry.

**Step 5:** Add the event log INSERT to the trigger function.

**Step 6:** Run both in parallel for at least 2 weeks. Compare outputs. The scheduled script acts as a safety net.

**Step 7:** Retire the scheduled script. Keep in `archive/` folder for reference.

---

### 8. Library-Wide Decision Criteria (All API Scripts)

Use this framework for any script in `backend/scrapes/**`, not just PJM.

#### 8.1 Required Inputs Before Deciding

Capture these fields for every script:

| Input | Description |
|---|---|
| Script path | Example: `backend/scrapes/wsi/weighted_degree_day/...` |
| Source type | External API, internal table, file drop, webhook |
| Publish-time behavior | Fixed window, variable window, or unknown |
| Freshness SLA | Maximum acceptable delay (minutes/hours) |
| Backfill need | None, short lookback, long historical replay |
| Downstream fan-out | Number/criticality of dependent jobs |
| API limits/cost | Quotas, rate limits, paid call constraints |
| Failure impact | Business impact of late/missed run |

#### 8.2 Scoring Rubric (1-5)

Score each mode using the same criteria:

| Criterion | 1 means | 5 means |
|---|---|---|
| Freshness/latency fit | Misses SLA often | Reliably meets SLA |
| Publish-time predictability | Trigger rarely aligns with release | Trigger aligns tightly with release |
| Reliability and retry behavior | Weak retry/recovery | Strong retry + deterministic recovery |
| Backfill/recovery capability | Manual, error-prone replay | Automated, repeatable replay |
| Operational complexity | High ongoing operator burden | Low burden, easy to reason about |
| Cost and API-rate-limit safety | Frequent quota/cost risk | Efficient and quota-safe |
| Observability and on-call burden | Poor signal, noisy alerts | Clear signal, actionable alerts |

#### 8.3 Decision Rules

1. Score **Scheduled**, **Event-driven**, and **Hybrid** from 1-5 for each criterion.
2. Sum the scores.
3. Pick the highest total, unless a hard rule below applies.

Hard rules:

- Choose **Scheduled** when the upstream only supports pull and has a reliable fixed publish window, especially with strict quotas.
- Choose **Event-driven** when publish time is variable/unpredictable and downstream work must start as soon as new data lands.
- Choose **Hybrid** when both are true:
  - External ingestion needs scheduled backfill safety.
  - Internal dependencies should react immediately to landed data.

Tie-break rule:

- If totals are within 2 points, default to **Hybrid** with a scheduled reconciliation/catch-up job.

#### 8.4 Default Policy for This Library

- Default external API pulls to **Scheduled** with retries and lookback.
- Promote to **Event-driven** when arrival time is variable or downstream latency requirements are tight.
- For critical pipelines, use **Hybrid**:
  - Event-driven primary path.
  - Scheduled reconciler to repair missed events.

#### 8.5 Worked Example: `backend/scrapes/wsi/weighted_degree_day` -> Event-Driven

Recommended mode for this folder: **Event-driven primary + scheduled reconciler**.

Why:

| Criterion | Evidence | Direction |
|---|---|---|
| Publish-time predictability | Forecast/model updates can arrive at variable times | Event-driven |
| Freshness/latency | Downstream consumers benefit from processing immediately after new forecast arrival | Event-driven |
| Downstream dependency chain | WDD tables feed additional analytics/reporting | Event-driven |
| Backfill/recovery | Replay is still needed for missed events/outages | Add scheduled reconciler |
| Cost/rate-limit safety | Event trigger reduces unnecessary blind polling windows when no update exists | Event-driven |

Implementation note for this folder:

- Trigger on detected new upstream payload/version (for example `init_time` change, content hash change, or landing-table event), run WDD handlers immediately, and run a periodic scheduled reconciliation to catch misses.

---

### 9. File/Folder Organization

```
backend/
  src/
    power/
      # -- SCHEDULED SCRIPTS (external API -> raw tables) --
      scheduled/
        iso/
          pjm/
            da_hrl_lmps.py
            rt_hrl_lmps.py
            settings.py
          ercot/
            ...
          caiso/
            ...

      # -- EVENT-DRIVEN HANDLERS (raw tables -> downstream actions) --
      event_driven/
        iso/
          pjm/
            da_hrl_lmps.py          # handle_event(payload)
            rt_hrl_lmps.py
          ercot/
            ...

    # -- LISTENER SERVICE --
    listeners/
      __init__.py
      pg_listener.py                # PostgreSQLListener class
      registry.py                   # maps channels -> handler functions
      main.py                       # entry point
      error_handler.py              # retry logic, dead-letter, Slack alerts

    # -- SHARED UTILITIES (already exist) --
    utils/
      azure_postgresql_utils.py
      logging_utils.py
      slack_utils.py

  # -- dbt --
  dbt/
    dbt_azure_postgresql/
      macros/
        triggers/                   # All trigger SQL lives here
          pjm_da_hrl_lmps.sql
          pjm_rt_hrl_lmps.sql
          ...
      models/
        power/
          ...

backend/schedulers/
  task_scheduler_azurepostgresql/
    power/
      scheduled/
        pjm_da_hrl_lmps.ps1
      listeners/
        start_pg_listener.ps1       # Starts the listener service
```

#### Registry Pattern

```python
# backend/scrapes/listeners/registry.py

from backend.scrapes.power.event_driven.iso.pjm.da_hrl_lmps import handle_event as pjm_da_hrl_lmps_handler

CHANNEL_REGISTRY: dict[str, callable] = {
    "notifications_pjm_da_hrl_lmps": pjm_da_hrl_lmps_handler,
}
```

```python
# backend/scrapes/listeners/main.py

from backend.scrapes.listeners.pg_listener import PostgreSQLListener
from backend.scrapes.listeners.registry import CHANNEL_REGISTRY

def main():
    listener = PostgreSQLListener(dsn=build_dsn())
    for channel, handler in CHANNEL_REGISTRY.items():
        listener.register(channel, handler)
    listener.run()
```

---

### 10. Summary of Deliverables

| # | Artifact | Type | Location |
|---|----------|------|----------|
| 1 | `PostgreSQLListener` class | Python | `backend/scrapes/listeners/pg_listener.py` |
| 2 | Channel registry | Python | `backend/scrapes/listeners/registry.py` |
| 3 | Listener entry point | Python | `backend/scrapes/listeners/main.py` |
| 4 | Error handler with retry decorator | Python | `backend/scrapes/listeners/error_handler.py` |
| 5 | `events.event_log` migration | SQL/dbt | `backend/dbt/.../macros/triggers/event_log_table.sql` |
| 6 | Trigger template/macros (per table) | SQL/dbt | `backend/dbt/.../macros/triggers/{schema}_{table}.sql` |
| 7 | Handler functions (per event) | Python | `backend/scrapes/power/event_driven/iso/{iso}/{table}.py` |
| 8 | Listener service wrapper | PowerShell | `backend/schedulers/.../listeners/start_pg_listener.ps1` |
| 9 | `events.listener_heartbeat` table | SQL/dbt | `backend/dbt/.../macros/triggers/listener_heartbeat_table.sql` |

**Recommended implementation order:** 1 -> 5 -> 2 -> 3 -> 4 -> 6 -> 7 -> 8 -> 9
