output "github_azure_client_id" {
  description = "Put this in GitHub environment secret AZURE_CLIENT_ID (not a credential/secret itself)."
  value       = azurerm_user_assigned_identity.github.client_id
}

output "federated_subject" {
  value = azurerm_federated_identity_credential.github_environment.subject
}

output "deployer_scope" {
  value = data.azurerm_container_app.voting.id
}
