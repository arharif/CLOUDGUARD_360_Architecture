# RELEASE B: enable_role_assignments must be explicitly set to true.
# These are group-scoped permission GRANTS, not Entra directory administrator roles.
locals {
  assignments = {
    engineer_network_reader = {
      group_key = "cloud_engineers"
      role      = "Reader"
      scope     = data.azurerm_resource_group.network.id
    }
    engineer_app_reader = {
      group_key = "cloud_engineers"
      role      = var.enable_app_contributor ? "Contributor" : "Reader"
      scope     = data.azurerm_resource_group.app.id
    }
    developer_app_reader = {
      group_key = "developers"
      role      = "Reader"
      scope     = data.azurerm_resource_group.app.id
    }
    auditor_network_reader = {
      group_key = "security_auditors"
      role      = "Reader"
      scope     = data.azurerm_resource_group.network.id
    }
    auditor_app_reader = {
      group_key = "security_auditors"
      role      = "Reader"
      scope     = data.azurerm_resource_group.app.id
    }
    ops_network_monitoring = {
      group_key = "operations"
      role      = "Monitoring Reader"
      scope     = data.azurerm_resource_group.network.id
    }
    ops_app_monitoring = {
      group_key = "operations"
      role      = "Monitoring Reader"
      scope     = data.azurerm_resource_group.app.id
    }
  }
}

resource "azurerm_role_assignment" "lab" {
  for_each             = var.enable_role_assignments ? local.assignments : {}
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_group.lab[each.value.group_key].object_id
  principal_type       = "Group"
  description          = "CloudGuard 360 Phase 02 lab: ${each.key}"
}
