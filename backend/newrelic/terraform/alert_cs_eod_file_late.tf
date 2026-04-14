# Direct port of backend/grafana/provisioning/alerting/rules.yaml rule
# `cs-eod-file-late`.
#
# In the Grafana version, the wall-clock + weekday gating lived inside the
# raw SQL CASE expression. In the New Relic version, that gating moves into
# Python: backend/monitoring/postions_and_trades/clear_street_eod/events.py
# emits a ClearStreetEodFileLate event only when:
#
#   * the local time in America/Denver is at or after 22:00,
#   * it's a weekday (Mon–Fri), and
#   * no ClearStreetEodFileLanded event was emitted for today.
#
# This NRQL alert condition therefore only needs to ask the trivial question:
# "did a late event arrive?"
#
# Severity: warning (matches Grafana label).

resource "newrelic_nrql_alert_condition" "cs_eod_file_late" {
  policy_id = newrelic_alert_policy.clear_street_eod_file.id

  name        = "Clear Street EOD file late"
  type        = "static"
  description = "ClearStreetEodFileLate event observed — past 22:00 MT on a weekday with no Clear Street EOD file landed yet."
  enabled     = true

  nrql {
    query = "FROM ClearStreetEodFileLate SELECT count(*) WHERE environment = 'prod'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option       = "static"
  fill_value        = 0
  aggregation_window = 60
  aggregation_method = "event_flow"
  aggregation_delay  = 60
}
