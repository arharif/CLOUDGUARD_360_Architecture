#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform plan -destroy -out=phase03-destroy.tfplan
terraform show -no-color phase03-destroy.tfplan | grep -E 'will be destroyed|Plan:' || true
echo 'REVIEW: Only the Container App + Environment should be destroyed; never delete the existing RG.'
echo 'Execute terraform apply phase03-destroy.tfplan ONLY if review is successful.'
