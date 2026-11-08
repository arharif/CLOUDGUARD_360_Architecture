# CloudGuard 360 — Phase 02 Masterclass

**English interactive course + Terraform + evidence toolkit**

Open **`index.html`** in a browser to use the **animated offline course** (sidebar navigation, code-copy buttons, lesson checklists and diagrams). Read **`terraform.md`** for the complete 9-subphase step-by-step course.

> **Important for returning learners:** Your already-deployed identity Terraform state is in the original project at `~/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform`. This ZIP intentionally does **not** contain or replace that state. Do not rerun a fresh identity root if your four groups and seven role assignments already exist.

## Contents

| Path | Contents |
|---|---|
| `index.html` | Animated offline interactive course |
| `terraform.md` | Fully detailed walkthrough, expected results, failures and verification |
| `assets/` | Four original PNG diagrams + SVG vector versions + DOT source |
| `templates/identity-rbac/` | Reference Terraform project for genuinely fresh environments only |
| `policy-audit/` | Independent Azure Policy audit Terraform root; OFF by default |
| `scripts/00-detect-workspace.sh` | Read-only existing state/workspace discovery |
| `scripts/06-policy-plan-guard.py` | Reject anything except one Audit policy creation on app RG |
| `scripts/07-collect-evidence.sh` | Read-only evidence collection into private persistent folder |
| `scripts/08-final-review.sh` | Final Terraform state validation |
| `docs/` | Evidence register template, verification matrix, authoritative sources and earlier detailed reference |

## First five safe commands (Cloud Shell Bash)

```bash
mountpoint -q "$HOME/clouddrive" && echo "Persistent mount OK"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Masterclass"
bash scripts/00-detect-workspace.sh
```

Read `terraform.md` **Subphase 00** for the exact click-by-click Cloud Shell upload instructions. Do not apply any Terraform until your actual plan is reviewed. The policy-audit stage is optional and requires Azure Policy assignment privileges.

## Verification performed on the downloadable package

The archive can be extracted without needing internet or a paid app. Shell scripts are syntax-checked and Python scripts compile; the policy plan guard has positive and negative fixture checks. These **do not** replace running `terraform init`, `terraform validate` or an actual Azure deployment in your subscription.

© Course material generated for instructional use. Azure/Entra service interfaces and pricing may change. See `docs/REFERENCES.md` for authoritative links.
