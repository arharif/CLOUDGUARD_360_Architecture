#!/usr/bin/env bash
set -euo pipefail
command -v az >/dev/null || { echo 'FAIL: Azure CLI is not installed'; exit 2; }
az account show --query '{Name:name,State:state}' -o table
echo 'INFO: read-only preflight. No Azure resources will be created.'
for rg in rg-cg360-app rg-cg360-network; do
  if az group show -n "$rg" --query name -o tsv >/dev/null 2>&1; then
    echo "PASS: Found RG $rg"
  else
    echo "WARN: $rg unavailable (expired subscription, missing role, or never created)"
  fi
done
