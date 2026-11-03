#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for tool in terraform python3 tflint checkov helm; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
python3 -m unittest discover -s tests -v
python3 -m compileall -q app scripts
for script in scripts/*.sh cisco/wan-init.sh; do
  bash -n "$script"
done
terraform fmt -check -recursive
for env in dev prod; do
  (cd "environments/$env" && terraform init -backend=false -input=false && terraform validate)
done
export TFLINT_CONFIG_FILE="$PWD/.tflint.hcl"
tflint --init --config="$TFLINT_CONFIG_FILE"
for env in dev prod; do
  tflint --chdir="environments/$env" --config="$TFLINT_CONFIG_FILE"
done
python3 -c 'import yaml; yaml.safe_load(open("cisco/containerlab.yaml"))'
helm lint helm/hybrid-demo --set azure.keyvaultName=a --set azure.workloadClientId=b --set azure.tenantId=c
checkov -d . --framework terraform --quiet --skip-download
