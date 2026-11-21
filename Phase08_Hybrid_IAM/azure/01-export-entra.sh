#!/usr/bin/env bash
# Read-only Azure Entra and RBAC export. Will stop if Entra group access is denied.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/evidence/cloud}"
mkdir -p "$OUT"
command -v az >/dev/null || { echo 'FAIL: az CLI missing'; exit 2; }
az account show --query '{name:name,state:state}' -o json > "$OUT/azure_subscription.json"
for n in CG360-Cloud-Engineers CG360-Developers CG360-Security-Auditors CG360-Operations; do
  az ad group list --filter "displayName eq '$n'" --query '[].{displayName:displayName,id:id,securityEnabled:securityEnabled}' -o json > "$OUT/$n.json"
done
python3 - "$OUT" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]); names=('CG360-Cloud-Engineers','CG360-Developers','CG360-Security-Auditors','CG360-Operations')
all_groups=[]
for n in names:
    data=json.loads((p/(n+'.json')).read_text())
    all_groups.extend(data)
(p/'entra_groups.json').write_text(json.dumps(all_groups,indent=2)+'\n')
print('Entra group records:',len(all_groups))
PY
for rg in rg-cg360-app rg-cg360-network; do
  if az group show -n "$rg" -o none >/dev/null 2>&1; then
    az role assignment list --resource-group "$rg" --all --include-inherited --query '[].{role:roleDefinitionName,scope:scope,principalId:principalId,principalType:principalType}' -o json > "$OUT/rbac_${rg}.json"
    echo "PASS: RBAC exported for $rg"
  else
    echo "WARN: RG $rg unavailable; RBAC not exported"
  fi
done
echo "PASS: Read-only evidence saved in $OUT"
echo 'WARNING: Contains cloud object/resource identifiers. Keep evidence private.'
