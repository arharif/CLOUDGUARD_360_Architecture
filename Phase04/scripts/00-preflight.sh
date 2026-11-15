#!/usr/bin/env bash
set -euo pipefail
for bin in az terraform git python3; do
  if command -v "$bin" >/dev/null 2>&1; then echo "OK: $bin"; else echo "MISSING: $bin"; fi
done
if mountpoint -q "$HOME/clouddrive"; then echo 'OK: Persistent Cloud Shell storage'; else echo 'WARNING: clouddrive not mounted'; fi
az account show --query '{Name:name,State:state}' --output table
for rg in rg-cg360-app rg-cg360-network; do
  az group show -n "$rg" --query '{Name:name,Location:location}' -o table
done
if az containerapp show -g rg-cg360-app -n ca-cg360-voting >/dev/null 2>&1; then
  echo 'OK: Phase 03 application exists'
  az containerapp show -g rg-cg360-app -n ca-cg360-voting --query 'properties.template.containers[].{Name:name,Image:image}' -o table
else
  echo 'WARNING: Phase 03 Container App not found; CI-only route remains available.'
fi
