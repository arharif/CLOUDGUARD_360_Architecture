# Matrice de tests et critères d'acceptation

| ID | Test | Procédure | PASS si | Statut initial |
|---|---|---|---|---|
| T01 | Domain isolation | `Get-ADDomain` sur VM lab | DNSRoot `corp.cg360.test` | Non exécuté |
| T02 | Domain controller | `Get-Service NTDS,DNS` | Services Running | Non exécuté |
| T03 | Organisation | `Get-ADOrganizationalUnit` | OU CG360/Users/Groups | Non exécuté |
| T04 | Comptes | `Get-ADUser -SearchBase ...` | Quatre comptes fictifs | Non exécuté |
| T05 | Groupes | `Get-ADGroup` | Quatre CG360 Security/Global | Non exécuté |
| T06 | Membership | `Get-ADGroupMember` | Quatre correspondances | Non exécuté |
| T07 | Export | `03-Export-LabEvidence.ps1` | CSV/JSON lisibles | Non exécuté |
| T08 | Offboarding | `04-Offboard-LabUser.ps1 -WhatIf` puis apply | Compte `cg360.dev` Disabled | Non exécuté |
| T09 | Entra inventory | `azure/01-export-entra.sh` | Quatre groupes existants (si autorisés) | Non exécuté |
| T10 | RBAC verification | `rbac_rg-cg360-*.json` | Rôles cohérents avec Phase 02 | Non exécuté |
| T11 | Name reconcile | `tools/reconcile.py` | Rapport exact, mention NOT VERIFIED | Non exécuté |
| T12 | Hybrid synchronization | Journaux de Microsoft Entra Cloud Sync | Uniquement si agent/config fonctionnels | Hors périmètre par défaut |
| T13 | Azure cost protection | Cost Management | Pas de nouvelle VM ou ressource cloud déployée par ce module | Non exécuté |

Attention : T11 avec données DEMO ne permet pas de déclarer T09/T10/T12 réussis.
