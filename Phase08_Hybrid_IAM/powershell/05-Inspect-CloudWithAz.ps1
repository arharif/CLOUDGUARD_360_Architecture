# Optional READ-ONLY PowerShell exercise in Azure Cloud Shell (PowerShell mode).
$ErrorActionPreference = 'Stop'
Import-Module Az.Accounts,Az.Resources
$ctx = Get-AzContext
if (-not $ctx) { throw 'No active Azure context. Sign in using Connect-AzAccount if authorized.' }
Write-Host "Subscription: $($ctx.Subscription.Name); Tenant: $($ctx.Tenant.Id)"
$names = @('CG360-Cloud-Engineers','CG360-Developers','CG360-Security-Auditors','CG360-Operations')
foreach ($name in $names) {
  try {
    $g = Get-AzADGroup -DisplayName $name -ErrorAction Stop
    Write-Host "$name : $(@($g).Count) match(es)"
  } catch { Write-Warning "Group lookup for $name failed (check directory read permission): $($_.Exception.Message)" }
}
foreach ($rg in @('rg-cg360-app','rg-cg360-network')) {
  try {
    Write-Host "--- Role assignments for $rg ---"
    Get-AzRoleAssignment -ResourceGroupName $rg -ErrorAction Stop |
      Select-Object RoleDefinitionName,ObjectType,Scope | Format-Table -AutoSize
  } catch { Write-Warning "RBAC lookup failed for $rg: $($_.Exception.Message)" }
}
