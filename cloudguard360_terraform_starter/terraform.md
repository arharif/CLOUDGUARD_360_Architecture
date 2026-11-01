# CloudGuard 360 — Terraform on Azure

> **Complete hands-on lab: Azure Cloud Shell → Terraform → Hub-and-Spoke networking → safe region-error recovery → verification → controlled cleanup.**  
> **Audience:** beginner-to-intermediate Azure / Terraform learners. **Language:** English.  
> **Revision:** 1 November 2026. **Lab scope:** the first 11 Azure networking resources, not yet the later AKS/DevSecOps platform.  
> **Companion:** open `index.html` for an **animated, offline, interactive version** of this walkthrough, with clickable steps, copy buttons and progress tracking.

## Important: start here if you have already received the Azure 403 error

Your exact error was:

```text
RequestDisallowedByAzure: The selected region is currently not accepting new customers.
Virtual Network: vnet-cg360-hub / vnet-cg360-app
Requested region: westeurope
```

**Do not rerun your saved `step01.tfplan`. Do not delete `terraform.tfstate`, destroy your Resource Groups or simply change `location` without inspecting the state.** An unsuccessful `terraform apply` can leave already-created resources recorded in Terraform state. HashiCorp documents that `apply` does **not** automatically roll back a partially completed operation.

Go directly to **[Path B — recover an existing partially failed deployment](#path-b--recover-an-existing-partially-failed-deployment)**. The updated source includes a controlled region fix that keeps the previously created Resource Groups in their original region while placing new VNets and NSG in another region.

---

## Table of contents

1. [The outcome and architecture](#1-the-outcome-and-architecture)
2. [Understand the Terraform files and costs](#2-understand-the-terraform-files-and-costs)
3. [Path A — begin from zero: Azure Portal and Cloud Shell](#path-a--begin-from-zero-azure-portal-and-cloud-shell)
4. [Download the ZIP and upload it to Cloud Shell](#4-download-the-zip-and-upload-it-to-cloud-shell)
5. [Select the correct subscription and register the provider](#5-select-the-correct-subscription-and-register-the-provider)
6. [Path A — first clean Terraform plan and apply](#6-path-a--first-clean-terraform-plan-and-apply)
7. [Path B — recover an existing partially failed deployment](#path-b--recover-an-existing-partially-failed-deployment)
8. [Verify the deployment with Terraform, Azure CLI and Azure Portal](#8-verify-the-deployment-with-terraform-azure-cli-and-azure-portal)
9. [Inspect NSGs, subnets, CIDRs and network behaviour](#9-inspect-nsgs-subnets-cidrs-and-network-behaviour)
10. [Repeatability, source control and evidence](#10-repeatability-source-control-and-evidence)
11. [Controlled deletion and cost hygiene](#11-controlled-deletion-and-cost-hygiene)
12. [Troubleshooting and incident playbooks](#12-troubleshooting-and-incident-playbooks)
13. [Mastery exercises and next module](#13-mastery-exercises-and-next-module)
14. [References](#14-references)

---

## 1. The outcome and architecture

### 1.1 Business story

You are the Cloud Engineer for a fictional company, **CloudGuard 360**. Your assignment is to deploy the base Azure networking platform for an application. You must use **Terraform**, not manual point-and-click creation of the networks. Later, this platform will host an existing Docker application, AKS, Entra ID access controls, Zabbix, Grafana and incident workflows.

For now, the acceptance criteria are measurable: **2 Resource Groups, 2 VNets, 3 subnets, 1 NSG, 1 NSG-to-subnet association and 2 reciprocal peerings**.

```text
Azure Subscription (Free Trial / eligible subscription)
│
├── rg-cg360-network                     (Resource Group metadata location)
│   └── vnet-cg360-hub                    (Network region: northeurope*)
│       ├── CIDR: 10.0.0.0/16
│       └── snet-shared: 10.0.1.0/24
│
└── rg-cg360-app                         (Resource Group metadata location)
    ├── vnet-cg360-app                    (Network region: northeurope*)
    │   ├── CIDR: 10.10.0.0/16
    │   ├── snet-workload: 10.10.1.0/24 ── NSG association
    │   └── snet-private-endpoints: 10.10.2.0/24
    └── nsg-cg360-workload                (Same region as application VNet)

vnet-cg360-hub <---- two directional VNet peerings ----> vnet-cg360-app

* The sample choice of northeurope is not a guarantee of subscription eligibility.
```

### 1.2 Network vocabulary made simple

| Concept | Meaning | Practical example |
|---|---|---|
| Resource Group | Logical lifecycle and management boundary | `rg-cg360-app` |
| VNet | An isolated IP network inside Azure | `10.10.0.0/16` |
| Subnet | A smaller address space within a VNet | `10.10.1.0/24` |
| NSG | Stateful allow/deny rules evaluated for network traffic | Attached to `snet-workload` |
| Peering | Private connectivity between two VNets | Hub ↔ Application Spoke |
| Terraform configuration | Desired Azure resources described in `.tf` files | `network.tf` |
| Terraform state | Terraform's mapping of managed resources to actual IDs | `terraform.tfstate` |
| Plan | Proposed actions without making changes | `terraform plan` |
| Apply | Execute an approved Terraform plan | `terraform apply planfile` |

**Architectural honesty:** Hub-and-Spoke **without** Azure Firewall or a network virtual appliance is not a centrally inspected network. VNet peering is not transitive. The sample NSG initially has only Azure's default rules. No VM, workload, packet test or AKS cluster exists yet.

### 1.3 Why the region fix requires care

There are **two distinct region settings** in this revised starter:

```hcl
# terraform.tfvars
location                = "northeurope"  # VNets and NSG
resource_group_location = "westeurope"   # preserve existing RG metadata location
```

A Resource Group's metadata location **does not need to match the location of the resources it contains**. However, changing the Resource Group's own `location` property in Terraform triggers **replacement**, which can lead to deletion of the entire Resource Group and its contents. This course therefore preserves Resource Group location during recovery and changes only the actual network resources' region.

**For a brand-new deployment with no existing Resource Groups**, you may instead choose the same eligible region for both settings, for example `northeurope`. Only do so if you are on Path A, with no pre-existing state or similarly named resources.

---

## 2. Understand the Terraform files and costs

### 2.1 Deliverable package

The complete downloadable package contains:

```text
CloudGuard360_Terraform_Course/
├── terraform.md                     ← this deep technical guide
├── index.html                       ← animated interactive guide (offline)
└── cloudguard360_terraform_starter/
    ├── README.md
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── terraform.tfvars.example
    ├── main.tf
    ├── network.tf
    ├── outputs.tf
    ├── .gitignore
    └── scripts/
        ├── preflight.sh
        ├── verify.sh
        ├── verify.ps1
        ├── repair_existing_lab.sh
        └── check_plan.py
```

The **old ZIP** had a single location variable that applied to Resource Groups and VNets. The **revised ZIP** deliberately separates `resource_group_location` from `location`, for the region-recovery scenario you encountered.

### 2.2 What is and isn't free

| Item | Cost note |
|---|---|
| Resource Groups | No separate management fee |
| VNets and subnets | Generally no hourly charge for the VNet itself; associated services and traffic may cost |
| NSG | No separate NSG hourly fee; related network services may cost |
| VNet peering | Creation itself does not generate traffic charges, but peered data transfers can be billed |
| Cloud Shell | Shell usage is free; attached Azure Files storage has a charge |
| Terraform CLI | No licence required for this local lab |
| AKS, Azure Firewall, VPN Gateway | **Not deployed in this lab**; can be chargeable in later stages |

**Budget gate:** Azure Portal → **Cost Management + Billing** → check your **actual subscription type**, **credit balance**, **expiry date**, and **Costs/Budgets**. An Azure budget notification is **not** a hard spending cap. Do **not** upgrade the subscription or remove a spending limit just to run this exercise. Regions can have different service rates, so check pricing if deploying additional services.

### 2.3 Secrets and state safety

Never publish or share:

- `terraform.tfstate`, `terraform.tfstate.backup`, or `terraform state pull` output;
- `terraform.tfvars` if it contains confidential values;
- saved plan files (`*.tfplan`), which can contain sensitive settings;
- access tokens, tenant IDs, subscription IDs, credentials or device-login codes.

The provided `.gitignore` excludes local state, plans and `terraform.tfvars`. **Commit `.terraform.lock.hcl`** when setting up Git; it records the exact selected provider versions.

In this lab, we start with the local state file under persistent `~/clouddrive`. This is acceptable for **a controlled single-user training lab**, but is **not an enterprise-grade remote state setup**. A later exercise will migrate to an Azure Blob Storage backend with locking and Microsoft Entra authentication.

---

## Path A — begin from zero: Azure Portal and Cloud Shell

> **Skip this path if Terraform has already created any of your 11 resources.** Use Path B instead.

### 3.1 Open Azure Portal

1. Open your browser (Chrome or Edge).
2. Navigate to **https://portal.azure.com/**.
3. Sign in with the account that owns your Azure subscription.
4. In the top search bar, type **Subscriptions** and click the **Subscriptions** service result.
5. Open **Azure subscription 1** (or the subscription shown in your own portal).
6. Check **Status = Enabled**. Confirm the correct tenant/directory and verify remaining credit via **Cost Management + Billing**.
7. **Do not** create a VNet manually. Terraform will create it.

**Expected:** you see an active subscription. The label "Azure subscription 1" alone does **not** prove that Free Trial credit remains.

### 3.2 Open Azure Cloud Shell

1. In the Azure Portal top toolbar, find the Cloud Shell icon `>_` and click it. Alternatively visit **https://shell.azure.com/**.
2. Select **Bash** (not PowerShell) when asked.
3. If Cloud Shell opens immediately, continue to 3.4.
4. If an initial setup window is shown, choose an option to **mount a storage account**, rather than an ephemeral session. Follow the wizard to select your subscription and create or attach a compatible Azure Files share.
5. Confirm any storage charges before provisioning. Do not enable unnecessary paid services.

### 3.3 If Cloud Shell has no `clouddrive`

If you previously chose ephemeral storage, in Cloud Shell toolbar click **Settings (gear)** → **Reset User Settings** → **Reset**. Relaunch Cloud Shell, choose **Bash**, and select the persistent storage mount path during setup. This may create an Azure Storage Account and Azure Files share, which can cost money. **Download any important ephemeral files before resetting**, because they can be lost.

Test your mount:

```bash
mountpoint -q "$HOME/clouddrive" \
  && echo 'SUCCESS: persistent Cloud Shell storage' \
  || echo 'ERROR: no persistent Cloud Shell storage'
```

**Expected:** `SUCCESS: persistent Cloud Shell storage`. If you see `ERROR`, stop before any `terraform apply`.

Prove that files survive reconnecting:

```bash
echo 'CloudGuard 360 storage test' > "$HOME/clouddrive/cg360-storage-test.txt"
cat "$HOME/clouddrive/cg360-storage-test.txt"
```

Close and reopen the shell; then:

```bash
cat "$HOME/clouddrive/cg360-storage-test.txt"
```

The text should still be there. **Your Terraform project must stay inside this persistent mount, not in the ephemeral home directory.**

### 3.4 Verify installed tools

```bash
terraform version
az version
```

You previously observed Terraform `1.17.0` and Azure CLI `2.91.0`. A minor Terraform update notification does **not** explain the Azure region 403; you need not update Terraform simply to fix that error.

In Cloud Shell, do **not** run `az login` automatically. It is usually already authenticated. A manual device-code login in your environment produced an `AADSTS530035` policy block; using the inherited portal session avoids that unnecessary flow.

```bash
az account list --query '[].{Name:name,State:state,IsDefault:isDefault}' -o table
az account show --query '{Name:name,State:state}' -o table
```

**Expected:** your target subscription is `Enabled` and `IsDefault=True`.

---

## 4. Download the ZIP and upload it to Cloud Shell

### 4.1 Download the package from the ChatGPT conversation

1. In this conversation, find the **CloudGuard 360 Complete Terraform Package** attachment/link.
2. Click **Download**. Your browser should save a `.zip` file (often into **Downloads**).
3. If the download fails with *“This action couldn't be completed”*, use the alternative standalone Markdown and HTML links provided in the chat, or ask for a working attachment. Do not assume a ZIP was downloaded until it appears in your local Downloads folder.
4. **Do not paste a `sandbox:` link into Azure Cloud Shell**: that is a ChatGPT attachment link, not a public HTTP address Azure can fetch.

### 4.2 Upload via Azure Portal Cloud Shell toolbar

1. Open **https://portal.azure.com/** and open **Cloud Shell**.
2. In Cloud Shell's toolbar, click **Manage files** (the upload/download file menu; wording can vary).
3. Choose **Upload**.
4. In your computer's file picker, navigate to **Downloads**.
5. Choose `CloudGuard360_Terraform_Complete_Package.zip`.
6. Click **Open** to start uploading.
7. Return to the Bash prompt and confirm the archive exists:

```bash
ls -lh "$HOME/CloudGuard360_Terraform_Complete_Package.zip"
```

**Troubleshooting:** If it is not in `$HOME`, run `pwd` and `ls -lah ~/` and inspect the upload notification. Avoid changing directories randomly. You can upload the archive again if necessary.

### 4.3 Extract without overwriting the old project

```bash
# Create a course folder on the PERSISTENT mount.
mkdir -p "$HOME/clouddrive/cloudguard360/course"

# Extract the newly downloaded course; DO NOT overwrite your previous live state.
unzip -o "$HOME/CloudGuard360_Terraform_Complete_Package.zip" \
  -d "$HOME/clouddrive/cloudguard360/course"

# Verify all components were extracted.
ls -lah "$HOME/clouddrive/cloudguard360/course/CloudGuard360_Terraform_Course"
```

**Expected:** `terraform.md`, `index.html`, and `cloudguard360_terraform_starter/`.

> **Path A:** use the newly extracted starter.  
> **Path B:** keep working in your **old existing Terraform folder** because it contains your real state; use the repair script from the new package to patch its source safely. **Never replace the old state file with a new ZIP.**

### 4.4 (Path A only) Change to the clean starter

```bash
cd "$HOME/clouddrive/cloudguard360/course/CloudGuard360_Terraform_Course/cloudguard360_terraform_starter"
pwd
ls -lah
```

---

## 5. Select the correct subscription and register the provider

### 5.1 Set the subscription environment variable

```bash
# Azure Cloud Shell is already authenticated.
az account show --query '{Name:name,State:state}' -o table

# Required by AzureRM provider 4.x: set subscription ID privately in this shell.
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# Check presence WITHOUT printing the identifier.
test -n "${ARM_SUBSCRIPTION_ID:-}" \
  && echo 'PASS: ARM_SUBSCRIPTION_ID set' \
  || echo 'FAIL: missing subscription'
```

**Why:** `az account show` finds the active subscription; `--query id -o tsv` selects only its ID; `export` makes it available to Terraform. This is an environment variable, not a password. You must repeat it after opening a new Cloud Shell session.

### 5.2 Check `Microsoft.Network`

```bash
az provider show --namespace Microsoft.Network \
  --query registrationState -o tsv
```

If **`Registered`**, do nothing. If **`NotRegistered`** and you have the rights to register resource providers:

```bash
az provider register --namespace Microsoft.Network --wait --output none
az provider show --namespace Microsoft.Network --query registrationState -o tsv
```

Resource Provider registration does **not** create a VNet, but it is a subscription-wide configuration change. If you receive `AuthorizationFailed`, ask your Azure administrator to register the provider; do not elevate permissions unnecessarily.

### 5.3 Run the supplied preflight

```bash
bash scripts/preflight.sh
```

**Expected:** the script prints Terraform version, your current subscription (without full IDs), the `Microsoft.Network` registration state and a budget reminder.

If you see `ARM_SUBSCRIPTION_ID is missing`, repeat 5.1. If you encounter an `AADSTS530035` device login block, restart Cloud Shell from the Azure Portal and avoid a new manual `az login`.

---

## 6. Path A — first clean Terraform plan and apply

> Follow this section only if **no resources have been created by an earlier run** and this new folder is your first state for the lab. If you already had a partial `apply`, follow Path B.

### 6.1 Configure your selected location

Start from the revised template:

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Recommended example **only if Azure accepts the region for your subscription**:

```hcl
prefix                  = "cg360"
location                = "northeurope"
resource_group_location = "northeurope"  # clean start ONLY

tags = {
  project     = "CloudGuard360"
  environment = "lab"
  managed_by  = "terraform"
}
```

In `nano`: press **Ctrl+O**, press **Enter** to save, then **Ctrl+X** to quit. `northeurope` is a suggestion, **not a guarantee** that Azure will accept the deployment. `az account list-locations` is a discovery tool; a region can appear there while deployment remains restricted.

Check:

```bash
grep -E '^(prefix|location|resource_group_location) ' terraform.tfvars
az account list-locations \
  --query "[?name=='northeurope' || name=='francecentral'].{Name:name,DisplayName:displayName}" \
  -o table
```

### 6.2 Initialize and validate

```bash
terraform fmt -recursive
terraform init
terraform validate
```

**Expected:** `Terraform has been successfully initialized!` and `Success! The configuration is valid.` For the existing starter, the selected AzureRM provider might be `4.81.0` based on your previous output. The lock file captures the actual installed version. Do not casually change the provider major version mid-lab.

### 6.3 Create a saved execution plan

```bash
terraform plan -out=step01-reviewed.tfplan
python3 scripts/check_plan.py step01-reviewed.tfplan
terraform show -no-color step01-reviewed.tfplan | grep -E '^  # |^Plan:'
```

For a **fresh clean state**, expect **11 create actions, 0 changed, 0 destroyed**. Stop if resource names, regions, or actions differ unexpectedly. The supplied `check_plan.py` flags Resource Group deletions/replacements.

Review the full plan:

```bash
terraform show -no-color step01-reviewed.tfplan
```

**Do not run `apply` until you have inspected the plan, confirmed subscription ownership, and checked the cost/credit.**

### 6.4 Apply exactly the reviewed plan

```bash
terraform apply step01-reviewed.tfplan
```

**Expected in a successful clean deployment:** `Apply complete! Resources: 11 added, 0 changed, 0 destroyed.`

Because this is a **saved** plan, Terraform will not show the usual interactive `yes` prompt. Never use an old `step01.tfplan` that still targets `westeurope`.

If your `apply` fails with a region error, **do not start again from Path A**. Move to Path B, because some resources may have been successfully created already.

---

## Path B — recover an existing partially failed deployment

> **This is the recommended path for your current CloudGuard 360 situation.** You previously ran a real `terraform apply` using `westeurope`, and Azure rejected the two VNets with `RequestDisallowedByAzure` (403).

### B1. Open your original project folder — not the newly extracted copy

In Cloud Shell Bash:

```bash
cd "$HOME/clouddrive/cloudguard360/cloudguard360_terraform_starter"
pwd
ls -lah
```

**Expected:** original `.tf` files, `.terraform/` and (usually) `terraform.tfstate`. If state is missing, stop. Do **not** run an apply that assumes all resources are new.

Reset the Azure environment variable for this session:

```bash
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
```

### B2. Inventory what the failed apply DID create

```bash
terraform state list
```

You might see:

```text
azurerm_resource_group.app
azurerm_resource_group.network
azurerm_network_security_group.workload
```

This is only an **illustration**: the exact list depends on which operations completed. The state may contain fewer or more resources. Never invent or overwrite its contents.

Now inspect the actual Azure Resource Groups:

```bash
az group show -n rg-cg360-network \
  --query '{Name:name,Location:location}' -o table

az group show -n rg-cg360-app \
  --query '{Name:name,Location:location}' -o table

az resource list -g rg-cg360-network \
  --query '[].{Name:name,Type:type,Region:location}' -o table

az resource list -g rg-cg360-app \
  --query '[].{Name:name,Type:type,Region:location}' -o table
```

If `az group show` returns `ResourceGroupNotFound`, that group was not created. If resources exist in Azure but are not in Terraform's state, investigate ownership and state recovery **before** applying. `terraform import` can be used later for verified out-of-state existing resources, but never import by guessing.

### B3. Make a protected state backup — before changes

```bash
umask 077
mkdir -p "$HOME/clouddrive/cloudguard360/backups"

terraform state pull > \
  "$HOME/clouddrive/cloudguard360/backups/terraform-before-region-fix.tfstate"

ls -lh "$HOME/clouddrive/cloudguard360/backups/terraform-before-region-fix.tfstate"
```

The backup must have a **non-zero size**. Do not upload it to public GitHub or the chat. It can contain sensitive state data. Save it in the private persistent storage accessible only to you. Keep the original state in place.

### B4. Why editing only `terraform.tfvars` is unsafe

Your old starter used this expression for Resource Group location:

```hcl
# OLD main.tf (problematic for region changes after a partial apply)
location = var.location
```

If you merely change `location = "westeurope"` to `location = "northeurope"`, Terraform may propose replacing Resource Groups already created in West Europe. The AzureRM Resource Group resource documents that changing its `location` **forces replacement**, which can delete all resources contained in that group.

The **revised** code decouples these settings:

```hcl
# Revised main.tf, both Resource Groups
location = var.resource_group_location

# Revised network.tf, both VNets and the NSG
location = var.location
```

Keep the pre-existing Group's metadata in `westeurope`, while requesting network resources in a potentially available alternative region.

### B5. Use the supplied safe source patch script (recommended)

**First download/unzip the revised course as shown in section 4.** While still in your **original Terraform folder**, run:

```bash
bash "$HOME/clouddrive/cloudguard360/course/CloudGuard360_Terraform_Course/cloudguard360_terraform_starter/scripts/repair_existing_lab.sh" northeurope
```

The script:

- requires you to be inside persistent `~/clouddrive` and have an existing local Terraform state file;
- backs up the original `.tf` files, `terraform.tfvars` and state before editing;
- changes `main.tf` so existing Resource Groups **remain in West Europe**;
- changes `network.tf` so the VNets and NSG use `location` (the new target region);
- adds `resource_group_location` and sets `location = "northeurope"`;
- formats the source but **does not run `terraform apply`**.

**If this script reports an unexpected file structure or no state, stop**. Do not force it. Instead use the manual editing method below and compare with your state before planning.

### B6. Manual repair option if the script cannot be used

Open each file and make only the described changes:

```bash
nano main.tf
```

Replace the two Resource Group lines `location = var.location` with:

```hcl
location = var.resource_group_location
```

Next:

```bash
nano variables.tf
```

Add (once) at the bottom:

```hcl
variable "resource_group_location" {
  description = "Keep original resource group metadata region for existing deployment."
  type        = string
  default     = "westeurope"
}
```

Next:

```bash
nano network.tf
```

Change **only** the regional `location` settings for the **two VNets and the NSG**, from the `azurerm_resource_group.*.location` references to:

```hcl
location = var.location
```

Do not change `resource_group_name` references or subnet addresses.

Finally:

```bash
nano terraform.tfvars
```

Ensure it contains these values while preserving your original `prefix` and tags:

```hcl
location                = "northeurope"
resource_group_location = "westeurope"
```

**If your Resource Groups were actually created in another location**, use the location returned by `az group show`, not a guessed value.

### B7. Validate the repaired source and inspect actions

```bash
terraform fmt -recursive
terraform validate
terraform plan -out=step01-region-recovery.tfplan
```

**Important:** the new plan should no longer be an unconditional `11 to add` if some resources already exist in state. A perfectly normal recovery plan could show, for example, new VNets/subnets/peerings and a **replacement of an existing NSG** to align it to the new network region. Do **not** assume these counts are fixed.

Check the exact actions:

```bash
terraform show -no-color step01-region-recovery.tfplan \
  | grep -E '^  # |^Plan:'
```

You can also run the revised safety checker directly by absolute path:

```bash
python3 \
  "$HOME/clouddrive/cloudguard360/course/CloudGuard360_Terraform_Course/cloudguard360_terraform_starter/scripts/check_plan.py" \
  step01-region-recovery.tfplan
```

**STOP if either `azurerm_resource_group.app` or `azurerm_resource_group.network` is marked `destroy`, `delete`, `replace` or `-/+`.** Correct the Resource Group location before going further.

If **an NSG** is marked for replacement because its actual region is West Europe, this may be expected for our currently empty lab; inspect whether it is used or contains custom rules before approving. Never approve the replacement of a shared/production NSG.

### B8. Check Azure eligibility and cost before applying

List candidate regions:

```bash
az account list-locations \
  --query "[?name=='northeurope' || name=='francecentral' || name=='swedencentral'].{Region:name,DisplayName:displayName}" \
  -o table
```

**This output does NOT guarantee eligibility**. A deployment can still be denied if your subscription lacks regional access. Microsoft's documented resolution for `locationineligible` is to choose another region or request support if you have a justified regional requirement.

Confirm trial credit and subscriptions in the Azure Portal, and review any proposed replacement actions.

### B9. Apply only the newly approved recovery plan

```bash
terraform apply step01-region-recovery.tfplan
```

**Never apply the old `step01.tfplan`**: it still specifies the original region. Because a saved plan is applied exactly, editing files after producing it does not update that plan.

If this apply succeeds, proceed to section 8. If the new region also returns `RequestDisallowedByAzure`, keep the current state, pick another region **after verifying restrictions**, make a new plan and repeat only the controlled region-change procedure; do not wipe state or Resource Groups.

---

## 8. Verify the deployment with Terraform, Azure CLI and Azure Portal

### 8.1 Terraform state and output

From the **same working directory and same state** used for apply:

```bash
terraform state list
terraform state list | wc -l
terraform output
```

**Expected after full success:** 11 Terraform resource addresses. `terraform output` lists the configured resource-group names, VNet names/address spaces and resource IDs.

If the count differs, do not immediately rerun apply; examine the state and the last error.

### 8.2 Run the supplied verification script

```bash
# Path A: script is in the current starter directory
bash scripts/verify.sh

# Path B: use your original script if it exists
# bash scripts/verify.sh
```

Check that the script prints the two Resource Groups, both VNets and peerings.

### 8.3 Independent Azure CLI checks

```bash
# Resource Groups (metadata region may be westeurope in a recovered lab)
az group list \
  --query "[?starts_with(name,'rg-cg360-')].{Name:name,Location:location}" \
  -o table

# Actual VNet regions and CIDRs
az network vnet show \
  -g rg-cg360-network -n vnet-cg360-hub \
  --query '{Name:name,Region:location,CIDR:addressSpace.addressPrefixes}' -o json

az network vnet show \
  -g rg-cg360-app -n vnet-cg360-app \
  --query '{Name:name,Region:location,CIDR:addressSpace.addressPrefixes}' -o json

# All subnets in the application VNet
az network vnet subnet list \
  -g rg-cg360-app --vnet-name vnet-cg360-app \
  --query '[].{Name:name,CIDR:addressPrefix}' -o table

# NSG location
az network nsg show -g rg-cg360-app -n nsg-cg360-workload \
  --query '{Name:name,Location:location}' -o table

# Hub -> app
az network vnet peering list -g rg-cg360-network \
  --vnet-name vnet-cg360-hub \
  --query '[].{Name:name,State:peeringState}' -o table

# App -> hub
az network vnet peering list -g rg-cg360-app \
  --vnet-name vnet-cg360-app \
  --query '[].{Name:name,State:peeringState}' -o table
```

**Expected:** two VNets in the selected network region, CIDRs `10.0.0.0/16` and `10.10.0.0/16`; three subnets overall; an NSG in the app VNet region; two peerings with **`Connected`** status.

### 8.4 Verify the NSG-to-subnet association

```bash
az network vnet subnet show \
  -g rg-cg360-app \
  --vnet-name vnet-cg360-app \
  -n snet-workload \
  --query '{Subnet:name,NSG:networkSecurityGroup.id}' -o json
```

**Expected:** `NSG` points to `nsg-cg360-workload`. Its full Azure resource ID may be displayed locally; you do not need to paste it into the conversation.

### 8.5 Verify in Azure Portal — exact clicks

1. Open **https://portal.azure.com/**.
2. Search for **Resource groups**.
3. Open **rg-cg360-network** → **Resources** → click **vnet-cg360-hub**.
4. Inside the VNet, choose **Subnets** and verify `snet-shared`, `10.0.1.0/24`.
5. In the VNet left menu, choose **Peerings** → verify `peer-hub-to-app`, state **Connected**.
6. Go back to **Resource groups** → **rg-cg360-app** → click **vnet-cg360-app**.
7. Choose **Subnets** → verify `snet-workload` and `snet-private-endpoints`.
8. Choose **Peerings** → verify `peer-app-to-hub`, **Connected**.
9. In `rg-cg360-app` resources, open **nsg-cg360-workload** → **Subnets** → check `snet-workload` association.
10. Open each resource's **Overview** and confirm the resource region. The Resource Group's metadata location can legitimately differ from the VNets' locations.

Capture screenshots **without exposing the full subscription ID, tenant ID or other private details**.

### 8.6 Final idempotence check

After a successful apply, rerun:

```bash
terraform plan
```

The expected ideal result is **`No changes. Your infrastructure matches the configuration.`** If it proposes changes, inspect them; do not automatically apply them.

---

## 9. Inspect NSGs, subnets, CIDRs and network behaviour

### 9.1 CIDR basics

The Hub uses `10.0.0.0/16`; the application Spoke uses `10.10.0.0/16`. These ranges do not overlap, which allows peering. `/16` is a larger network than `/24`. Within each VNet, subnet prefixes must be within the parent address range and must not overlap with each other.

Azure reserves **five IP addresses per subnet** for platform use. For a `/24` subnet with 256 total addresses, 251 are available for Azure resource allocation, subject to additional service-specific requirements. This is a capacity-planning example, not a claim that 251 AKS nodes fit in that subnet.

### 9.2 NSG defaults do not equal a production security design

An NSG created without custom rules uses platform default rules. Those default rules allow some traffic, including VNet traffic, and deny some other inbound traffic. **Do not assume our Spoke is hardened simply because an NSG exists.** Our next lab will define explicit allow/deny rules, inspect effective security rules and test traffic with controlled workloads.

### 9.3 Peering connects network address spaces; it does not test application reachability

Status `Connected` means the peering resource relationship is configured. It does not prove that a VM can authenticate to a service or that an application endpoint is healthy. We will test actual routing, DNS, NSG filtering and workload traffic after deploying suitable test workloads.

---

## 10. Repeatability, source control and evidence

### 10.1 Organize evidence

```bash
mkdir -p "$HOME/clouddrive/cloudguard360/evidence/step01"
```

Save only **sanitized** command summaries/screenshots. Never copy Terraform state or full plans into a public evidence repository.

### 10.2 Useful Terraform commands

| Command | Meaning | When to use |
|---|---|---|
| `terraform fmt -recursive` | Format the configuration | After editing `.tf` files |
| `terraform init` | Initialize backend/providers | New working directory or backend changes |
| `terraform validate` | Validate HCL structure | Before planning |
| `terraform plan -out=FILE` | Save reviewed actions | Before applying |
| `terraform show FILE` | Inspect a saved plan | Approval gate |
| `terraform apply FILE` | Execute reviewed plan | After approval |
| `terraform state list` | See Terraform-managed resources | Troubleshooting / audits |
| `terraform output` | Read declared outputs | Verify deployed infrastructure |
| `terraform plan` | Check drift | After successful apply |
| `terraform plan -destroy -out=FILE` | Preview teardown | Controlled cleanup only |

### 10.3 Git basics

Use Git to version **source**: `.tf`, scripts, documentation and `.terraform.lock.hcl`. Your `.gitignore` already excludes plan files, state and `terraform.tfvars`. Before your first public push, inspect the repository with:

```bash
git status --short
```

Never add `-f` to force tracked secret or state files. Later, we'll create GitHub Actions workflows using **OIDC federation**, not long-lived Azure secrets.

---

## 11. Controlled deletion and cost hygiene

**Optional — only for a disposable, verified laboratory.** Do not destroy the lab until you have collected your learning evidence, and do not destroy a Resource Group that contains resources owned by another project.

### 11.1 Check Terraform scope and unmanaged Azure resources

```bash
terraform state list
az resource list -g rg-cg360-network \
  --query '[].{Name:name,Type:type}' -o table
az resource list -g rg-cg360-app \
  --query '[].{Name:name,Type:type}' -o table
```

Compare Terraform-managed resources with Azure's real inventory. If unrelated resources exist in these Resource Groups, **stop** and determine ownership.

### 11.2 Preview the destroy plan

```bash
terraform plan -destroy -out=cleanup-reviewed.tfplan
terraform show -no-color cleanup-reviewed.tfplan
```

Review every proposed deletion and the scope before proceeding.

### 11.3 Apply cleanup only if authorised

```bash
terraform apply cleanup-reviewed.tfplan
```

This command permanently removes the resources in the destroy plan. Azure Resource Group deletion is destructive to contents; do **not** proceed if the group contains resources outside your isolated lab.

Do not assume the Cloud Shell Azure Files share is cleaned up by this Terraform destroy — it was created separately. Check your cost management account for any separately provisioned storage and follow the appropriate owner-approved cleanup process.

---

## 12. Troubleshooting and incident playbooks

### E01 — `ARM_SUBSCRIPTION_ID is missing`

**Cause:** the AzureRM 4.x provider needs a subscription ID, and Bash variables are lost when a shell session ends.

**Fix:**

```bash
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
test -n "$ARM_SUBSCRIPTION_ID" && echo 'PASS: subscription set'
bash scripts/preflight.sh
```

Do not hardcode your subscription ID into committed `.tf` source.

### E02 — `Microsoft.Network: NotRegistered`

**Cause:** the subscription hasn't registered the Network Resource Provider.

```bash
az provider register --namespace Microsoft.Network --wait --output none
az provider show --namespace Microsoft.Network --query registrationState -o tsv
```

Requires proper subscription permissions. Expected: `Registered`.

### E03 — `AADSTS530035` after `az login`

**Cause:** your device-code authentication method was blocked by Microsoft Entra security defaults. Cloud Shell normally inherits portal authentication; **do not disable Security Defaults**.

**Fix:** close/reopen Cloud Shell from Azure Portal and run `az account list -o table` without requesting manual login. Verify the right directory/subscription in the portal if needed.

### E04 — `clouddrive not mounted`

**Cause:** ephemeral Cloud Shell setup or missing storage mount.

**Fix:** Cloud Shell **Settings → Reset User Settings**, select a persistent storage mount in setup, confirm potential Azure Files charges, then rerun `mountpoint -q "$HOME/clouddrive"` and a persistence test.

### E05 — `RequestDisallowedByAzure`, region `westeurope`

**Cause:** Microsoft regional admission policy, **not** a Terraform HCL syntax error.

**Fix:** Path B; inspect current Terraform state and Azure inventory; back up state; safely separate Resource Group metadata location from actual VNet/NSG region; use another region such as North Europe (subject to eligibility); plan and review all destroy/replace actions; apply only a newly approved plan.

**Do not:** delete `.tfstate`, repeatedly apply the original saved plan or blindly change the existing Resource Groups' location.

### E06 — Plan says `-/+ azurerm_resource_group.*`

**Cause:** Terraform is planning to destroy and recreate a Resource Group. Changing its location forces replacement, and deleting a Resource Group can delete its contents.

**Fix:** STOP. Verify `resource_group_location` matches the **existing metadata location** returned by Azure CLI. Run `terraform plan` again. Do not apply until the unexpected Resource Group replacement disappears.

### E07 — Plan proposes replacing an NSG

**Cause:** it might already have been created in West Europe. An NSG must be in the correct region for the subnet association. Changing its region forces replacement.

**Fix:** inspect whether the NSG contains rules or is attached to production workloads. For this empty lab, replacement may be acceptable **after explicit review**. Never generalize this approval to shared environments.

### E08 — `Resource already exists` but missing from state

**Cause:** Azure contains an object that the current Terraform state does not manage (possible partial apply, manual changes or wrong working directory).

**Fix:** stop; confirm your original working directory and state; compare `terraform state list` with the Azure inventory. Use verified Terraform imports or state recovery only after establishing the object's ownership. Do not delete resources merely to eliminate the error.

### E09 — `AuthorizationFailed`, 403 (not region error)

**Cause:** identity doesn't have sufficient Azure RBAC permissions to create/update a resource or register the necessary provider.

**Fix:** inspect the full Azure error code and required action; ask the subscription owner to grant appropriately scoped permissions. Do not use Owner by default for routine Terraform work.

### E10 — Provider initialization/download failure

**Cause:** connectivity to Terraform Registry, provider version constraint mismatch or corrupted local cache.

**Fix:** inspect the exact error, verify `versions.tf` and `terraform version`, then rerun `terraform init`. Avoid deleting the state file or casually upgrading to a new provider major version.

### E11 — `terraform plan` shows unexpected deletions

**Cause:** region changes, renamed resources, missing variables, wrong working directory, or drift.

**Fix:** **do not apply**. Check `pwd`, `terraform state list`, `terraform.tfvars`, and `terraform show -no-color PLAN`. Require a clean reason for each deletion. The course includes `scripts/check_plan.py` to block Resource Group deletions in a saved plan.

### E12 — `terraform apply` fails halfway through

**Cause:** Azure operation failed after some independent resources were already created.

**Fix:** keep state, run `terraform state list`, inspect actual Azure resources, back up state, correct the cause, generate and review a **new** plan. HashiCorp documents that Terraform does not roll back partial apply automatically.

---

## 13. Mastery exercises and next module

### 13.1 Five questions to check your understanding

1. Why can Terraform `validate` succeed even if Azure rejects your deployment?
2. Why do two VNets need non-overlapping address spaces when peering?
3. What is the difference between `terraform plan` and `terraform apply`?
4. Why is changing the location of an existing Resource Group dangerous?
5. Why do we keep Terraform state private and persistent?

**Short model answers:** (1) `validate` checks configuration, not Azure regional admission or permissions; (2) routing must unambiguously identify destination networks; (3) plan previews versus apply performs changes; (4) the Terraform AzureRM RG location change forces replacement and deletion can affect contents; (5) state identifies managed resources, supports safe reconciliation and may include sensitive values.

### 13.2 Acceptance checklist

- [ ] My correct Azure subscription is `Enabled` and its credits/budget were checked.
- [ ] Cloud Shell's `~/clouddrive` mount is present and persistent.
- [ ] `Microsoft.Network` is `Registered`.
- [ ] `ARM_SUBSCRIPTION_ID` is configured in the current Bash session.
- [ ] I know whether I'm on Path A (fresh) or Path B (previous partial apply).
- [ ] I have kept/backed up my original Terraform state (Path B).
- [ ] Terraform source uses the correct VNet/NSG region and safe Resource Group location.
- [ ] `terraform init` and `terraform validate` succeed.
- [ ] I reviewed a newly generated plan; no unexpected RG deletion is present.
- [ ] The apply succeeded in an eligible region.
- [ ] `terraform state list` shows the expected 11 resource addresses.
- [ ] Both VNet peerings report `Connected`.
- [ ] The NSG is attached to the workload subnet.
- [ ] A fresh `terraform plan` reports no unexpected changes.

### 13.3 Where we go next

This completes **only CloudGuard 360's Azure networking foundation**. The next modules will address NSG rules and real connectivity testing, Terraform state migration to a secure Azure Blob backend, Entra ID and least-privilege Azure RBAC, PowerShell automation, the existing Azure Voting App, Docker, a cost-controlled temporary AKS cluster, GitHub Actions, Zabbix/Grafana monitoring and incident automation.

---

## 14. References

Official sources used to verify this guide (links may evolve):

1. Microsoft — **Resolve location ineligible errors**: https://learn.microsoft.com/en-us/azure/azure-resource-manager/troubleshooting/error-region-access-policy
2. Microsoft — **Persist files in Azure Cloud Shell**: https://learn.microsoft.com/en-us/azure/cloud-shell/persisting-shell-storage
3. HashiCorp — **AzureRM Provider 4.0 upgrade guide** (subscription ID and provider registration): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/4.0-upgrade-guide
4. HashiCorp — **Terraform apply command / recovery after errors**: https://developer.hashicorp.com/terraform/cli/commands/apply
5. HashiCorp — **Azure Resource Group** (`location` replacement semantics): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
6. HashiCorp — **Terraform azurerm backend**: https://developer.hashicorp.com/terraform/language/backend/azurerm
7. Microsoft — **Store Terraform state in Azure Storage**: https://learn.microsoft.com/en-us/azure/terraform/terraform-backend
8. Microsoft — **Azure Virtual Network Peering**: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
9. Azure — **Pricing Calculator**: https://azure.microsoft.com/en-us/pricing/calculator/

**Revision note:** All commands are designed for **Azure Cloud Shell in Bash**, except PowerShell scripts in the starter folder. Example results are illustrative until verified in your own subscription. Never treat an instructional screenshot, command or plan as proof of successful deployment unless your Azure environment actually produced it.
