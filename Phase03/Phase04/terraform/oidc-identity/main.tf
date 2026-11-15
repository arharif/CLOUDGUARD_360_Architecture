# Independent root. It does NOT own or recreate the existing app, VNets or RG.
data "azurerm_resource_group" "app" {
  name = var.resource_group_name
}

data "azurerm_container_app" "voting" {
  name                = var.container_app_name
  resource_group_name = data.azurerm_resource_group.app.name
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "uami-cg360-github-actions"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_container_app.voting.location
  tags = {
    project     = "CloudGuard360"
    phase       = "04"
    managed_by  = "terraform"
    environment = "lab"
  }
}

# GitHub Actions OIDC subject includes the exact GitHub Environment name.
resource "azurerm_federated_identity_credential" "github_environment" {
  name                = "fic-cg360-release"
  resource_group_name = data.azurerm_resource_group.app.name
  parent_id           = azurerm_user_assigned_identity.github.id
  issuer              = "https://token.actions.githubusercontent.com"
  audience            = ["api://AzureADTokenExchange"]
  subject             = "repo:${var.github_repository}:environment:${var.github_environment}"
}

# Built-in role can update OR delete the scoped Container App: manual workflow approval required.
resource "azurerm_role_assignment" "app_deployer" {
  count                = var.enable_deployment_role ? 1 : 0
  scope                = data.azurerm_container_app.voting.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
