# Direct port of backend/grafana/provisioning/alerting/rules.yaml rule
# `cs-eod-file-detected`. Fires whenever the ingest job has emitted at least
# one ClearStreetEodFileLanded event in the last 10 minutes — i.e. today's
# Clear Street EOD file has been pulled from SFTP and the row is present in
# clear_street.helios_transactions_v2_*.
#
# Severity: critical (matches Grafana label).

resource "newrelic_alert_policy" "clear_street_eod_file" {
  name                = "Clear Street EOD File"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "cs_eod_file_detected" {
  policy_id = newrelic_alert_policy.clear_street_eod_file.id

  name        = "Clear Street EOD file detected"
  type        = "static"
  description = "Detected at least one ClearStreetEodFileLanded event in the last 10 minutes — today's file has landed on SFTP and been ingested."
  enabled     = true

  nrql {
    query = "FROM ClearStreetEodFileLanded SELECT count(*) WHERE environment = 'prod'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 600
    threshold_occurrences = "all"
  }

  fill_option       = "static"
  fill_value        = 0
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 60
}
