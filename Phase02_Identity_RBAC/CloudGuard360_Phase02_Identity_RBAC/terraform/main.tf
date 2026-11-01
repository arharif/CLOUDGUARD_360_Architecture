# Look up EXISTING Phase 01 Resource Groups: this project never manages or deletes them.
data "azurerm_resource_group" "app" {
  name = var.app_resource_group
}

data "azurerm_resource_group" "network" {
  name = var.network_resource_group
}

locals {
  group_definitions = {
    cloud_engineers = {
      display_name = "${var.prefix}-Cloud-Engineers"
      description  = "CloudGuard 360 laboratory cloud engineers; restricted privileges"
    }
    developers = {
      display_name = "${var.prefix}-Developers"
      description  = "CloudGuard 360 application developers; read-only initial access"
    }
    security_auditors = {
      display_name = "${var.prefix}-Security-Auditors"
      description  = "CloudGuard 360 security and compliance review team"
    }
    operations = {
      display_name = "${var.prefix}-Operations"
      description  = "CloudGuard 360 monitoring operations; monitoring read access"
    }
  }
}

# RELEASE A: groups only. Requires permission to create Microsoft Entra groups.
resource "azuread_group" "lab" {
  for_each                = local.group_definitions
  display_name            = each.value.display_name
  description             = each.value.description
  security_enabled        = true
  prevent_duplicate_names = true
}

# Optional controlled group membership: never add someone without their consent.
resource "azuread_group_member" "demo_developer" {
  count            = var.demo_member_object_id == "" ? 0 : 1
  group_object_id  = azuread_group.lab["developers"].object_id
  member_object_id = var.demo_member_object_id
}
