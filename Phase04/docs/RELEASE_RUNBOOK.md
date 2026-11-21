# CloudGuard 360 — Release runbook

- This repository contains a vendored snapshot of the Microsoft Azure Voting App (exact commit recorded in `docs/UPSTREAM_COMMIT.txt`, original licence in `docs/UPSTREAM_LICENSE.txt`).
- Never commit Azure credentials, Terraform state, `.tfvars`, or GitHub CLI credential files.
- The CI job blocks secret/configuration risks and performs a real frontend + Redis HTTP smoke test.
- Image vulnerabilities are **reported, not blocked** and must be reviewed; a successful CI is not a production attestation.
- GitHub image published to `ghcr.io/<owner>/cloudguard360-vote:<full git SHA>`. GHCR package must be **public** before anonymous Azure pulls work. Public packages allow anonymous pulls, but do not use this pattern for internal apps.
- The GitHub Actions `cloudguard360-lab` environment must be configured in repository Settings → Environments. Apply main-branch restrictions and reviewers if available; deploy is always manual.
- GitHub OIDC `sub` is captured from a real token (only the non-secret claim), not constructed from a legacy repo-name format. New 2026 GitHub repositories use immutable IDs.
- Identity has **Container Apps Contributor** on the single existing Container App, which can include deletion; this is a teaching lab, not minimal production custom RBAC.
- Deployment updates only `vote-frontend`, with Redis container image comparison pre/post. It doesn't change application network or Terraform backend.
- After deployment, update the Phase 03 Terraform `frontend_image` variable and verify the drift plan before further Terraform applies. The automation does NOT run Terraform apply for Phase 03.
- Cost: running Azure resources and persistent Cloud Shell storage may cost money. Observe Cost Management and stop applications not in use.

## Recovery

If the new image is broken, open Azure Portal → Container Apps → `ca-cg360-voting` → Revisions and inspect the latest revision and logs. If the previous image is still available, a qualified operator may restore it using an approved `az containerapp update --container-name vote-frontend --image <previous-image>` command. Never blindly run Terraform apply to roll back.
