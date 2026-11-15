# Approved release runbook — CloudGuard 360 Phase 04

## Prerequisite gates
1. Phase 03 app exists and `vote-frontend` is its exact container name.
2. GitHub Actions CI is green; base image is pullable.
3. Review and accept/remediate legacy image security findings; do not confuse a report-only scan with a security approval.
4. GHCR package is **public** and the image reference is correct. Use GitHub **Packages → [package] → Package settings → Change visibility**.
5. Optional deployment identity has OIDC subject `repo:OWNER/REPO:environment:cloudguard360-lab` and scoped access on the existing Container App.
6. GitHub environment `cloudguard360-lab` has required reviewers if your GitHub plan supports them.
7. Azure subscription credit/quotas are checked.

## Release flow
1. GitHub → Actions → `02 | Manual Release to Azure Container Apps` → Run workflow.
2. Select `deploy_to_azure=false` initially: only publish an image.
3. Make GHCR image public, confirm package path (no credentials in Azure for this route).
4. After OIDC and scoped access is ready, re-run workflow with `deploy_to_azure=true`.
5. Inspect workflow logs for the exact SHA image and HTTP smoke test.
6. Verify frontend `vote-frontend` image changed, Redis image did not.
7. Open Phase 03 Terraform root and reconcile `frontend_image` variable; review plan for unintended changes.

## Rollback
A rollback is a controlled release of a previously known-working image using the same `--container-name vote-frontend` targeted Azure CLI command. Record the prior image before each release. In Single revision mode, do not assume old revisions are still active or routable.

## Incident data
Record the Git commit, image digest, GitHub Actions run URL, deployment time, HTTP result, Azure revision name, assigned approver and post-change Terraform plan.
