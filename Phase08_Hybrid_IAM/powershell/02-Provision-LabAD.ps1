# Idempotent AD provisioning for an isolated CG360 lab forest only.
# Creates four security groups and four fictitious accounts. Never uses privileged AD groups.
#Requires -Modules ActiveDirectory
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
if ($domain.DNSRoot -ne 'corp.cg360.test') { throw "REFUSED: Domain '$($domain.DNSRoot)' is not the isolated lab domain corp.cg360.test." }
$base = $domain.DistinguishedName
$labOU = "OU=CG360,$base"
$usersOU = "OU=Users,$labOU"
$groupsOU = "OU=Groups,$labOU"
function Ensure-OU($distinguishedName,$name,$parent) {
  try { Get-ADOrganizationalUnit -Identity $distinguishedName -ErrorAction Stop | Out-Null }
  catch { New-ADOrganizationalUnit -Name $name -Path $parent -ProtectedFromAccidentalDeletion $true -ErrorAction Stop | Out-Null; Write-Host "CREATED OU $distinguishedName" }
}
Ensure-OU $labOU 'CG360' $base
Ensure-OU $usersOU 'Users' $labOU
Ensure-OU $groupsOU 'Groups' $labOU
$mapping = @(
  @{ Group='CG360-Cloud-Engineers'; Account='cg360.eng'; Name='CG360 Engineer Demo' },
  @{ Group='CG360-Developers'; Account='cg360.dev'; Name='CG360 Developer Demo' },
  @{ Group='CG360-Security-Auditors'; Account='cg360.audit'; Name='CG360 Auditor Demo' },
  @{ Group='CG360-Operations'; Account='cg360.ops'; Name='CG360 Operations Demo' }
)
$pass = Read-Host 'Enter a strong initial password for the four LAB users (not saved anywhere)' -AsSecureString
foreach ($item in $mapping) {
  $group = Get-ADGroup -Filter "Name -eq '$($item.Group)'" -ErrorAction Stop
  if ($group -and $group.DistinguishedName -notlike "*,$groupsOU") { throw "REFUSED: Group $($item.Group) exists outside the lab OU." }
  if (-not $group) {
    New-ADGroup -Name $item.Group -SamAccountName $item.Group -GroupCategory Security -GroupScope Global -Path $groupsOU -Description 'CloudGuard 360 - LOCAL AD TRAINING ONLY; not cloud-synchronized' -ErrorAction Stop
    Write-Host "CREATED GROUP $($item.Group)"
  }
  $user = Get-ADUser -Filter "SamAccountName -eq '$($item.Account)'" -ErrorAction Stop
  if ($user -and $user.DistinguishedName -notlike "*,$usersOU") { throw "REFUSED: User $($item.Account) exists outside the lab OU." }
  if (-not $user) {
    New-ADUser -Name $item.Name -SamAccountName $item.Account -UserPrincipalName "$($item.Account)@corp.cg360.test" -Path $usersOU -AccountPassword $pass -Enabled $true -ChangePasswordAtLogon $true -Description 'Fictitious user for CG360 local lab' -ErrorAction Stop
    Write-Host "CREATED USER $($item.Account)"
  }
  $current = @(Get-ADGroupMember -Identity $item.Group -ErrorAction Stop | Select-Object -ExpandProperty SamAccountName)
  if ($item.Account -notin $current) {
    Add-ADGroupMember -Identity $item.Group -Members $item.Account -ErrorAction Stop
    Write-Host "MEMBER ADDED $($item.Account) -> $($item.Group)"
  }
}
Write-Host 'PASS: local demo OU, groups, users, and membership are provisioned.' -ForegroundColor Green
