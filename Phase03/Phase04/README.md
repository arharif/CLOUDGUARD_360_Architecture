# CLOUDGUARD 360 — PHASE 04
## One complete practical lab: GitHub Actions, CI/CD, Docker, DevSecOps, GHCR and Azure Container Apps

> **Audience:** Azure/Terraform beginner who completed CloudGuard 360 Phases 01–03. **Language:** English. **Duration:** complete at your own pace. **Method:** one continuous, end-to-end phase with eight numbered steps. **Cost principle:** reuse Azure resources, deploy only if required, and never create AKS/ACR/VMs in this phase.

**Start:** open `index.html` locally for the animated, interactive course. This README and `terraform.md` give you all commands and explanations without the HTML interface.

**Important safety facts**
- Phase 01 owns two Resource Groups, VNets, subnets, NSG and peerings. DO NOT import, recreate or destroy them from this phase.
- Phase 02 owns Entra groups and RBAC role assignments. DO NOT duplicate them.
- Phase 03 owns `ca-cg360-voting` (containers `vote-frontend` and `redis`) in `rg-cg360-app`. Phase 04 deploys a new **frontend image** to that EXISTING resource; it does not provision the Container App again.
- The optional OIDC identity Terraform root provisions only **one managed identity, one federated credential, and an optional scoped role assignment**. It has its own state.
- The sample base image is legacy: Phase 04 **wraps a prebuilt Microsoft example image rather than compiling its source**. The vulnerability report is **informational**; secret and IaC checks are gating. This is a portfolio lab, **not a production security certification**.
- GitHub Container Registry packages are initially private in many accounts. For this public demo route, set the specific package public before Azure deployment. Never publish secrets, production code or real customer data.
- Your subscription may be geographically restricted; Phase 04 reuses the Phase 03 app's actual location and requires no new regional compute.

---

# 0. What you are building

```text
Developer / GitHub repository
        |
        | Push / pull request
        v
  GitHub Actions (CI)
        |-- repository validation
        |-- Trivy secrets and IaC scan (blocking)
        |-- Docker build from existing Phase 03 demo image
        |-- Trivy image scan (REPORT ONLY for legacy base)
        |-- CycloneDX Software Bill of Materials
        v
 GitHub Actions (manual release)
        |-- controlled publish to GHCR (git SHA tag)
        |-- optional approval via GitHub Environment
        |-- GitHub OIDC -> Azure managed identity
        v
Existing Azure Container App ca-cg360-voting
        |-- vote-frontend image -> GHCR version
        |-- redis sidecar remains unchanged
        v
HTTPS smoke test -> incident/evidence -> Terraform reconciliation
```

**Separation of duties:** GitHub packages/builds the image; Microsoft Entra authenticates the release workload; Azure RBAC authorises a specific container app operation; Terraform remains the source of truth for infrastructure.

**Definition of done:** CI is green, vulnerabilities are documented, a CycloneDX SBOM is stored as a GitHub Actions artifact, a GHCR image is tagged with the Git commit SHA, optional OIDC identity is validated, a reviewed release changes only the frontend image, HTTP succeeds, the Phase 03 Terraform plan is reconciled, and evidence is captured.

---

# Step 1 — Audit your Phase 03 application and Azure costs

## 1.1 Navigate through the Azure Portal
1. Open https://portal.azure.com and sign in with the account that deployed Phases 01–03.
2. Select **Subscriptions → Azure subscription 1** and verify state `Enabled`.
3. Navigate to **Cost Management + Billing → Cost Management → Cost analysis**, inspect usage and remaining Free Trial credit. A budget alert does not cap spending.
4. Select **Resource groups → rg-cg360-app → Overview**.
5. Select the **Container App** named `ca-cg360-voting` and open **Containers / Revisions**. Confirm the `vote-frontend` and `redis` container names.
6. Review its application URL, but do not change the configuration in the portal.

## 1.2 Azure Cloud Shell commands (Bash)

```bash
mountpoint -q "$HOME/clouddrive" && echo 'PASS: persistent storage' || echo 'STOP: Cloud Shell is ephemeral'
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
az account show --query '{Name:name,State:state}' --output table
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query 'properties.template.containers[].{Name:name,Image:image}' --output table
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query properties.configuration.ingress.fqdn --output tsv
```

**Expected:** the application exists and has **two containers**. If it does not exist, complete Phase 03 first; you can still run CI-only in Step 4 without Azure.

**Why this matters:** the application belongs to Phase 03 Terraform. We may update its frontend in Phase 04, but we must reconcile drift afterwards; otherwise a subsequent Phase 03 apply can revert the new image.

---

# Step 2 — Download the Phase 04 ZIP and prepare the folder

## 2.1 Download and upload
1. Download `CloudGuard360_Phase04.zip` from this chat to your computer.
2. In **Azure Portal**, click the terminal **Cloud Shell** icon, choose **Bash**.
3. Select **Manage files → Upload** and upload `CloudGuard360_Phase04.zip`.
4. Run the following commands:

```bash
mkdir -p "$HOME/clouddrive/cloudguard360"
ls -lh "$HOME/CloudGuard360_Phase04.zip"
unzip -n "$HOME/CloudGuard360_Phase04.zip" -d "$HOME/clouddrive/cloudguard360"
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass"
ls -la
bash scripts/00-preflight.sh
python3 scripts/validate_repo.py
```

If you downloaded the ZIP under another name, rename it before uploading or modify the file path. `unzip -n` prevents overwriting existing files on a rerun. **Never unzip over the Phase 01/02/03 Terraform root directories.**

## 2.2 Folder map

```text
CloudGuard360_Phase04_DevSecOps_Masterclass/
├── README.md                     ← This full lab
├── terraform.md                  ← GitHub-ready implementation manual
├── index.html                    ← Offline, animated UI
├── Dockerfile                    ← Wraps Phase 03 prebuilt demo image
├── .dockerignore, .gitignore
├── .github/workflows/
│   ├── 01-ci.yml                 ← On push/pull request
│   └── 02-release.yml            ← Manual publish / optional Azure deploy
├── terraform/oidc-identity/      ← SEPARATE Terraform state
├── scripts/                      ← Verification and evidence
├── docs/                         ← Architecture, release/rollback
├── assets/                       ← Architecture diagrams PNG/SVG
└── evidence/                     ← Local evidence, keep private
```

---

# Step 3 — Create your GitHub repository and upload the pipeline

## 3.1 Using the GitHub website
1. Open https://github.com/new and sign in.
2. Repository name: `cloudguard360-phase04`. Choose **Public** ONLY if the source contains no secrets or private company data; a public repository allows standard GitHub-hosted Actions usage without runner minutes charges. A private repository can also work, subject to your account usage allowances.
3. Optionally initialise with README and click **Create repository**.
4. Copy the new repository URL, e.g. `https://github.com/YOUR_USERNAME/cloudguard360-phase04`.
5. Go to **Settings → Actions → General** and verify Actions are allowed (do not enable unsafe third-party workflows in untrusted repositories).

**Important:** this package contains no app source code. It wraps the **prebuilt** Voting App from Phase 03. You do not have to fork or rebuild the original Python Flask application for this learning phase.

## 3.2 Recommended Cloud Shell Git method

```bash
# Check whether GitHub CLI is available; installation is NOT mandatory.
command -v gh || echo 'gh unavailable: GitHub web upload remains an option'

# Replace the placeholder with the actual HTTPS address of your repository.
GITHUB_REPO_URL="https://github.com/YOUR_USERNAME/cloudguard360-phase04.git"
cd "$HOME/clouddrive/cloudguard360"
git clone "$GITHUB_REPO_URL" cloudguard360-phase04-repo

# Copy only the files required by GitHub Actions from this package.
bash "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass/scripts/04-copy-to-repo.sh" \
  "$HOME/clouddrive/cloudguard360/cloudguard360-phase04-repo"
cd "$HOME/clouddrive/cloudguard360/cloudguard360-phase04-repo"
git status --short
python3 scripts/validate_repo.py
```

For a new empty repository, `git clone` may warn about an empty repository; this is normal.

## 3.3 Push to GitHub

```bash
git add Dockerfile .dockerignore .gitignore .github/workflows scripts/validate_repo.py docs/release-runbook.md
git commit -m "Add CloudGuard 360 Phase 04 CI and DevSecOps pipelines"
git branch -M main
git push -u origin main
```

GitHub no longer accepts account passwords for HTTPS pushes. If Git reports authentication failure, sign in using Git Credential Manager or `gh auth login` (if installed); follow the official browser flow, and never paste a Personal Access Token into this conversation or into your repository. If Git CLI authentication is blocked, use GitHub's web **Add file → Upload files** for ordinary files and **Add file → Create new file** with paths `.github/workflows/01-ci.yml` and `.github/workflows/02-release.yml`, copying content from the supplied package.

**Expected:** GitHub displays the `Dockerfile`, `.github/workflows/01-ci.yml` and `.github/workflows/02-release.yml` under the `main` branch.

---

# Step 4 — Execute CI and read the DevSecOps results

## 4.1 Navigate in GitHub
1. Open the repository → **Actions**.
2. Select `01 | Continuous Integration and DevSecOps`.
3. If the workflow did not start on push, select **Run workflow → main → Run workflow**.
4. Open the run and expand each step.

## 4.2 Understand the gates

| Check | Implementation | Enforcement |
|---|---|---|
| Folder layout | `python3 scripts/validate_repo.py` | **Blocking** |
| Shell script syntax | `bash -n scripts/*.sh` | **Blocking** |
| Secret and IaC scan | Trivy filesystem scan (`secret,misconfig`) | **Blocking on high/critical findings** |
| Docker build | Buildx wraps legacy voting frontend | **Blocking if build fails** |
| Container vulnerability scan | Trivy image (`vuln`) | **Report-only; no vulnerability gate** |
| Software Bill of Materials | Trivy CycloneDX JSON | Artifact uploaded for inspection |

**Critical realism:** The older Microsoft sample image may contain known vulnerabilities or may be unavailable on MCR. If the base image cannot be pulled, the Docker build will fail: do not describe CI as completed. Verify base-image availability and select an approved replacement that is compatible with the deployed application, then update the `Dockerfile` and document the change. The example is not production-hardened.

## 4.3 Verify CI success and SBOM
- A successful run shows green checks on validation/build/artifact steps.
- Click the run summary → **Artifacts** → download `phase04-sbom-<run-number>`.
- Open the JSON and note the components. **An SBOM is an inventory, not a guarantee of security.**
- Review high/critical vulnerability logs. Document findings rather than hiding them.

**Cost:** Standard GitHub-hosted runners for public repositories are generally free; private repositories consume plan-based included usage and may incur charges beyond it. See GitHub Billing documentation.

---

# Step 5 — Publish a versioned image to GHCR (no Azure deployment yet)

1. GitHub → **Actions → 02 | Manual Release to Azure Container Apps**.
2. Select **Run workflow** and choose `main`.
3. Set `deploy_to_azure` = **false** for the first run.
4. Click **Run workflow**.
5. Watch the `publish` job: repository scan → GHCR login → Docker build/push.
6. The log prints a path similar to `ghcr.io/YOUR_USERNAME/cloudguard360-vote:FULL_GIT_SHA`.

GitHub supplies a repository-scoped `GITHUB_TOKEN` to the workflow. No Personal Access Token or Azure service principal password is required for publishing this repo's GHCR package.

## 5.1 Make only your demo package public

By default a new GHCR container package is often private. For the credential-free Azure demo deployment:
1. Open your GitHub profile → **Packages** → select `cloudguard360-vote`.
2. Select **Package settings → Change visibility → Public** (the exact layout can vary).
3. Confirm public visibility and verify the image reference used in the publish log.
4. DO NOT make unrelated packages public. A public image exposes its contents.

Azure Container Apps must be configured for registry `ghcr.io` even for the public-image route in current Microsoft guidance; the release workflow handles `az containerapp registry set`.

---

# Step 6 — Configure passwordless GitHub → Azure access with Terraform (optional but recommended)

This step changes Azure access control. It requires the necessary Azure permissions. If you cannot grant roles, continue with CI + GHCR publishing and stop before Azure deployment.

## 6.1 Register the identity provider if needed

```bash
az provider show --namespace Microsoft.ManagedIdentity --query registrationState -o tsv
# Only if NotRegistered and you are authorised:
# az provider register --namespace Microsoft.ManagedIdentity --wait --output none
```

## 6.2 Open the independent Terraform identity root

```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass/terraform/oidc-identity"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
cp -n terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Change:

```hcl
github_repository       = "YOUR_USERNAME/cloudguard360-phase04"
github_environment      = "cloudguard360-lab"
resource_group_name     = "rg-cg360-app"
container_app_name      = "ca-cg360-voting"
enable_deployment_role  = false
```

**Do not write tokens or secrets in `terraform.tfvars`.** The GitHub repo must be named exactly as in the federated subject; case and environment matter. The identity will be created in the same region as your existing Container App, avoiding Phase 01's restricted `westeurope` region issue.

## 6.3 First Terraform plan: identity + federation only

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=phase04-oidc.tfplan
terraform show -no-color phase04-oidc.tfplan | grep -E 'will be created|Plan:'
terraform show -json phase04-oidc.tfplan | python3 ../../scripts/05-check-oidc-plan.py
```

**Expected:** 2 to add, 0 to change, 0 to destroy: user-assigned identity and federated identity credential. Apply only after reviewing the plan and verifying resource names and OIDC trust subject:

```bash
terraform apply phase04-oidc.tfplan
terraform output -raw github_azure_client_id
terraform output federated_subject
```

The Azure Client ID is not itself a password, but still treat identity configuration carefully.

## 6.4 Restrict the deployment role to the existing Container App

In `terraform.tfvars`, change only:

```hcl
enable_deployment_role = true
```

Prepare a new plan:

```bash
terraform plan -out=phase04-access.tfplan
terraform show -no-color phase04-access.tfplan | grep -E 'will be created|Plan:'
terraform show -json phase04-access.tfplan | python3 ../../scripts/05-check-oidc-plan.py
```

**Expected:** 1 role assignment created, at the exact Container App resource scope, using built-in `Container Apps Contributor`. This role **can update and delete Container Apps**, so it is not a read-only role; restrict it to the existing app and use approval gates. Role creation requires `Microsoft.Authorization/roleAssignments/write` at the appropriate scope. If you do not have those rights, request authorised help; do not escalate privileges yourself.

After review:

```bash
terraform apply phase04-access.tfplan
```

## 6.5 Configure GitHub Environment and OIDC secrets

1. GitHub repo → **Settings → Environments → New environment** → name **`cloudguard360-lab`**.
2. Configure required reviewers if supported by your GitHub plan. Environment protection availability varies with repository visibility and plan.
3. Inside this environment → **Environment secrets** → add exactly:
   - `AZURE_CLIENT_ID`: Terraform output `github_azure_client_id`
   - `AZURE_TENANT_ID`: `az account show --query tenantId -o tsv`
   - `AZURE_SUBSCRIPTION_ID`: `az account show --query id -o tsv`
4. Never create `AZURE_CLIENT_SECRET` for this workflow; `azure/login@v2` uses OIDC trust.
5. Confirm the federated subject corresponds to `repo:YOUR_USERNAME/cloudguard360-phase04:environment:cloudguard360-lab`.

**Note:** If the repo name or environment is different, OIDC sign-in will fail even if the Client ID is correct.

---

# Step 7 — Controlled Azure release and verification

## 7.1 Deploy the published GHCR image

1. Ensure the GHCR image is public (Step 5).
2. Ensure the managed identity, federation, scoped role and Environment secrets are configured (Step 6).
3. GitHub → **Actions → 02 | Manual Release to Azure Container Apps → Run workflow**.
4. Choose `main` and select `deploy_to_azure = true`.
5. Click **Run workflow**, then approve the Environment deployment if a reviewer gate is configured.
6. The workflow publishes a commit-SHA image, signs in using Azure OIDC, configures `ghcr.io` registry access and updates the **`vote-frontend` container only**.
7. It runs an HTTPS health check on the Container App URL.

If Azure login fails with `AADSTS70021` or similar, check issuer, subject, audience, repo, environment, tenant and deployment permissions. **Do not disable Microsoft Entra security defaults.**

## 7.2 Verify from Cloud Shell

```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass"
bash scripts/01-check-deployment.sh
```

You should see the updated `vote-frontend` image with a `ghcr.io/...:<commit-sha>` tag and Redis still on `redis:7-alpine`. HTTP result should be 200. Zero minimum replicas can introduce a cold start.

## 7.3 Reconcile Terraform ownership (mandatory governance)

**The Phase 03 Terraform root still owns the Container App.** An external `az containerapp update` changes its template and can cause Terraform drift. Never run the old Phase 03 `terraform apply` without reviewing the plan.

```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform"
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
terraform plan -detailed-exitcode -no-color > phase03-drift-review.txt 2>&1
RESULT=$?
echo "Terraform detailed exit code: $RESULT (0=no change, 2=change, 1=error)"
grep -E 'frontend_image|image|registry|Plan:' phase03-drift-review.txt || true
```

If the result shows that Terraform wants to revert the frontend image to MCR, edit `terraform.tfvars` (the Phase 03 config) and set:

```hcl
frontend_image = "ghcr.io/YOUR_USERNAME/cloudguard360-vote:FULL_GIT_SHA"
```

Review a new `terraform plan` **carefully**. The GHCR registry configuration added during release may also appear as drift. Do not approve unexpected replacement, deletion or networking changes. Keep the Phase 03 Terraform code/state aligned with actual Azure resources before another infrastructure deployment. In an advanced architecture, Terraform manages the application deployment model end-to-end, rather than letting a separate tool make unmanaged changes; the reconciliation exercise teaches the limitation explicitly.

## 7.4 Rollback if your deployment fails

Before each release, write down the previous known-working frontend image. A controlled rollback is:

```bash
# EDIT to a real, previously working image; do not run with the placeholder.
PREVIOUS_IMAGE="REPLACE_WITH_PREVIOUS_KNOWN_GOOD_IMAGE"
# az containerapp update -g rg-cg360-app -n ca-cg360-voting \
#   --container-name vote-frontend --image "$PREVIOUS_IMAGE"
```

The rollback command is intentionally commented out to prevent accidental changes. **Never** delete/recreate the Phase 03 Resource Group. Redis data is temporary; do not use this approach for production stateful data.

---

# Step 8 — Security evidence, negative test, cost control and final sign-off

## 8.1 Security evidence

```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase04_DevSecOps_Masterclass"
bash scripts/02-report-evidence.sh
```

Record in the evidence checklist: GitHub Actions run URL, CI status, Trivy findings, SBOM artifact, GHCR image tag, OIDC subject, reviewer approval, Azure revision name and HTTP smoke result. Keep this folder private or redact identifiers before publication.

## 8.2 Demonstrate a security gate safely

In a temporary Git branch or pull request **only**, intentionally introduce a benign IaC misconfiguration or harmless invalid project layout (e.g. temporarily rename the `Dockerfile` in a branch). Confirm that CI refuses to pass, then revert the change. **Do not commit passwords or real-looking secrets into Git**, even for a demo.

## 8.3 Final checks
- ✅ CI passes when the repository is valid.
- ✅ Trivy secret/misconfiguration gate has been exercised.
- ✅ Vulnerability findings are **reported**, and high-risk legacy dependencies are acknowledged.
- ✅ CycloneDX SBOM exists.
- ✅ GHCR image is accessible as intended.
- ✅ Optional OIDC login works without client secret.
- ✅ Deployment changes **only** `vote-frontend`, not Redis or the network.
- ✅ HTTP response is successful.
- ✅ Terraform image drift is reviewed and reconciled.
- ✅ Budget is checked; unused Azure resources are removed **from their owning Terraform roots only**.

**Conclusion:** This phase teaches an audited, human-controlled delivery chain for a prebuilt application, not a production-ready software supply chain. Phase 05 will use Kubernetes/AKS after a cost and quota check.

---

# Quick troubleshooting matrix

| Symptom | Likely cause | Safe next action |
|---|---|---|
| `No such file or directory` in Cloud Shell | ZIP or project folder path differs | `pwd`, `ls -la`, check uploaded ZIP name |
| `terraform init` cannot authenticate | Subscription env variable absent | `export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"` |
| `docker: command not found` | Cloud Shell is not a Docker host | Use GitHub Actions Docker runner or local Docker Desktop |
| GitHub push asks for a password | GitHub does not support password authentication for Git HTTPS | Use supported browser-based credential flow or web editor |
| `docker build` cannot pull MCR base | Prebuilt sample unavailable or network issue | Verify base, document replacement; don't pretend release succeeded |
| Trivy CI blocked | Real secret or HIGH/CRITICAL IaC finding | Inspect and fix; don't disable gate just to obtain green check |
| Image scan reports vulnerabilities | Legacy sample base | Document as known risk; use a modern supported base for real production |
| GHCR push permission denied | Packages write permission or package not linked to repo | Check Actions token permissions and package Actions access |
| GHCR image pull returns 401 | Package private or wrong path; registry config missing | Set intended demo package public, verify URL, configure registry |
| Azure OIDC `AADSTS70021` | Federated credential mismatch | Verify exact repo/environment/issuer/audience/client ID |
| Role assignment `AuthorizationFailed` | No roleAssignments/write | Request authorised scope-limited grant; never self-escalate |
| Azure 403 region unavailable | Subscription location restriction | Reuse Phase 03 Container App; identity region is derived from existing app |
| Azure deployment updates the wrong container | Wrong container name or CLI extension | Use `--container-name vote-frontend`, inspect two-container list beforehand |
| New image appears then disappears | Phase 03 Terraform applied old frontend image | Reconcile Phase 03 config and state; inspect plans before apply |
| HTTP 503 after release | Revision startup/image pull or cold-start | Inspect revision state and container logs; rollback to known-good image if needed |
| Cost concern | Persistent ACA workload or network data usage | Review Cost Analysis, min replicas and optional release; do not provision AKS |

---

# Authoritative references (verified November 2026)
- GitHub sample: https://github.com/Azure-Samples/azure-voting-app-redis
- Azure CLI Container App update: https://learn.microsoft.com/en-us/cli/azure/containerapp?view=azure-cli-latest
- Azure Container Apps GitHub Actions, GHCR: https://learn.microsoft.com/en-us/azure/container-apps/github-actions
- Azure OIDC: https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect
- Container Apps Contributor role: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/containers
- GitHub Container Registry: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- GitHub Actions billing: https://docs.github.com/en/actions/concepts/billing-and-usage
- Terraform drift: https://learn.microsoft.com/en-us/azure/developer/terraform/prevent-terraform-drift-stateful-resources

**Privacy:** Never paste GitHub tokens, subscription/tenant full IDs, Azure access tokens, service account credentials or Terraform state files into chats or GitHub issues.
