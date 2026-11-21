# Phase 04 — isolated Terraform root, separate state from phases 01, 02 and 03.
# Data lookups only: the existing RG and app are NOT created or destroyed by this root.
data "azurerm_resource_group" "app" {
  name = "rg-cg360-app"
}

data "azurerm_container_app" "voting" {
  name                = "ca-cg360-voting"
  resource_group_name = data.azurerm_resource_group.app.name
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "uami-cg360-phase04"
  resource_group_name = data.azurerm_resource_group.app.name
  location            = data.azurerm_container_app.voting.location
  tags = {
    project = "CloudGuard360"
    phase   = "04"
  }
}

resource "azurerm_federated_identity_credential" "github_env" {
  name                = "fic-cg360-gh-actions"
  resource_group_name = data.azurerm_resource_group.app.name
  parent_id           = azurerm_user_assigned_identity.github.id
  issuer              = "https://token.actions.githubusercontent.com"
  audience            = ["api://AzureADTokenExchange"]
  subject             = var.github_oidc_subject
}

# Container Apps Contributor includes broad rights on THIS app (including delete).
# Manual dispatch + environment protection required; scope is NOT the whole RG.
resource "azurerm_role_assignment" "deploy" {
  scope                = data.azurerm_container_app.voting.id
  role_definition_name = "Container Apps Contributor"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
  principal_type       = "ServicePrincipal"
}
