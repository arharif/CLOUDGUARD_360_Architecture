# Approved Phase 02 Azure RBAC Role Matrix

| Principal (Microsoft Entra security group) | RG application | RG network | Total |
|---|---|---|---|
| CG360-Cloud-Engineers | Reader | Reader | 2 |
| CG360-Developers | Reader | None | 1 |
| CG360-Security-Auditors | Reader | Reader | 2 |
| CG360-Operations | Monitoring Reader | Monitoring Reader | 2 |
| **Total** | **4** | **3** | **7** |

**Notes:** No Contributor grants are intended in the default lab. Read-only group assignments do not cancel existing Owner/Contributor inherited from other scopes. All groups start with zero members unless intentionally populated. Role creation requires `Microsoft.Authorization/roleAssignments/write` at the appropriate scope.
