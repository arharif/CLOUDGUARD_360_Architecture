# Safe offboarding of one fictitious account in the dedicated lab OU.
# Example preview: .\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev -WhatIf
# Example execution: .\04-Offboard-LabUser.ps1 -SamAccountName cg360.dev
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param([Parameter(Mandatory=$true)][ValidateSet('cg360.dev','cg360.eng','cg360.audit','cg360.ops')][string]$SamAccountName)
#Requires -Modules ActiveDirectory
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
if ($domain.DNSRoot -ne 'corp.cg360.test') { throw 'REFUSED: Not the lab domain.' }
$userOU = "OU=Users,OU=CG360,$($domain.DistinguishedName)"
$u = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
if (-not $u.DistinguishedName.EndsWith("," + $userOU, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'REFUSED: user is outside the CG360 lab Users OU.' }
if ($PSCmdlet.ShouldProcess($SamAccountName,'Disable lab account')) {
  Disable-ADAccount -Identity $u -ErrorAction Stop -Confirm:$false
  Write-Host "DISABLED: $SamAccountName"
}
foreach ($g in @('CG360-Cloud-Engineers','CG360-Developers','CG360-Security-Auditors','CG360-Operations')) {
  $grp = Get-ADGroup -Identity $g -ErrorAction Stop
  if (-not $grp.DistinguishedName.EndsWith(",OU=Groups,OU=CG360,$($domain.DistinguishedName)",[System.StringComparison]::OrdinalIgnoreCase)) { throw "REFUSED: group $g is outside lab OU." }
  $current = @(Get-ADGroupMember $grp -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
  if ($SamAccountName -in $current -and $PSCmdlet.ShouldProcess($SamAccountName,"Remove lab group membership $g")) {
    Remove-ADGroupMember -Identity $grp -Members $u -Confirm:$false -ErrorAction Stop
    Write-Host "REMOVED MEMBERSHIP: $g"
  }
}
Write-Host 'Offboarding process finished. Re-export evidence to verify the new state.'
