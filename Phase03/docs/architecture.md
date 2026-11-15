# Phase 03 architecture decisions

**ADR-03-001 — Azure Container Apps Consumption instead of AKS**

Decision: for the first hosted two-container lab, use Terraform to deploy a small Consumption Container App rather than provision an AKS node pool. The latter has ongoing compute/node costs. Use AKS as a later, separately budgeted exercise.

**ADR-03-002 — Container Apps Environment not injected into Phase 01 VNet**

Reason: existing `snet-workload` is /24 and its purpose is future workload networking. Azure Container Apps Consumption-only VNet integration needs a delegated, appropriately sized dedicated subnet. The public sandbox model avoids new routes, private endpoints, NAT costs and untested configuration changes. This is NOT proof of Hub-and-Spoke application network segmentation.

**ADR-03-003 — One Container App with two containers**

Azure Vote front + Redis are tightly coupled for demonstration. They share network namespace, so `REDIS=localhost` and Redis remains unexposed. Both scale together and Redis is ephemeral. This is not an enterprise persistence architecture; the future architecture should separate durable state, use authentication/TLS and support multiple replicas.

**ADR-03-004 — No long-running registry, no Log Analytics workspace**

Use publicly accessible pre-built container images; deliberately omit Log Analytics to minimise bills. Console logs can be inspected during active Container App sessions, and durable log storage comes in later observability phases.

**ADR-03-005 — State isolation**

Phase 01 Terraform root owns resource groups, VNets, peerings, NSGs. Phase 02 Terraform root owns Entra groups and RBAC. Phase 03 only reads RG/VNet data and manages the Container Apps Environment and App. Never combine or delete existing Terraform states.
