# CloudGuard 360 — Phase 04 architecture

## Reuse from previous phases
- Phase 01: `rg-cg360-network`, `rg-cg360-app`, hub/spoke VNets, NSG, peering — do not alter.
- Phase 02: Entra groups and RBAC — unchanged by Phase 04.
- Phase 03: existing Azure Container App `ca-cg360-voting` with `vote-frontend` + `redis` — the deployment target.

## New components
- GitHub repository holding only the existing sample image wrapper and workflow configurations.
- GitHub Actions runner (`ubuntu-latest`) for automated scans and Docker image builds.
- GitHub Container Registry (GHCR) publishing to `ghcr.io/owner/cloudguard360-vote:<git-commit-sha>`.
- Trivy for secrets/IaC checks, image vulnerability reporting and CycloneDX SBOM.
- Optional separate Terraform identity root creating a user-assigned managed identity and GitHub OIDC trust.
- Optional Azure release job that updates **only** the frontend container of the existing Azure Container App.

## Security and limitations
- The Microsoft sample base image is a learning image; image vulnerability findings are report-only. Resolve findings before any production use.
- The pipeline doesn't build Python source code from the upstream sample. It repackages the prebuilt frontend image and adds metadata.
- Published GHCR image must be set **public** for the credential-free Azure pull route.
- GitHub OIDC is bound to a specific repo and Environment. The built-in `Container Apps Contributor` includes delete rights, so approval and scope control matter.
- `az containerapp update` causes Terraform image drift because Phase 03 owns the Container App. Reconcile Phase 03 `frontend_image` after release.
- Azure Container Apps may charge for running containers/requests and related resources; GitHub-hosted public-repo standard runners are generally included, subject to GitHub billing terms.
