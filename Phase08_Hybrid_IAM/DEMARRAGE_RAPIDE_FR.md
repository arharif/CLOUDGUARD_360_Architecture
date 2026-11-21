# PHASE 08 — Démarrage rapide (une session, huit étapes)

**Attention : il s'agit de Hybrid IAM & Automation, PAS de Kubernetes/AKS/EKS.**

## Étape 1 — AUJOURD'HUI : sauvegarder Azure (Cloud Shell Bash)

1. Télécharger le ZIP Phase 08 sur l'ordinateur.
2. Dans Azure Portal → Cloud Shell → Bash → Manage files → Upload, téléverser le ZIP.
3. Exécuter :

```bash
mkdir -p ~/clouddrive/cloudguard360
unzip -n ~/CloudGuard360_Phase08_Hybrid_IAM_2026.zip -d ~/clouddrive/cloudguard360
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase08_Hybrid_IAM_2026
bash azure/00-preflight.sh
bash azure/01-export-entra.sh
bash azure/02-archive-evidence.sh
```

4. Cloud Shell → Manage files → **Download** : télécharger le ZIP dans `evidence/`, ainsi que vos anciens dossiers Terraform **sur votre PC**, en conservant leurs States dans un emplacement privé. Si Azure a déjà expiré, continuez localement.

## Étape 2 — Préparer le serveur AD DS local

- Télécharger l'ISO d'évaluation Windows Server 2025 depuis le site officiel Microsoft.
- Sur Windows Pro/Enterprise avec Hyper-V, créer une VM isolée (environ 2 vCPU, 4–6 Go RAM, disque virtuel 60 Go, réseau interne `CG360-Private`).
- Installer Windows Server Desktop Experience. Configurer le réseau local avec une IP stable, p. ex. `192.168.88.10/24`, et le DNS pointant vers cette adresse. Ne pas exposer AD DS à Internet.
- Copier le sous-dossier `powershell/` dans `C:\CG360\powershell` **à l'intérieur de cette VM**.

## Étape 3 — Forêt AD DS (VM isolée seulement, PowerShell administrateur)

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\CG360\powershell
.\00-Preflight-LocalAD.ps1
.\01-Install-LabForest.ps1
```

**Arrêt obligatoire :** la deuxième commande promeut la VM en contrôleur de domaine et la redémarre. Ne l'utilisez jamais sur votre poste principal ou un serveur existant.

## Étape 4 — Créer groupes et utilisateurs (après redémarrage)

Se connecter en administrateur de domaine sur la VM :

```powershell
cd C:\CG360\powershell
.\02-Provision-LabAD.ps1
Get-ADOrganizationalUnit -Filter 'Name -eq "CG360"'
Get-ADGroup -Filter 'Name -like "CG360-*"' | Select-Object Name,GroupScope
```

## Étape 5 — Contrôler et exporter AD DS

```powershell
.\03-Export-LabEvidence.ps1 -OutputDirectory 'C:\CG360\evidence\ad'
Import-Csv 'C:\CG360\evidence\ad\ad_groups.csv' | Format-Table
```

Copier `ad_groups.csv` sur le PC dans `evidence/ad/` du dossier Phase 08.

## Étape 6 — Comparer AD et Entra (PC ou Cloud Shell)

```bash
python3 tools/reconcile.py \
  --ad evidence/ad/ad_groups.csv \
  --entra evidence/cloud/entra_groups.json \
  --out evidence/reconciliation
```

Si vous ne disposez pas des données Azure, vous pouvez tester le programme avec des **données synthétiques** :

```bash
python3 tools/reconcile.py --demo \
  --ad examples/ad_groups.csv \
  --entra examples/entra_groups_DEMO.json \
  --out evidence/reconciliation-demo
```

**Ne confondez pas la présence des mêmes noms et une synchronisation d'identités réelle.**

## Étape 7 — Tester la désactivation de compte

Dans la VM Windows Server, faites d'abord une simulation puis confirmez :

```powershell
.\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev -WhatIf
.\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev
.\03-Export-LabEvidence.ps1 -OutputDirectory 'C:\CG360\evidence\ad'
```

## Étape 8 — Clôturer

- Vérifier les quatre groupes dans AD et les rôles existants de Phase 02 dans Azure.
- Conserver les CSV, JSON et les captures dans un dossier privé ; compiler le rapport de preuves avec `azure/02-archive-evidence.sh` si vous avez ramené les exports sur Cloud Shell.
- **Ne pas créer de VM Azure pour AD DS le dernier jour.** La lab principale continue en local après la fin de l'abonnement.
- Étudier `docs/CLOUD_SYNC_OPTIONNEL.md` pour réaliser plus tard une synchronisation réelle avec les bons droits/licences et un serveur agent joignable.
