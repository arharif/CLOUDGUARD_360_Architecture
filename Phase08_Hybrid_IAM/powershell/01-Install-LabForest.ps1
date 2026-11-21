# DANGEROUS ON A NON-LAB SYSTEM. Use only inside a disposable Windows Server VM.
# This changes the OS into an AD DS domain controller and restarts it.
# Fixed isolated lab DNS namespace: corp.cg360.test
# Microsoft documentation: https://learn.microsoft.com/windows-server/identity/ad-ds/deploy/install-active-directory-domain-services--level-100-
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$targetDomain = 'corp.cg360.test'
$os = Get-CimInstance Win32_OperatingSystem
if ($os.ProductType -eq 1) { throw 'REFUSED: This command requires Windows Server in an isolated LAB VM.' }
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.PartOfDomain) { throw 'REFUSED: This VM is already domain-joined. Never modify an existing domain.' }
if (Get-Service NTDS -ErrorAction SilentlyContinue) { throw 'REFUSED: Active Directory Domain Services already appears to be installed.' }
Write-Host 'THIS WILL CREATE A NEW AD FOREST AND RESTART THIS WINDOWS SERVER VM.' -ForegroundColor Yellow
Write-Host "Domain: $targetDomain; expected use: private disposable lab VM only."
$confirmation = Read-Host 'To proceed, enter exactly INSTALL LAB FOREST'
if ($confirmation -cne 'INSTALL LAB FOREST') { throw 'Canceled. No changes made.' }
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Out-Host
Import-Module ADDSDeployment
$dsrm = Read-Host 'Enter a strong Directory Services Restore Mode password (DSRM)' -AsSecureString
Install-ADDSForest -DomainName $targetDomain -DomainNetbiosName 'CG360' -InstallDNS -SafeModeAdministratorPassword $dsrm -Force
# The OS normally reboots during the promotion.
