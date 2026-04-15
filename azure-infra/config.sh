#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Shared configuration for HeliosCTA Azure infrastructure scripts.
# Source this file; do not execute directly.
# ------------------------------------------------------------------------------

# Subscription and region
SUBSCRIPTION="ec7843fc-6505-4677-b84f-f4c613b2914d"
LOCATION="eastus2"

# Resource Group
RG="helioscta-backend-rg"

# Azure Managed Grafana
GRAFANA_NAME="amg-helioscta-backend"
GRAFANA_SKU_TIER="Standard"
GRAFANA_VIEWERS_GROUP_NAME="grafana-viewers"
GRAFANA_VIEWERS_GROUP_DESCRIPTION="Org-wide read-only access to Azure Managed Grafana dashboards."

# Azure Monitor Action Group
ACTION_GROUP_NAME="helioscta-alerts-ag"
ACTION_GROUP_SHORT_NAME="HCTAAlerts"
# Set explicitly or leave empty to default to current az account user principal name.
ACTION_GROUP_PUSH_EMAIL=""
ACTION_GROUP_EMAIL_RECEIVER=""  # defaults to PUSH_EMAIL if empty
# App registration client ID (for RBAC — reuse Outlook app registration)
ACTION_GROUP_APP_CLIENT_ID="6cb4894f-6595-48d9-ab04-e042cefed6d4"

# Azure Storage Account (Blob)
STORAGE_ACCOUNT="sthelioscta"
STORAGE_CONTAINER="helioscta"
STORAGE_SKU="Standard_LRS"

# Test Database
TEST_PG_SERVER="psql-helioscta-test"
TEST_PG_ADMIN="testadmin"
TEST_PG_DB="helioscta"

# Optional local-only secrets/overrides file (ignored by git).
# Create azure-infra/config.secrets.sh on your machine for passwords.
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_SECRETS_FILE="$CONFIG_DIR/config.secrets.sh"
if [[ -f "$LOCAL_SECRETS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_SECRETS_FILE"
fi