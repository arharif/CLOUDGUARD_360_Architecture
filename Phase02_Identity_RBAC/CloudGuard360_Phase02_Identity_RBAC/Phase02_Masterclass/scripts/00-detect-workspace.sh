#!/usr/bin/env bash
set -euo pipefail
printf '\nCLOUDGUARD 360 / PHASE 02 WORKSPACE DISCOVERY\n'
if mountpoint -q "$HOME/clouddrive"; then echo 'PASS: persistent Cloud Shell mount'; else echo 'STOP: ~/clouddrive is not mounted'; exit 2; fi
for c in az terraform python3 unzip; do command -v "$c" >/dev/null || { echo "STOP: missing $c"; exit 2; }; done
az account show --query '{Name:name,State:state}' -o table
ROOT="$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform"
if [ -f "$ROOT/versions.tf" ]; then
 echo "EXISTING IDENTITY PROJECT: $ROOT"
 if [ -f "$ROOT/terraform.tfstate" ]; then echo 'Existing local state detected: DO NOT overwrite/move it.'; fi
 (cd "$ROOT" && terraform state list 2>/dev/null | sed -n '1,20p') || echo 'Unable to inspect state: check Terraform initialisation and backend.'
else
 echo 'Existing Phase 02 project NOT found at default path. Use the template only for a fresh lab.'
fi
printf '\nREAD-ONLY DISCOVERY COMPLETE\n'
