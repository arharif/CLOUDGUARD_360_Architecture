variable "github_oidc_subject" {
  type        = string
  description = "Exact GitHub OIDC sub, retrieved from a signed GitHub Actions ID token (never guessed)."
  validation {
    condition     = can(regex("^repo:.*:environment:cloudguard360-lab$", var.github_oidc_subject))
    error_message = "OIDC subject must match the phase04 cloudguard360-lab deployment environment."
  }
}
