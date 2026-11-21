#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/evidence/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
CTX="$(kubectl config current-context)"
[[ "$CTX" == aks-cg360-lab || "$CTX" == kind-cg360 ]] || { echo "STOP: contexte inattendu: $CTX"; exit 1; }
printf '%s\n' "$CTX" > "$OUT/context.txt"
kubectl get nodes -o wide > "$OUT/nodes.txt"
kubectl -n cg360 get pods,deploy,svc -o wide > "$OUT/workloads.txt"
kubectl -n cg360 describe deploy cg360-web > "$OUT/deployment-description.txt"
kubectl -n cg360 get events --sort-by='.lastTimestamp' > "$OUT/events.txt"
kubectl -n cg360 logs deploy/cg360-web --tail=100 > "$OUT/web-logs.txt" 2>&1 || true
if [[ "$CTX" == aks-cg360-lab ]]; then
  az aks show -g rg-cg360-aks-lab -n aks-cg360-lab --query '{Name:name,Location:location,State:provisioningState,NodeResourceGroup:nodeResourceGroup,Version:kubernetesVersion}' -o json > "$OUT/aks-summary.json"
  az resource list -g rg-cg360-aks-lab --query '[].{Name:name,Type:type,Location:location}' -o json > "$OUT/resources.json"
fi
( cd "$(dirname "$OUT")" && zip -qr "$(basename "$OUT").zip" "$(basename "$OUT")" )
echo "PASS: Dossier de preuves: $OUT"
echo "Télécharger: $(dirname "$OUT")/$(basename "$OUT").zip"
echo 'Ne pas joindre kubeconfig, tokens ou secrets au rapport.'
