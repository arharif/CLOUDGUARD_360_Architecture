#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/evidence/$(date -u +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
az account show --query '{Name:name,State:state}' -o json > "$OUT/01-subscription-context.json"
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query '{name:name,location:location,containers:properties.template.containers[].{name:name,image:image},fqdn:properties.configuration.ingress.fqdn}' -o json > "$OUT/02-containerapp.json"
az containerapp revision list -g rg-cg360-app -n ca-cg360-voting --query '[].{name:name,active:properties.active}' -o json > "$OUT/03-revisions.json"
cat > "$OUT/04-questions.md" <<'MD'
# CloudGuard 360 Phase 04 evidence checklist
- GitHub Actions CI run URL and result:
- Repo security scan result:
- Docker build result:
- Vulnerability report reviewed (legacy image exceptions):
- SBOM artifact name:
- GHCR package visibility:
- Published commit SHA image:
- OIDC authentication verification:
- Manual release run URL:
- HTTP smoke-test status:
- Phase 03 Terraform image drift reconciled:
- Cost / teardown decision:
MD
printf 'Evidence saved to %s\n' "$OUT"
