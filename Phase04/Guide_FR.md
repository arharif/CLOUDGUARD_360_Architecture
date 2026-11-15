# CLOUDGUARD 360 — PHASE 04
## Laboratoire unique : GitHub Actions, CI/CD, DevSecOps et déploiement Azure

**But :** à partir de l'application Azure Voting App déjà déployée en Phase 03 (`ca-cg360-voting`), automatiser la préparation, les contrôles de sécurité et la livraison d'une image Docker, sans recréer les VNets, les groupes Entra ni AKS. Le guide complet en anglais est disponible dans `terraform.md`. L'interface animée est `index.html`.

**Important :** Terraform reste propriétaire des ressources de la Phase 03. Une modification d'image par GitHub Actions produit potentiellement une dérive Terraform, à réconcilier explicitement. La solution utilise une image d'exemple historique : son scan de vulnérabilités produit un **rapport, pas une autorisation de production**.

## 1. Vérifier Azure et l'application existante

Portail Azure → **Subscriptions → Cost Management**, puis **Resource groups → rg-cg360-app → Container Apps → ca-cg360-voting**. Vérifiez l'existence des conteneurs `vote-frontend` et `redis`.

Cloud Shell → **Bash** :

```bash
mountpoint -q "$HOME/clouddrive" && echo 'STOCKAGE OK'
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
az account show --query '{Name:name,State:state}' -o table
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query 'properties.template.containers[].{Name:name,Image:image}' -o table
```

Si l'application Phase 03 n'existe plus, réalisez d'abord le pipeline CI (sans déployer sur Azure) et rétablissez le service Phase 03 avant le CD.

## 2. Télécharger et extraire le ZIP dans Cloud Shell

1. Téléchargez **CloudGuard360_Phase04.zip** depuis le chat.
2. Portail Azure → icône **Cloud Shell** → **Bash** → **Manage files / Gérer les fichiers → Upload / Charger**.
3. Choisissez le ZIP depuis votre ordinateur.
4. Exécutez :

```bash
mkdir -p ~/clouddrive/cloudguard360
unzip -n ~/CloudGuard360_Phase04.zip -d ~/clouddrive/cloudguard360
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass
ls -la
bash scripts/00-preflight.sh
```

Ne remplacez jamais les states des Phases 01, 02 ou 03.

## 3. Créer le dépôt GitHub

1. Ouvrez https://github.com/new → **New repository**.
2. Nom : `cloudguard360-phase04`. Un dépôt public peut éviter les frais de minutes d'exécution standard, mais ne publiez aucune donnée sensible.
3. **Create repository** puis copiez son URL HTTPS.
4. Dans Cloud Shell, en remplaçant votre nom de compte :

```bash
cd ~/clouddrive/cloudguard360
git clone https://github.com/YOUR_USERNAME/cloudguard360-phase04.git cloudguard360-phase04-repo
bash ~/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass/scripts/04-copy-to-repo.sh \
  ~/clouddrive/cloudguard360/cloudguard360-phase04-repo
cd ~/clouddrive/cloudguard360/cloudguard360-phase04-repo
git add Dockerfile .dockerignore .gitignore .github/workflows scripts/validate_repo.py docs/release-runbook.md
git commit -m "Add Phase 04 secure CI CD pipeline"
git branch -M main
git push -u origin main
```

En cas de refus d'authentification GitHub, utilisez la connexion navigateur de GitHub CLI si disponible ou l'édition sur le site GitHub. N'insérez jamais un mot de passe dans les commandes affichées publiquement.

## 4. Exécuter CI et comprendre les contrôles

GitHub → dépôt → **Actions → 01 | Continuous Integration and DevSecOps**. Le workflow vérifie les fichiers, recherche les secrets et mauvaises configurations (blocage), prépare une image Docker, exécute un scan de vulnérabilités (rapport uniquement) et génère un SBOM CycloneDX téléchargeable dans **Artifacts**.

Le Dockerfile réutilise l'image préconstruite de la Phase 03. **Si l'image MCR n'est plus disponible**, le build échoue : consignez le problème et utilisez uniquement une image compatible explicitement vérifiée. Un pipeline rouge n'est pas une validation.

## 5. Publier l'image dans GitHub Container Registry

GitHub → **Actions → 02 | Manual Release to Azure Container Apps → Run workflow**. Gardez `deploy_to_azure = false` pour la première exécution.

Le job doit créer `ghcr.io/VOTRE_COMPTE/cloudguard360-vote:<commit-sha>`.

Pour cette application de démonstration sans secrets, GitHub → **Profile → Packages → cloudguard360-vote → Package settings → Change visibility → Public**. Ne rendez pas publics d'autres packages privés. La partie déploiement Azure ne doit pas être activée avant cette vérification.

## 6. Configurer OIDC avec Terraform (sans secret client)

Dans le ZIP, ouvrez le projet Terraform **distinct** `terraform/oidc-identity` :

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass/terraform/oidc-identity
cp -n terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Remplacez `YOUR_ACCOUNT/cloudguard360-phase04` par le nom exact du dépôt GitHub. Conservez `enable_deployment_role = false` initialement.

```bash
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
terraform init
terraform validate
terraform plan -out=phase04-oidc.tfplan
terraform show -json phase04-oidc.tfplan | python3 ../../scripts/05-check-oidc-plan.py
```

Plan attendu : **deux créations** (Managed Identity + Federated Credential). Après revue, `terraform apply phase04-oidc.tfplan`. Puis activez `enable_deployment_role = true`, regénérez et contrôlez le plan : **une affectation** `Container Apps Contributor`, limitée à l'application existante. Cette action nécessite la permission RBAC appropriée. Le rôle peut modifier ou supprimer la Container App : ne le considérez pas comme un rôle lecture seule.

Dans GitHub → **Settings → Environments → New environment**, créez `cloudguard360-lab`. Configurez les approbations si disponibles, et les secrets de l'environnement `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, sans `AZURE_CLIENT_SECRET`.

## 7. Déploiement manuel, vérification et réconciliation Terraform

Après validation GHCR public et OIDC : GitHub → **Actions → 02 | Manual Release** → `deploy_to_azure=true`. Le job met à jour **uniquement `vote-frontend`**, et vérifie le statut HTTPS.

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass
bash scripts/01-check-deployment.sh
```

**Étape essentielle :** le `terraform.tfvars` de la Phase 03 référence encore probablement l'ancienne image Microsoft. Définissez `frontend_image` avec le chemin GHCR réellement déployé, puis exécutez `terraform plan` dans le **dossier Phase 03**. Ne lancez aucun `apply` sans inspecter la dérive, notamment les informations de registre et la définition de l'image.

## 8. Preuves, tests négatifs et clôture

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass
bash scripts/02-report-evidence.sh
```

Documentez : exécution CI, rapport Trivy, SBOM, image GHCR, identité OIDC, approbation, nouvelle révision de l'application, HTTP 200 et revue Terraform. Pour tester un contrôle de sécurité sans risque, renommez temporairement `Dockerfile` dans une **branche de test**, constatez l'échec CI, puis rétablissez le fichier. Ne publiez jamais de faux secrets ressemblant à de vraies clés.

**Phase suivante :** Phase 05 — Kubernetes local puis AKS temporaire, uniquement après vérification des quotas et coûts Azure.
