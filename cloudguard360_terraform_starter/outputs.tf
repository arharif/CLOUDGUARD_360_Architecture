output "resource_group_names" {
  description = "Resource groups created by the starter module."
  value = {
    network = azurerm_resource_group.network.name
    app     = azurerm_resource_group.app.name
  }
}

output "vnet_names" {
  description = "Created Azure VNet names."
  value = {
    hub = azurerm_virtual_network.hub.name
    app = azurerm_virtual_network.app.name
  }
}

output "vnet_address_spaces" {
  description = "Non-overlapping network ranges."
  value = {
    hub = azurerm_virtual_network.hub.address_space
    app = azurerm_virtual_network.app.address_space
  }
}

output "subnet_ids" {
  description = "Subnets for the Hub, workloads and future private endpoints."
  value = {
    hub_shared        = azurerm_subnet.hub_shared.id
    app_workload      = azurerm_subnet.app_workload.id
    app_private       = azurerm_subnet.app_private.id
  }
}

output "nsg_id" {
  description = "Workload subnet's Network Security Group."
  value       = azurerm_network_security_group.workload.id
}
