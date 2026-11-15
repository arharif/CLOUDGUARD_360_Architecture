output "app_url" {
  description = "HTTPS public demonstration endpoint. Do not send sensitive data."
  value       = "https://${azurerm_container_app.voting.ingress[0].fqdn}"
}

output "container_app_name" {
  value = azurerm_container_app.voting.name
}

output "deployed_region" {
  value = local.region
}

output "network_integration" {
  value = "NOT integrated with Phase 01 VNet in the cost-controlled lab"
}
