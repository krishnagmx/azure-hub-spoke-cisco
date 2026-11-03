#!/usr/bin/env bash
set -euo pipefail
: "${STATE_RG:?Set STATE_RG}"
: "${STATE_ACCOUNT:?Set STATE_ACCOUNT, 3-24 lowercase letters/digits}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
LOCATION="${LOCATION:-westeurope}"
az group create --name "$STATE_RG" --location "$LOCATION" --output none
az storage account create --name "$STATE_ACCOUNT" --resource-group "$STATE_RG" \
  --location "$LOCATION" --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --https-only true --allow-blob-public-access false \
  --output none
# Backend must be accessible from GitHub-hosted runners; enforce Azure AD RBAC.
ACCOUNT_ID="$(az storage account show -n "$STATE_ACCOUNT" -g "$STATE_RG" --query id -o tsv)"
az storage account blob-service-properties update -n "$STATE_ACCOUNT" -g "$STATE_RG" \
  --enable-versioning true --output none
OID="$(az ad signed-in-user show --query id -o tsv)"
az role assignment create --assignee-object-id "$OID" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$ACCOUNT_ID" --output none || true
az storage container create --name "$STATE_CONTAINER" --account-name "$STATE_ACCOUNT" \
  --auth-mode login --output none
printf 'State backend: rg=%s account=%s container=%s\n' "$STATE_RG" "$STATE_ACCOUNT" "$STATE_CONTAINER"
printf 'Assign Blob Data Contributor to the plan and apply OIDC identities; allow RBAC propagation.\n'
