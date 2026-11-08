# CLOUDGUARD 360 — PHASE 02
## Microsoft Entra ID, Azure RBAC & Identity Governance with Terraform

**Complete hands-on guide · English · Cloud Shell Bash · Azure Free Trial-conscious · Version 1.0 (November 2026)**

> **Current starting point:** You already completed Phase 01: `rg-cg360-network`, `rg-cg360-app`, Hub/Spoke VNets, three subnets, NSG and bidirectional peerings. **Do not recreate the Phase 01 infrastructure.** This Phase 02 package has its own Terraform root and state.
>
> **Important:** The diagrams below are accurate **conceptual schematics**, not fabricated Azure Portal screenshots. Portal labels may differ slightly based on UI changes or tenant settings.

![Phase 02 identity architecture](assets/01-identity-architecture.png)

### Learning outcomes
By the end, you should be able to explain authentication vs authorization; Microsoft Entra directory roles vs Azure RBAC; security groups, resource-group scopes, inheritance, Reader vs Contributor; Terraform `azuread` and `azurerm` providers; create/read/verify role assignments; evidence collection, least privilege, drift, and secure cleanup.

### Contents
1. [Read this before you start](#1-read-this-before-you-start)
2. [Understand the identity architecture](#2-understand-the-identity-architecture)
3. [Verify Phase 01 is really complete](#3-verify-phase-01-is-really-complete)
4. [Navigate the Azure and Entra portals](#4-navigate-the-azure-and-entra-portals)
5. [Download and upload the ZIP into Cloud Shell](#5-download-and-upload-the-zip-into-cloud-shell)
6. [Understand your Phase 02 project folder](#6-understand-your-phase-02-project-folder)
7. [Authenticate and run a read-only access audit](#7-authenticate-and-run-a-read-only-access-audit)
8. [Check directory and RBAC prerequisites](#8-check-directory-and-rbac-prerequisites)
9. [Release A: create four Entra security groups](#9-release-a-create-four-entra-security-groups)
10. [Verify groups in the portal and CLI](#10-verify-groups-in-the-portal-and-cli)
11. [Release B: add least-privilege Azure RBAC](#11-release-b-add-least-privilege-azure-rbac)
12. [Verify permissions and perform a controlled test](#12-verify-permissions-and-perform-a-controlled-test)
13. [Optional: use an authorised test user](#13-optional-use-an-authorised-test-user)
14. [Understand Terraform state and drift](#14-understand-terraform-state-and-drift)
15. [Free-trial costs and security checkpoints](#15-free-trial-costs-and-security-checkpoints)
16. [Troubleshooting playbook](#16-troubleshooting-playbook)
17. [Controlled cleanup and next phase](#17-controlled-cleanup-and-next-phase)
18. [Acceptance criteria and interview questions](#18-acceptance-criteria-and-interview-questions)
19. [Authoritative documentation](#19-authoritative-documentation)

---

## 1. Read this before you start

### 1.1 Your starting situation
You are using **Azure Cloud Shell (Bash)** with Terraform and Azure CLI. You reconfigured Cloud Shell with a persistent `~/clouddrive` mount, fixed an `ARM_SUBSCRIPTION_ID` error, registered `Microsoft.Network`, recovered from a `westeurope` region restriction, and successfully deployed the Phase 01 network.

The new folder intentionally **does not contain** any `azurerm_virtual_network`, `azurerm_subnet`, `azurerm_network_security_group` or Resource Group *resource* declarations. Instead, it uses `data "azurerm_resource_group"` to look up existing groups without taking ownership of their lifecycle. The new Terraform state will cover only Phase 02 groups and RBAC grants.

### 1.2 Cost and permissions checkpoint
- Microsoft Entra security groups and Azure RBAC role assignments generally do **not** incur a separate per-assignment resource charge under the basic free-tier capability used here; availability is tenant-dependent. **Do not enable Entra P1/P2 trials, PIM or create VMs to complete Phase 02.**
- Cloud Shell's backing Azure Files share may incur charges. Use your subscription cost dashboard.
- Creating Entra groups requires Microsoft Graph directory permissions. **Owning an Azure subscription does not imply Entra Global Administrator or Group Administrator permissions.**
- Creating Azure role assignments requires `Microsoft.Authorization/roleAssignments/write` at the chosen resource-group scope or an ancestor; Owner or Role Based Access Control Administrator can have it, whereas Contributor normally does not.
- Security defaults should stay enabled. **Do not disable MFA or Security Defaults as a shortcut.**
- Do not publish subscription IDs, tenant IDs, access tokens, `.tfstate`, `terraform.tfvars` or raw personal details in a public repository.

### 1.3 Zero-trust habit
For every identity, ask: **Who is it? What can it do? On which resources? Why is that access required? How can I prove it?**

---

## 2. Understand the identity architecture

![Scope inheritance diagram](assets/02-rbac-scopes.png)

| Concept | Meaning | CloudGuard 360 example |
|---|---|---|
| Authentication | Confirm who signed in | Entra ID validates your account |
| Authorization | Decide permitted operations | RBAC grants Reader on an RG |
| Principal | User, security group, service principal or managed identity | `CG360-Security-Auditors` |
| Role | Set of permissions | Reader, Monitoring Reader, Contributor |
| Scope | Where the role applies | `rg-cg360-app`, not the entire subscription |
| Role assignment | One principal + one role + one scope | Auditors + Reader + App RG |
| Inheritance | Children inherit higher-scope assignments | Subscription-level Owner can affect RGs |
| Directory role | Administration *inside Entra* | Groups Administrator (not the same as Azure RBAC) |

**Example:** A person assigned Reader on the application RG can inspect applicable management-plane resources but cannot change a VNet configuration using that role alone. They could still possess **other, inherited** permissions. Azure RBAC Reader is also **not** an application-data authorization system or an automatic grant to read secrets in Key Vault.

### 2.1 What this Terraform project manages
Four **security groups**:
1. `CG360-Cloud-Engineers`
2. `CG360-Developers`
3. `CG360-Security-Auditors`
4. `CG360-Operations`

The role assignments are a **separate second release**. Default values set `enable_role_assignments=false` and `enable_app_contributor=false`. There are **seven default read-only assignments** when enabled:

| Security group | Role | Scope |
|---|---|---|
| Cloud Engineers | Reader | Network RG |
| Cloud Engineers | Reader | App RG |
| Developers | Reader | App RG |
| Security Auditors | Reader | Network RG |
| Security Auditors | Reader | App RG |
| Operations | Monitoring Reader | Network RG |
| Operations | Monitoring Reader | App RG |

You may later explore an **explicit** Contributor assignment for Cloud Engineers on **only** the application RG, but it is **not part of the recommended baseline** and is blocked by the plan guard unless you deliberately override and review it.

![Terraform release flow](assets/03-terraform-process.png)

---

## 3. Verify Phase 01 is really complete

### 3.1 Open the existing Azure Portal
1. On your computer, open a browser and visit **https://portal.azure.com/**.
2. Sign in with the Azure account you used for Phase 01.
3. In the search bar at the top, enter **Resource groups**. Click the matching service.
4. Verify that **`rg-cg360-network`** and **`rg-cg360-app`** both appear.
5. Click **`rg-cg360-network` → Resources** and find your Hub VNet.
6. Click **`rg-cg360-app` → Resources** and find your application Spoke VNet and NSG.
7. Return to the portal home. Open **Cloud Shell** using the terminal icon in the top toolbar. Select **Bash**.

### 3.2 Run the verification commands
```bash
# Read-only: confirm active subscription without printing IDs
az account show --query '{Name:name,State:state}' -o table

# Read-only: verify the two Phase 01 resource groups
az group show -n rg-cg360-network --query '{Name:name,Location:location}' -o table
az group show -n rg-cg360-app --query '{Name:name,Location:location}' -o table

# Read-only: verify peering status (if Phase 01 kept these names)
az network vnet peering list -g rg-cg360-network \
  --vnet-name vnet-cg360-hub \
  --query '[].{Name:name,State:peeringState}' -o table
```

**Expected:** both Resource Groups exist; the Hub peering reports `Connected`. **Do not assume** the original `westeurope` region is still in use: after your successful recovery the actual region may have changed.

### 3.3 Check Cloud Shell persistence
```bash
mountpoint -q "$HOME/clouddrive" \
  && echo 'PASS: clouddrive mounted' \
  || echo 'STOP: clouddrive not mounted'
```

**STOP** if `clouddrive` is not mounted. State stored in an ephemeral Cloud Shell location may be lost.

---

## 4. Navigate the Azure and Entra portals

![Portal navigation map](assets/04-portal-navigation.png)

### 4.1 Find Azure RBAC role assignments
1. Open **https://portal.azure.com/**.
2. Search **Resource groups** and open `rg-cg360-app`.
3. From the left menu, click **Access control (IAM)**.
4. Choose **Role assignments**. This shows direct and inherited grants available in the UI.
5. Optionally select **Check access**, choose your current account, and review your effective access.
6. Repeat for `rg-cg360-network`.

**Important:** do not click **Add role assignment** to manually create our test grants; we want Terraform to manage them. Use the portal to **inspect** results.

### 4.2 Find Entra security groups
1. Open a separate tab: **https://entra.microsoft.com/**.
2. Confirm the selected directory/tenant matches the one holding your Azure subscription.
3. From the side menu choose **Identity → Groups → All groups** (wording may vary).
4. Observe any existing security groups, and search for `CG360-`.
5. Under **Identity → Users → All users**, inspect whether you have any legitimate test account you are authorised to use.
6. Review **Roles & admins** only to understand directory permissions; no changes required.

**Expected before Phase 02 creation:** no groups of our four specific names. If the names already exist, use the troubleshooting and import instructions rather than creating duplicates.

### 4.3 Find cost management
Azure Portal → **Cost Management + Billing** → choose subscription/billing scope → **Cost analysis** and **Budgets**. Do not assume that a budget alert will stop charges.

---

## 5. Download and upload the ZIP into Cloud Shell

This section is written for someone using only the Azure Portal and Cloud Shell — no local Terraform installation required.

### 5.1 Download the course ZIP
1. In this ChatGPT conversation, click **Download: CloudGuard360_Phase02_Identity_RBAC.zip**.
2. Your browser downloads the ZIP, generally into **Downloads**. If you don't see it, use your browser downloads menu (`Ctrl + J` on Windows).
3. **Do not open or upload the ZIP to a public website.** Keep it on your computer until import into Azure Cloud Shell.

### 5.2 Upload into Cloud Shell
1. Return to **https://portal.azure.com/**.
2. Open **Cloud Shell → Bash**.
3. In the Cloud Shell toolbar open **Manage files → Upload** (the exact label may vary).
4. Click **Choose file**, browse to your computer's **Downloads** folder.
5. Select `CloudGuard360_Phase02_Identity_RBAC.zip`, then complete the upload.
6. In Bash, confirm the ZIP was uploaded into your home folder:
```bash
ls -lh "$HOME/CloudGuard360_Phase02_Identity_RBAC.zip"
```

**Expected:** a file line showing the ZIP and its size. If it says **No such file**, run `find "$HOME" -maxdepth 2 -name 'CloudGuard360_Phase02_Identity_RBAC.zip' -print` to locate it; use the discovered path below.

### 5.3 Extract into persistent storage
```bash
# Create a parent directory on mounted persistent storage
mkdir -p "$HOME/clouddrive/cloudguard360"

# Extract the ZIP: it contains one top-level Phase 02 folder
unzip -o "$HOME/CloudGuard360_Phase02_Identity_RBAC.zip" \
  -d "$HOME/clouddrive/cloudguard360"

# Enter ONLY the Phase 02 Terraform root
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform"

# Inspect files
pwd
ls -la
```

**Expected:** `main.tf`, `rbac.tf`, `versions.tf`, `providers.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `.gitignore`.

> **CRITICAL:** Phase 01 project: `.../cloudguard360_terraform_starter` (your VNets). Phase 02 project: `.../CloudGuard360_Phase02_Identity_RBAC/terraform` (your Entra groups and RBAC). **Never run Phase 02 apply from Phase 01 root.**

---

## 6. Understand your Phase 02 project folder

```text
CloudGuard360_Phase02_Identity_RBAC/
├── README.md                    Start here
├── terraform.md                 Full illustrated guide
├── index.html                   Animated offline HTML course
├── assets/                      Four PNG + SVG diagrams and sources
│   ├── 01-identity-architecture.png
│   ├── 02-rbac-scopes.png
│   ├── 03-terraform-process.png
│   └── 04-portal-navigation.png
├── terraform/                   Separate Terraform root and state
│   ├── versions.tf              AzureRM 4.x + AzureAD 3.x
│   ├── providers.tf             Uses Azure CLI login
│   ├── variables.tf             Variables and safety flags
│   ├── main.tf                  Looks up existing RGs; creates groups
│   ├── rbac.tf                  Seven OPTIONAL RBAC grants
│   ├── outputs.tf               Safe summary outputs
│   ├── terraform.tfvars.example Configuration example
│   └── .gitignore               State/plan files excluded from Git
├── scripts/
│   ├── preflight.sh             Checks mount and Azure context
│   ├── audit.sh                 Read-only IAM inventory
│   ├── verify_groups.sh         Check four Entra groups
│   ├── verify_rbac.sh           Check group role assignments
│   ├── check_plan.py            Rejects destructive/unexpected plan
│   └── checks.sh                Formatting and validation
└── evidence/                    Local assessment notes (not public)
```

**Terraform semantics:** `resource` creates/manages something; `data` reads an existing object. This project uses **`data.azurerm_resource_group`** for Phase 01 groups. The `azuread_group.lab` resource creates the new security groups. The `azurerm_role_assignment.lab` resource creates **only** the grants you explicitly enable. The two providers act against different planes: `azuread` manages the Entra tenant directory, and `azurerm` manages Azure resource authorization.

---

## 7. Authenticate and run a read-only access audit

### 7.1 Set context in Cloud Shell Bash
```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform"

# Cloud Shell normally already has an authenticated Azure CLI session.
# Do NOT run az login again unless the current account is genuinely wrong.
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"

# Print the name/status without revealing identifiers
az account show --query '{Name:name,State:state}' -o table
```

**Why:** AzureRM 4.x requires an explicit subscription ID. AzureAD operates on the tenant. Environment variables are valid for the current Bash session; repeat this after reopening Cloud Shell.

### 7.2 Run preflight and audit
```bash
bash ../scripts/preflight.sh
bash ../scripts/audit.sh
```

**Expected:** active subscription; both Resource Groups found; existing role assignment information printed. If preflight shows a Microsoft Graph warning, the user might have insufficient directory permissions. It does not automatically mean Azure RBAC is broken.

### 7.3 Inspect role assignment scope directly
```bash
APP_SCOPE="$(az group show -n rg-cg360-app --query id -o tsv)"
NET_SCOPE="$(az group show -n rg-cg360-network --query id -o tsv)"

az role assignment list --scope "$APP_SCOPE" --include-inherited \
  --query '[].{Role:roleDefinitionName,Scope:scope}' -o table

az role assignment list --scope "$NET_SCOPE" --include-inherited \
  --query '[].{Role:roleDefinitionName,Scope:scope}' -o table
```

**Interpretation:** an Owner inherited from the subscription could still affect these groups. Do not confuse `--include-inherited` results with assignments created directly by Phase 02.

---

## 8. Check directory and RBAC prerequisites

### 8.1 Entra group creation
The logged-in identity must be allowed to create security groups in this tenant. The tenant administrator can restrict the ability of members to create security groups. A Groups Administrator or appropriately authorised principal can manage group operations. Terraform `azuread_group` uses Microsoft Graph, and an app/service-principal authentication path may require delegated/admin-consented Graph permissions such as `Group.ReadWrite.All` as appropriate for the selected authentication model.

Check whether the CLI can list relevant groups:
```bash
az ad group list \
  --filter "startswith(displayName,'CG360-')" \
  --query '[].{Name:displayName}' -o table
```

**Expected:** an empty table on a new lab, or an existing group list. **Do not create duplicates.** Note that successful listing is a useful read check but **does not prove** you can create groups.

### 8.2 Azure role assignment creation
**You need a role with `Microsoft.Authorization/roleAssignments/write`** on each target RG (or inherited). `Contributor` by itself does not grant this. If you lack these rights, you can still complete group creation, read-only auditing, and learning exercises; an authorised subscription administrator must enable/approve the RBAC stage. No privilege bypass is appropriate.

Azure Portal → **Resource groups → rg-cg360-app → Access control (IAM) → Check access** is a helpful way to inspect your effective roles. Repeat for `rg-cg360-network`.

### 8.3 IMPORTANT: keep Security Defaults enabled
Earlier you encountered `AADSTS530035` due to a device-code login blocked by Entra Security Defaults. This guide uses your **existing authenticated Cloud Shell session** and **does not instruct you to disable Security Defaults**.

---

## 9. Release A: create four Entra security groups

This release deliberately **does not create any Azure RBAC assignment**. Group creation changes your Entra directory but does not grant resource permissions while groups remain empty and unassigned.

### 9.1 Copy the configuration example
```bash
cd "$HOME/clouddrive/cloudguard360/CloudGuard360_Phase02_Identity_RBAC/terraform"
cp -n terraform.tfvars.example terraform.tfvars
cat terraform.tfvars
```

Your initial settings should include:
```hcl
enable_role_assignments = false
enable_app_contributor   = false
demo_member_object_id   = ""
```

Never store secrets or tokens in `.tfvars`. The example intentionally includes no user object IDs.

### 9.2 Read the code before running it
```bash
cat versions.tf
cat providers.tf
cat main.tf
cat rbac.tf
```

Check especially that **`main.tf` reads** your Phase 01 resource groups with `data`, not `resource`. Check `rbac.tf` uses `enable_role_assignments` to keep all assignments off during Release A.

### 9.3 Initialize and validate
```bash
terraform fmt -recursive
terraform init
terraform validate
```

**Expected:** `Terraform has been successfully initialized!` and `Success! The configuration is valid.` This does **not** prove directory group creation is authorised; that is checked when Terraform plans/applies against Microsoft Graph.

### 9.4 Create and carefully review a saved plan
```bash
terraform plan -out=phase02.tfplan
terraform show -no-color phase02.tfplan | grep 'will be created'
terraform show -json phase02.tfplan | python3 ../scripts/check_plan.py
```

**Expected for a new tenant without these names:** `Plan: 4 to add, 0 to change, 0 to destroy.` Resource addresses should be `azuread_group.lab["..."]`. Plan guard should print `PLAN PASS`. If any Resource Group, VNet, subnet, NSG, VM or AKS object is planned for change, **STOP**.

**Safety:** `terraform plan -out` saves the plan, potentially including sensitive information. Keep the file within the persistent private workspace, never GitHub.

### 9.5 Apply Release A
Only after you have reviewed the actual plan and confirmed you are authorised to create Entra groups:
```bash
terraform apply phase02.tfplan
```

**Expected:** `Apply complete! Resources: 4 added, 0 changed, 0 destroyed.` If it fails with `403 Authorization_RequestDenied`, do not try to bypass it; consult troubleshooting and tenant admin permissions.

### 9.6 Inspect the new Phase 02 state
```bash
terraform state list
terraform output security_group_names
terraform output rbac_assignment_count
```

**Expected:** four `azuread_group.lab[...]` resources, the four names, and `rbac_assignment_count = 0`. **This is separate from your existing Phase 01 state containing 11 network resources.**

---

## 10. Verify groups in the portal and CLI

### 10.1 Microsoft Entra Admin Center
1. Open **https://entra.microsoft.com/**.
2. Choose your subscription's **directory/tenant**.
3. Navigate **Identity → Groups → All groups**.
4. Search for `CG360-`.
5. Confirm the four names exist, and each has **Group type: Security**.
6. Open `CG360-Developers` → **Members**: it will usually be empty until a membership is added. Empty group membership is expected and safer for the initial exercise.

### 10.2 Azure CLI verification
```bash
bash ../scripts/verify_groups.sh
```

Or manually:
```bash
az ad group show --group 'CG360-Developers' \
  --query '{Name:displayName,SecurityGroup:securityEnabled}' -o table
```

**Expected:** `CG360-Developers`, `True`. If the portal lags behind the CLI, allow time for propagation and refresh.

---

## 11. Release B: add least-privilege Azure RBAC

**Prerequisite:** Release A has completed and your account is authorised to create role assignments. A security-group membership does not automatically grant access; a **role assignment** supplies permissions for a scope.

### 11.1 Enable only read-only roles
Open the config in Cloud Shell:
```bash
nano terraform.tfvars
```

Change only:
```hcl
enable_role_assignments = true
```

Keep these values:
```hcl
enable_app_contributor = false
demo_member_object_id = ""
```

Save Nano using `Ctrl + O`, Enter, then `Ctrl + X`.

### 11.2 Inspect and save the new plan
```bash
terraform fmt -check
terraform validate
terraform plan -out=phase02-rbac.tfplan
terraform show -no-color phase02-rbac.tfplan | grep 'will be created'
terraform show -json phase02-rbac.tfplan | python3 ../scripts/check_plan.py
```

**Expected:** `Plan: 7 to add, 0 to change, 0 to destroy.` They should all be `azurerm_role_assignment.lab[...]` with roles Reader or Monitoring Reader at the two existing RG scopes. Confirm **there is no subscription-scoped Owner or Contributor assignment**. 

**If this plan proposes replacing groups or changing Phase 01 resources: STOP and investigate before apply.**

### 11.3 Apply after scope review
```bash
terraform apply phase02-rbac.tfplan
```

**Expected:** `Apply complete! Resources: 7 added, 0 changed, 0 destroyed.` This requires `roleAssignments/write`. A `403 AuthorizationFailed` usually means permissions are insufficient, even if you have Contributor.

### 11.4 Confirm state counts
```bash
terraform state list
terraform output rbac_assignment_count
```

**Expected:** 11 Phase 02 Terraform-managed resources (4 groups + 7 grants), **not** the same 11 as Phase 01. If you supplied an optional test group member, expect one more.

---

## 12. Verify permissions and perform a controlled test

### 12.1 Inspect via Azure CLI
```bash
bash ../scripts/verify_rbac.sh
```

Expected role scopes:
- Cloud Engineers: Reader on `rg-cg360-network`, Reader on `rg-cg360-app`
- Developers: Reader on `rg-cg360-app`
- Security Auditors: Reader on both
- Operations: Monitoring Reader on both

If Microsoft Graph lookups are blocked in this command but the group IDs are known from private Terraform state, inspect Azure Portal **Access control (IAM) → Role assignments** instead. In tools with the appropriate permissions, group object IDs may be used to bypass some Microsoft Graph resolution, but this **does not** bypass Azure RBAC authorisation.

### 12.2 Inspect via Azure Portal
1. Portal → **Resource groups** → `rg-cg360-app`.
2. Select **Access control (IAM)** → **Role assignments**.
3. Search for `CG360-` groups.
4. Verify their roles and scope. Repeat for `rg-cg360-network`.
5. Do **not** confuse inherited subscription Owner with the new direct Reader grants.

### 12.3 Functional access test (only if you have an authorised test user)
The `terraform output` and CLI role listing verify **configured grants**, but not that an end user can authenticate and perform/deny actions. A functional test requires a test user you control and may require MFA and propagation time.

Use a dedicated, authorised test user, place it in a test group, sign in as that user in a separate private browser session, and verify:
1. They can view only the allowed RG resources (read operation).
2. They cannot change NSG rules or delete VNets using Reader alone (denied write operation).
3. They cannot view a resource outside their scope unless other inherited grants allow it.

Do not attempt disruptive production tests, and do not assume denial where the test user has additional existing role grants. Record evidence without credentials or personal details.

---

## 13. Optional: use an authorised test user

Leave this step out if you do not have an approved lab identity. Never create fake identities representing real people or grant unrelated users access.

The example includes an optional Terraform resource `azuread_group_member.demo_developer` to manage **one** authorised user's membership in the Developers group. Use only the Microsoft Entra **user object ID**, not the email address or subscription ID.

To avoid storing a personal object ID in your `.tfvars` file, set it as a session variable:
```bash
# Replace the placeholder with a real AUTHORISED test user object ID
export TF_VAR_demo_member_object_id='00000000-0000-0000-0000-000000000000'

terraform plan -out=membership.tfplan
terraform show -no-color membership.tfplan | grep 'will be created'
terraform show -json membership.tfplan | python3 ../scripts/check_plan.py
```

**Expected:** `1 to add` (provided prior releases are already applied). Review the user identity **privately** and verify the requested membership. Then apply only if appropriate:
```bash
terraform apply membership.tfplan
```

When finished, remove membership in a **reviewed Terraform plan**, not by directly destroying the group. Unset the variable, plan, and review the single planned membership deletion. The provided **safe plan guard will intentionally reject deletions**, so remove the membership only with deliberate, manually documented approval and full inspection of the planned address.

---

## 14. Understand Terraform state and drift

### 14.1 Your two distinct Terraform roots
**Phase 01 network root**: owns 11 Azure networking resources. **Phase 02 identity root**: owns four Entra groups and up to seven role assignments. Their states must remain separate. Using two roots means a Phase 02 `terraform destroy` cannot directly destroy the VNets **as long as each state remains correctly isolated**.

### 14.2 Inspect state safely
```bash
pwd
terraform state list
terraform output security_group_names
terraform plan
```

**Expected after both releases:** `No changes. Your infrastructure matches the configuration.` (unless something changed outside Terraform). Do not share raw state files or plans publicly.

### 14.3 Drift example
If somebody manually changes a Terraform-managed role assignment in Azure, Terraform may detect a difference in a subsequent plan and propose a change to restore the declared desired state. Do not blindly apply drift corrections without change approval.

### 14.4 Remote state maturity step
Your mounted `~/clouddrive` is persistent but still a **local Terraform backend**. When we introduce GitHub Actions, migrate the state to an appropriate Azure Blob backend using Entra authentication, Azure Storage Blob Data Contributor permissions scoped appropriately, locking, restricted access and documented backup/recovery. **Do not enable a new backend in these Terraform files without planning a controlled state migration.**

---

## 15. Free-trial costs and security checkpoints

| Area | Phase 02 policy |
|---|---|
| Entra groups | Four basic security groups only; no P1/P2 features requested |
| Azure RBAC | Seven RG-scoped read-only grants; no per-assignment infrastructure deployment |
| VNets / AKS / VMs | **No new VNets, AKS or VMs** |
| Storage | Existing Cloud Shell storage may have ongoing storage charges |
| Subscription | Do not upgrade the trial to Pay-As-You-Go merely for this module |
| Security Defaults | Keep enabled |
| Credentials | Keep tokens/client secrets out of Git and Terraform state |
| Data | Test users only; no real client/banking/customer data |

### Four professional controls before every apply
1. **Scope** — Is the current subscription correct? Are all role assignments limited to the intended RGs?
2. **Privilege** — Are Reader/Monitoring Reader sufficient? Has anyone requested Owner/Contributor without an authorised justification?
3. **Blast radius** — Does the plan change anything outside `azuread_group` and `azurerm_role_assignment`?
4. **State** — Is Cloud Shell persistence still available? Is this the right Terraform root?

---

## 16. Troubleshooting playbook

### T01 — `ARM_SUBSCRIPTION_ID is absent`
Cause: a new Bash session does not retain exports. Fix:
```bash
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ARM_TENANT_ID="$(az account show --query tenantId -o tsv)"
```

### T02 — `No subscriptions found` after `az login` or `AADSTS530035`
Cause: Cloud Shell generally has an authenticated session and device-code sign-in can be blocked by tenant Security Defaults. **Do not disable Security Defaults**. Close and reopen Cloud Shell from the signed-in Azure Portal and run `az account list -o table`. Check directory selection if necessary.

### T03 — `~/clouddrive` is not mounted
Cause: ephemeral Cloud Shell session or a mount/configuration issue. Azure Portal Cloud Shell → Settings → **Reset User Settings** → **Mount storage account**; confirm the storage cost. Do not run a state-mutating Terraform apply until persistence is proven.

### T04 — `Authorization_RequestDenied` creating Entra groups
Cause: Entra directory security-group creation not permitted or Graph token lacks the needed permissions. Your Azure subscription Owner role is **not** a substitute for Entra directory access. Have an authorised Entra admin check group creation policy/roles, or complete the read-only audit. Do not grant yourself Global Administrator or disable tenant controls.

### T05 — `AuthorizationFailed` assigning Azure role
Cause: user lacks `Microsoft.Authorization/roleAssignments/write` at the RG scope. Check Azure Portal → Resource Group → Access control (IAM) → Check access. Owner or RBAC Administrator at the intended scope can create assignments, subject to conditions. Contributor alone cannot.

### T06 — `resource group not found`
Cause: Phase 01 not deployed, different subscription, or different RG name. Verify with `az group list -o table`; edit `app_resource_group` and `network_resource_group` in `.tfvars` to match. **Do not recreate the network.**

### T07 — `Group already exists` or `Duplicate group name`
Cause: Entra display names match existing directory groups. **Do not create duplicates.** Determine whether the groups were previously created by this Terraform configuration but lost from state. If so, use a documented, carefully reviewed `terraform import` for `azuread_group.lab["developers"]` and analogous addresses, using the existing Entra group object IDs. Never import unrelated groups without ownership approval. An easier option for a fresh lab is a distinct prefix only if you have confirmed those groups are not part of existing deployments.

### T08 — Role assignment propagation delay / `PrincipalNotFound`
Cause: new group has not propagated across Azure control planes. Confirm the group object exists, allow replication time, then rerun `terraform plan` and review. `principal_type = "Group"` is specified in the example to help appropriate principal handling. Do not set `skip_service_principal_aad_check` for groups: that flag is for service principals.

### T09 — Wrong Terraform folder / planned network deletion
Cause: running Terraform from the Phase 01 folder or using the wrong state. Check `pwd` and `terraform state list`. **STOP.** Phase 02 code intentionally has no network resources and the safety checker rejects unexpected changes.

### T10 — `Error acquiring the state lock`
Cause: concurrent Terraform process or an interrupted run. Verify no other process is active. Do not use `-lock=false` as a routine workaround. Follow HashiCorp recovery steps only with positive evidence that an orphaned lock exists.

### T11 — `Provider configuration not present` / provider mismatch
Cause: changed Terraform root, provider lock file mismatch or removed provider block. Return to the correct folder, keep `providers.tf` in place and run `terraform init`; do not delete state or use `-upgrade` blindly.

### T12 — `Plan: 0 to add` unexpectedly
Cause: groups already managed and state matches code, or the wrong directory/flags are active. Run `terraform state list`, `cat terraform.tfvars`, `az account show --query '{Name:name,State:state}' -o table`; review what actually exists before assuming failure.

### T13 — Existing Phase 01 `westeurope` / `RequestDisallowedByAzure`
Your former network restriction is irrelevant to Phase 02 group creation and RG-scoped RBAC: **Phase 02 does not deploy a new network or choose a new Azure compute region.** Leave the successfully completed Phase 01 network as it is. Do not revisit the old region error unless a future resource deployment is actually blocked.

### T14 — `terraform plan` fails due to Graph or Entra provider authentication
Check the selected tenant and existing Cloud Shell login. `azuread` manages tenant resources and may require the appropriate directory permissions distinct from AzureRM. `az ad group list` read access is not proof of group-write access. **Do not store a client secret as a workaround.**

---

## 17. Controlled cleanup and next phase

**Do not destroy Phase 02 simply because the exercise is complete** if you intend to retain these groups for the upcoming GitHub Actions, application and AKS modules.

If you want to remove only the Phase 02 lab:
1. Confirm every group is a lab-only group and no application, policy or user depends on it.
2. Audit effective memberships, child resources, and grants.
3. Ensure you are in the **Phase 02** Terraform root, not Phase 01.
4. Run `terraform plan -destroy -out=cleanup-phase02.tfplan` and review each address.
5. Obtain explicit authorisation to delete these groups and grants.
6. Only then run `terraform apply cleanup-phase02.tfplan`.

**Never** use `terraform destroy` from the Phase 01 network folder to clean up Phase 02.

### Next CloudGuard 360 modules
**Phase 03**: deploy prebuilt Azure Voting App with Docker, first locally to save Azure credits. **Phase 04**: GitHub Actions CI/CD and scanning. **Phase 05**: Kubernetes locally then time-boxed AKS. **Phase 06**: Zabbix/Grafana. **Phase 07**: approved automated incident workflows. We will reuse the identity model, not recreate it.

---

## 18. Acceptance criteria and interview questions

### Technical checklist
- [ ] Azure subscription and `~/clouddrive` verified.
- [ ] Phase 01 RGs and Hub/Spoke network verified without modification.
- [ ] Azure Portal IAM and Entra Admin Center navigation completed.
- [ ] Phase 02 ZIP uploaded to Cloud Shell and extracted to persistent path.
- [ ] `ARM_SUBSCRIPTION_ID` and tenant context verified.
- [ ] Audit script completed; prerequisites examined.
- [ ] Release A: four security groups created with Terraform.
- [ ] Groups verified in Entra Admin Center.
- [ ] Release B: seven read-only scoped role assignments created (if authorised).
- [ ] Scope and role evidence reviewed in Azure Portal and CLI.
- [ ] Optional authorised test principal exercised allowed/denied action.
- [ ] `terraform plan` reports no unintended changes or drift.
- [ ] CloudGuard 360 evidence and budget check recorded.

### Interview question 1 — Theory
**What is the difference between Microsoft Entra ID authentication and Azure RBAC authorization?**

**Model answer:** Entra ID verifies identity and issues authentication tokens. Azure RBAC evaluates the signed-in principal's roles at a resource scope and determines which Azure control-plane operations are permitted. Successful authentication does not automatically grant permission to change Azure resources.

### Interview question 2 — Architecture
**Why did we create groups in one Terraform root and look up existing Resource Groups through data sources?**

**Model answer:** This separates the identity lifecycle from the networking lifecycle, reduces the blast radius of changes, and prevents our identity project from inadvertently managing or deleting the networking resources built in Phase 01. Data sources read existing infrastructure without importing it into Phase 02 state.

### Interview question 3 — Security / Operations
**A Developer has Reader on the App RG but can still change a VM. How is that possible?**

**Model answer:** Azure RBAC permissions accumulate across direct and inherited assignments, so the user might have Contributor or Owner at the subscription or another applicable scope. I would check effective access, group membership and inherited role assignments rather than assuming Reader is the only permission.

---

## 19. Authoritative documentation

1. Microsoft — [List Azure role assignments with Azure CLI](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-list-cli)
2. Microsoft — [Assign Azure roles using the portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal)
3. Microsoft — [Steps to assign Azure roles and prerequisites](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-steps)
4. Microsoft — [Secure external access with Microsoft Entra groups](https://learn.microsoft.com/en-us/entra/architecture/4-secure-access-groups)
5. Microsoft — [Cloud Shell persistent storage](https://learn.microsoft.com/en-us/azure/cloud-shell/persisting-shell-storage)
6. Terraform Registry — [AzureAD Group resource](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group)
7. Terraform Registry — [AzureRM Role Assignment resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)
8. HashiCorp — [AzureRM state backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)

**Document control:** CloudGuard 360 / PH02 / v1.0 / November 2026. Status: package prepared and locally checked; **not deployed to your Azure subscription**.
