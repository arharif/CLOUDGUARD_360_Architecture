# CloudGuard 360 — Security Evidence Register (template)

**Classification:** Internal / private. Store in persistent storage and redact before external publication.

| Control ID | Control objective | Method / test | Expected result | Actual result | Status | Evidence file | UTC date | Reviewer | Finding / remediation |
|---|---|---|---|---|---|---|---|---|---|
| ID-01 | Four groups are unique | Portal + CLI + Terraform state | Four correct security groups | Not executed | NOT TESTED | — | — | — | — |
| RBAC-01 | Read-only group permissions | IAM + role assignments | 7 matching role/scope entries | Not executed | NOT TESTED | — | — | — | — |
| GOV-01 | Region policy Audit | `az policy assignment list` | One app-scope Audit assignment (optional) | Not executed | NOT TESTED | — | — | — | — |
| GOV-02 | Compliance assessment | Policy Insights | Verified evaluation data | Not executed | NOT TESTED | — | — | — | — |
| NET-01 | VNet peering stable | Azure CLI | Both peerings Connected | Not executed | NOT TESTED | — | — | — | — |
| IAC-01 | No Terraform drift | `terraform plan -detailed-exitcode` | Exit code 0 | Not executed | NOT TESTED | — | — | — | — |

Use **PASS / FAIL / PENDING / NOT TESTED / NOT APPLICABLE**. Evidence of a command running is not proof of correctness unless the actual result supports the control. Do not store plaintext credentials or access tokens in reports.
