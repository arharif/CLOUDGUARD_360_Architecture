#!/usr/bin/env python3
"""Fail-closed guard for an optional single Azure Policy audit assignment.
Usage: terraform show -json policy.tfplan | python3 ../scripts/06-policy-plan-guard.py
Never replaces manual review of scope and Azure permissions.
"""
import json, sys
try:
    p=json.load(sys.stdin)
except Exception as exc:
    print('REJECT: invalid JSON:',exc); sys.exit(2)
changes=[r for r in p.get('resource_changes',[]) if r.get('change',{}).get('actions')!=['no-op']]
errors=[]
if len(changes)!=1: errors.append(f'Expected exactly one change; found {len(changes)}')
for c in changes:
    ac=c.get('change',{}).get('actions',[]); after=c.get('change',{}).get('after') or {}
    if c.get('type')!='azurerm_resource_group_policy_assignment': errors.append('Unexpected type: '+str(c.get('type')))
    if ac!=['create']: errors.append('Unexpected action: '+str(ac))
    if after.get('name')!='cg360-locations-audit': errors.append('Unexpected assignment name')
    definition=after.get('policy_definition_id') or ''
    if not definition.endswith('/e56962a6-4747-49cd-b67b-bf8b01975c4c'): errors.append('Unexpected policy definition')
    rg=(after.get('resource_group_id') or '').lower()
    if not rg.endswith('/resourcegroups/rg-cg360-app'): errors.append('Scope must be rg-cg360-app')
    try:
        params=json.loads(after.get('parameters') or '{}')
        if params['effect']['value']!='Audit': errors.append('Effect must be Audit')
        loc=params['listOfAllowedLocations']['value']
        if not isinstance(loc,list) or len(loc)!=1 or not loc[0]: errors.append('Expected one non-empty allowed region')
    except Exception as e: errors.append('Invalid policy parameters: '+str(e))
if errors:
 print('PLAN REJECTED:'); [print(' - '+x) for x in errors]; sys.exit(2)
print('PLAN PASS: one new app-RG allowed-locations policy with Audit effect, no other changes.')
print('Manual scope, permission and cost review remains required.')
