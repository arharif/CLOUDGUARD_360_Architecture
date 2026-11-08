variable "resource_group_name" {
  description = "An EXISTING Phase 01 application resource group. Terraform only looks it up."
  type        = string
  default     = "rg-cg360-app"
}
variable "vnet_name" {
  description = "An EXISTING Phase 01 application VNet, used to discover the allowed region."
  type        = string
  default     = "vnet-cg360-app"
}
variable "enable_policy_audit" {
  description = "OFF by default. Set true only after confirming the scope and permissions."
  type        = bool
  default     = false
}
