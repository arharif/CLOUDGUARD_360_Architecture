#!/usr/bin/env bash
set -euo pipefail
PROJECT="${HOME}/clouddrive/cloudguard360"
command -v az >/dev/null || { echo 'STOP: Azure CLI not found'; exit 1; }
command -v terraform >/dev/null || { echo 'STOP: Terraform not found'; exit 1; }
mountpoint -q "${HOME}/clouddrive" || { echo 'STOP: Persistent Cloud Shell mount is missing'; exit 1; }
SUB_NAME=$(az account show --query name -o tsv 2>/dev/null) || { echo 'STOP: Azure login unavailable'; exit 1; }
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
[[ -n "$ARM_SUBSCRIPTION_ID" ]] || { echo 'STOP: Subscription ID unavailable'; exit 1; }
echo "PASS: Subscription: $SUB_NAME"
az group show -n rg-cg360-app --query '{Name:name,Location:location}' -o table
az network vnet show -g rg-cg360-app -n vnet-cg360-app --query '{Name:name,Location:location}' -o table
echo "Microsoft.App provider registration: $(az provider show --namespace Microsoft.App --query registrationState -o tsv)"
echo 'PASS: Preflight read-only checks complete. Check Azure credits before deployment.'
