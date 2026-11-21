output "github_client_id" {
  value       = azurerm_user_assigned_identity.github.client_id
  description = "Public identifier, stored as a GitHub environment secret for convenience."
}
output "federated_subject" {
  value = azurerm_federated_identity_credential.github_env.subject
}
output "scoped_application_id" {
  value = data.azurerm_container_app.voting.id
}
