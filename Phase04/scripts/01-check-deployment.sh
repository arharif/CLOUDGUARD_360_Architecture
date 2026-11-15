#!/usr/bin/env bash
set -euo pipefail
RG='rg-cg360-app'
APP='ca-cg360-voting'
az containerapp show -g "$RG" -n "$APP" --query '{FQDN:properties.configuration.ingress.fqdn,Provisioning:properties.provisioningState}' -o table
az containerapp show -g "$RG" -n "$APP" --query 'properties.template.containers[].{Name:name,Image:image}' -o table
az containerapp revision list -g "$RG" -n "$APP" --query '[].{Name:name,Active:properties.active,Created:properties.createdTime}' -o table
FQDN=$(az containerapp show -g "$RG" -n "$APP" --query properties.configuration.ingress.fqdn -o tsv)
curl --fail --location --retry 6 --retry-delay 5 --retry-all-errors --max-time 30 -o /dev/null -w 'HTTP %{http_code}\n' "https://${FQDN}/"
