output "application_region" {
  description = "Region of the EXISTING application VNet."
  value       = data.azurerm_virtual_network.app.location
}
output "policy_assignment_count" {
  description = "Policy resources managed by this isolated Terraform root."
  value       = length(azurerm_resource_group_policy_assignment.locations_audit)
}
