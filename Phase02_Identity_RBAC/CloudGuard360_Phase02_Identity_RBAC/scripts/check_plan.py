#!/usr/bin/env python3
"""Fail closed if a saved Terraform plan changes resource types beyond Phase 02 or deletes resources.
Run: terraform show -json phase02.tfplan | python3 ../scripts/check_plan.py
This guard is supplementary; review `terraform show` yourself.
"""
import json, sys
p=json.load(sys.stdin)
allowed={'azuread_group','azuread_group_member','azurerm_role_assignment'}
errors=[]; count={}
for change in p.get('resource_changes',[]):
    typ=change['type']; actions=change.get('change',{}).get('actions',[])
    if actions == ['no-op']:continue
    key='/'.join(actions);count[key]=count.get(key,0)+1
    if typ not in allowed:errors.append(f"UNEXPECTED RESOURCE TYPE: {typ} at {change['address']}")
    if 'delete' in actions or 'update' in actions:errors.append(f"DESTRUCTIVE/MODIFYING ACTION: {change['address']}: {actions}")
    if typ=='azurerm_role_assignment':
        after=change['change'].get('after') or {}
        role=after.get('role_definition_name')
        if role not in {'Reader','Monitoring Reader','Contributor'}:
            errors.append(f"UNEXPECTED ROLE: {role} at {change['address']}")
        if role=='Contributor':
            errors.append('WARNING: Contributor requested. This project plan guard requires manual documented review; plan rejected by default.')
        scope=after.get('scope') or ''
        if scope and '/resourceGroups/rg-cg360-' not in scope:
            errors.append(f"OUT-OF-LAB SCOPE: {scope}")
print('Plan action counts:',count)
if errors:
    print('PLAN REJECTED:');print('\n'.join('- '+e for e in errors));sys.exit(2)
print('PLAN PASS: no deletion/update, no unexpected resource type or role detected.')
print('Review the full plan and Azure cost/permissions before any apply.')
