#!/usr/bin/env python3
"""Read-only comparison of independent AD and Entra group inventories.
Name equality NEVER establishes that Microsoft Entra Cloud Sync is configured.
"""
import argparse,csv,json,datetime
from pathlib import Path
EXPECTED=['CG360-Cloud-Engineers','CG360-Developers','CG360-Security-Auditors','CG360-Operations']
p=argparse.ArgumentParser(description='Group-name comparison only. NOT an identity synchronization tool.')
p.add_argument('--ad',required=True,help='AD groups CSV exported by 03-Export-LabEvidence.ps1')
p.add_argument('--entra',required=True,help='Entra group JSON from az CLI export')
p.add_argument('--out',required=True,help='Existing or new output directory')
p.add_argument('--demo',action='store_true',help='Explicitly label results as synthetic demo')
a=p.parse_args()
with open(a.ad,encoding='utf-8-sig',newline='') as f:
    rows=list(csv.DictReader(f))
ad={r.get('Name',r.get('Group','')).strip() for r in rows}
cloud=json.loads(Path(a.entra).read_text(encoding='utf-8-sig'))
if not isinstance(cloud,list): raise SystemExit('FAIL: Entra JSON must be an array')
en={r['displayName'] for r in cloud if isinstance(r,dict) and r.get('displayName')}
comparisons=[{'group':name,'in_local_ad':name in ad,'in_entra':name in en,'same_display_name':name in ad and name in en} for name in EXPECTED]
match=sum(r['same_display_name'] for r in comparisons)
result={'timestamp_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
'lab_mode':'SYNTHETIC_DEMO' if a.demo else 'REAL_INVENTORIES',
'comparison_type':'NAME_MATCH_ONLY','actual_cloud_sync_verified':False,
'group_display_name_matches':match,'expected':len(EXPECTED), 'groups':comparisons,
'warning':'Matching names do not prove synchronization, matching identity, ownership, sourceAnchor or RBAC membership.'}
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
(out/'reconciliation.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
text=['# CloudGuard 360 — AD / Entra reconciliation','',f"Mode: **{result['lab_mode']}**",'',
      '**Important : comparaison de noms uniquement ; aucune synchronisation hybride n’est démontrée.**','',
      '| Groupe | Active Directory | Microsoft Entra | Même nom |','|---|---|---|---|']
for r in comparisons:
 text.append(f"| {r['group']} | {'Oui' if r['in_local_ad'] else 'Non'} | {'Oui' if r['in_entra'] else 'Non'} | {'Oui' if r['same_display_name'] else 'Non'} |")
text+=['',f'Correspondances de noms : **{match}/{len(EXPECTED)}**.','',
       'Pour une synchronisation réelle, utiliser Microsoft Entra Cloud Sync avec ses prérequis, son agent et ses journaux de provisioning.']
(out/'reconciliation.md').write_text('\n'.join(text)+'\n',encoding='utf-8')
print(f"PASS: Group-name overlap {match}/{len(EXPECTED)}; cloud sync status NOT VERIFIED; mode={result['lab_mode']}")
print('Evidence:',out)
