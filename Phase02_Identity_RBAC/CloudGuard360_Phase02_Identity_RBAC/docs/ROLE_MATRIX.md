# CLOUDGUARD 360 — Phase 02 RBAC Role Matrix

| Principal | Azure scope | Role | Reason | Default |
| --- | --- | --- | --- | --- |
| CG360-Cloud-Engineers | rg-cg360-network | Reader | Network inspection without modification | Enabled in Release B |
| CG360-Cloud-Engineers | rg-cg360-app | Reader | App inspection | Enabled in Release B |
| CG360-Developers | rg-cg360-app | Reader | Inspect non-production app resources | Enabled in Release B |
| CG360-Security-Auditors | rg-cg360-network | Reader | Evidence-based network audit | Enabled in Release B |
| CG360-Security-Auditors | rg-cg360-app | Reader | Evidence-based app audit | Enabled in Release B |
| CG360-Operations | rg-cg360-network | Monitoring Reader | Monitoring information | Enabled in Release B |
| CG360-Operations | rg-cg360-app | Monitoring Reader | Monitoring information | Enabled in Release B |
| CG360-Cloud-Engineers | rg-cg360-app | Contributor | Optional elevated exercises | **Disabled** by default; explicit approval needed |

**Limitations:** An empty group does not grant anyone access. Reader doesn't authorize all resource data-plane operations. `Monitoring Reader` has defined read operations for monitoring, not application-level Grafana RBAC. Existing inherited permissions may increase effective access.
