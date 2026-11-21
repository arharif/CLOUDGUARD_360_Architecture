# CloudGuard 360 — Phase 04 FINAL 2026

**A single, resumable DevSecOps laboratory** for Azure Voting App → GitHub Actions → Docker → GHCR → Entra OIDC → existing Azure Container Apps → evidence & Terraform reconciliation.

- Start with **[QUICK_START_FR.md](QUICK_START_FR.md)** or the fully offline **[index.html](index.html)**.
- Read **[GUIDE_COMPLET_FR.md](GUIDE_COMPLET_FR.md)** for every Azure Portal click, command, explanation, expected output, risk, and recovery.
- Run `bash automation/phase04.sh doctor --repo NabilNet/cloudguard360-phase04`, then `bash automation/phase04.sh all --repo NabilNet/cloudguard360-phase04` once prerequisites are ready.
- Optional offline validation: `python3 tests/test_package.py` (requires `PyYAML`, `beautifulsoup4`, `node` for full validation; not required to run Cloud Shell lab).

## Contents

| Folder / file | Meaning |
|---|---|
| `automation/phase04.sh` | Idempotent/restartable master orchestration; no force-push or destroy |
| `.github/workflows/` | Real OIDC `sub` verification, CI, GHCR image publish, manual Azure deploy |
| `terraform/oidc/` | Separate root and state for identity / federated trust / app-scoped role |
| `Dockerfile` | Modern Python container for official Azure Vote application code |
| `scripts/` | Safety checks for Terraform plan, real Azure app topology and tfvars reconciliation |
| `docs/` | Release runbook and French troubleshooting |
| `assets/` | PNG/SVG/Graphviz architecture diagrams |
| `index.html` | Responsive animated tutorial with live progress and copy buttons |
| `tests/test_package.py` | Offline tests that reject deletion and overbroad Azure RBAC scopes |

## Preflight assumptions

This phase is **not a new Azure deployment**. It requires the existing `rg-cg360-app/ca-cg360-voting` from Phase 03 with `vote-frontend` + `redis` and port 80 ingress. For full automation, operator needs `gh` GitHub admin/push rights, Azure identity creation and the `Microsoft.Authorization/roleAssignments/write` permission at the appropriate scope, plus outbound access from Cloud Shell to GitHub. Github and Azure quotas and permissions cannot be validated inside the downloadable package.

## Security boundaries

- No long-lived Azure client secret is created; OIDC subject is taken directly from the GitHub job token and **only the subject string** is logged.
- The Azure role is limited to **one existing Container App**, but the built-in Container Apps Contributor role can still permit destructive operations within that app.
- Push, identity Terraform apply, image publication and deployment have explicit operator approval.
- Trivy secret/IaC checks are blocking; CVE image scan is informative and requires review. This is **not production-hardened**.
- No operations modify Phase 01/02 Terraform State. Phase 03 tfvars is only reconciled after explicit approval, with a backup and non-applying Terraform plan.

Verified against public reference documentation (2026-11-21); offline tests are included. **No claim is made that the live Azure deployment is already finished.**
