#!/usr/bin/env bash
set -euo pipefail
printf '\nAZURE CONTEXT (do not share tenant/subscription IDs):\n'
az account show --query '{Name:name,State:state}' -o table
for rg in rg-cg360-network rg-cg360-app; do
 printf '\nRESOURCE GROUP: %s\n' "$rg"
 az group show -n "$rg" --query '{Name:name,Location:location}' -o table
 printf 'ROLE ASSIGNMENTS (includes inherited):\n'
 az role assignment list --resource-group "$rg" --include-inherited --query '[].{Role:roleDefinitionName,Scope:scope}' -o table || echo 'WARNING: could not list all assignments; check permissions.'
done
printf '\nREAD-ONLY AUDIT COMPLETE\n'
