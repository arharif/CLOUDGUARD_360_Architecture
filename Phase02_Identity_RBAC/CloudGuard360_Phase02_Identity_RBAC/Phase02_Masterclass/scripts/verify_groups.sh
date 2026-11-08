#!/usr/bin/env bash
set -euo pipefail
prefix="${1:-CG360}"
for name in "${prefix}-Cloud-Engineers" "${prefix}-Developers" "${prefix}-Security-Auditors" "${prefix}-Operations"; do
 echo "\nGROUP: $name"
 az ad group show --group "$name" --query '{DisplayName:displayName,SecurityEnabled:securityEnabled}' -o table || echo "NOT FOUND / permission denied: $name"
done
