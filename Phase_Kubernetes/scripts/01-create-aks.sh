#!/usr/bin/env bash
set -Eeuo pipefail
LAB_RG=rg-cg360-aks-lab
AKS=aks-cg360-lab
REGION="${CG360_AKS_REGION:-$(az group show -n rg-cg360-app --query location -o tsv)}"
SIZE="${CG360_AKS_SIZE:-Standard_D4s_v5}"
[[ -n "$REGION" && "$SIZE" =~ ^Standard_D[0-9]+[a-zA-Z0-9_]*$ ]] || { echo 'STOP: région ou SKU VM invalide'; exit 1; }
[[ $(az group exists -n "$LAB_RG") == false ]] || { echo "STOP: $LAB_RG existe déjà. Ne pas recréer ni réutiliser aveuglément."; exit 1; }
echo "AKS demandera une VM $SIZE facturable dans $REGION. Cluster Free = plan de contrôle uniquement."
echo "Groupe isolé: $LAB_RG. Ne touche pas rg-cg360-app ni rg-cg360-network."
read -r -p "Créer ce cluster temporaire ? Tapez CREATE-AKS : " answer
[[ "$answer" == CREATE-AKS ]] || { echo 'Annulé'; exit 1; }
az provider register -n Microsoft.ContainerService --wait
az group create -n "$LAB_RG" -l "$REGION" -o table
printf '\n=== Création AKS (facturation VM/disque/réseau) ===\n'
if ! az aks create --resource-group "$LAB_RG" --name "$AKS" --location "$REGION" \
  --tier free --node-count 1 --node-vm-size "$SIZE" --os-sku Ubuntu \
  --enable-managed-identity --network-plugin azure --network-plugin-mode overlay \
  --no-ssh-key --output table; then
  echo "ÉCHEC: vérifier l'erreur Azure; le RG $LAB_RG peut déjà contenir des ressources facturables. Exécuter le nettoyage contrôlé scripts/05-delete-aks.sh après inspection." >&2
  exit 1
fi
az aks get-credentials -g "$LAB_RG" -n "$AKS" --overwrite-existing
kubectl config current-context
kubectl get nodes -o wide
echo 'PASS: Cluster AKS créé. Ne pas le laisser allumé après le laboratoire.'
