variable "resource_group_name" {
  description = "Existing Phase 01 resource group. This configuration will NOT create or destroy it."
  type        = string
  default     = "rg-cg360-app"
}

variable "application_vnet_name" {
  description = "Existing Phase 01 VNet; used to discover its actual deployment location (read-only)."
  type        = string
  default     = "vnet-cg360-app"
}

variable "location_override" {
  description = "Optional alternate region IF Azure Container Apps is supported and permitted there. Empty uses the current application VNet location."
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Microsoft public demo image, NOT production-hardened."
  type        = string
  default     = "mcr.microsoft.com/azuredocs/azure-vote-front:v1"
}

variable "redis_image" {
  description = "Temporary Redis demo sidecar image (no persistent data)."
  type        = string
  default     = "redis:7-alpine"
}
