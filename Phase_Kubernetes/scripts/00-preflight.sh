#!/usr/bin/env bash
set -Eeuo pipefail
for c in az kubectl python3 zip curl; do command -v "$c" >/dev/null || { echo "STOP: $c introuvable"; exit 1; }; done
az account show >/dev/null || { echo 'STOP: Azure non authentifié'; exit 1; }
: "${CG360_AKS_RG:=rg-cg360-aks-lab}"
: "${CG360_AKS_NAME:=aks-cg360-lab}"
: "${CG360_AKS_SIZE:=Standard_D4s_v5}"
: "${CG360_AKS_REGION:=$(az group show -n rg-cg360-app --query location -o tsv)}"
[[ "$CG360_AKS_RG" == rg-cg360-aks-lab && "$CG360_AKS_NAME" == aks-cg360-lab ]] || { echo 'STOP: noms fixes de labo requis'; exit 1; }
echo '=== SUBSCRIPTION ==='
az account show --query '{Name:name,State:state}' -o table
echo '=== REGION / SIZE (vérifier disponibilité et quotas) ==='
echo "REGION=$CG360_AKS_REGION SIZE=$CG360_AKS_SIZE"
az provider show -n Microsoft.ContainerService --query '{Namespace:namespace,State:registrationState}' -o table || true
az vm list-skus -l "$CG360_AKS_REGION" --size "$CG360_AKS_SIZE" --output table || true
echo '=== QUOTA RÉGIONAL (lecture seule) ==='
az vm list-usage -l "$CG360_AKS_REGION" --query '[].{Name:name.localizedValue,Current:currentValue,Limit:limit}' -o table || true
echo '=== RG LAB EXISTANT ? ==='
az group exists --name "$CG360_AKS_RG"
echo '=== CLUSTERS AKS EXISTANTS ==='
az aks list --query '[].{Name:name,RG:resourceGroup,State:provisioningState}' -o table || true
echo 'PRECHECK: aucune ressource modifiée. Vérifier budget, quota et restrictions Azure Portal AVANT de créer.'
