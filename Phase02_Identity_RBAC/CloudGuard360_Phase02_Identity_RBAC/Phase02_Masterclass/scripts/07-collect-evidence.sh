#!/usr/bin/env bash
# Read-only collection. It does not export Terraform state or object IDs from Entra.
set -euo pipefail
COURSE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY_DIR="${IDENTITY_DIR:-$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform}"
POLICY_DIR="${POLICY_DIR:-$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Masterclass/policy-audit}"
if ! mountpoint -q "$HOME/clouddrive"; then echo 'STOP: persistent mount not found'; exit 2; fi
DEST="$HOME/clouddrive/cloudguard360/phase02-evidence/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$DEST"; chmod 700 "$DEST"
run(){ local name="$1";shift; printf '$';printf ' %q' "$@";printf '\n' > /dev/null; if "$@" > "$DEST/$name" 2>&1; then echo "PASS: $name"; else echo "REVIEW: $name (permission or data unavailable)"; fi; }
run subscription.txt az account show --query '{Name:name,State:state}' -o table
run groups.txt az ad group list --filter "startswith(displayName,'CG360-')" --query '[].{Name:displayName,Security:securityEnabled}' -o table
for rg in rg-cg360-app rg-cg360-network; do
 run "roles-${rg}.txt" az role assignment list --resource-group "$rg" --include-inherited --query '[].{Role:roleDefinitionName,Type:principalType}' -o table
done
run policy-assignments.txt az policy assignment list --resource-group rg-cg360-app --query '[].{Name:name,DisplayName:displayName}' -o table
run policy-compliance.txt az policy state list --resource-group rg-cg360-app --top 25 --query '[].{Policy:policyAssignmentName,State:complianceState}' -o table
if [ -f "$IDENTITY_DIR/versions.tf" ]; then
 run identity-validate.txt bash -c 'cd "$1" && terraform validate' _ "$IDENTITY_DIR"
 run identity-resources.txt bash -c 'cd "$1" && terraform state list | grep -E "^(azuread_group|azurerm_role_assignment)"' _ "$IDENTITY_DIR"
else echo 'REVIEW: identity root not available' > "$DEST/identity-missing.txt"; fi
if [ -f "$POLICY_DIR/versions.tf" ]; then
 run policy-resources.txt bash -c 'cd "$1" && terraform state list | grep "azurerm_resource_group_policy_assignment"' _ "$POLICY_DIR"
fi
cat > "$DEST/READ_ME_FIRST.txt" <<'EOT'
This evidence bundle is PRIVATE. It documents commands run, not their independent verification.
Empty results and permission failures are NOT PASS. Review every output.
Do not upload full state files, access tokens or user object IDs publicly.
Do not count a policy compliant until Azure Policy Insights has assessed relevant resources.
EOT
printf '\nPRIVATE EVIDENCE DIRECTORY: %s\n' "$DEST"
