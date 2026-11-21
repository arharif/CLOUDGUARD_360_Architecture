# CloudGuard 360 Phase 08 - Local AD lab preflight (read-only)
$ErrorActionPreference = 'Stop'
Write-Host '=== CG360 Local AD DS preflight ==='
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "Operating system: $($os.Caption)"
if ($os.ProductType -eq 1) { throw 'Install and run this lab inside a Windows Server VM, not your Windows workstation.' }
$computer = Get-CimInstance Win32_ComputerSystem
Write-Host "Domain joined: $($computer.PartOfDomain)"
Write-Host "Computer name: $env:COMPUTERNAME"
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
$ad = Get-Module -ListAvailable -Name ActiveDirectory
Write-Host "AD module available: $([bool]$ad)"
if ($ad) {
  Import-Module ActiveDirectory
  try { $domain = Get-ADDomain -ErrorAction Stop; Write-Host "Detected AD DNS domain: $($domain.DNSRoot)" }
  catch { Write-Host 'No responding AD domain yet. This is expected before forest deployment.' }
}
Write-Host 'PASS: read-only preflight finished.'
