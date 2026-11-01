#!/usr/bin/env bash
set -euo pipefail

for cmd in az terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERREUR: l'outil '$cmd' n'est pas installe ou pas dans le PATH." >&2
    exit 1
  fi
done

if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  echo "ERREUR: ARM_SUBSCRIPTION_ID est absent. Configurez-le localement sans le committer." >&2
  exit 1
fi

printf '\n--- Terraform ---\n'
terraform version | head -n 2
printf '\n--- Azure subscription (sans afficher les IDs) ---\n'
az account show --query '{Name:name,State:state,IsDefault:isDefault}' -o table
printf '\n--- Microsoft.Network resource provider ---\n'
az provider show --namespace Microsoft.Network --query registrationState -o tsv
printf '\n--- Readiness ---\n'
echo "Vérifiez le budget et les permissions avant terraform apply."
