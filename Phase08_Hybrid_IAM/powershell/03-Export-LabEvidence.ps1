# Read-only, AD DS evidence exporter. Does not export passwords or privileged group data.
param([string]$OutputDirectory = "$PSScriptRoot\..\evidence\ad")
#Requires -Modules ActiveDirectory
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
if ($domain.DNSRoot -ne 'corp.cg360.test') { throw 'REFUSED: unexpected domain. Only corp.cg360.test is supported.' }
$labOU = "OU=CG360,$($domain.DistinguishedName)"
$usersOU = "OU=Users,$labOU"
$groupsOU = "OU=Groups,$labOU"
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$users = @(Get-ADUser -SearchBase $usersOU -Filter * -Properties Enabled,UserPrincipalName -ErrorAction Stop | Sort-Object SamAccountName)
$users | Select-Object SamAccountName,Name,UserPrincipalName,Enabled | Export-Csv (Join-Path $OutputDirectory 'ad_users.csv') -NoTypeInformation -Encoding UTF8
$groups = @(Get-ADGroup -SearchBase $groupsOU -Filter * -ErrorAction Stop | Sort-Object Name)
$groups | Select-Object Name,SamAccountName,GroupScope,GroupCategory | Export-Csv (Join-Path $OutputDirectory 'ad_groups.csv') -NoTypeInformation -Encoding UTF8
$members = foreach ($group in $groups) {
  foreach ($member in @(Get-ADGroupMember -Identity $group -ErrorAction Stop)) {
    [pscustomobject]@{ Group=$group.Name; Account=$member.SamAccountName; Type=$member.objectClass }
  }
}
$members | Export-Csv (Join-Path $OutputDirectory 'ad_membership.csv') -NoTypeInformation -Encoding UTF8
[pscustomobject]@{ GeneratedAtUTC=[DateTime]::UtcNow.ToString('o'); Domain=$domain.DNSRoot; Users=$users.Count; Groups=$groups.Count; IdentitySource='LOCAL_AD_DS'; CloudSyncVerified=$false } |
 ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'ad_summary.json') -Encoding UTF8
Write-Host "PASS: Evidence exported to $OutputDirectory"
Write-Host "Users: $($users.Count); Groups: $($groups.Count); Memberships: $(@($members).Count)"
