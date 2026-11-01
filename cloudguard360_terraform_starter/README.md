# CloudGuard 360 — Terraform Azure Networking Starter (Étape 01)

**Objectif :** déployer une infrastructure réseau Azure minimale avec Terraform (sans VM, AKS, pare-feu payant ni IP publique).

## Architecture

```text
Azure Subscription
├── rg-cg360-network
│   └── vnet-cg360-hub (10.0.0.0/16)
│       └── snet-shared (10.0.1.0/24)
│             <---- VNet Peering dans les deux sens ---->
└── rg-cg360-app
    ├── vnet-cg360-app (10.10.0.0/16)
    │   ├── snet-workload (10.10.1.0/24) -- NSG
    │   └── snet-private-endpoints (10.10.2.0/24)
    └── nsg-cg360-workload
```

**Ressources créées : 11** (2 Resource Groups, 2 VNets, 3 subnets, 1 NSG, 1 association NSG/subnet, 2 peerings).

## Ce que l'infrastructure NE fait PAS encore

- Le Hub ne contient pas encore Azure Firewall, VPN Gateway ni point d'inspection central.
- Le peering ne constitue pas une connectivité transitive.
- Aucun trafic n'est généré sans workload; il n'y a pas de VM ni de cluster AKS.
- Les NSG utilisent leurs règles Azure par défaut. Des règles personnalisées seront ajoutées et testées lors de l'étape suivante.
- Le code utilise le **state local**. N'exécutez pas `terraform apply` dans Cloud Shell sans stockage persistant.

## Prérequis

- Souscription Azure active, type de licence et crédits vérifiés.
- Permissions de création de Resource Groups et ressources réseau, par exemple Contributor au scope concerné.
- Azure CLI et Terraform installés sur un **ordinateur avec stockage persistant** (Windows PowerShell 7, Linux ou macOS).
- `Microsoft.Network` enregistré pour la souscription Azure (vérifier avec `az provider show --namespace Microsoft.Network --query registrationState -o tsv`). Si non enregistré, demander au propriétaire/administrateur l'enregistrement.
- Budget/alertes configurés; vérifier le coût et la région avant `apply`.

## Démarrage sur Windows (PowerShell)

Ouvrir PowerShell depuis la racine du projet, puis :

```powershell
terraform version
az version
az login
az account list --query '[].{Name:name,IsDefault:isDefault}' --output table

# En cas de plusieurs souscriptions :
# az account set --subscription 'NOM_DE_VOTRE_SOUSCRIPTION'

# L'ID reste dans votre session locale, jamais dans Git :
$env:ARM_SUBSCRIPTION_ID = az account show --query id -o tsv

# Vérifier que Microsoft.Network est enregistré :
az provider show --namespace Microsoft.Network --query registrationState -o tsv

Copy-Item terraform.tfvars.example terraform.tfvars

terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=step01.tfplan
```

**STOP :** lire le plan et confirmer qu'il contient uniquement les 11 ressources attendues avant de passer à l'exécution :

```powershell
terraform show step01.tfplan
terraform apply step01.tfplan
terraform output
./scripts/verify.ps1
```

Si le plan montre une ressource inattendue, ne lancez pas `apply`. Si vous perdez le state, ne relancez pas directement `apply` sur les ressources existantes : vous devez restaurer/migrer le state ou importer les ressources.

## Linux / Bash

```bash
az login
az account list --query '[].{Name:name,IsDefault:isDefault}' -o table
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
az provider show --namespace Microsoft.Network --query registrationState -o tsv
cp terraform.tfvars.example terraform.tfvars
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=step01.tfplan
terraform show step01.tfplan
# Après examen du plan :
terraform apply step01.tfplan
terraform output
bash scripts/verify.sh
```

## Explication des fichiers

- `versions.tf` : versions minimales de Terraform et provider AzureRM compatible.
- `providers.tf` : configuration AzureRM, sans identifiants secrets en dur.
- `variables.tf` : préfixe, région, tags et validation du préfixe.
- `main.tf` : deux Resource Groups.
- `network.tf` : Hub, Spoke, subnets, NSG, peering dans les deux sens.
- `outputs.tf` : noms, préfixes réseau et identifiants des ressources créées.
- `terraform.tfvars.example` : exemple de variables à personnaliser.
- `.gitignore` : empêche la publication accidentelle de state, plans et configurations privées.
- `scripts/` : vérifications en lecture seule.

## Sécurité, coût et cycle de vie

- VNet/NSG/peering sans trafic et sans workload ne créent normalement pas une facture d'infrastructure compute, mais les services associés peuvent être payants plus tard. Le transfert de données en peering est facturable.
- Le state Terraform peut contenir des valeurs sensibles; protégez le fichier local et ne l'envoyez jamais dans Git.
- Le provider est contraint à la série 4.x pour stabiliser le laboratoire; le fichier `.terraform.lock.hcl` créé après `init` doit être conservé dans Git.
- Ne détruisez pas des ressources provenant d'autres projets. Pour ce laboratoire, vérifiez la portée avec `terraform plan -destroy` avant `terraform destroy`.
- Azure Cloud Shell en mode éphémère efface les fichiers après la session. Utiliser plutôt un PC persistant, puis migrer vers un backend Azure Blob avec verrouillage (prochaine étape).

## Prochaines étapes

02. Backend Terraform Azure Blob sécurisé avec authentification Entra et verrouillage.
03. Identity/RBAC et fédération OIDC GitHub Actions.
04. Key Vault + contrôles Azure Policy, selon coût/licences.
05. Registry + AKS temporaire et application Azure Voting App.
06. CI/CD, Zabbix, Grafana et réponse aux incidents.

## Références

- https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- https://developer.hashicorp.com/terraform/language/backend/azurerm
- https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq
- https://developer.hashicorp.com/terraform/install
