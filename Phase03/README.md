# CloudGuard 360 — PHASE 03: Docker & Application Deployment

**One practical phase, start to finish | Azure Cloud Shell (Bash) + Terraform + Azure Container Apps | Cost-controlled lab**

> **Scope:** This is a deliberately small, public, anonymous, demonstration web application. It is **not production-hardened** and does **not** integrate its Container Apps environment with the Phase 01 Spoke VNet. Neither this package nor Terraform will recreate or destroy the existing Phase 01/02 infrastructure.

## Executive summary

You already created Azure networking in Phase 01 and Microsoft Entra/RBAC in Phase 02. In this phase you will run a **prebuilt Microsoft Azure Voting App (Flask web frontend)** and a **Redis sidecar** inside **one Azure Container App** in the **Consumption** plan, created with **Terraform**. You will inspect the live HTTPS endpoint, learn container networking, test the application, document evidence, troubleshoot and optionally remove **only Phase 03** resources.

**Why not run Docker inside Azure Cloud Shell?** Cloud Shell does not have a running Docker daemon. It is suitable for Terraform/Azure CLI commands, **not** for `docker build`, `docker run` or `docker compose up`. We provide an **optional local Docker Compose** exercise to run on a computer with Docker installed.

**Safety and budget:** Container Apps has a monthly Consumption free grant, but not an unlimited free tier. Consumption beyond grants and other integrated Azure services may cost money. Our configuration uses 0–1 replicas, 0.5 total vCPU and 1 GiB total RAM across both containers. It does not enable a Log Analytics workspace, Private Endpoints, VNet injection, NAT Gateway, ACR or AKS. Do not upgrade your Azure subscription or disable trial protections merely for the lab. **Check the subscription's remaining credit and cost before `terraform apply`.** The existing `clouddrive` Azure Files mount can also incur storage charges.

## Architecture

```text
                   PUBLIC INTERNET (HTTPS)
                             |
                             v
            Azure Container Apps / Consumption
          ca-cg360-voting   (min 0, max 1 replica)
           +-----------------------------------+
           | Azure Vote Front (Flask)  :80     |
           |       REDIS=localhost            |
           |               |                   |
           |               v                   |
           | Redis 7 Alpine            :6379  |
           +-----------------------------------+
                             |
       Managed environment cae-cg360-lab
                             |
          Existing rg-cg360-app (READ only)

 Phase 01 VNet is READ to select region. The new Container Apps
 environment is NOT injected into the Phase 01 VNet.
```

### Why the Redis address differs

In **Docker Compose**, frontend and Redis are separate services on a Docker network; use `REDIS=azure-vote-back`. In **Azure Container Apps**, both containers live in one Container App replica with a shared network namespace; the frontend uses `REDIS=localhost`. Neither configuration publicly exposes port 6379.

**Data limitation:** Redis is **ephemeral**, has no durable volume, and has no password because it is only used internally for this isolated lab. Scaling to zero or restarting the app loses voting data. Do not send personal or real business data. The frontend is publicly accessible and does not yet use Entra SSO.

---

# Main Phase 03 — Full end-to-end guide

## Step 1 — Verify the Azure prerequisites and budget

1. Open **https://portal.azure.com/** and sign in with the account you used for Phases 01–02.
2. Open **Subscriptions**, select your existing subscription and verify that it is **Enabled**.
3. Navigate to **Cost Management + Billing → Cost Management → Budgets**. Check your remaining trial credits and applicable budget alerts. Do **not** upgrade the subscription to proceed.
4. From the Azure Portal toolbar, launch **Cloud Shell**, select **Bash** and confirm the `clouddrive` mount.
5. Copy the commands below into Cloud Shell Bash. This initial set **only reads** existing resources.

```bash
mountpoint -q "$HOME/clouddrive" && echo 'PASS: persistent Cloud Shell mount' || echo 'STOP: persistent mount unavailable'
az account show --query '{Name:name,State:state}' -o table
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
az group show -n rg-cg360-app --query '{Name:name,Location:location}' -o table
az network vnet show -g rg-cg360-app -n vnet-cg360-app --query '{Name:name,Location:location}' -o table
```

**Expected:** a mounted `clouddrive`, `Enabled` subscription, existing `rg-cg360-app` and existing `vnet-cg360-app`. **Stop** if the networking resources are missing or the mount is unavailable.

6. Register the container service provider only if it is not registered. Resource Provider registration requires appropriate subscription permissions and does **not** create a billed Container App:

```bash
az provider show --namespace Microsoft.App --query registrationState -o tsv
# Run the following command ONLY if it says NotRegistered:
az provider register --namespace Microsoft.App --wait --output none
az provider show --namespace Microsoft.App --query registrationState -o tsv
```

**Expected final state:** `Registered`. A registered provider and an existing VNet do **not** guarantee your subscription is eligible for Container Apps in that region. Your earlier `westeurope` 403 may recur; see Troubleshooting.

## Step 2 — Download, upload and extract the Phase 03 ZIP

1. Download `CloudGuard360_Phase03_Docker_Application.zip` from ChatGPT to your computer.
2. In the Azure Portal, open **Cloud Shell → Manage files → Upload**.
3. Choose the downloaded ZIP and wait until upload succeeds.
4. Paste the commands below into **Bash**. The ZIP normally uploads to your home directory (`~`).

```bash
ls -lh ~/CloudGuard360_Phase03_Docker_Application.zip
mkdir -p ~/clouddrive/cloudguard360
unzip -n ~/CloudGuard360_Phase03_Docker_Application.zip -d ~/clouddrive/cloudguard360
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application
ls -la
```

**Expected folders:** `terraform`, `docker`, `scripts`, `docs`. The `unzip -n` flag **does not overwrite existing files**. Do not extract this project over your existing Phase 01/02 Terraform directories.

Check the included network architecture and Terraform source:

```bash
ls -la terraform
sed -n '1,220p' terraform/main.tf
```

This new Terraform root reads `rg-cg360-app` and `vnet-cg360-app` as **data sources**. Its managed resources are **only** the Container Apps environment and the Container App.

## Step 3 — Configure Terraform, one separate state

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform
export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
cp -n terraform.tfvars.example terraform.tfvars
cat terraform.tfvars
bash ../scripts/preflight.sh
```

The file `terraform.tfvars` identifies the existing RG and VNet. `location_override = ""` means *use the actual VNet location*, **not the Resource Group's metadata location**. This matters because your earlier network deployment was blocked in `westeurope`.

If your existing VNet is in a region where Container Apps is not allowed for your subscription, you may choose an alternate `location_override` after checking eligibility and cost. **Do not pick a new region at random**. Run a read-only check before modifying the variable:

```bash
az network vnet show -g rg-cg360-app -n vnet-cg360-app --query location -o tsv
az account list-locations --query '[].{Name:name,DisplayName:displayName}' -o table
```

The `list-locations` output is a reference list, **not proof of permission for specific services**.

**State safety:** Phase 03 uses local state stored in the mounted Azure Files directory. This is appropriate for a single-user, supervised lab but is **not** the final enterprise backend. Never upload `.tfstate` or a saved plan to GitHub, never delete them, and do not run multiple Terraform clients simultaneously. The next DevOps phase will introduce a protected Blob backend and automated deployments.

## Step 4 — Terraform init, validate, inspect and plan

Run commands in order:

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=phase03.tfplan
terraform show -no-color phase03.tfplan | grep -E 'will be created|will be destroyed|Plan:'
terraform show -json phase03.tfplan | python3 ../scripts/check-plan.py
```

**Expected results (first deployment):** `Success! The configuration is valid.`, then **`Plan: 2 to add, 0 to change, 0 to destroy`** and **`PLAN PASS`**. The two created resources must be:

1. `azurerm_container_app_environment.lab`
2. `azurerm_container_app.voting`

The output must **not** contain resource group, VNet, NSG, peering, identity or RBAC changes. The strict plan checker rejects any unexpected resources and any change/delete actions.

**Stop** if you have anything other than exactly those two creates. Revisit `terraform.tfvars` and check for existing resources or drift.

## Step 5 — Deploy the application to Azure (first billed operation)

Only after you have checked credit/eligibility, accepted the public demo endpoint and reviewed `PLAN PASS`, execute:

```bash
terraform apply phase03.tfplan
```

For a first successful deployment expect a summary close to:

```text
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Next extract the HTTPS endpoint:

```bash
terraform output
terraform output -raw app_url
```

**Expected:** an `https://...azurecontainerapps.io` address. Copy it to your browser. Wait for a cold start if the replica was scaled to zero. Try selecting an option in the Voting App.

> Azure Container Apps can have a service-level regional restriction. An Azure `403 RequestDisallowedByAzure` means you must check the region/subscription eligibility, and possibly use a different permitted region; do not keep retrying the same location. If `apply` only partially succeeds, run `terraform state list` and inspect Azure before changing code or destroying anything.

## Step 6 — Verify the live application and understand Docker

Run the verification script:

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application
bash scripts/verify.sh
```

Or check manually:

```bash
cd terraform
terraform state list
terraform output -raw app_url
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query '{Name:name,Status:properties.provisioningState,FQDN:properties.configuration.ingress.fqdn}' -o table
az containerapp revision list -g rg-cg360-app -n ca-cg360-voting --query '[].{Name:name,Active:properties.active,Health:properties.healthState}' -o table
```

If `az containerapp ...` is unavailable, check the CLI's Container Apps command group and add/update the extension as appropriate:

```bash
az extension add --name containerapp --upgrade
```

**Browser tests:** HTTPS URL loads, the Voting App UI is visible, a sample vote can be submitted. Note that Redis is not persistent and its values may disappear between cold starts.

**What you just learned:**

- **Docker image** — a packaged application specification (`mcr.microsoft.com/azuredocs/azure-vote-front:v1`).
- **Container** — one running instance of an image.
- **Two-container application** — application container plus Redis container, in the same ACA replica.
- **Port 80** — frontend listens for web requests.
- **Port 6379** — private Redis endpoint inside the shared network namespace.
- **Ingress** — Azure's managed HTTPS entry point to port 80.
- **Replica** — one instance of the whole container combination, with scale-to-zero for cost control.

### Optional hands-on Docker Compose on a PC (not in Cloud Shell)

1. Install Docker Desktop / Docker Engine on a suitable personal computer.
2. Copy the included `docker/compose.yaml` to that computer.
3. In a terminal on that **computer**, open its directory and run:

```bash
docker version
docker compose up -d
docker compose ps
docker compose logs --tail=30
# Open http://localhost:8080 in your computer's browser
docker compose down
```

**Important:** this Docker Compose file uses the same two public prebuilt images, but with `REDIS=azure-vote-back` because containers communicate by **Compose service name**, not `localhost`. It does **not** expose Redis port 6379 to the host, and the voting UI is bound to loopback `127.0.0.1:8080`.

## Step 7 — Troubleshoot and collect proof

If the app does not load, inspect the revision and logs:

```bash
az containerapp revision list -g rg-cg360-app -n ca-cg360-voting -o table
az containerapp logs show -g rg-cg360-app -n ca-cg360-voting --type system --tail 30
az containerapp logs show -g rg-cg360-app -n ca-cg360-voting --container vote-frontend --tail 30
```

If you get a Container App revision/container selection error, use `az containerapp replica list` / `az containerapp revision list` to identify the active replica and supply `--replica` and `--revision` as required. If the scale-to-zero replica is absent, open the HTTPS URL first to trigger activation.

Create a small evidence folder without exporting the sensitive Terraform State:

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application
mkdir -p evidence
cd terraform
terraform validate > ../evidence/01-validation.txt 2>&1
terraform state list > ../evidence/02-resource-addresses.txt
terraform output -raw app_url > ../evidence/03-app-url.txt
az containerapp show -g rg-cg360-app -n ca-cg360-voting --query '{Name:name,Status:properties.provisioningState}' -o json > ../evidence/04-app-status.json
```

Your complete proof is: passing Terraform validation; **two Phase 03 resources** managed in state; a working HTTPS address; app screen; a sample vote; and no changes to Phase 01/02.

## Step 8 — Final check, then cleanup or handover

Check idempotency:

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform
terraform plan -detailed-exitcode
```

Exit code `0` = no changes; `2` = changes; `1` = error. Review any changes before applying them.

### Option A — Keep the demo temporarily

Keep `min_replicas=0` to reduce idle costs and check Cost Management. The public URL will remain available but wake a new replica when traffic arrives. This is **not a guarantee of zero total cost**, and other services such as your Cloud Shell Azure Files share may still be charged.

### Option B — Delete only Phase 03 resources to eliminate unnecessary lab usage

**Do not delete `rg-cg360-app`, the original VNet or any Phase 01/02 resources.** Preview destruction first:

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application
bash scripts/cleanup-preview.sh
```

Expect **only these two resources** planned for deletion:

```text
azurerm_container_app.voting
azurerm_container_app_environment.lab
```

If so, and after verifying no other workloads use the environment, run:

```bash
cd ~/clouddrive/cloudguard360/CloudGuard360_Phase03_Docker_Application/terraform
terraform apply phase03-destroy.tfplan
terraform state list
```

The state list should be empty of **managed** Phase 03 resources. The `data.azurerm_resource_group.app` and `data.azurerm_virtual_network.app` data sources may still be listed if they were read by Terraform; **do not delete the Phase 01/02 resources**.

---

## Troubleshooting table

| Symptom | Probable cause | Safe action |
|---|---|---|
| `ARM_SUBSCRIPTION_ID` missing | Shell restarted | Re-run `export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"` |
| `clouddrive` not mounted | Ephemeral Cloud Shell | Reconnect persistent storage; do not apply |
| `Microsoft.App NotRegistered` | Resource Provider inactive | Register provider if you have permission |
| `403 RequestDisallowedByAzure` | Region not accepting your subscription | Check subscription-specific eligibility, choose an allowed supported region |
| `AuthorizationFailed` | Azure RBAC insufficient for Microsoft.App | Verify effective role/scope; ask authorised admin |
| `terraform validate` fails | HCL/provider mismatch | Inspect line and error; `terraform init -upgrade` only after checking compatibility |
| Plan shows RG replacement | Wrong root/state or extra code | STOP; correct project directory, never apply |
| Container revision unhealthy | Image pull, startup or memory | Check revision state and Container Apps logs |
| App returns Redis connection error | Redis is not ready / wrong hostname | Confirm `REDIS=localhost` in ACA and 2 containers exist |
| Voting resets | Redis ephemeral / scale-to-zero | Expected for lab; persistence is future work |
| Docker command fails in Cloud Shell | No Docker daemon | Use local Docker / Codespaces, or deploy public images via Terraform |
| Plan after apply shows changes | Drift, state/version/config mismatch | Review drift, do not auto-apply |

## Official references

- Azure Voting App sample: https://github.com/Azure-Samples/azure-voting-app-redis
- Azure Container Apps billing: https://learn.microsoft.com/azure/container-apps/billing
- Container Apps multiple containers: https://learn.microsoft.com/azure/container-apps/containers
- Azure Container App Terraform resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
- Container App Environment Terraform resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment
- Cloud Shell Docker limitation: https://github.com/MicrosoftDocs/azure-dev-docs/blob/main/articles/azure-developer-cli/troubleshoot.md

**Exit criterion:** the web frontend works from your browser, both containers run as one Azure Container App replica, Terraform owns only two Phase 03 resources, and you have either documented the operating cost or deleted those temporary resources safely. The next workstream is GitHub Actions CI/CD and DevSecOps scanning, followed by AKS and Zabbix/Grafana.
