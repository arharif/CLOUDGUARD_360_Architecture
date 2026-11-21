# CloudGuard 360 — PHASE 08 : Hybrid IAM & Automation

**Le bon module : PowerShell · Active Directory Domain Services (AD DS) · Microsoft Entra ID · Azure RBAC · réconciliation d'identités · Microsoft Entra Cloud Sync (option avancée).**

Cette archive **remplace** le précédent ZIP Phase 08 Kubernetes/AKS. Aucun AKS, EKS ou service Kubernetes n'est requis.

> **Stratégie dernier jour d'abonnement Azure** : sauvegarder les preuves cloud en premier, puis travailler gratuitement sur une VM Windows Server locale. Le laboratoire principal ne crée **aucune ressource Azure facturable** et ne modifie pas les groupes de Phase 02.

## Démarrage immédiat

1. Ouvrir [`index.html`](index.html) sur votre ordinateur pour le guide interactif hors ligne.
2. Lire [`DEMARRAGE_RAPIDE_FR.md`](DEMARRAGE_RAPIDE_FR.md) pour la séquence compacte et [`GUIDE_COMPLET_FR.md`](GUIDE_COMPLET_FR.md) pour la théorie et le mode opératoire détaillé.
3. Dans Azure Cloud Shell (Bash), télécharger les preuves **avant** l'expiration du Free Trial.
4. Sur une **VM Windows Server d'évaluation isolée**, déployer votre domaine AD DS local et les utilisateurs fictifs avec PowerShell.
5. Comparer les groupes AD et Entra avec `tools/reconcile.py` — ce n'est pas une synchronisation réelle.
6. Pour un hybride **réel**, suivre le runbook optionnel Microsoft Entra Cloud Sync et ses prérequis vérifiés. Ne pas installer l'agent sans les droits et les contrôles nécessaires.

## Structure

```text
CloudGuard360_Phase08_Hybrid_IAM_2026/
├── index.html                  Guide HTML animé (autonome, hors ligne)
├── GUIDE_COMPLET_FR.md        Manuel pratique détaillé
├── DEMARRAGE_RAPIDE_FR.md     Commandes essentielles
├── README_FR.md               Ce fichier
├── assets/                    Architecture PNG + SVG
├── azure/
│   ├── 00-preflight.sh          Vérifications Azure en lecture seule
│   ├── 01-export-entra.sh       Export des groupes Entra et des rôles RBAC
│   └── 02-archive-evidence.sh   Archive ZIP de preuves (sans secrets)
├── powershell/
│   ├── 00-Preflight-LocalAD.ps1  Vérification du serveur
│   ├── 01-Install-LabForest.ps1 Promotion en contrôleur de domaine (destructive pour la VM)
│   ├── 02-Provision-LabAD.ps1   OUs, utilisateurs et groupes fictifs
│   ├── 03-Export-LabEvidence.ps1 Export local CSV + JSON
│   ├── 04-Offboard-LabUser.ps1  Désactivation d'un compte de démonstration (-WhatIf)
│   └── 05-Inspect-CloudWithAz.ps1 Az PowerShell (optionnel)
├── tools/reconcile.py         Comparaison déterministe des noms AD / Entra
├── examples/                  Données DEMO clairement étiquetées
└── docs/                      Notes d'architecture, runbook Cloud Sync et matrice de tests
```

## Niveaux de réalisation

| Niveau | Réel ? | Azure requis ? | Ce que l'on peut prouver |
|---|---|---|---|
| AD DS local sur VM Windows Server | Oui | Non | Forêt, OUs, 4 groupes, 4 comptes, membres et cycle de vie |
| Audit de Microsoft Entra / Azure RBAC | Oui | Souscription active + autorisations au moment de la collecte | Groupes et affectations existants |
| Réconciliation AD / Entra | Oui, comparaison d'inventaires | Non après export | Présence de groupes portant les mêmes noms **seulement** |
| Données DEMO | Non | Non | Fonctionnement du rapprochement, **pas** de conformité cloud |
| Microsoft Entra Cloud Sync | Option réelle distincte | Tenant Entra et conditions de licence + serveur connecté | Objets synchronisés et journaux de provisioning (si effectivement configuré) |

## Sécurité

- Ne pas promouvoir un serveur d'entreprise en DC ; ne jamais joindre le domaine d'entreprise à cette expérience.
- Pas de réutilisation de mots de passe réels ; le mot de passe de démonstration est saisi en invite protégée et n'est pas exporté.
- Ne pas donner Domain Admin aux comptes fictifs.
- Les sorties Azure et les preuves doivent rester **privées** (IDs d'objets, identifiants de compte).
- Ne pas utiliser Terraform `destroy`, ne pas nettoyer vos Resource Groups CloudGuard 360 pour accomplir cette phase.
- Ne pas lancer le script `01-Install-LabForest.ps1` hors d'une VM de laboratoire jetable.

## Documentation Microsoft

- AD DS : https://learn.microsoft.com/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
- Cloud Sync : https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/how-to-prerequisites
- Tutoriel Cloud Sync : https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/tutorial-single-forest
- Téléchargement Windows Server Evaluation : https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025
