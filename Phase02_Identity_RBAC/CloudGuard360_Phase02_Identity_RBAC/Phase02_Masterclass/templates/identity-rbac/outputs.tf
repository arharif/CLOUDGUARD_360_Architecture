output "security_group_names" {
  description = "Display names of the four managed Entra security groups."
  value       = { for key, group in azuread_group.lab : key => group.display_name }
}

output "security_group_ids" {
  description = "Directory object IDs; do not publish to public repositories."
  value       = { for key, group in azuread_group.lab : key => group.object_id }
  sensitive   = true
}

output "rbac_assignment_count" {
  description = "Number of role assignments managed by this separate Phase 02 state."
  value       = length(azurerm_role_assignment.lab)
}

output "target_resource_groups" {
  value = {
    app     = data.azurerm_resource_group.app.name
    network = data.azurerm_resource_group.network.name
  }
}
