# CloudGuard 360 — Phase 08: Kubernetes & AKS

The complete, step-by-step **French** training is in `README_FR.md`. Start with `DEMARRAGE_RAPIDE.md` if you have limited Azure subscription time.

- Azure trial-sensitive live lab: preflight → optional AKS → Kubernetes smoke tests → evidence → verified deletion.
- Free local continuation: Docker Desktop + kind, with the same YAML manifests.
- Optional Phase 04 integration: Redis + Voting App using a real, public SHA-pinned GHCR image.
- Safeguard: isolated AKS RG `rg-cg360-aks-lab`; never delete `rg-cg360-app` or `rg-cg360-network`.

The scripts must be run with Bash on Azure Cloud Shell. The local kind instructions are PowerShell for Windows.

This package has been statically checked locally; the AKS provisioning and image availability require your account, permissions, credits and region and have not been executed here.
