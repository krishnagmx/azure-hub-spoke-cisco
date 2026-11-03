#!/usr/bin/env bash
set -euo pipefail
: "${KEYVAULT_NAME:?KEYVAULT_NAME must be set}"
printf 'Value of secret example-message (not echoed): '
IFS= read -rs VALUE
printf '\n'
[ -n "$VALUE" ] || { echo 'Empty values are disallowed.' >&2; exit 1; }
# Run from a network that can reach the vault PRIVATE endpoint and has
# Key Vault Secrets Officer data-plane RBAC. Never pass values as Terraform vars.
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name example-message \
  --value "$VALUE" --output none
unset VALUE
printf 'Secret uploaded to private Key Vault.\n'
