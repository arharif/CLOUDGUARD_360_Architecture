#!/usr/bin/env bash
set -euo pipefail
PREFIX="${1:-cg360}"

echo "--- Terraform outputs ---"
terraform output
echo "--- Network resource group ---"
az group show --name "rg-${PREFIX}-network" --query '{Name:name,Location:location}' -o table
echo "--- Application resource group ---"
az group show --name "rg-${PREFIX}-app" --query '{Name:name,Location:location}' -o table
echo "--- Hub VNet ---"
az network vnet show -g "rg-${PREFIX}-network" -n "vnet-${PREFIX}-hub" --query '{Name:name,AddressSpace:addressSpace.addressPrefixes}' -o json
echo "--- App VNet ---"
az network vnet show -g "rg-${PREFIX}-app" -n "vnet-${PREFIX}-app" --query '{Name:name,AddressSpace:addressSpace.addressPrefixes}' -o json
echo "--- Hub peerings ---"
az network vnet peering list -g "rg-${PREFIX}-network" --vnet-name "vnet-${PREFIX}-hub" --query '[].{Name:name,State:peeringState}' -o table
echo "--- App peerings ---"
az network vnet peering list -g "rg-${PREFIX}-app" --vnet-name "vnet-${PREFIX}-app" --query '[].{Name:name,State:peeringState}' -o table
