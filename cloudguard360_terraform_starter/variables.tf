variable "prefix" {
  description = "Short, lowercase prefix used for the laboratory resources."
  type        = string
  default     = "cg360"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.prefix))
    error_message = "prefix must be 2-15 lowercase characters, numbers or hyphens, starting with a letter."
  }
}

variable "location" {
  description = "Azure region for the starter network."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Common tags applied to resources that support tagging."
  type        = map(string)
  default = {
    project     = "CloudGuard360"
    environment = "lab"
    managed_by  = "terraform"
  }
}
