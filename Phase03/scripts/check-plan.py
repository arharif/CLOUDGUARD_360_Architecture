#!/usr/bin/env python3
"""Strict safety check for FIRST deployment, called with: terraform show -json phase03.tfplan | python3 scripts/check-plan.py"""
import json
import sys

plan = json.load(sys.stdin)
changes = plan.get("resource_changes", [])
expected = {
    "azurerm_container_app_environment.lab",
    "azurerm_container_app.voting",
}
issues = []
seen = set()
for change in changes:
    addr = change["address"]
    actions = change.get("change", {}).get("actions", [])
    if actions == ["no-op"]:
        continue
    seen.add(addr)
    if addr not in expected:
        issues.append(f"Unexpected resource: {addr}")
    if actions != ["create"]:
        issues.append(f"Unsafe action {actions} on {addr}")
if seen != expected:
    issues.append(f"Expected exactly {sorted(expected)}, got {sorted(seen)}")
if issues:
    print("REJECTED: Terraform deployment plan is not the expected two-resource creation")
    for issue in issues:
        print(" -", issue)
    sys.exit(2)
print("PLAN PASS: Only Azure Container Apps Environment + voting app will be created. Phase 01/02 are untouched.")
