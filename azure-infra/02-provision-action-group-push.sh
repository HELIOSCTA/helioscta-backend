#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Phase 2: Provision Azure Monitor Action Group with push + email receivers
# and grant RBAC so the app registration can trigger notifications from Python.
#
# This script:
#   1) Creates or updates one Action Group in the configured Resource Group
#   2) Configures two receiver types: Azure app push + email
#   3) Grants Monitoring Contributor to the app registration (for createNotifications API)
#   4) Optionally sends a test notification
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - `bash azure-infra/01-provision-infrastructure.sh` already run (RG exists)
#   - In config.sh, set ACTION_GROUP_* values as needed
#
# Usage:
#   bash azure-infra/02-provision-action-group-push.sh
#
# Optional:
#   TEST_NOTIFICATION=1 bash azure-infra/02-provision-action-group-push.sh
# ------------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Helper: run az with MSYS_NO_PATHCONV to prevent Git Bash mangling /subscriptions/... paths
az() { MSYS_NO_PATHCONV=1 command az "$@"; }

if [[ "$SUBSCRIPTION" == "<your-subscription-id>" ]]; then
  echo "ERROR: Set SUBSCRIPTION in config.sh before running." >&2
  exit 1
fi

if [[ -z "${ACTION_GROUP_NAME:-}" || -z "${ACTION_GROUP_SHORT_NAME:-}" ]]; then
  echo "ERROR: Set ACTION_GROUP_NAME and ACTION_GROUP_SHORT_NAME in config.sh." >&2
  exit 1
fi

echo ""
echo "=== Setting subscription ==="
az account set --subscription "$SUBSCRIPTION"

if ! az group show --name "$RG" --output none 2>/dev/null; then
  echo "ERROR: Resource Group '$RG' not found. Run 01-provision-infrastructure.sh first." >&2
  exit 1
fi

# ── Resolve receiver emails ──────────────────────────────────────────────────

PUSH_EMAIL="${ACTION_GROUP_PUSH_EMAIL:-}"
if [[ -z "$PUSH_EMAIL" ]]; then
  PUSH_EMAIL="$(az account show --query 'user.name' -o tsv | tr -d '\r')"
fi

if [[ -z "$PUSH_EMAIL" ]]; then
  echo "ERROR: Could not resolve push receiver email. Set ACTION_GROUP_PUSH_EMAIL in config.sh." >&2
  exit 1
fi

EMAIL_RECEIVER="${ACTION_GROUP_EMAIL_RECEIVER:-$PUSH_EMAIL}"

# ── Create/update Action Group ───────────────────────────────────────────────

echo ""
echo "=== Creating/updating Action Group: $ACTION_GROUP_NAME ==="
echo "  Push receiver:  $PUSH_EMAIL"
echo "  Email receiver: $EMAIL_RECEIVER"

az monitor action-group create \
  --resource-group "$RG" \
  --name "$ACTION_GROUP_NAME" \
  --short-name "$ACTION_GROUP_SHORT_NAME" \
  --action azureapppush mobilepush "$PUSH_EMAIL" \
  --action email emailnotify "$EMAIL_RECEIVER" \
  --output none

ACTION_GROUP_ID="$(az monitor action-group show \
  --resource-group "$RG" \
  --name "$ACTION_GROUP_NAME" \
  --query id -o tsv | tr -d '\r')"

echo ""
echo "=== Action Group ready ==="
echo "  Name: $ACTION_GROUP_NAME"
echo "  Resource ID: $ACTION_GROUP_ID"
echo "  Push receiver:  $PUSH_EMAIL"
echo "  Email receiver: $EMAIL_RECEIVER"

# ── Grant RBAC for Python createNotifications API ────────────────────────────

APP_CLIENT_ID="${ACTION_GROUP_APP_CLIENT_ID:-}"
if [[ -n "$APP_CLIENT_ID" ]]; then
  echo ""
  echo "=== Granting Monitoring Contributor to app registration ==="
  APP_OBJECT_ID="$(az ad sp show --id "$APP_CLIENT_ID" --query id -o tsv | tr -d '\r')"
  az role assignment create \
    --assignee-object-id "$APP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Monitoring Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION/resourceGroups/$RG" \
    --output none 2>/dev/null || echo "  (role assignment already exists)"
  echo "  Granted to: $APP_CLIENT_ID"
else
  echo ""
  echo "=== Skipping RBAC — set ACTION_GROUP_APP_CLIENT_ID in config.sh ==="
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "Next: attach this Action Group to alert rules using:"
echo "  --action \"$ACTION_GROUP_ID\""

# ── Optional test notification ───────────────────────────────────────────────

if [[ "${TEST_NOTIFICATION:-0}" == "1" ]]; then
  echo ""
  echo "=== Sending test notification to Action Group ==="
  az monitor action-group test-notifications create \
    --resource-group "$RG" \
    --action-group "$ACTION_GROUP_NAME" \
    --alert-type metricstaticthreshold \
    --add-action azureapppush mobilepush "$PUSH_EMAIL" \
    --add-action email emailnotify "$EMAIL_RECEIVER"
  echo "Test request submitted."
fi

