#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../terraform"
terraform fmt -check
terraform validate
if [ -f phase02.tfplan ]; then
 terraform show -json phase02.tfplan | python3 ../scripts/check_plan.py
else
 echo 'No saved plan found. Create one using: terraform plan -out=phase02.tfplan'
fi
