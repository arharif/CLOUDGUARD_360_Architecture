#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CTX="$(kubectl config current-context)"
[[ "$CTX" == aks-cg360-lab || "$CTX" == kind-cg360 ]] || { echo "STOP: mauvais contexte Kubernetes: $CTX"; exit 1; }
echo "Context: $CTX"
kubectl apply -f "$ROOT/k8s/00-smoke.yaml"
kubectl -n cg360 rollout status deploy/cg360-web --timeout=180s
kubectl -n cg360 get deployments,pods,svc -o wide
printf '\n=== Test HTTP par port-forward, sans IP publique ===\n'
kubectl -n cg360 port-forward svc/cg360-web 18080:80 --address 127.0.0.1 >/tmp/cg360-pf-$$.log 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; rm -f /tmp/cg360-pf-$$.log' EXIT
success=0
for i in $(seq 1 20); do
  if curl --fail --silent --show-error --max-time 3 -o /tmp/cg360-smoke-$$.html http://127.0.0.1:18080/ 2>/dev/null; then success=1; break; fi
  sleep 2
done
[[ "$success" == 1 ]] || { echo 'STOP: échec HTTP; logs port-forward:'; cat /tmp/cg360-pf-$$.log; exit 1; }
grep -qi 'nginx' /tmp/cg360-smoke-$$.html || { echo 'STOP: HTML inattendu'; exit 1; }
rm -f /tmp/cg360-smoke-$$.html
echo 'PASS: Kubernetes Deployment Ready + Service ClusterIP + HTTP local OK'
