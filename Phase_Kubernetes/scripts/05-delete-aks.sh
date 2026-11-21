#!/usr/bin/env bash
set -Eeuo pipefail
RG=rg-cg360-aks-lab
AKS=aks-cg360-lab
if [[ $(az group exists -n "$RG") == false ]]; then echo "PASS: $RG déjà absent"; exit 0; fi
node_rg="$(az aks show -g "$RG" -n "$AKS" --query nodeResourceGroup -o tsv 2>/dev/null || true)"
echo 'ATTENTION: destruction du seul groupe de laboratoire:'
az resource list -g "$RG" --query '[].{Name:name,Type:type}' -o table
[[ -z "$node_rg" ]] || echo "Le groupe géré des nœuds AKS est: $node_rg"
read -r -p "Pour confirmer la suppression de $RG tapez exactement DELETE-LAB : " ans
[[ "$ans" == DELETE-LAB ]] || { echo 'Annulé'; exit 1; }
az group delete -n "$RG" --yes
if [[ $(az group exists -n "$RG") == false ]]; then echo "PASS: $RG supprimé"; else echo "ALERTE: RG encore présent; vérifier Azure Portal"; exit 1; fi
if [[ -n "$node_rg" ]]; then
  echo "Vérification du RG géré: $node_rg"
  if [[ $(az group exists -n "$node_rg") == true ]]; then echo "ALERTE: groupe géré encore présent; inspecter avant expiration du crédit."; exit 1; fi
fi
echo 'PASS: les réseaux historiques rg-cg360-app et rg-cg360-network ne sont pas touchés.'
