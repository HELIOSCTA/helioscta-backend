#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Phase 3: Provision Azure Blob Storage for parquet cache layer.
#
# This script provisions:
#   1) Storage Account
#   2) Blob container
#
# Prerequisites:
#   - Azure CLI installed and authenticated (az login)
#   - config.sh populated (subscription, location, storage account names)
#   - Phase 1 already run (resource group exists)
#
# Usage:
#   bash azure-infra/03-provision-blob-storage.sh
# ------------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Helper: run az with MSYS_NO_PATHCONV to prevent Git Bash mangling /subscriptions/... paths
az() { MSYS_NO_PATHCONV=1 command az "$@"; }

echo ""
echo "=== Setting subscription ==="
az account set --subscription "$SUBSCRIPTION"

# ── Storage Account ──────────────────────────────────────────────────────────

echo ""
if az storage account show --resource-group "$RG" --name "$STORAGE_ACCOUNT" --output none 2>/dev/null; then
  echo "=== Storage Account '$STORAGE_ACCOUNT' already exists - skipping ==="
else
  echo "=== Creating Storage Account: $STORAGE_ACCOUNT ==="
  az storage account create \
    --resource-group "$RG" \
    --name "$STORAGE_ACCOUNT" \
    --location "$LOCATION" \
    --sku "$STORAGE_SKU" \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access true \
    --output none
fi

# ── Blob Container ───────────────────────────────────────────────────────────

echo ""
CONNECTION_STRING=$(az storage account show-connection-string \
  --resource-group "$RG" \
  --name "$STORAGE_ACCOUNT" \
  --query connectionString \
  -o tsv)

if az storage container show \
  --name "$STORAGE_CONTAINER" \
  --connection-string "$CONNECTION_STRING" \
  --output none 2>/dev/null; then
  echo "=== Blob Container '$STORAGE_CONTAINER' already exists - skipping ==="
else
  echo "=== Creating Blob Container: $STORAGE_CONTAINER ==="
  az storage container create \
    --name "$STORAGE_CONTAINER" \
    --connection-string "$CONNECTION_STRING" \
    --public-access blob \
    --output none
fi

# ── Summary ──────────────────────────────────────────────────────────────────

BLOB_ENDPOINT=$(az storage account show \
  --resource-group "$RG" \
  --name "$STORAGE_ACCOUNT" \
  --query "primaryEndpoints.blob" \
  -o tsv)

echo ""
echo "=== Blob Storage provisioning complete ==="
echo ""
echo "Resources ready:"
echo "  Storage Account:    $STORAGE_ACCOUNT"
echo "  Blob Container:     $STORAGE_CONTAINER"
echo "  Blob Endpoint:      $BLOB_ENDPOINT"
echo ""
echo "Add to .env.shared:"
echo "  AZURE_STORAGE_CONNECTION_STRING=$CONNECTION_STRING"
echo "  AZURE_STORAGE_ACCOUNT_NAME=$STORAGE_ACCOUNT"
echo "  AZURE_CONTAINER_NAME=$STORAGE_CONTAINER"
