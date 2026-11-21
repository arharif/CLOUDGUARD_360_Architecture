#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="$(kubectl config current-context)"
[[ "$CTX" == aks-cg360-lab || "$CTX" == kind-cg360 ]] || { echo "STOP: contexte inattendu: $CTX"; exit 1; }
[[ $# == 1 ]] || { echo 'Usage: bash scripts/04-vote.sh ghcr.io/nabilnet/cloudguard360-vote:SHA_COMPLET'; exit 2; }
IMAGE="$1"
[[ "$IMAGE" =~ ^ghcr\.io/[a-z0-9_.-]+/[a-z0-9_.-]+:[a-f0-9]{40}$ ]] || { echo 'STOP: image attendue GHCR : tag SHA Git complet'; exit 2; }
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
sed "s|__VOTE_IMAGE__|$IMAGE|g" "$ROOT/k8s/01-redis-vote-template.yaml" > "$TMP"
kubectl apply -f "$ROOT/k8s/00-smoke.yaml"
kubectl apply -f "$TMP"
kubectl -n cg360 rollout status deploy/cg360-redis --timeout=180s
kubectl -n cg360 rollout status deploy/cg360-vote --timeout=180s
kubectl -n cg360 get pods,svc -o wide
echo 'PASS: Voting App + Redis Ready. Pour tester: kubectl -n cg360 port-forward svc/cg360-vote 18081:80'
