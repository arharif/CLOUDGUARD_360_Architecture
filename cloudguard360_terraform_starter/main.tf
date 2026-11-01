# Step 01 creates two resource groups. No VMs, public IPs, firewalls, or AKS.
resource "azurerm_resource_group" "network" {
  name     = "rg-${var.prefix}-network"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${var.prefix}-app"
  location = var.location
  tags     = var.tags
}
