# Routes incidents raised by the Clear Street EOD alert policy to email
# notifications inside New Relic. Replaces the legacy Grafana PagerDuty
# contact point in backend/grafana/provisioning/alerting/contactpoints.yaml.
#
# Mobile push notifications are NOT defined here — they are an implicit
# per-user setting in the New Relic mobile app. Anyone with access to this
# NR account who installs the app and enables push will receive these
# alerts in their feed automatically; no Terraform required.
#
# Filtering parity with the old policies.yaml:
#   - In Grafana the route was matched on label `team = helioscta-positions`.
#   - Here, every alert in the Clear Street EOD policy is implicitly part of
#     the helioscta-positions team, so we filter on policy id rather than
#     re-implementing label matching. If a future alert in this policy should
#     NOT route to email, narrow the filter then.

resource "newrelic_notification_destination" "email" {
  account_id = var.new_relic_account_id
  name       = "Email - HeliosCTA Positions"
  type       = "EMAIL"

  property {
    key   = "email"
    value = join(",", var.alert_email_recipients)
  }
}

resource "newrelic_notification_channel" "email_clear_street_eod" {
  account_id     = var.new_relic_account_id
  name           = "Email - Clear Street EOD"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[New Relic] {{ annotations.title }}"
  }
}

resource "newrelic_workflow" "clear_street_eod" {
  account_id            = var.new_relic_account_id
  name                  = "Clear Street EOD → Email"
  enrichments_enabled   = true
  destinations_enabled  = true
  workflow_enabled      = true
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "Clear Street EOD policy"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.clear_street_eod_file.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email_clear_street_eod.id
  }
}
