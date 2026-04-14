# `backend/newrelic/terraform/`

Terraform module that defines the New Relic dashboard, alert conditions, and
email-notification workflow that replace the legacy Grafana stack at
`backend/grafana/`.

This is the **deploy-time** half of the migration. The **runtime** half lives
under `backend/monitoring/postions_and_trades/clear_street_eod/` — that's the
Python ingest job that materialises Postgres rows into NRDB events for the
NRQL queries in this module to read.

## Layout

```
versions.tf                              Terraform / NR provider version pins
variables.tf                             Input variables (account id, keys, env)
main.tf                                  Provider config + locals
dashboard_clear_street_trades_to_mufg.tf newrelic_one_dashboard
alert_cs_eod_file_detected.tf            Critical alert: today's file landed (port of cs-eod-file-detected)
alert_cs_eod_file_late.tf                Warning alert: today's file is late (port of cs-eod-file-late)
workflows.tf                             Email destination + notification channel + workflow
example.tfvars                           Sample variables file
.gitignore                               Excludes .terraform/, *.tfstate, *.tfvars
```

## Required env vars

| Variable | Source | Notes |
|---|---|---|
| `TF_VAR_new_relic_account_id` | NR account console | Numeric, e.g. `1234567` |
| `TF_VAR_new_relic_api_key` | NR User API key | Starts with `NRAK-`. **Different from the License/Ingest key the Python job uses.** |
| `TF_VAR_alert_email_recipients` | Operator emails | HCL list literal, e.g. `'["alerts@example.com","oncall@example.com"]'`. At least one address required. |

`new_relic_region` defaults to `US` and `environment` defaults to `prod` — override only if needed.

Mobile push notifications do **not** need a Terraform variable: anyone with access to this NR account who installs the NR mobile app and enables push will receive these alerts in their feed automatically.

## First-time setup

```bash
cd backend/newrelic/terraform
terraform init
terraform plan
terraform apply
```

State is local for the first cut (`terraform.tfstate` is gitignored). Migrate
to an Azure Storage backend in a follow-up by adding a `backend "azurerm"`
block to `versions.tf` and running `terraform init -migrate-state`.

## Relationship to the Python ingest job

| Resource here | Reads NR event type | Emitted by |
|---|---|---|
| Dashboard `Pipeline Runs Summary` widget | `ClearStreetPipelineSummary` | `events.build_pipeline_summary_events` |
| Dashboard SFTP/MUFG log widgets | `PipelineRun` | `events.build_pipeline_run_events` |
| Dashboard 4 stat billboards | `ClearStreetEodSummary` | `events.build_eod_summary_event` |
| Dashboard MUFG/EOD detail tables | `ClearStreetTrade` | `events.build_trade_events` |
| Alert `cs_eod_file_detected` | `ClearStreetEodFileLanded` | `events.build_eod_file_landed_event` |
| Alert `cs_eod_file_late` | `ClearStreetEodFileLate` | `events.build_eod_file_late_event` |

If you change the dashboard NRQL or add an alert, check whether the ingest
job still emits the right shape. If you rename an event type, both sides
must be updated in the same change.

## Cutover from Grafana

The plan in `.claude/plans/curried-bubbling-micali.md` mandates a parallel-run
window: keep the Grafana stack up under `docker compose up grafana` while you
diff the new NR dashboard against it for one full week of EOD cycles. Only
delete `backend/grafana/` after the diff is clean and the NR email workflow
has fired at least once on a real (or synthetic) incident. The legacy Grafana
PagerDuty contact point can be deleted in the same change — the migration
moves alerting entirely off PagerDuty.
