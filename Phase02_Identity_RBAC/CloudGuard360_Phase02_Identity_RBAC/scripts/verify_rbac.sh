#!/usr/bin/env bash
set -euo pipefail
prefix="${1:-CG360}"
for name in "${prefix}-Cloud-Engineers" "${prefix}-Developers" "${prefix}-Security-Auditors" "${prefix}-Operations"; do
 printf '\nASSIGNMENTS FOR GROUP: %s\n' "$name"
 object_id="$(az ad group show --group "$name" --query id -o tsv)" || { echo 'Graph access denied or group missing'; continue; }
 # Use --all to find assignments below the subscription, not just at subscription level.
 az role assignment list --all --assignee "$object_id" --query '[].{Role:roleDefinitionName,Scope:scope}' -o table || echo 'Cannot enumerate assignments'
done
