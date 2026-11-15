# We READ the infrastructure already owned by Phase 01.
# No azurerm_resource_group or azurerm_virtual_network resource is managed here.
data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "app" {
  name                = var.application_vnet_name
  resource_group_name = data.azurerm_resource_group.app.name
}

locals {
  # The RG's metadata region may differ from the VNet's actual resource region.
  region = var.location_override != "" ? var.location_override : data.azurerm_virtual_network.app.location

  tags = {
    project     = "CloudGuard360"
    phase       = "03"
    environment = "lab"
    managed_by  = "terraform"
  }
}

# Cost-aware default: no Log Analytics workspace, no VNet injection, no dedicated workload profile.
# Azure Container Apps environment is separate from the existing Phase 01 VNet.
resource "azurerm_container_app_environment" "lab" {
  name                = "cae-cg360-lab"
  location            = local.region
  resource_group_name = data.azurerm_resource_group.app.name
  tags                = local.tags
}

# In this demo the two containers share a single network namespace/lifecycle.
# Redis is reachable at localhost:6379 and is NOT exposed to the internet.
resource "azurerm_container_app" "voting" {
  name                         = "ca-cg360-voting"
  container_app_environment_id = azurerm_container_app_environment.lab.id
  resource_group_name          = data.azurerm_resource_group.app.name
  revision_mode                = "Single"
  tags                         = local.tags

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = "vote-frontend"
      image  = var.frontend_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "REDIS"
        value = "localhost"
      }
    }

    container {
      name   = "redis"
      image  = var.redis_image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    allow_insecure_connections = false
    transport                  = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
