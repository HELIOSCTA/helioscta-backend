provider "newrelic" {
  account_id = var.new_relic_account_id
  api_key    = var.new_relic_api_key
  region     = var.new_relic_region
}

# Flat root-module layout. Resources are grouped by file:
#
#   versions.tf                              — Terraform / provider pins
#   variables.tf                             — input variables
#   main.tf                                  — provider config + this comment
#   dashboard_clear_street_trades_to_mufg.tf — newrelic_one_dashboard
#   alert_cs_eod_file_detected.tf            — newrelic_nrql_alert_condition + policy
#   alert_cs_eod_file_late.tf                — newrelic_nrql_alert_condition (shared policy)
#   workflows.tf                             — Email destination + notification channel + workflow
#
# State is local for the first cut (`terraform.tfstate` is gitignored). Migrate
# to an Azure Storage backend in a follow-up by adding a `backend "azurerm"`
# block here and running `terraform init -migrate-state`.

locals {
  team_label  = "helioscta-positions"
  environment = var.environment
}
