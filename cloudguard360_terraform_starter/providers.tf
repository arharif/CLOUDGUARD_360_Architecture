# Authenticate with Azure CLI (`az login`) on your own computer.
# The subscription is provided via ARM_SUBSCRIPTION_ID; no account IDs are stored in Git.
provider "azurerm" {
  features {}
  # Avoid requiring broad resource-provider registration permissions.
  # Microsoft.Network and Microsoft.Resources must already be registered by Azure.
  resource_provider_registrations = "none"
}
