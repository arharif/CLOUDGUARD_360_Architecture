# Hub-and-Spoke networking: the Hub does not contain a firewall or gateway yet.
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.prefix}-hub"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = var.tags
}

resource "azurerm_virtual_network" "app" {
  name                = "vnet-${var.prefix}-app"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags
}

# Do not use AzureFirewallSubnet as a name until actually deploying Azure Firewall.
resource "azurerm_subnet" "hub_shared" {
  name                 = "snet-shared"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "app_workload" {
  name                 = "snet-workload"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "app_private" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.10.2.0/24"]
}

# The NSG has Azure's default rules. Custom allow/deny rules arrive in the next lab.
resource "azurerm_network_security_group" "workload" {
  name                = "nsg-${var.prefix}-workload"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.app_workload.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

# Peering is directional: create both sides. Peering alone is not transitive.
resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                         = "peer-hub-to-app"
  resource_group_name          = azurerm_resource_group.network.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.app.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "app_to_hub" {
  name                         = "peer-app-to-hub"
  resource_group_name          = azurerm_resource_group.app.name
  virtual_network_name         = azurerm_virtual_network.app.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
