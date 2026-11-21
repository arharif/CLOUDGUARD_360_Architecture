# CloudGuard 360 — PHASE 08

## HYBRID IAM & AUTOMATION — Formation pratique intégrale

**Niveau : débutant → ingénieur IAM / administrateur système / GRC.**  
**Environnement : Active Directory Domain Services (AD DS) sur Windows Server local, PowerShell, Microsoft Entra ID, Azure RBAC, comparaison et gouvernance des identités.**  
**Écart explicitement assumé : le rapprochement AD/Entra ne remplace PAS un produit de synchronisation.**

> Le laboratoire Kubernetes/AKS précédemment présenté comme Phase 08 est remplacé. La Phase 08 officielle CloudGuard 360 de votre cursus porte sur l'IAM hybride et l'automatisation.

## 0. La vue globale : pourquoi cette phase ?

Imaginez une banque : les ressources humaines tiennent la liste des employés (source métier), l'annuaire AD DS gère les comptes des ordinateurs et applications internes, Microsoft Entra gère l'identité cloud, et Azure RBAC autorise ou refuse l'accès à des ressources Azure. Les changements RH doivent déclencher des changements contrôlés sur les identités et les permissions.

### Six idées essentielles

1. **AD DS** est un annuaire Windows sur vos propres contrôleurs de domaine. Il utilise notamment LDAP, Kerberos et DNS, et permet les Group Policies.
2. **Microsoft Entra ID** est un annuaire d'identités cloud. Ce n'est pas « un AD DS accessible depuis Internet ».
3. **L'authentification** répond à « qui êtes-vous ? » et **l'autorisation** répond à « que pouvez-vous faire ? ».
4. **Le RBAC** attribue un rôle à un principal sur un scope. Les permissions héritées s'ajoutent généralement aux permissions propres à un groupe.
5. **PowerShell** automatise les changements répétitifs et rend les contrôles reproductibles. Il faut borner précisément les scripts à un périmètre.
6. **L'hybride réel** suppose un mécanisme de provisioning pris en charge, tel que Microsoft Entra Cloud Sync, et la vérification de ses journaux de provisionnement.

### Objectifs pédagogiques et preuves

| Compétence | Démonstration réelle | Preuve |
|---|---|---|
| AD DS | Créer une forêt de laboratoire isolée | `Get-ADDomain`, capture ADUC |
| OUs | Organiser les comptes et groupes | Export AD OU |
| Identités | Quatre comptes de démonstration | `ad_users.csv` |
| Autorisations | Quatre groupes Security / Global | `ad_groups.csv`, `ad_membership.csv` |
| Lifecycle | Désactiver un compte ; retirer ses groupes | Export avant/après |
| Entra | Lire les groupes de Phase 02 | `entra_groups.json` |
| Azure RBAC | Examiner les droits existants | `rbac_*.json` |
| Réconciliation | Comparer les inventaires | `reconciliation.json` + `.md` |
| Cloud Sync réel | Option si prérequis satisfaits | Logs de provisioning (non couverts automatiquement) |

### Architecture

```text
[VM Windows Server locale, isolée]
  AD DS : corp.cg360.test
    OU=CG360
      OU=Users: cg360.dev / cg360.eng / cg360.ops / cg360.audit
      OU=Groups: quatre groupes CG360
           | PowerShell -> CSV (comptes / groupes / membres)
           v
[Reconciliation.py] <-- JSON en lecture seule <-- [Microsoft Entra ID]
         |                                         4 groupes Phase 02
         |                                         |
         |                                         v
         +----> Rapport                         [Azure RBAC]
                « mêmes noms »                  7 affectations Reader/Monitoring Reader

   OPTION SÉPARÉE, non installée par nos scripts :
     AD DS -> Agent Microsoft Entra Cloud Sync -> Entra ID
      (Serveur joint au domaine, accès sortant, autorisations, scopes, logs)
```

## 1. Étape 01 — Priorité absolue : votre dernier jour Azure

### Pourquoi ?

Un essai gratuit Azure peut être désactivé après l'épuisement du crédit ou au bout de la durée d'essai. Les données doivent être exportées pendant qu'elles sont accessibles. Une VM Azure n'est **pas nécessaire** pour ce laboratoire. Vérifiez le statut réel de votre abonnement sous **Cost Management + Billing**, sans supposer que l'expiration permet automatiquement toute utilisation future du tenant Entra.

### Dans le portail

1. Aller sur https://portal.azure.com et ouvrir **Cloud Shell → Bash**.
2. Cliquer **Manage files → Upload** et choisir `CloudGuard360_Phase08_Hybrid_IAM_2026.zip`.
3. Vérifier `~/clouddrive` ; extraire sans écraser les dossiers précédents :

```bash
mkdir -p ~/clouddrive/cloudguard360
unzip -n ~/CloudGuard360_Phase08_Hybrid_IAM_2026.zip -d ~/clouddrive/cloudguard360
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase08_Hybrid_IAM_2026
bash azure/00-preflight.sh
bash azure/01-export-entra.sh
bash azure/02-archive-evidence.sh
```

`00-preflight.sh` affiche le contexte courant sans modification. `01-export-entra.sh` interroge exactement les quatre groupes de Phase 02 et les affectations existantes des deux Resource Groups. `02-archive-evidence.sh` archive uniquement des sorties d'audit (pas de Terraform State ni de secrets).

### Résultats attendus

- `evidence/cloud/entra_groups.json` : liste des groupes et leurs Object IDs, s'ils sont accessibles.
- `evidence/cloud/rbac_rg-cg360-app.json` et `rbac_rg-cg360-network.json` lorsque les Resource Groups sont visibles.
- `evidence/CG360_Phase08_Evidence_....zip` : archive téléchargeable.

Si Azure répond `AuthorizationFailed`, `Insufficient privileges`, ou subscription disabled, **ne créez pas de rôle administratif**. Enregistrez le message ; continuez en local et utilisez les données DEMO uniquement à titre pédagogique.

> Pratique : faites aussi une copie privée des répertoires CloudGuard360 Phase 01–04 et des états Terraform existants. Ne publiez jamais `terraform.tfstate`, fichiers secrets ou tokens GitHub.

## 2. Étape 02 — Préparer Active Directory LOCAL sans coût cloud

### Pourquoi une VM locale ?

AD DS a besoin de Windows Server. Une installation directe sur Windows 11 n'est pas un contrôleur de domaine. Microsoft propose Windows Server Evaluation pour les exercices de laboratoire : https://www.microsoft.com/en-us/evalcenter/download-windows-server-2025

### Préparation recommandée sur Windows 11 Pro/Enterprise

1. Ouvrir **Turn Windows features on or off** et activer **Hyper-V**, si disponible.
2. Ouvrir **Hyper-V Manager → Virtual Switch Manager → New virtual network switch → Internal**.
3. Nommer le switch `CG360-Private`. Ne pas connecter directement le DC au réseau d'entreprise.
4. Créer `CG360-DC01` : **Generation 2**, **2 vCPU**, **4–6 Go RAM**, **60 Go disque virtuel**, ISO Windows Server 2025 Evaluation.
5. Connecter la VM au switch `CG360-Private`, installer l'édition **Desktop Experience**.
6. Dans la VM, régler une adresse IP **statique** pour le lab, p. ex. `192.168.88.10/24`, **sans passerelle** ; DNS local `192.168.88.10`. La connectivité Internet n'est pas nécessaire à ce premier lab, mais peut être nécessaire à l'activation de l'édition d'évaluation.
7. Dans le PC hôte, configurer `vEthernet (CG360-Private)` à `192.168.88.1/24` si ce sous-réseau est libre. Ne le faites pas sur l'interface réseau principale.

### Vérification réseau dans la VM (PowerShell administrateur)

```powershell
Get-NetAdapter
Get-NetIPAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,IPAddress,PrefixLength
Get-DnsClientServerAddress -AddressFamily IPv4
```

**N'appliquez pas aveuglément `New-NetIPAddress`** : confirmez d'abord le nom de l'interface et l'absence de conflit IP. Vous pouvez définir l'adresse et DNS depuis les paramètres de la carte réseau Windows.

Si vous utilisez Windows Home, Hyper-V peut être indisponible : utilisez un hyperviseur compatible avec votre édition Windows. L'important est de garder la VM **isolée**.

## 3. Étape 03 — Construire la forêt AD DS

### Analogie

Une forêt AD est le territoire administratif ; le **domaine** est une zone d'identités ; le **Domain Controller** est le serveur qui stocke et vérifie l'annuaire ; les **OUs** structurent les objets ; un **groupe** représente une population ayant le même besoin d'accès.

1. Copier `powershell/` depuis le ZIP vers `C:\CG360\powershell` dans **la VM Windows Server**.
2. Ouvrir **Windows PowerShell 5.1 en administrateur** sur cette VM.
3. Utiliser, uniquement pour le processus PowerShell courant :

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\CG360\powershell
.\00-Preflight-LocalAD.ps1
.\01-Install-LabForest.ps1
```

Le script refuse Windows client, une machine déjà membre d'un domaine et une installation AD DS existante. Il exige de saisir `INSTALL LAB FOREST`, puis installe AD DS, demande le mot de passe **DSRM** en mode sécurisé et promeut la VM comme premier contrôleur du domaine `corp.cg360.test`.

**Risque :** le script change le système d'exploitation de la VM et la redémarre. Ne jamais l'exécuter sur une machine contenant des données importantes, ni sur un serveur d'entreprise.

### Après le redémarrage

Se connecter au domaine de laboratoire, ouvrir PowerShell administrateur :

```powershell
Import-Module ActiveDirectory
Get-ADDomain | Select-Object DNSRoot,NetBIOSName
Get-ADForest | Select-Object Name,ForestMode
Get-Service NTDS,DNS | Select-Object Name,Status
```

Résultat attendu : DNSRoot `corp.cg360.test`, services `NTDS` et `DNS` opérationnels.

> Dépannage : si une étape de promotion échoue, vérifier le journal des événements AD DS/DNS, IP/DNS local, prérequis et mot de passe DSRM ; ne pas relancer les commandes sur une machine non isolée.

## 4. Étape 04 — Automatiser le provisioning AD

### Objectif

Créer des **OUs** : `CG360/Users` et `CG360/Groups` ; **4 groupes de sécurité Global** et **4 comptes fictifs**. L'automatisation est idempotente dans le domaine de laboratoire : le script recherche un objet existant avant de le créer, refuse un objet du même nom hors OU et n'utilise jamais les groupes `Domain Admins`.

```powershell
cd C:\CG360\powershell
.\02-Provision-LabAD.ps1
Get-ADGroup -Filter 'Name -like "CG360-*"' | Select-Object Name,GroupCategory,GroupScope
Get-ADUser -SearchBase 'OU=Users,OU=CG360,DC=corp,DC=cg360,DC=test' -Filter * |
  Select-Object SamAccountName,Enabled
```

L'invite demande un mot de passe initial complexe pour **ces comptes fictifs uniquement**, que l'utilisateur devra changer à la connexion. Ne réutilisez pas un mot de passe d'entreprise.

### Groupes et comptes

| Groupe | Compte test membre | Rôle professionnel |
|---|---|---|
| CG360-Cloud-Engineers | cg360.eng | Infrastructure cloud |
| CG360-Developers | cg360.dev | Développement |
| CG360-Security-Auditors | cg360.audit | Lecture et audit |
| CG360-Operations | cg360.ops | Exploitation |

### Pourquoi les groupes ?

Accorder un accès à un groupe plutôt qu'à quatre comptes séparés réduit la charge administrative : lorsque l'employé change d'équipe, on change son appartenance au groupe plutôt que de modifier directement chaque ressource. C'est un fondement de **RBAC**.

## 5. Étape 05 — Auditer Active Directory et offboarder un utilisateur

### Audit (lecture seule)

```powershell
.\03-Export-LabEvidence.ps1 -OutputDirectory 'C:\CG360\evidence\ad'
Get-ADGroupMember -Identity 'CG360-Developers' | Select-Object Name,SamAccountName
Get-ADUser -Identity cg360.dev -Properties Enabled | Select-Object SamAccountName,Enabled
```

Preuves : `ad_users.csv`, `ad_groups.csv`, `ad_membership.csv`, `ad_summary.json`.

### Cycle de vie : départ d'un salarié

Dans la vraie vie, l'offboarding exige coordination RH, revocation des sessions, accès VPN/SaaS, comptes locaux, MFA, etc. Le labo effectue **seulement deux actions AD** : `Disable-ADAccount` et retrait des quatre groupes CG360 du compte fictif.

```powershell
.\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev -WhatIf
.\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev
Get-ADUser cg360.dev -Properties Enabled | Select-Object SamAccountName,Enabled
.\03-Export-LabEvidence.ps1 -OutputDirectory 'C:\CG360\evidence\ad'
```

Pour finir, rapprocher l'export avant/après. La commande `-WhatIf` simule les modifications ; la commande sans cette option demande confirmation.

**Ne supprimez pas les objets de laboratoire** : leur conservation vous aidera à comprendre la traçabilité d'une décision de sécurité.

## 6. Étape 06 — Lire Microsoft Entra et les rôles Azure

### Rappel de vos phases précédentes

Vous avez préparé quatre **groupes CloudGuard 360 dans Microsoft Entra** et sept affectations Azure RBAC `Reader`/`Monitoring Reader`. Cette phase utilise l'inventaire existant : **aucune duplication**.

Dans Azure Portal : https://entra.microsoft.com → **Entra ID → Groups → All groups**, rechercher `CG360-`. Puis https://portal.azure.com → `rg-cg360-app` → **Access control (IAM) → Role assignments** ; répéter sur `rg-cg360-network`.

Dans Cloud Shell **Bash** :

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase08_Hybrid_IAM_2026
bash azure/01-export-entra.sh
cat evidence/cloud/entra_groups.json
```

La commande est en lecture seule ; l'accès Microsoft Graph peut être interdit selon les rôles du compte. En cas de refus, ne contournez pas la politique de l'organisation.

### Variante Azure Cloud Shell PowerShell

Passer Cloud Shell en mode **PowerShell**, puis :

```powershell
.\powershell\05-Inspect-CloudWithAz.ps1
```

Cela permet de comprendre `Get-AzADGroup`, `Get-AzRoleAssignment`, ainsi que la distinction entre **objet Entra** et **permission Azure RBAC**.

> **Attention** : les groupes homonymes créés dans AD DS LOCAL restent indépendants des groupes Entra de votre Phase 02. Ils n'accordent aucun droit Azure à vos comptes fictifs du lab.

## 7. Étape 07 — Réconcilier AD DS et Microsoft Entra

### Objectif

Le script Python compare **des inventaires**, sans écrire dans AD ou Entra. Cela entraîne la capacité d'audit : identifier les groupes attendus, l'absence d'un groupe, et les écarts entre systèmes d'identités.

Copier `ad_groups.csv` de la VM Windows Server vers le dossier `evidence/ad/` du package sur votre PC ou Cloud Shell. Vous devez également disposer du fichier Entra exporté à l'étape 06.

```bash
python3 tools/reconcile.py \
  --ad evidence/ad/ad_groups.csv \
  --entra evidence/cloud/entra_groups.json \
  --out evidence/reconciliation
cat evidence/reconciliation/reconciliation.md
```

Résultat attendu **si les mêmes quatre noms sont présents** : `Group-name overlap 4/4; cloud sync status NOT VERIFIED`.

Cette phrase est volontaire : **un nom identique n'établit ni le même identifiant objet, ni une synchronisation d'identités, ni le même accès**.

### Parcours sans Azure (pour continuer après expiration)

```bash
python3 tools/reconcile.py --demo \
  --ad examples/ad_groups.csv \
  --entra examples/entra_groups_DEMO.json \
  --out evidence/reconciliation-demo
```

Le rapport indiquera clairement `SYNTHETIC_DEMO`.

### À quoi ressemblerait une vraie synchronisation ?

Microsoft Entra **Cloud Sync** nécessite notamment un serveur Windows joint à AD DS avec connectivité vers le service cloud, un agent, des autorisations adéquates et une configuration de provisioning. On configure le **scope sur une OU/un groupe pilote**, on teste la synchronisation puis on vérifie **les logs de provisioning** et les attributs des objets dans Entra. Pour des utilisateurs devant se connecter avec leur UPN AD, un domaine DNS public vérifié dans Entra est habituellement nécessaire ; `corp.cg360.test` est uniquement un espace de noms de labo **non vérifiable publiquement** et ne doit pas être utilisé comme domaine d'ouverture de session cloud réel.

Références :

- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-prerequisites
- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/tutorial-single-forest
- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-configure

Le guide détaillé est disponible dans [`docs/CLOUD_SYNC_OPTIONNEL.md`](docs/CLOUD_SYNC_OPTIONNEL.md). Ce package n'installe pas l'agent, afin de protéger votre tenant et d'éviter de dépasser les conditions de votre fin d'essai.

## 8. Étape 08 — Clôture et conservation des preuves

### Rapport de fin de projet

Vérifiez que vous possédez :

- [ ] AD DS `corp.cg360.test` fonctionnel sur VM locale **isolée**.
- [ ] OU `CG360` avec `Users` et `Groups`.
- [ ] Quatre comptes fictifs et quatre groupes de sécurité avec membership.
- [ ] Export AD (`ad_users.csv`, `ad_groups.csv`, `ad_membership.csv`).
- [ ] Test d'offboarding avec preuve avant/après et sortie `-WhatIf`.
- [ ] Export Entra réel, ou donnée DEMO explicitement signalée.
- [ ] Comparaison des groupes, y compris écarts.
- [ ] Examen Azure RBAC des groupes existants si abonnement accessible.
- [ ] Archive conservée sur le PC hors d'Azure.
- [ ] Statut de synchronisation : **non configuré** ou **réellement prouvé par logs** — jamais supposé.

### Conservation et coûts

Aucune nouvelle ressource Azure payante n'est créée par nos scripts de formation. La VM AD DS est locale, et vous pouvez l'éteindre depuis l'hyperviseur. Ne supprimez pas `rg-cg360-app` ou `rg-cg360-network` sans une stratégie de sauvegarde de l'ensemble du projet. Attention à d'éventuelles ressources Azure existantes dont la facturation perdure si vous avez converti l'essai en abonnement payant.

### Test oral — 3 questions d'entretien

1. **Quelle différence entre AD DS et Microsoft Entra ID ?** AD DS héberge des identités et mécanismes d'authentification d'un domaine Windows (Kerberos, LDAP, DNS). Entra ID gère l'authentification et l'accès des applications cloud et Azure. Ce ne sont pas des services équivalents.
2. **Un membre d'un groupe AD portant le même nom qu'un groupe Entra reçoit-il automatiquement les droits Azure ?** Non. Une synchronisation effective, un objet Entra approprié, une appartenance effective et une affectation RBAC sont nécessaires. La simple égalité des noms n'apporte rien.
3. **Comment prouvez-vous un offboarding correct ?** Par une demande autorisée, un journal de modifications, la désactivation, la suppression des accès pertinents et une vérification indépendante, avec clôture documentée. Le laboratoire couvre une partie AD DS seulement.

## Dépannage

| Message | Diagnostic | Correctif sûr |
|---|---|---|
| `Get-ADUser not recognized` | AD module absent ou mauvaise machine | Exécuter sur Windows Server/RSAT et installer les outils AD DS |
| `The server is not operational` | DNS, AD DS non installé, domaine indisponible | Vérifier IP/DNS, `Get-Service NTDS,DNS`, logs |
| `Password does not meet policy` | Complexité non satisfaite | Entrer un mot de passe lab fort, sans le stocker dans un fichier |
| `REFUSED: unexpected domain` | Évitez tout domaine de production | Utiliser exclusivement `corp.cg360.test` dans une VM isolée |
| `AuthorizationFailed` | Manque de permissions Azure | Continuer en local ; demander autorisation plutôt que contourner |
| `No subscription found` | Expiration Azure/absence de contexte | Utiliser le laboratoire local et le dataset DEMO |
| `0/4 matching` | Exports manquants ou noms divergents | Contrôler que l'export Entra est bien réel et correspond au bon tenant |
| `Module Az.Resources missing` | Az PowerShell non installé | Utiliser Cloud Shell ou la variante Azure CLI Bash |

**Règle finale :** un laboratoire est complet quand les contrôles sont prouvés par des observations réelles, pas quand un script affiche seulement « PASS ».
