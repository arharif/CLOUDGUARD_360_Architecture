provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

# Uses the logged-in Azure CLI tenant. Never put credentials in .tf files.
provider "azuread" {}
