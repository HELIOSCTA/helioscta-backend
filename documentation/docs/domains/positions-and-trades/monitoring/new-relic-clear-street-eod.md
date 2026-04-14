# New Relic — Clear Street EOD Monitoring

Replaces the legacy Grafana dashboard at `backend/grafana/dashboards/Positions and Trades/clear-street-trades-to-mufg.json` and the two alert rules in `backend/grafana/provisioning/alerting/rules.yaml` (which routed to PagerDuty via the contact point in `contactpoints.yaml`). The migration drops PagerDuty in favor of NR-native email + mobile push notifications.

This page documents the operator-facing runtime: where the ingest job lives, when it runs, what it produces, and how to register or remove it from Task Scheduler.

## What it does

A scheduled Python job (`backend/monitoring/postions_and_trades/clear_street_eod/runs.py`) reads the same SQL queries that the Grafana dashboard used to embed inline, shapes the rows into New Relic custom events, and POSTs them to the New Relic Event API. New Relic dashboards and alerts then read from NRDB instead of Postgres.

## Key facts

| Field | Value |
|---|---|
| **Python entrypoint** | `backend/monitoring/postions_and_trades/clear_street_eod/runs.py` |
| **CLI** | `python backend\monitoring\postions_and_trades\clear_street_eod\runs.py` (add `--dry-run` to skip the NR POST) |
| **PowerShell runner** | `backend/schedulers/task_scheduler_azurepostgresql/positions_and_trades/monitoring/clear_street_eod_to_newrelic.ps1` |
| **Task Scheduler task name** | `Monitoring Clear Street EOD to New Relic` |
| **Task Scheduler task path** | `\helioscta-backend\Positions and Trades\Monitoring\` |
| **Cadence (scheduler host local time, MT)** | Mon–Fri at 19:35, 20:05, 20:35, 21:05, **22:05**, 23:55 |
| **Source database** | Azure PostgreSQL `helioscta` |
| **Source tables** | `clear_street.helios_transactions_v2_2026_feb_23`, `trades_cleaned.clear_street_trades`, `logging.pipeline_runs` |
| **Sink** | New Relic Event API (`insights-collector.newrelic.com`, US region) |
| **Run tracking** | `logging.pipeline_runs` rows with `pipeline_name = 'clear_street_eod_to_newrelic'` |

The 22:05 trigger is the **wall-clock late check** trigger — without it, no run between 22:00 and 23:50 would notice that today's Clear Street EOD file is late. The other five triggers are intentionally offset by 5 minutes from the upstream `SFTP Clear Street Trades` task so that each ingest run sees the freshly upserted rows from the same cycle.

## Custom event types emitted

| `eventType` | Cardinality per run | Source query |
|---|---|---|
| `PipelineRun` | ~tens (last 14 days, two pipeline names) | `PIPELINE_RUNS_RECENT` |
| `ClearStreetPipelineSummary` | ≤14 (one per trade date) | `PIPELINE_RUNS_SUMMARY` |
| `ClearStreetEodSummary` | 1 | `LATEST_MUFG_SFTP_DATE` + `TITAN_QTY_*` + `MISSING_PRODUCT_CODE_GROUPING` |
| `ClearStreetTrade` | ~thousands (MUFG-filtered + all EOD for latest sftp_date) | `MUFG_FILTERED_TRADES_DETAIL`, `ALL_EOD_TRADES_DETAIL` |
| `ClearStreetEodFileLanded` | 0 or 1 | `EOD_FILE_LANDED_TODAY` |
| `ClearStreetEodFileLate` | 0 or 1 (only after 22:00 MT on a weekday with no landed event) | wall-clock check in `events.build_eod_file_late_event` |

Every event carries `environment`, `hostname`, `source`, and `timestamp` from `backend/monitoring/newrelic/base_event.py`. Dashboards and alerts must filter `WHERE environment = 'prod'`.

## New Relic resources (Terraform-managed)

Defined in `backend/newrelic/terraform/`. Apply with:

```bash
cd backend/newrelic/terraform
terraform init
terraform plan
terraform apply
```

| Resource | File | Replaces |
|---|---|---|
| Dashboard | `dashboard_clear_street_trades_to_mufg.tf` | Grafana JSON dashboard |
| Alert: file detected (critical) | `alert_cs_eod_file_detected.tf` | `rules.yaml` rule `cs-eod-file-detected` |
| Alert: file late (warning) | `alert_cs_eod_file_late.tf` | `rules.yaml` rule `cs-eod-file-late` |
| Email notification workflow | `workflows.tf` | `contactpoints.yaml` + `policies.yaml` (PagerDuty is dropped — see Notification delivery below) |

### Notification delivery

This migration drops PagerDuty entirely. Alerts are delivered through New Relic itself via two parallel channels:

- **Email** — driven by `newrelic_notification_destination.email` in `workflows.tf`. Recipients are configured by the `alert_email_recipients` Terraform variable. Add or remove addresses by re-running `terraform apply` with the updated list.
- **Mobile push** — automatic. Anyone with access to this NR account who installs the New Relic mobile app and enables push notifications receives these alerts in their feed. No Terraform configuration needed.

The Issues feed at `one.newrelic.com` is the third (always-on) delivery surface and is the canonical place to triage in-flight incidents.

## Register / remove the Task Scheduler entry

Run the .ps1 from an elevated PowerShell on the scheduler host:

```powershell
PowerShell -ExecutionPolicy Bypass -File `
  "C:\Users\AidanKeaveny\Documents\github\helioscta-backend\backend\schedulers\task_scheduler_azurepostgresql\positions_and_trades\monitoring\clear_street_eod_to_newrelic.ps1"
```

To remove:

```powershell
Unregister-ScheduledTask -TaskName "Monitoring Clear Street EOD to New Relic" `
  -TaskPath "\helioscta-backend\Positions and Trades\Monitoring\" -Confirm:$false
```

## Local validation (no NR account writes)

```bash
# from repo root, with the helioscta-backend conda env active
python backend\monitoring\postions_and_trades\clear_street_eod\runs.py --dry-run
```

Expect: per-query row counts logged to stdout, no HTTPS calls to NR, and one `RUN_SUCCESS` row appended to `logging.pipeline_runs` with `pipeline_name = 'clear_street_eod_to_newrelic'`.

## Failure modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `RUN_FAILURE` row in `logging.pipeline_runs` with `error_type = NewRelicConfigError` | NR license key not set, or wrong region | `backend/.env.shared` → `NEW_RELIC_LICENSE_KEY`, `NEW_RELIC_REGION` |
| `RUN_FAILURE` with `psycopg2.OperationalError` | Postgres credentials missing or DB unreachable | `backend/.env.prod` |
| New Relic dashboard widgets empty | No events in NRDB; the ingest job hasn't run successfully OR it ran in dev mode | Check `logging.pipeline_runs` for `clear_street_eod_to_newrelic` AND that the dashboard NRQL filters `environment = 'prod'` |
| `Clear Street EOD file late` alert never fires | The 22:05 MT trigger is not registered, or it ran but `EOD_FILE_LANDED_TODAY` returned a row | `Get-ScheduledTask -TaskName "Monitoring Clear Street EOD to New Relic"`; inspect the latest `logging.pipeline_runs` row's log content |

## Rollback to Grafana (until cutover)

The legacy Grafana stack remains in `backend/grafana/` and can be brought back at any time before the cutover commit:

```bash
cd backend
docker compose up -d grafana
# browse to http://localhost:4000
```

After the cutover commit (see migration plan at `.claude/plans/curried-bubbling-micali.md`), rollback requires `git revert`.
