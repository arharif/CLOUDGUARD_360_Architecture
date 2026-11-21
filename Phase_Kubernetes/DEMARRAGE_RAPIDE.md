# DÉMARRAGE RAPIDE — PHASE 08 (dernier jour Azure)

## Télécharger et préparer

1. Télécharger `CloudGuard360_Phase08_Kubernetes_AKS.zip` sur votre PC.
2. Azure Portal → Cloud Shell Bash → Manage files → Upload.
3. Copier une commande par message :

```bash
mkdir -p ~/clouddrive/cloudguard360
unzip -n ~/CloudGuard360_Phase08_Kubernetes_AKS.zip -d ~/clouddrive/cloudguard360
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase08_Kubernetes_AKS
```

## Ne jamais ignorer ces étapes

```bash
bash scripts/00-preflight.sh
```

**Stop si** crédit insuffisant, souscription désactivée, région interdite ou quota < 4 vCPU. L'AKS Free n'inclut pas la VM gratuite. Vérifier vos crédits dans Azure Portal.

## Si autorisé, AKS temporaire

```bash
bash scripts/01-create-aks.sh
bash scripts/02-deploy-check.sh
kubectl -n cg360 get pods,svc
bash scripts/03-evidence.sh
bash scripts/05-delete-aks.sh
```

Télécharger l'archive de preuves sur votre PC **avant** la suppression et la désactivation du compte.

## Sinon, Kubernetes gratuitement sur Windows avec Docker Desktop

```powershell
kind create cluster --name cg360
kubectl config use-context kind-cg360
kubectl apply -f .\k8s\00-smoke.yaml
kubectl -n cg360 rollout status deploy/cg360-web --timeout=180s
kubectl -n cg360 port-forward svc/cg360-web 8080:80
```

Ouvrez http://localhost:8080. Lisez `README_FR.md` pour toutes les explications et le diagnostic.
