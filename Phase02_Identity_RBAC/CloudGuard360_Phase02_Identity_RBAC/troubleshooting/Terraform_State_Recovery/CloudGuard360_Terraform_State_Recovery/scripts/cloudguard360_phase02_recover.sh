#!/usr/bin/env bash
# CloudGuard360 / Phase 02 — safe, repeatable state diagnosis and recovery.
# Modes: --diagnose (default, no Terraform state changes), --recover (imports to state ONLY).
# No 'terraform apply' or Azure resource mutations are performed by this script.
set -Eeuo pipefail
umask 077

MODE="${1:---diagnose}"
case "$MODE" in
  --diagnose|--recover) ;;
  -h|--help)
    printf 'Usage: bash %s [--diagnose|--recover]\n' "$0"
    exit 0 ;;
  *) printf 'Invalid mode: %s\n' "$MODE" >&2; exit 2 ;;
esac

BASE="${CG360_BASE:-$HOME/clouddrive/cloudguard360}"
PROJECT="${CG360_PROJECT:-$BASE/CloudGuard360_Phase02_Identity_RBAC/terraform}"
PRIVATE="$BASE/.phase02-recovery-private"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

info() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn() { printf 'REVIEW: %s\n' "$*" >&2; }
fail() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
trap 'printf "Stopped at line %s. Inspect output; do not run terraform apply blindly.\n" "$LINENO" >&2' ERR

for cmd in az terraform python3 grep; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
done
[[ -d "$PROJECT" ]] || fail "Terraform project not found: $PROJECT"
cd "$PROJECT"

info "01 / Project and Azure context"
[[ -f main.tf && -f rbac.tf && -f outputs.tf && -f variables.tf ]] || fail "Missing required .tf files"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)" || fail "Please sign in with 'az login'"
TENANT_ID="$(az account show --query tenantId -o tsv)"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" ARM_TENANT_ID="$TENANT_ID"
printf 'Project: %s\nSubscription: %s\nTenant: %s\n' "$PROJECT" "$SUBSCRIPTION_ID" "$TENANT_ID"

# Optional stricter pinning before recovery; never guess or silently switch subscriptions.
if [[ -n "${CG360_EXPECTED_SUBSCRIPTION_ID:-}" ]]; then
  [[ "$SUBSCRIPTION_ID" == "$CG360_EXPECTED_SUBSCRIPTION_ID" ]] || fail "Wrong subscription"
fi
if [[ -n "${CG360_EXPECTED_TENANT_ID:-}" ]]; then
  [[ "$TENANT_ID" == "$CG360_EXPECTED_TENANT_ID" ]] || fail "Wrong tenant"
fi

# This runbook is specifically for the local, default workspace of Phase 02.
# Do not import into a remote backend or an unexpected workspace.
if grep -Eq 'backend[[:space:]]+"|^[[:space:]]*cloud[[:space:]]*\{' ./*.tf; then
  fail "Remote backend/cloud configuration detected. Inspect and recover that backend instead."
fi

info "02 / Terraform initialization and workspace"
terraform init -input=false -no-color >/dev/null
terraform validate -no-color
WORKSPACE="$(terraform workspace show)"
[[ "$WORKSPACE" == default ]] || fail "Unexpected Terraform workspace '$WORKSPACE'"
printf 'Workspace: %s\n' "$WORKSPACE"

if [[ -f terraform.tfvars ]]; then
  printf 'terraform.tfvars: found (will not overwrite)\n'
else
  warn 'terraform.tfvars missing'
fi

info "03 / Phase 01 Resource Groups (read only)"
for rg in rg-cg360-app rg-cg360-network; do
  [[ "$(az group exists --name "$rg")" == true ]] || fail "Resource group not found: $rg"
  printf 'OK %s\n' "$rg"
done

info "04 / Existing Entra groups (read only)"
declare -a GROUP_KEYS=(cloud_engineers developers security_auditors operations)
declare -a GROUP_NAMES=(CG360-Cloud-Engineers CG360-Developers CG360-Security-Auditors CG360-Operations)
declare -A GROUP_IDS=()
for i in "${!GROUP_KEYS[@]}"; do
  key="${GROUP_KEYS[$i]}"; name="${GROUP_NAMES[$i]}"
  # Exact display-name filter; reject missing/duplicate results or non-security groups.
  payload="$(az ad group list --filter "displayName eq '$name'" -o json)" || fail "Entra query failed for $name"
  id="$(python3 -c '
import json,sys
name=sys.argv[1]
a=json.load(sys.stdin)
a=[x for x in a if x.get("displayName")==name and x.get("securityEnabled") is True]
if len(a)!=1: sys.exit("Expected exactly one security group: %s; got %d"%(name,len(a)))
print(a[0]["id"])
' "$name" <<< "$payload")" || fail "Ambiguous or invalid Entra group: $name"
  GROUP_IDS["$key"]="$id"
  printf 'OK %-27s object=%s\n' "$name" "$id"
done

info "05 / RBAC exact-scope inventory (read only)"
mkdir -p "$PRIVATE"
chmod 700 "$PRIVATE" 2>/dev/null || true
NET_SCOPE="$(az group show -n rg-cg360-network --query id -o tsv)"
APP_SCOPE="$(az group show -n rg-cg360-app --query id -o tsv)"
AZ_ARGS=(--all --fill-principal-name false --fill-role-definition-name false -o json)
az role assignment list --scope "$NET_SCOPE" "${AZ_ARGS[@]}" > "$PRIVATE/network-rbac.json" || fail "Cannot read network RBAC"
az role assignment list --scope "$APP_SCOPE" "${AZ_ARGS[@]}" > "$PRIVATE/app-rbac.json" || fail "Cannot read app RBAC"

# Inventory expected pairs using stable built-in Azure role definition GUIDs.
{
  printf 'cloud_engineers\t%s\n' "${GROUP_IDS[cloud_engineers]}"
  printf 'developers\t%s\n' "${GROUP_IDS[developers]}"
  printf 'security_auditors\t%s\n' "${GROUP_IDS[security_auditors]}"
  printf 'operations\t%s\n' "${GROUP_IDS[operations]}"
} > "$PRIVATE/groups.tsv"

python3 - "$PRIVATE/groups.tsv" "$PRIVATE/network-rbac.json" "$PRIVATE/app-rbac.json" "$NET_SCOPE" "$APP_SCOPE" > "$PRIVATE/expected-rbac.tsv" <<'PY'
import json,sys
ids_file, net_file, app_file, net_scope, app_scope = sys.argv[1:]
with open(ids_file,encoding='utf-8') as f:
    ids=dict(line.strip().split('\t',1) for line in f if line.strip())
with open(net_file,encoding='utf-8') as f: net=json.load(f)
with open(app_file,encoding='utf-8') as f: app=json.load(f)
roles={
    'Reader':'acdd72a7-3385-48ef-bd42-f606fba81ae7',
    'Monitoring Reader':'43d0d8ad-25c7-4714-9337-8ba259a9fe05'
}
expected=[
    ('engineer_network_reader','cloud_engineers',net_scope,'Reader',net),
    ('engineer_app_reader','cloud_engineers',app_scope,'Reader',app),
    ('developer_app_reader','developers',app_scope,'Reader',app),
    ('auditor_network_reader','security_auditors',net_scope,'Reader',net),
    ('auditor_app_reader','security_auditors',app_scope,'Reader',app),
    ('ops_network_monitoring','operations',net_scope,'Monitoring Reader',net),
    ('ops_app_monitoring','operations',app_scope,'Monitoring Reader',app)
]
for key, group, scope, role, assignments in expected:
    matches=[a for a in assignments
             if str(a.get('principalId','')).lower()==ids[group].lower()
             and str(a.get('scope','')).lower()==scope.lower()
             and str(a.get('roleDefinitionId','')).lower().endswith('/'+roles[role])]
    if len(matches)>1: sys.exit('Duplicate direct role assignments: '+key)
    assignment_id=(matches[0].get('id') or '') if matches else 'ABSENT'
    if matches and '/providers/microsoft.authorization/roleassignments/' not in assignment_id.lower():
        sys.exit('Unrecognised role-assignment ID for '+key)
    print(key+'\t'+assignment_id)
PY

FOUND=0; MISSING=0
while IFS=$'\t' read -r key assignment_id; do
  if [[ "$assignment_id" == ABSENT ]]; then
    printf 'MISSING %-29s\n' "$key"
    MISSING=$((MISSING+1))
  else
    printf 'FOUND   %-29s\n' "$key"
    FOUND=$((FOUND+1))
  fi
done < "$PRIVATE/expected-rbac.tsv"
printf 'RBAC exact matches found: %d/7; missing: %d/7\n' "$FOUND" "$MISSING"

info "06 / Terraform state status"
if [[ -f terraform.tfstate ]]; then
  cp -p terraform.tfstate "$PRIVATE/terraform.tfstate.precheck.$STAMP"
  printf 'State backup saved privately\n'
fi
if STATE_LIST="$(terraform state list 2>&1)"; then
  printf '%s\n' "$STATE_LIST" | sed '/^$/d'
else
  [[ ! -f terraform.tfstate ]] || fail "State exists but cannot be read: $STATE_LIST"
  STATE_LIST=""
  warn 'No readable local Terraform state yet'
fi

if [[ "$MODE" == --diagnose ]]; then
  info "DIAGNOSIS COMPLETE: infrastructure unchanged, state unchanged"
  printf 'To recover missing state addresses, first verify that no other active Terraform state owns these resources.\n'
  printf 'Then run: bash %q --recover\n' "$0"
  exit 0
fi

info "07 / Explicit recovery approval"
if [[ ! -f terraform.tfvars ]]; then
  cat > terraform.tfvars <<'TFVARS'
prefix                  = "CG360"
app_resource_group      = "rg-cg360-app"
network_resource_group  = "rg-cg360-network"
enable_role_assignments = true
enable_app_contributor  = false
demo_member_object_id   = ""
TFVARS
  chmod 600 terraform.tfvars 2>/dev/null || true
  printf 'Created conservative terraform.tfvars for seven Reader/Monitoring Reader roles\n'
else
  grep -Eq '^[[:space:]]*enable_role_assignments[[:space:]]*=[[:space:]]*true([[:space:]]*(#.*)?)?$' terraform.tfvars ||
    fail 'Existing tfvars must explicitly enable_role_assignments = true; no import performed'
  if grep -Eq '^[[:space:]]*enable_app_contributor[[:space:]]*=[[:space:]]*true' terraform.tfvars; then
    fail 'Contributor escalation detected. Review configuration manually.'
  fi
fi

printf 'Recovery will WRITE ONLY Terraform state and (if absent) terraform.tfvars.\n'
printf 'It will NOT change Azure resources. Confirm ownership and subscription.\n'
read -r -p 'Type RECOVER to approve local state imports: ' CONFIRM
[[ "$CONFIRM" == RECOVER ]] || fail 'Recovery cancelled'

# The seven role assignments are intentionally required to prevent a half-managed
# state from being treated as ready. Existing partial imports remain idempotent.
[[ "$FOUND" -eq 7 ]] || fail "Only $FOUND/7 assignments exist. Diagnose missing permissions first."

STATE_LIST="$(terraform state list 2>/dev/null || true)"
for key in "${GROUP_KEYS[@]}"; do
  addr="azuread_group.lab[\"$key\"]"
  if grep -Fqx "$addr" <<< "$STATE_LIST"; then
    printf 'SKIP  %-35s already in state\n' "$addr"
  else
    terraform import -input=false -no-color "$addr" "/groups/${GROUP_IDS[$key]}"
    STATE_LIST="$(terraform state list)"
  fi
done

while IFS=$'\t' read -r key assignment_id; do
  addr="azurerm_role_assignment.lab[\"$key\"]"
  if grep -Fqx "$addr" <<< "$STATE_LIST"; then
    printf 'SKIP  %-45s already in state\n' "$addr"
  else
    terraform import -input=false -no-color "$addr" "$assignment_id"
    STATE_LIST="$(terraform state list)"
  fi
done < "$PRIVATE/expected-rbac.tsv"

info "08 / Refresh-only PREVIEW (no apply)"
terraform plan -refresh-only -input=false -no-color
printf '\nTo review and write refreshed outputs to state, run MANUALLY:\n'
printf '  terraform apply -refresh-only\n'
printf 'Then run terraform output rbac_assignment_count and terraform plan.\n'
printf 'Do not apply a normal plan before reviewing any drift.\n'
info "RECOVERY IMPORTS COMPLETE"
