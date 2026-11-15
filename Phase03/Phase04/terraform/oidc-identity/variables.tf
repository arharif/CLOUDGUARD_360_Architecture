variable "resource_group_name" {
  description = "Existing Phase 01/03 app resource group. Read-only lookup."
  type        = string
  default     = "rg-cg360-app"
}

variable "container_app_name" {
  description = "Existing Phase 03 Container App. Read-only lookup."
  type        = string
  default     = "ca-cg360-voting"
}

variable "github_repository" {
  description = "Full GitHub repository: owner/repo. OIDC trust is scoped to this repository."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository)) && !strcontains(var.github_repository, "YOUR_")
    error_message = "Set a real GitHub owner/repository, for example example-user/cloudguard360-phase04."
  }
}

variable "github_environment" {
  type    = string
  default = "cloudguard360-lab"
}

variable "enable_deployment_role" {
  description = "Default false: configure identity first; enable scoped RBAC only after permissions review."
  type        = bool
  default     = false
}
