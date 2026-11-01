variable "prefix" {
  description = "A short prefix for laboratory Microsoft Entra groups."
  type        = string
  default     = "CG360"
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]{2,14}$", var.prefix))
    error_message = "Prefix: start with a letter; use 3-15 letters, numbers or hyphens."
  }
}

variable "app_resource_group" {
  description = "Name of the existing Application resource group from Phase 01."
  type        = string
  default     = "rg-cg360-app"
}

variable "network_resource_group" {
  description = "Name of the existing Network resource group from Phase 01."
  type        = string
  default     = "rg-cg360-network"
}

variable "enable_role_assignments" {
  description = "Release B only: create seven read-only, resource-group-scoped Azure RBAC assignments."
  type        = bool
  default     = false
}

variable "enable_app_contributor" {
  description = "Optional explicit privilege elevation for the cloud engineers group on the app RG only. Default false."
  type        = bool
  default     = false
}

variable "demo_member_object_id" {
  description = "Optional existing Entra USER object ID added to Developers group; leave empty unless expressly testing."
  type        = string
  default     = ""
  validation {
    condition     = var.demo_member_object_id == "" || can(regex("^[0-9a-fA-F-]{36}$", var.demo_member_object_id))
    error_message = "Set an empty string or a 36-character Entra user object ID."
  }
}
