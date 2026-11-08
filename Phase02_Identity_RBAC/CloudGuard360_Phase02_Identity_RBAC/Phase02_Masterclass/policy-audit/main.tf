# A completely separate Terraform state. No changes to Phase 01 VNets or Phase 02 groups/RBAC.
data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "app" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.app.name
}

# Azure built-in definition: Allowed locations (parameters: listOfAllowedLocations + effect).
# Audit reports noncompliance; it DOES NOT deny resource creation.
resource "azurerm_resource_group_policy_assignment" "locations_audit" {
  count                = var.enable_policy_audit ? 1 : 0
  name                 = "cg360-locations-audit"
  display_name         = "CloudGuard 360 - Allowed Locations (Audit)"
  description          = "CloudGuard 360 lab-only region compliance audit; nonblocking."
  resource_group_id    = data.azurerm_resource_group.app.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = [data.azurerm_virtual_network.app.location]
    }
    effect = {
      value = "Audit"
    }
  })
}
