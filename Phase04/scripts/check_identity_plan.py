#!/usr/bin/env python3
"""Reject any unexpected Terraform changes in Phase 04 OIDC root."""
import argparse,json,sys
ap=argparse.ArgumentParser()
ap.add_argument('--subject',required=True);ap.add_argument('--app',required=True)
a=ap.parse_args()
try:p=json.load(sys.stdin)
except json.JSONDecodeError as e:sys.exit(f'PLAN REJECTED: invalid JSON {e}')
allowed={'azurerm_user_assigned_identity','azurerm_federated_identity_credential','azurerm_role_assignment'}
changes=p.get('resource_changes',[])
if not changes:print('PLAN PASS: no changes (identity already in Terraform state).');sys.exit(0)
seen=set()
for x in changes:
    typ=x.get('type'); change=x.get('change',{}); actions=change.get('actions',[])
    if typ not in allowed or actions!=['create']:
        sys.exit(f'PLAN REJECTED: unsafe {x.get("address")}: {actions}')
    if typ in seen:sys.exit(f'PLAN REJECTED: unexpected duplicate resource type {typ}')
    seen.add(typ)
    after=change.get('after') or {}
    if typ=='azurerm_federated_identity_credential':
        if after.get('subject')!=a.subject:sys.exit('PLAN REJECTED: unexpected OIDC subject')
        if after.get('issuer')!='https://token.actions.githubusercontent.com':sys.exit('PLAN REJECTED: wrong issuer')
        if after.get('audience')!=['api://AzureADTokenExchange']:sys.exit('PLAN REJECTED: wrong audience')
    if typ=='azurerm_role_assignment':
        if after.get('role_definition_name')!='Container Apps Contributor':sys.exit('PLAN REJECTED: role not expected')
        scope=str(after.get('scope') or '').lower()
        if not scope.endswith('/providers/microsoft.app/containerapps/'+a.app.lower()):
            sys.exit(f'PLAN REJECTED: role scope not restricted to existing app ({scope})')
print('PLAN PASS: only expected Phase 04 identity, trust, app-scoped RBAC creates')
