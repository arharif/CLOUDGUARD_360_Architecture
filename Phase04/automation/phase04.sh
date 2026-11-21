#!/usr/bin/env bash
# CloudGuard 360 Phase 04 — resumable, permission-gated, Azure Cloud Shell Bash workflow.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$HOME/clouddrive/cloudguard360"
REPO_DIR="$WORKSPACE/cloudguard360-phase04-repo"
UPSTREAM_DIR="$WORKSPACE/azure-voting-app-redis-upstream"
AZ_RG="rg-cg360-app"
AZ_APP="ca-cg360-voting"
ENVIRONMENT="cloudguard360-lab"
TF_DIR="$ROOT/terraform/oidc"
REPO="NabilNet/cloudguard360-phase04"
OPERATION="${1:-help}"
[[ $# -eq 0 ]] || shift
while (( $# )); do
  case "$1" in
    --repo) [[ $# -gt 1 ]] || { echo 'Missing --repo value' >&2; exit 2; }; REPO="$2"; shift 2;;
    *) echo "Unknown argument: $1" >&2; exit 2;;
  esac
done
say(){ printf '\n[CG360] %s\n' "$*"; }
stop(){ echo "STOP: $*" >&2; exit 1; }
approve(){ local answer; read -r -p "$1 Type YES: " answer || stop 'No interactive approval received'; [[ "$answer" == YES ]] || stop 'Approval denied; nothing further executed'; }
need(){ command -v "$1" >/dev/null 2>&1 || stop "Missing $1. See docs/TROUBLESHOOTING_FR.md"; }
usage(){ cat <<'END'
CloudGuard 360 Phase 04 FINAL — Run in Azure Cloud Shell Bash
  bash automation/phase04.sh doctor     --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh prepare    --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh ci         --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh identity   --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh publish    --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh deploy     --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh verify     --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh reconcile  --repo NabilNet/cloudguard360-phase04
  bash automation/phase04.sh all        --repo NabilNet/cloudguard360-phase04

Each stage is resumable and explicitly approved before Git push, Terraform apply,
public image publication or Azure deployment. Never deletes existing Azure resources.
END
}
[[ "$OPERATION" == help || "$OPERATION" == --help ]] && { usage; exit 0; }
[[ "$OPERATION" =~ ^(doctor|prepare|ci|identity|publish|deploy|verify|reconcile|all)$ ]] || { usage; exit 2; }
[[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || stop 'Invalid --repo format: use OWNER/REPO'

base_checks(){
  for tool in az gh git python3 terraform curl; do need "$tool"; done
  [[ -d "$HOME/clouddrive" ]] || stop 'clouddrive does not exist: configure Cloud Shell persistent storage first.'
  mountpoint -q "$HOME/clouddrive" || stop 'clouddrive is not mounted. Preventing Terraform state loss.'
  gh auth status >/dev/null 2>&1 || stop 'GitHub CLI authentication required: gh auth login.'
  az account show >/dev/null 2>&1 || stop 'Azure CLI not authenticated; open Cloud Shell with the correct subscription.'
  export ARM_SUBSCRIPTION_ID; ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  export ARM_TENANT_ID; ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
  [[ -n "$ARM_SUBSCRIPTION_ID" && -n "$ARM_TENANT_ID" ]] || stop 'Azure subscription or tenant is missing.'
  local actual_repo
  actual_repo="$(gh api "repos/$REPO" --jq .full_name 2>/dev/null)" || stop "Cannot access GitHub repository $REPO. Verify its name and permissions."
  [[ "${actual_repo,,}" == "${REPO,,}" ]] || stop "GitHub returned unexpected repo: $actual_repo"
  REPO="$actual_repo"
  mkdir -p "$WORKSPACE"
}
app_json(){ az containerapp show -n "$AZ_APP" -g "$AZ_RG" -o json; }
check_app(){
  local js
  js="$(app_json)" || stop "Missing Phase 03 app: $AZ_RG / $AZ_APP (or insufficient Azure permission)."
  printf '%s' "$js" | python3 "$ROOT/scripts/check_azure_app.py" --expected "$AZ_APP" || stop 'Phase 03 app does not match the expected two-container demo.'
}
frontend(){ az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query "properties.template.containers[?name=='vote-frontend'].image | [0]" -o tsv; }
redis_image(){ az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query "properties.template.containers[?name=='redis'].image | [0]" -o tsv; }
repo_head(){ git -C "$REPO_DIR" rev-parse HEAD; }
ensure_clone(){
  [[ -d "$REPO_DIR/.git" ]] || stop 'Local GitHub clone absent; run prepare.'
  local remote
  remote="$(git -C "$REPO_DIR" remote get-url origin)"
  [[ "${remote,,}" == *"/${REPO,,}.git" || "${remote,,}" == *"/${REPO,,}" ]] || stop "Existing repository clone has a different origin: $remote"
  [[ -f "$REPO_DIR/vendor/azure-vote/main.py" ]] || stop 'Vendored official app missing: run prepare.'
  ( cd "$REPO_DIR" && python3 scripts/validate_repo.py )
  [[ -z "$(git -C "$REPO_DIR" status --porcelain)" ]] || stop 'Uncommitted Git changes; review before using CI.'
  [[ "$(git -C "$REPO_DIR" branch --show-current)" == main ]] || stop 'Local repository is not on main.'
  git -C "$REPO_DIR" fetch --quiet origin main || stop 'Could not fetch main from GitHub.'
  [[ "$(git -C "$REPO_DIR" rev-parse HEAD)" == "$(git -C "$REPO_DIR" rev-parse origin/main)" ]] || stop 'Local HEAD differs from remote main; pull/review before running.'
}
doctor(){
  base_checks
  say "GitHub repository: $(gh repo view "$REPO" --json nameWithOwner --jq .nameWithOwner)"
  say 'Azure subscription:'
  az account show --query '{Name:name,State:state}' -o table
  say 'Current Phase 03 Container App — read-only:'
  check_app
  az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query 'properties.template.containers[].{Container:name,Image:image}' -o table
  say 'GitHub permissions and repository visibility:'
  gh api "repos/$REPO" --jq '{full_name:.full_name,private:.private,can_push:.permissions.push,default_branch:.default_branch}'
  say 'PASS: doctor finished; no resources changed.'
}
copy_safe(){
  local from="$1" to="$2" backupdir="$3"
  mkdir -p "$(dirname "$to")"
  if [[ -f "$to" ]] && ! cmp -s "$from" "$to"; then
    mkdir -p "$backupdir/$(dirname "${to#"$REPO_DIR/"}")"
    cp -p "$to" "$backupdir/${to#"$REPO_DIR/"}"
    say "Existing file backed up outside Git repo: ${to#"$REPO_DIR/"}"
  fi
  cp "$from" "$to"
}
prepare(){
  base_checks; need find
  local perm
  perm="$(gh api "repos/$REPO" --jq .permissions.push)"
  [[ "$perm" == true ]] || stop 'GitHub CLI account lacks push access to this repository.'
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    [[ ! -e "$REPO_DIR" ]] || stop "Refusing to replace non-Git directory at $REPO_DIR"
    say 'Cloning YOUR existing repository (no new repository will be created).'
    git clone "https://github.com/$REPO.git" "$REPO_DIR" || stop 'git clone failed.'
  fi
  local origin
  origin="$(git -C "$REPO_DIR" remote get-url origin)"
  [[ "${origin,,}" == *"/${REPO,,}.git" || "${origin,,}" == *"/${REPO,,}" ]] || stop 'Local clone origin is not the expected repository.'
  [[ "$(git -C "$REPO_DIR" branch --show-current)" == main ]] || stop 'Expected main branch. Do not reset or force-push.'
  [[ -z "$(git -C "$REPO_DIR" status --porcelain)" ]] || stop 'Existing local clone has uncommitted changes. Review them first.'
  if [[ ! -f "$REPO_DIR/vendor/azure-vote/main.py" ]]; then
    if [[ ! -d "$UPSTREAM_DIR/.git" ]]; then
      [[ ! -e "$UPSTREAM_DIR" ]] || stop "Upstream folder exists without a Git checkout: $UPSTREAM_DIR"
      say 'Cloning the official Microsoft Voting App source.'
      git clone --depth 1 https://github.com/Azure-Samples/azure-voting-app-redis.git "$UPSTREAM_DIR" || stop 'Upstream clone failed.'
    fi
    local src="$UPSTREAM_DIR/azure-vote/azure-vote"
    if [[ ! -f "$src/main.py" || ! -f "$src/config_file.cfg" || ! -d "$src/templates" || ! -d "$src/static" ]]; then
      say 'Actual source candidates found:'
      find "$UPSTREAM_DIR" -maxdepth 6 -name main.py -print >&2
      stop "Official sample layout differs; expected $src. No code has been pushed."
    fi
    [[ -f "$UPSTREAM_DIR/LICENSE" ]] || stop 'Upstream license missing — review repository before distributing.'
    mkdir -p "$REPO_DIR/vendor/azure-vote" "$REPO_DIR/docs"
    cp -a "$src/." "$REPO_DIR/vendor/azure-vote/"
    git -C "$UPSTREAM_DIR" rev-parse HEAD > "$REPO_DIR/docs/UPSTREAM_COMMIT.txt"
    cp "$UPSTREAM_DIR/LICENSE" "$REPO_DIR/docs/UPSTREAM_LICENSE.txt"
  fi
  local backupdir="$WORKSPACE/phase04-backups/$(date -u +%Y%m%dT%H%M%SZ)"
  if [[ -f "$REPO_DIR/.github/workflows/02-release.yml" ]]; then
    say 'WARNING: old 02-release.yml workflow detected. It may conflict with the repaired 02-publish / 03-deploy workflows.'
    approve 'Back up and REMOVE legacy 02-release.yml from this repository (not from your old local phase package)?'
    mkdir -p "$backupdir/.github/workflows"
    cp -p "$REPO_DIR/.github/workflows/02-release.yml" "$backupdir/.github/workflows/02-release.yml"
    rm "$REPO_DIR/.github/workflows/02-release.yml"
  fi
  for f in Dockerfile .dockerignore .gitignore .github/workflows/00-oidc-subject.yml .github/workflows/01-ci.yml .github/workflows/02-publish.yml .github/workflows/03-deploy.yml scripts/validate_repo.py docs/RELEASE_RUNBOOK.md; do
    copy_safe "$ROOT/$f" "$REPO_DIR/$f" "$backupdir"
  done
  ( cd "$REPO_DIR" && python3 scripts/validate_repo.py ) || stop 'Repo validation failed: no Git push performed.'
  local unwanted
  unwanted="$(git -C "$REPO_DIR" status --short)"
  say 'Proposed Git changes:'
  printf '%s\n' "$unwanted"
  [[ -n "$unwanted" ]] || { say 'No changes needed; repository already prepared.'; return; }
  approve "Review the files above. Commit and PUSH them to https://github.com/$REPO ?"
  git -C "$REPO_DIR" add -A -- Dockerfile .dockerignore .gitignore .github/workflows/ scripts/validate_repo.py docs/ vendor/
  if git -C "$REPO_DIR" diff --cached --quiet; then say 'No staged changes.'; return; fi
  git -C "$REPO_DIR" config user.name >/dev/null || git -C "$REPO_DIR" config user.name "$(gh api user --jq .login)"
  git -C "$REPO_DIR" config user.email >/dev/null || git -C "$REPO_DIR" config user.email "$(gh api user --jq .login)@users.noreply.github.com"
  git -C "$REPO_DIR" commit -m 'CloudGuard 360: reproducible Phase 04 CI CD OIDC and Azure vote app'
  git -C "$REPO_DIR" push -u origin main || stop 'Git push failed; no force-push attempted.'
  say 'PASS: GitHub repository prepared.'
}
last_dispatch(){
  gh run list -R "$REPO" --workflow "$1" --event workflow_dispatch -L 5 --json databaseId --jq '.[0].databaseId // ""' 2>/dev/null || true
}
run_workflow(){
  local wf="$1"; shift
  ensure_clone
  local before id="" n sha
  sha="$(repo_head)"
  before="$(last_dispatch "$wf")"
  [[ "$before" =~ ^[0-9]+$ ]] || before=0
  say "Starting GitHub workflow $wf on main ($sha)" >&2
  gh workflow run "$wf" -R "$REPO" --ref main "$@" || stop "Cannot dispatch $wf. Check GitHub Actions permissions."
  for (( n=0; n<48; n++ )); do
    id="$(gh run list -R "$REPO" --workflow "$wf" --event workflow_dispatch -L 10 --json databaseId,headSha --jq ".[] | select(.headSha == \"$sha\" and .databaseId != $before) | .databaseId" 2>/dev/null | head -1 || true)"
    [[ "$id" =~ ^[0-9]+$ ]] && break
    sleep 5
  done
  [[ "$id" =~ ^[0-9]+$ ]] || stop "Workflow dispatched but no run ID found for $wf. Check https://github.com/$REPO/actions"
  say "Run: https://github.com/$REPO/actions/runs/$id" >&2
  gh run watch "$id" -R "$REPO" --exit-status >&2 || stop "Workflow FAILED: https://github.com/$REPO/actions/runs/$id"
  printf '%s\n' "$id"
}
ci(){ base_checks; say 'Running real GitHub CI, Docker smoke test and security scanning.'; run_workflow 01-ci.yml >/dev/null; say 'PASS: GitHub CI completed successfully.'; }
identity(){
  base_checks; check_app; ensure_clone
  local status; status="$(az provider show --namespace Microsoft.ManagedIdentity --query registrationState -o tsv)"
  [[ "$status" == Registered ]] || stop "Microsoft.ManagedIdentity provider is $status. If permitted run: az provider register -n Microsoft.ManagedIdentity --wait"
  say 'Configuring GitHub deployment environment (no required reviewers auto-added).'
  gh api -X PUT "repos/$REPO/environments/$ENVIRONMENT" >/dev/null || stop 'GitHub environment creation requires repository admin permissions.'
  local runid subject
  runid="$(run_workflow 00-oidc-subject.yml | grep -E '^[0-9]+$' | tail -1)"
  [[ "$runid" =~ ^[0-9]+$ ]] || stop 'Could not retrieve OIDC claims workflow run.'
  subject="$(gh run view "$runid" -R "$REPO" --log | sed -n 's/^.*CG360_OIDC_SUBJECT=//p' | tail -1 | tr -d '\r')"
  [[ "$subject" == "repo:"*":environment:$ENVIRONMENT" ]] || stop "Unexpected OIDC subject: $subject"
  [[ "$subject" == *"${REPO%%/*}"* && "$subject" == *"${REPO##*/}"* ]] || stop 'OIDC subject does not reference this GitHub repository.'
  say "Actual OIDC subject emitted by GitHub (never guessed): $subject"
  mkdir -p "$TF_DIR"
  local tfvars="$TF_DIR/terraform.tfvars"
  if [[ -f "$tfvars" ]]; then
    grep -Fqx "github_oidc_subject = \"$subject\"" "$tfvars" || stop "Existing terraform.tfvars has a different OIDC subject; review $tfvars. No overwrite."
  else
    python3 - "$tfvars" "$subject" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); sub=sys.argv[2]
p.write_text('github_oidc_subject = '+repr(sub).replace("'",'"')+'\n')
PY
  fi
  say 'Terraform will create UAMI, GitHub trust and a role on the existing Container App only.'
  ( cd "$TF_DIR" && terraform init -input=false && terraform validate && terraform plan -out=phase04-identity.tfplan -input=false && terraform show -json phase04-identity.tfplan | python3 "$ROOT/scripts/check_identity_plan.py" --subject "$subject" --app "$AZ_APP" ) || stop 'Identity Terraform plan failed or unsafe.'
  ( cd "$TF_DIR" && terraform show -no-color phase04-identity.tfplan | grep -E 'will be created|Plan:' || true )
  approve 'Review Azure identity + scoped RBAC plan. Apply with Terraform?'
  ( cd "$TF_DIR" && terraform apply -input=false phase04-identity.tfplan ) || stop 'Terraform apply failed. Review permissions; do not alter Phase 01/02/03 state.'
  local cid tid sid
  cid="$(cd "$TF_DIR" && terraform output -raw github_client_id)"
  tid="$ARM_TENANT_ID"; sid="$ARM_SUBSCRIPTION_ID"
  printf '%s' "$cid" | gh secret set AZURE_CLIENT_ID -e "$ENVIRONMENT" -R "$REPO"
  printf '%s' "$tid" | gh secret set AZURE_TENANT_ID -e "$ENVIRONMENT" -R "$REPO"
  printf '%s' "$sid" | gh secret set AZURE_SUBSCRIPTION_ID -e "$ENVIRONMENT" -R "$REPO"
  say 'PASS: OIDC trust + environment secrets configured. No Azure client secret used.'
  say "Review GitHub environment branch restriction at https://github.com/$REPO/settings/environments"
}
publish(){
  base_checks
  approve 'Publish a demo image to ghcr.io and generate security reports?'
  run_workflow 02-publish.yml >/dev/null
  say "PASS: image published for commit $(repo_head)."
  say "Now set GHCR package cloudguard360-vote to Public in GitHub Packages. Public means anonymously pullable."
}
deploy(){
  base_checks; ensure_clone; check_app
  local before_redis sha owner image
  before_redis="$(redis_image)"; sha="$(repo_head)"
  owner="${REPO%%/*}"; image="ghcr.io/${owner,,}/cloudguard360-vote:$sha"
  say "Planned image: $image"
  say "Redis image to preserve: $before_redis"
  say 'Prerequisite: set GitHub package to PUBLIC; anonymous GHCR pull is tested in the release workflow.'
  approve "Deploy this frontend image (only) to $AZ_RG/$AZ_APP using GitHub OIDC?"
  run_workflow 03-deploy.yml -f image_sha="$sha" >/dev/null
  check_app
  [[ "$(frontend)" == "$image" ]] || stop "Frontend was not updated to the expected image: $(frontend)"
  [[ "$(redis_image)" == "$before_redis" ]] || stop 'Redis sidecar image changed. Investigate immediately.'
  say 'PASS: frontend changed; Redis image preserved.'
}
verify(){
  base_checks; check_app
  local dir="$WORKSPACE/phase04-evidence/$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -p "$dir"
  az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query 'properties.template.containers[].{name:name,image:image}' -o json > "$dir/containers.json"
  az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query '{fqdn:properties.configuration.ingress.fqdn,revision:properties.latestRevisionName}' -o json > "$dir/endpoint.json"
  gh run list -R "$REPO" -L 15 --json databaseId,name,status,conclusion,headSha,url,workflowName > "$dir/actions.json"
  local fqdn http
  fqdn="$(az containerapp show -n "$AZ_APP" -g "$AZ_RG" --query properties.configuration.ingress.fqdn -o tsv)"
  [[ -n "$fqdn" && "$fqdn" != None ]] || stop 'No FQDN found on existing app.'
  http="$(curl -sS --location --max-time 30 --retry 3 --retry-delay 3 -o /dev/null -w '%{http_code}' "https://$fqdn/" || true)"
  printf 'HTTP_CODE=%s\nURL=https://%s/\n' "$http" "$fqdn" > "$dir/http.txt"
  cat > "$dir/REPORT_FR.md" <<EOF
# CloudGuard 360 — Phase 04 — Rapport de vérification

- Date (UTC) : $(date -u +%FT%TZ)
- Dépôt : https://github.com/$REPO
- Azure : $AZ_RG / $AZ_APP
- Frontend : $(frontend)
- Redis : $(redis_image)
- URL : https://$fqdn/
- Code HTTP : $http
- Résultats des workflows : actions.json
- Captures Azure : containers.json, endpoint.json

## Conditions de clôture
- [ ] CI réussie et test Docker de bout en bout réussi
- [ ] Scan secret/IaC bloquant réussi
- [ ] Rapport vulnérabilités consulté (rapport informatif, pas garantie d'absence de CVE)
- [ ] SBOM généré et artefact GitHub disponible
- [ ] Image GHCR publique et résolue par commit SHA
- [ ] OIDC GitHub vers Azure fonctionnel, sans secret client
- [ ] Image frontend mise à jour, image Redis inchangée
- [ ] HTTPS 200 constaté (ici : $http)
- [ ] Terraform Phase 03 réconcilié et plan vérifié
- [ ] Coûts Azure et droits GitHub revus
EOF
  say "Evidence saved at $dir"
  cat "$dir/http.txt"
  [[ "$http" == 200 ]] || stop 'HTTP test failed. Review Azure revisions and GitHub run logs.'
  say 'PASS: HTTPS 200. Review checklist and run reconcile for Terraform Phase 03.'
}
reconcile(){
  base_checks; check_app
  local tf3="$WORKSPACE/CloudGuard360_Phase03_Docker_Application/terraform"
  [[ -d "$tf3" ]] || stop "Phase 03 Terraform directory not present: $tf3. Locate it manually."
  [[ -f "$tf3/terraform.tfvars" ]] || stop 'Phase 03 terraform.tfvars missing. Do not invent a new state.'
  [[ -f "$tf3/terraform.tfstate" ]] || stop 'Phase 03 local terraform.tfstate missing. Confirm the actual backend/state before proceeding.'
  local image; image="$(frontend)"
  [[ "$image" == ghcr.io/*/cloudguard360-vote:* ]] || stop "Frontend is not the GHCR image expected: $image"
  say "Update Phase 03 local frontend_image to $image (no Azure apply)."
  approve 'Edit Phase 03 terraform.tfvars only, with a timestamped backup?'
  cp -p "$tf3/terraform.tfvars" "$tf3/terraform.tfvars.phase04-backup-$(date -u +%Y%m%d%H%M%S)"
  python3 "$ROOT/scripts/reconcile_tfvars.py" "$tf3/terraform.tfvars" "$image" || stop 'Could not safely update frontend_image.'
  say 'Running drift preview, never applying:'
  set +e
  ( cd "$tf3" && terraform plan -detailed-exitcode -input=false -no-color )
  local rc=$?
  set -e
  case "$rc" in
    0) say 'PASS: Phase 03 Terraform plan reports no drift.';;
    2) say 'REVIEW: Phase 03 Terraform still proposes changes. Inspect carefully, do not auto-apply.';;
    *) stop 'Terraform Phase 03 plan failed; investigate before any apply.';;
  esac
}
case "$OPERATION" in
  doctor) doctor;; prepare) prepare;; ci) ci;; identity) identity;;
  publish) publish;; deploy) deploy;; verify) verify;; reconcile) reconcile;;
  all)
    doctor
    prepare
    ci
    identity
    publish
    say "MANDATORY PAUSE: make GHCR image PUBLIC before Azure can pull it."
    approve 'I checked GHCR package visibility and GitHub environment settings; proceed?'
    deploy
    verify
    reconcile
    say 'PHASE 04 CHECKPOINTS COMPLETE — consult verification evidence and cost dashboard.';;
esac
