# CLOUDGUARD 360 — PHASE 04
## Automatisation DevSecOps de bout en bout — Tutoriel complet (Azure Cloud Shell + GitHub Actions + Terraform + GHCR)

> **Périmètre exact** : un seul projet GitHub public (`NabilNet/cloudguard360-phase04`) et la Container App Azure déjà créée pendant la Phase 03 (`rg-cg360-app/ca-cg360-voting`). Ce laboratoire ne crée ni nouveaux VNets, ni nouveau Resource Group, ni cluster AKS, ni Azure Container Registry. Le code Microsoft utilisé est cloné depuis [Azure-Samples/azure-voting-app-redis](https://github.com/Azure-Samples/azure-voting-app-redis). L'intégralité du déroulement s'exécute sur Azure Cloud Shell Bash, avec les exécutions Docker à l'intérieur de GitHub Actions.

**Objectif de clôture** : voir une application de vote répondant sur HTTPS depuis une image nouvellement créée et versionnée dans GHCR, avec des preuves CI, des contrôles DevSecOps, une identité GitHub OIDC, et une configuration Phase 03 Terraform réconciliée.

## Architecture logique

```text
Développeur / Cloud Shell                      GitHub                           Azure
     |                                           |                              |
     |---- phase04.sh prepare -----------------> | Dépôt NabilNet/phase04         |
     |                                           |-- 01 CI: lint + Trivy + Docker|
     |                                           |    Smoke test Flask <-> Redis |
     |                                           |-- 00 OIDC claim diagnostic    |
     |---- Terraform plan/apply ------------------------------------------------>|
     |                                           |    ID fédérée + RBAC sur app   |
     |                                           |-- 02 publish --> GHCR          |
     |                        visibilité image publique (vérification manuelle)   |
     |                                           |-- 03 deploy via OIDC -------->|
     |                                           |                ca-cg360-voting |
     |                                           |              vote-frontend    |
     |                                           |              redis inchangé   |
     |---- phase04.sh verify/reconcile ------------------------------------------>|
```

### Rôles des technologies

- **Git / GitHub** : contrôle de version et audit de chaque modification.
- **Dockerfile** : recette de l'image qui embarque le code Flask officiel, ses dépendances et le serveur Gunicorn. L'ancienne image `mcr.microsoft.com/azuredocs/azure-vote-front:v1` n'est plus utilisée.
- **GitHub Actions CI** : lance automatiquement les contrôles et un test de démarrage réel frontend + Redis sur un runner Ubuntu qui dispose de Docker.
- **Trivy** : analyse secrets/configuration (bloquante) et vulnérabilités (rapport à revoir) ; un SBOM CycloneDX est généré.
- **GHCR** : registre d'images de conteneur GitHub. Une image de laboratoire publique peut être téléchargée anonymement ; pour un usage professionnel, choisir un registre privé et une identité adaptée.
- **Microsoft Entra Workload Identity Federation / GitHub OIDC** : le runner GitHub échange un jeton temporaire contre un accès Azure, sans créer de secret client permanent.
- **Terraform** : crée uniquement une identité Azure dédiée, la relation fédérée et un rôle `Container Apps Contributor` au **scope de la Container App existante**. Le Terraform State reste séparé des Phases 01, 02 et 03.
- **Azure Container Apps** : héberge l'application Phase 03 ; nous changeons uniquement l'image du conteneur `vote-frontend`. Le conteneur `redis` est conservé.

---

## Étape 0 — Préparation des comptes et du stockage (lecture seule)

### Portail Azure

1. Aller sur https://portal.azure.com.
2. Ouvrir l'icône **Cloud Shell** dans la barre supérieure.
3. Sélectionner **Bash** et vérifier que `~/clouddrive` est monté.
4. Vérifier la souscription en cours : **Subscriptions → Azure subscription 1**, ou votre souscription réelle.
5. Dans **Resource groups → rg-cg360-app**, vérifier **Container Apps → ca-cg360-voting**.
6. Ouvrir **Containers** : les conteneurs doivent s'appeler `vote-frontend` et `redis`. Dans **Ingress**, le port cible doit être `80`.
7. Ouvrir **Cost Management + Billing → Cost analysis** : vérifier le solde et les coûts avant toute opération.

### Authentification GitHub

```bash
gh --version
gh auth status
```

Si `gh` existe mais n'est pas connecté, utilisez `gh auth login` et choisissez `GitHub.com → HTTPS → Login with a web browser`. **Ne partagez jamais le token** de `~/.config/gh/hosts.yml`. Le message « credentials saved in plain text » est un avertissement de sécurité, pas une erreur d'authentification.

Si `gh: command not found`, voyez `docs/TROUBLESHOOTING_FR.md`. Azure Cloud Shell peut évoluer et n'inclut pas toujours cet outil.

### Vérifications CLI

```bash
az account show --query '{Name:name,State:state}' -o table
az containerapp show -n ca-cg360-voting -g rg-cg360-app --query 'properties.template.containers[].{Name:name,Image:image}' -o table
gh repo view NabilNet/cloudguard360-phase04 --json nameWithOwner --jq .nameWithOwner
```

**Attendu** : abonnement actif, app existante, deux conteneurs, dépôt GitHub accessible. Si la Phase 03 n'a pas réellement été déployée, **STOP** : ce ZIP n'essaiera pas d'inventer une application manquante.

---

## Étape 1 — Upload du ZIP final et contrôle `doctor`

1. Téléchargez `CloudGuard360_Phase04_FINAL_2026.zip` sur votre PC.
2. Cloud Shell → **Manage files → Upload** → sélectionnez ce ZIP.
3. Exécutez les commandes suivantes :

```bash
mountpoint -q "$HOME/clouddrive" || { echo 'STOP: Cloud Shell non persistant'; exit 1; }
mkdir -p "$HOME/clouddrive/cloudguard360"
unzip -n "$HOME/CloudGuard360_Phase04_FINAL_2026.zip" -d "$HOME/clouddrive/cloudguard360"
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_FINAL_2026"
bash automation/phase04.sh doctor --repo NabilNet/cloudguard360-phase04
```

Pourquoi `unzip -n` ? Il n'écrase pas les fichiers déjà extraits. Pourquoi `clouddrive` ? Le Terraform State créé pendant la Phase 04 doit persister au-delà de la session Cloud Shell. Le script refuse d'aller plus loin si le stockage n'est pas monté.

**Attendu** : `PASS: doctor finished; no resources changed.` Si vous voyez `STOP`, lisez la cause exacte avant de reprendre.

---

## Étape 2 — Préparer et pousser le dépôt GitHub, sans recréer de dépôt

Vous avez déjà le dépôt : https://github.com/NabilNet/cloudguard360-phase04.

```bash
bash automation/phase04.sh prepare --repo NabilNet/cloudguard360-phase04
```

Ce que fait le script :

1. Il vérifie que l'utilisateur actuellement connecté avec `gh` peut **écrire** dans le dépôt, et refuse l'ancien placeholder `OWNER`.
2. Il clone **votre dépôt** dans `~/clouddrive/cloudguard360/cloudguard360-phase04-repo` ou réutilise le clone existant.
3. Il clone le dépôt public officiel Microsoft dans un dossier séparé, **sans le pousser automatiquement**.
4. Il vérifie les quatre éléments de l'application à l'emplacement exact `azure-vote/azure-vote/` : `main.py`, `config_file.cfg`, `templates/`, `static/`.
5. Il copie ces éléments dans `vendor/azure-vote/` de votre clone. La licence originale et le commit Microsoft sont conservés sous `docs/`.
6. Il installe **quatre workflows GitHub Actions**, la recette Docker et un validateur Python. Les fichiers existants divergents sont sauvegardés **en dehors du dépôt** avant remplacement.
7. Il affiche `git status --short`, puis vous demande **YES** avant `git commit && git push`. Il n'utilise jamais `--force`.

**Résultat attendu** : les fichiers apparaissent sur GitHub dans `main` et le pipeline CI est visible dans l'onglet **Actions**.

**Pourquoi l'ancienne erreur disparaît ?** L'erreur `Expected official sample main.py not found` provenait du chemin erroné `azure-vote/main.py`. Cette version utilise `azure-vote/azure-vote/main.py` et vérifie également les templates, les assets et la licence. Si Microsoft modifie encore sa structure, le script affichera les chemins trouvés et s'arrêtera **avant le push**, au lieu de chercher un autre fichier par hasard.

---

## Étape 3 — CI, image Docker, analyse DevSecOps et SBOM

```bash
bash automation/phase04.sh ci --repo NabilNet/cloudguard360-phase04
```

Dans GitHub → dépôt → **Actions → 01 | CI Security and Docker Smoke Test**, observez les tâches :

1. Vérification de la structure du dépôt et de la syntaxe du programme Python.
2. Analyse Trivy **bloquante** des secrets et mauvaises configurations `HIGH/CRITICAL`.
3. Build Docker sur un runner GitHub Linux : Azure Cloud Shell n'a **pas** besoin d'un démon Docker.
4. Démarrage d'un conteneur Redis et du frontend Flask, puis `curl` HTTP jusqu'à recevoir une réponse correcte.
5. Analyse des vulnérabilités **informatives** sur l'image. Les vulnérabilités trouvées doivent être évaluées et corrigées selon la politique de sécurité, mais ce laboratoire ne les bloque pas automatiquement.
6. Création d'un **SBOM CycloneDX** et téléchargement des rapports depuis **Actions → Run → Artifacts**.

**Critère de succès** : run vert, étape `PASS: Docker frontend + Redis integration and HTTP 200`, artefact de preuves présent. Le scan informatif ne certifie pas l'absence de CVE.

Si CI échoue : `gh run list -R NabilNet/cloudguard360-phase04` puis ouvrez le lien affiché ; les corrections doivent être apportées au dépôt, et **pas** en désactivant Trivy.

---

## Étape 4 — Authentification sans secret : OIDC + Terraform

```bash
bash automation/phase04.sh identity --repo NabilNet/cloudguard360-phase04
```

Cette étape exige le droit de créer une identité Azure et celui de créer des affectations RBAC au scope de la Container App. Ces droits ne sont pas impliqués par le simple rôle Reader ou Contributor. En cas de `403 AuthorizationFailed`, il faut contacter un administrateur légitime ; le script ne cherche pas à contourner ces permissions.

### Pourquoi cette version est différente : OIDC GitHub 2026

Depuis juillet 2026, les **nouveaux dépôts GitHub** utilisent des sujets OIDC immuables contenant l'ID propriétaire et l'ID dépôt, sous une forme analogue à :

```text
repo:OWNER@OWNER-ID/REPO@REPO-ID:environment:cloudguard360-lab
```

L'ancien format `repo:NabilNet/cloudguard360-phase04:environment:cloudguard360-lab` pouvait donc déclencher une erreur d'échange de jeton. Ici, le workflow **00 | Diagnose GitHub OIDC subject** demande un vrai jeton temporaire, décode son contenu **sans afficher le jeton**, et expose uniquement la valeur non secrète `sub`. Le script crée la confiance Azure à partir de cette valeur observée, pas d'une approximation.

### Ressources prévues dans Terraform Phase 04

- 1 identité gérée utilisateur : `uami-cg360-phase04` dans `rg-cg360-app`.
- 1 credential fédéré : `fic-cg360-gh-actions` pour le sujet GitHub réel et le public `api://AzureADTokenExchange`.
- 1 affectation `Container Apps Contributor` au scope de **`ca-cg360-voting` uniquement**, jamais au Resource Group complet.

**Limite de privilèges** : `Container Apps Contributor` autorise plus que le simple changement d'image, y compris des actions potentiellement destructrices sur cette Container App. Une production exige un rôle personnalisé plus strict, une revue et un processus de release gouverné. Les modifications Phase 04 requièrent une approbation explicite.

Le script lance `terraform init`, `validate`, `plan`, un contrôleur de plan qui rejette les changements destructifs, puis affiche le plan. Il demande `YES` avant `terraform apply`. Le Terraform State est stocké dans le nouveau dossier `terraform/oidc`, **indépendamment** des Phases 01/02/03.

Enfin, le script configure les secrets **d'environnement GitHub** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`. Aucun mot de passe Azure ni client secret n'est créé.

### GitHub : protection de l'environnement

Aller dans le dépôt → **Settings → Environments → cloudguard360-lab**. Sur votre dépôt public, limitez les branches autorisées à `main`, et ajoutez des approbateurs lorsque votre contexte GitHub et vos collaborateurs le permettent. Une approbation par le seul initiateur ne constitue pas une revue indépendante.

---

## Étape 5 — Publier l'image du frontend dans GHCR

```bash
bash automation/phase04.sh publish --repo NabilNet/cloudguard360-phase04
```

Le workflow **02 | Publish GHCR Image** reconstruit l'image après les tests de validation, se connecte à GHCR avec le jeton GitHub temporaire du workflow (`GITHUB_TOKEN`) et publie une image de type :

```text
ghcr.io/nabilnet/cloudguard360-vote:<SHA-GIT-COMPLET>
```

L'image est versionnée à partir du commit du dépôt. Le tag SHA reste techniquement modifiable si le registre autorise l'écrasement des tags : pour un mécanisme de verrouillage production, imposer un digest `sha256` ou une politique d'immuabilité du registre.

**Action manuelle obligatoire après la publication** : rendez la **package GHCR de démonstration** publique pour qu'Azure puisse la télécharger sans secret de registre. Sur GitHub : avatar → **Your profile → Packages → cloudguard360-vote → Package settings → Change visibility → Public**. Cette visibilité concerne l'image logicielle ; **ne mettez jamais de secrets ou de données personnelles dans l'image**.

La documentation GitHub confirme que les images publiques de GitHub Container Registry peuvent être téléchargées anonymement. Une image privée nécessiterait une autre architecture d'authentification du registre.

---

## Étape 6 — Déployer uniquement le frontend vers Azure Container Apps

```bash
bash automation/phase04.sh deploy --repo NabilNet/cloudguard360-phase04
```

Avant l'action, le script affiche le nom exact de l'image et la version de Redis ; il demande `YES`. Le workflow GitHub **03 | Approved Azure Container Apps Deploy** :

1. Vérifie le SHA Git fourni et que l'image est téléchargeable **sans identifiants GHCR**.
2. Authentifie le runner GitHub auprès d'Azure via **OIDC**, sans mot de passe.
3. Vérifie que l'Azure Container App contient exactement `vote-frontend` et `redis`.
4. Enregistre l'image Redis existante avant déploiement.
5. Exécute `az containerapp update --container-name vote-frontend --image <IMAGE>` : seule l'image du frontend est demandée à la CLI.
6. Vérifie que Redis a gardé la même image, que le frontend affiche exactement la nouvelle image et que l'URL HTTPS répond.

Le dépôt, le Resource Group et le VNet ne sont pas reconstruits.

**Attention** : le nouveau conteneur utilise le même port 80 que le frontend de la Phase 03. Le test CI vérifie le démarrage exact du conteneur avec Redis afin de détecter les problèmes applicatifs avant le déploiement Azure.

Si le déploiement échoue, ne lancez pas `terraform apply` au hasard : lisez les logs du run GitHub, examinez les revisions dans Azure Portal et voyez le runbook de récupération. Si une image précédente est encore disponible, une remise en place contrôlée peut être envisagée.

---

## Étape 7 — Collecter les preuves, vérifier Redis et l'application HTTPS

```bash
bash automation/phase04.sh verify --repo NabilNet/cloudguard360-phase04
```

Cette étape est **sans modification Azure**. Elle capture : images actuelles frontend/Redis, FQDN et révision Azure, dernières exécutions GitHub Actions, test HTTPS. Le rapport se trouve dans :

```text
~/clouddrive/cloudguard360/phase04-evidence/<date-utc>/REPORT_FR.md
```

**Critère de succès** : l'image frontend pointe vers `ghcr.io/nabilnet/cloudguard360-vote:<sha>`, le nom et l'image du conteneur Redis ne changent pas, et le test HTTP renvoie 200. Une réponse HTTP 200 ne garantit pas que chaque fonctionnalité est opérationnelle ; ouvrez l'URL dans votre navigateur et essayez un vote.

---

## Étape 8 — Réconcilier la configuration Terraform Phase 03

Après un déploiement manuel ou un pipeline GitHub Actions, Terraform Phase 03 peut croire que l'ancienne image est encore souhaitée. Un `terraform apply` ultérieur pourrait donc rétablir l'image précédente.

```bash
bash automation/phase04.sh reconcile --repo NabilNet/cloudguard360-phase04
```

Le script :

1. Vérifie que **le vrai Terraform State Phase 03 local existe** (sinon stop : on ne devine pas le backend).
2. Lit la nouvelle image GHCR dans Azure.
3. Demande `YES` avant de modifier le fichier `terraform.tfvars` de la Phase 03.
4. Crée une sauvegarde du fichier, puis remplace uniquement `frontend_image` par l'image exacte.
5. Lance **`terraform plan -detailed-exitcode` en lecture seule** ; il n'exécute jamais `terraform apply` de la Phase 03.

Résultat attendu : `PASS: Phase 03 Terraform plan reports no drift.` Si Terraform affiche toujours une modification, lisez le diff (par exemple un réglage de révision, un secret, un port, une image Redis) avant de décider d'une action.

---

## Commande unique (parcours complet)

Lorsque `doctor` est vert :

```bash
bash automation/phase04.sh all --repo NabilNet/cloudguard360-phase04
```

Cette commande réalise dans l'ordre : **doctor → prepare → CI → identity/OIDC → publish → pause GHCR public → deploy → verify → reconcile**. Les opérations sensibles demandent `YES`. En cas d'échec, **reprenez uniquement la commande de l'étape concernée**. Les scripts ne détruisent pas vos ressources Azure existantes.

### Critères de clôture et preuves

| Contrôle | Preuve attendue |
|---|---|
| Code officiel Microsoft | `vendor/azure-vote`, commit et licence conservés |
| Version GitHub | `main` contient 4 workflows |
| CI Docker | Test frontend + Redis HTTP 200, exécution verte |
| Analyse DevSecOps | Scan secret/configuration bloquant, rapport de CVE consulté |
| SBOM | Artefact CycloneDX dans GitHub Actions |
| Image | Image GHCR publique identifiée par SHA du commit |
| OIDC | Sujet exact constaté, échange Azure réussi, aucun secret client |
| Azure RBAC | Rôle appliqué seulement sur `ca-cg360-voting` |
| Déploiement | Frontend nouveau, image Redis identique |
| Test | URL HTTPS et vote en navigateur |
| Configuration | Terraform Phase 03 sans drift inattendu |
| Gouvernance | Coûts, droits et compromis de sécurité documentés |

**Une phrase importante** : le code du ZIP peut être testé localement, mais **personne ne peut promettre 100 % de succès contre une souscription Azure inconnue**, surtout si les permissions GitHub, Azure RBAC, les quotas ou les images évoluent. Le package privilégie donc des contrôles stricts et des arrêts explicites plutôt qu'un faux « succès ».

---

## Références officielles

- [Microsoft Azure Voting App GitHub](https://github.com/Azure-Samples/azure-voting-app-redis)
- [GitHub — OpenID Connect reference, immutable subjects](https://docs.github.com/en/actions/reference/security/oidc)
- [Microsoft — Authenticate to Azure from GitHub Actions by OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)
- [Microsoft — az containerapp CLI reference](https://learn.microsoft.com/en-us/cli/azure/containerapp)
- [GitHub — configuring GHCR package visibility](https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility)
- [Microsoft — Azure built-in roles for Containers](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/containers)
- [GitHub — Managing deployment environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
