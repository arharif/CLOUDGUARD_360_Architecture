#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
URL="$(terraform output -raw app_url)"
echo "Application URL: $URL"
echo 'Container App summary:'
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query '{Name:name,Provisioning:properties.provisioningState,FQDN:properties.configuration.ingress.fqdn}' -o table
echo 'Revisions:'
az containerapp revision list -g rg-cg360-app -n ca-cg360-voting --query '[].{Name:name,Active:properties.active,Health:properties.healthState}' -o table
status="$(curl -L -sS -o /dev/null -w '%{http_code}' --max-time 90 "$URL" || true)"
echo "HTTP status: $status"
if [[ "$status" == "200" ]]; then
  echo 'PASS: Voting web application returned HTTP 200'
else
  echo 'WARN: Expected HTTP 200. Check revisions, ingress and logs. Cold starts may need a second try.'
fi
