#!/usr/bin/env bash
set -euo pipefail
say(){ printf '\n[PHASE02] %s\n' "$*"; }
for c in az terraform python3 mountpoint; do command -v "$c" >/dev/null || { echo "ERROR: missing command: $c"; exit 1; }; done
say 'Checking Azure CLI session and persistence'
if ! mountpoint -q "$HOME/clouddrive"; then echo 'ERROR: ~/clouddrive is not mounted; STOP before Terraform apply.'; exit 1; fi
if [ -z "${ARM_SUBSCRIPTION_ID:-}" ]; then echo 'ERROR: export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"'; exit 1; fi
CURRENT_ID="$(az account show --query id -o tsv)"
[ "$CURRENT_ID" = "$ARM_SUBSCRIPTION_ID" ] || { echo 'ERROR: selected subscription differs from Terraform subscription.'; exit 1; }
az account show --query '{Name:name,State:state}' -o table
say 'Checking Phase 01 resource groups (read-only)'
for rg in rg-cg360-app rg-cg360-network; do
 if az group show --name "$rg" --query name -o tsv >/dev/null 2>&1; then echo "OK: $rg exists"; else echo "ERROR: cannot read $rg; check exact name and permissions"; exit 1; fi
done
say 'Checking directory API read access (optional for audit, required for group operations)'
if az ad group list --filter "startswith(displayName,'CG360-')" --query 'length(@)' -o tsv >/dev/null 2>&1; then
 echo 'Microsoft Graph group-list query: OK'
else echo 'WARNING: Microsoft Graph group-list query denied; group provisioning may require additional Entra permissions.'; fi
say 'Preflight completed. This script did not modify Azure.'
