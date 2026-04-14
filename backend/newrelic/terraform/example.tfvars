# Copy this file, fill in real values, and pass with:
#   terraform plan  -var-file=local.tfvars
#   terraform apply -var-file=local.tfvars
#
# Or, preferred, set the equivalent TF_VAR_* env vars from Azure Key Vault and
# omit the -var-file flag entirely.

new_relic_account_id = 0000000
new_relic_region     = "US"
environment          = "prod"

alert_email_recipients = [
  "alerts@helioscta.example",
  "oncall@helioscta.example",
]

# Sensitive — keep out of git
# new_relic_api_key = "NRAK-..."
