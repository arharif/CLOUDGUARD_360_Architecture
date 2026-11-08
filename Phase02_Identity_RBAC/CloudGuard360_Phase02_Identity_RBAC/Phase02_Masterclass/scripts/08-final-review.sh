#!/usr/bin/env bash
set -euo pipefail
IDENTITY_DIR="${IDENTITY_DIR:-$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform}"
POLICY_DIR="${POLICY_DIR:-$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Masterclass/policy-audit}"
echo 'PHASE 02 FINAL READ-ONLY REVIEW'
if [ ! -d "$IDENTITY_DIR" ]; then echo 'REVIEW: no existing identity root at expected path'; exit 2; fi
cd "$IDENTITY_DIR"
terraform validate
state="$(terraform state list)"
groups="$(printf '%s\n' "$state" | grep -c '^azuread_group\.lab\[' || true)"
rbac="$(printf '%s\n' "$state" | grep -c '^azurerm_role_assignment\.lab\[' || true)"
echo "Groups managed: $groups (target 4)"
echo "RBAC managed:   $rbac (target 7)"
if [ -d "$POLICY_DIR" ]; then
 cd "$POLICY_DIR"
 terraform validate
 policy_state="$(terraform state list)"
 count="$(printf '%s\n' "$policy_state" | grep -c '^azurerm_resource_group_policy_assignment\.locations_audit\[' || true)"
 echo "Policy managed: $count (target 1 if deployed, 0 if skipped)"
else echo 'Policy root: not configured'; fi
if [ "$groups" = 4 ] && [ "$rbac" = 7 ]; then echo 'Terraform inventory: expected identity counts'; else echo 'REVIEW: identity inventory differs'; fi
printf '%s\n' 'CAUTION: state counts do not prove directory permissions, effective access or policy compliance.'
