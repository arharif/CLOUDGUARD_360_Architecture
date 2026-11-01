param([string]$Prefix = 'cg360')
$ErrorActionPreference = 'Stop'
Write-Host '--- Terraform outputs ---'
terraform output
Write-Host '--- Resource groups ---'
az group show --name "rg-$Prefix-network" --query '{Name:name,Location:location}' -o table
az group show --name "rg-$Prefix-app" --query '{Name:name,Location:location}' -o table
Write-Host '--- Virtual networks ---'
az network vnet show -g "rg-$Prefix-network" -n "vnet-$Prefix-hub" --query '{Name:name,AddressSpace:addressSpace.addressPrefixes}' -o json
az network vnet show -g "rg-$Prefix-app" -n "vnet-$Prefix-app" --query '{Name:name,AddressSpace:addressSpace.addressPrefixes}' -o json
Write-Host '--- Peerings ---'
az network vnet peering list -g "rg-$Prefix-network" --vnet-name "vnet-$Prefix-hub" --query '[].{Name:name,State:peeringState}' -o table
az network vnet peering list -g "rg-$Prefix-app" --vnet-name "vnet-$Prefix-app" --query '[].{Name:name,State:peeringState}' -o table
