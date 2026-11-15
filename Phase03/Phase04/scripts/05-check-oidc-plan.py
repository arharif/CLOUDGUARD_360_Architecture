#!/usr/bin/env python3
"""Read terraform show -json output; exit nonzero on unsafe changes."""
import json, sys
plan = json.load(sys.stdin)
changes = [c for c in plan.get('resource_changes', []) if c.get('mode') == 'managed']
allowed = {'azurerm_user_assigned_identity','azurerm_federated_identity_credential','azurerm_role_assignment'}
fail = []
counts={}
for c in changes:
    t=c.get('type'); a=c.get('change',{}).get('actions',[])
    counts[t]=counts.get(t,0)+1
    if t not in allowed or a not in (['create'], ['no-op']):
        fail.append(f'{c.get("address")}: {a} (type: {t})')
    if t == 'azurerm_role_assignment':
        after=c.get('change',{}).get('after') or {}
        if after.get('role_definition_name') not in (None,'Container Apps Contributor'):
            fail.append('Role assignment is not scoped to the intended built-in role')
        if not c.get('address','').startswith('azurerm_role_assignment.app_deployer'):
            fail.append('Unexpected role-assignment address')
print('Planned managed types:',counts)
if fail:
    print('PLAN REJECTED:', '\n'.join(fail)); sys.exit(1)
if not changes:
    print('PLAN PASS: no changes')
else:
    print('PLAN PASS: only approved identity/RBAC resource types created; independently review scope and subject.')
