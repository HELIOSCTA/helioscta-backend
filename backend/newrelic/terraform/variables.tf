variable "new_relic_account_id" {
  description = "New Relic account ID. Sourced from TF_VAR_new_relic_account_id."
  type        = number
}

variable "new_relic_api_key" {
  description = "New Relic User API key. Sourced from TF_VAR_new_relic_api_key. Used by the provider for NerdGraph mutations."
  type        = string
  sensitive   = true
}

variable "new_relic_region" {
  description = "New Relic data region. US is the only value used today."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], var.new_relic_region)
    error_message = "new_relic_region must be \"US\" or \"EU\"."
  }
}

variable "environment" {
  description = "Environment label stamped on dashboard variables and alert names. Use \"prod\" for the canonical instance."
  type        = string
  default     = "prod"
}

variable "alert_email_recipients" {
  description = "Email addresses that receive Clear Street EOD alert notifications. Source from TF_VAR_alert_email_recipients (HCL list literal) or a tfvars file. Mobile push delivery is handled out-of-band by the NR mobile app and does not need a TF variable."
  type        = list(string)

  validation {
    condition     = length(var.alert_email_recipients) > 0
    error_message = "alert_email_recipients must contain at least one address."
  }
}
