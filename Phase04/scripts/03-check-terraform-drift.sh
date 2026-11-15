#!/usr/bin/env bash
set -euo pipefail
PROJECT="$HOME/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform"
if [[ ! -d "$PROJECT" ]]; then echo "Phase 03 Terraform folder not found at $PROJECT"; exit 2; fi
cd "$PROJECT"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
terraform plan -detailed-exitcode -no-color > phase03-drift-review.txt 2>&1 && rc=0 || rc=$?
case "$rc" in
  0) echo 'PASS: No drift detected';;
  2) echo 'REVIEW: Terraform proposes changes; inspect phase03-drift-review.txt BEFORE applying';;
  *) echo 'ERROR: Terraform plan failed; inspect phase03-drift-review.txt';;
esac
printf 'Output file: %s/phase03-drift-review.txt\n' "$PWD"
exit 0
