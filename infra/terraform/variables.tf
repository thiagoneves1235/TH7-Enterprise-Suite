variable "subscription_id" {
  description = "Azure subscription ID, supplied through TF_VAR_subscription_id or workload identity."
  type        = string
}

variable "location" {
  description = "Azure region for the development foundation."
  type        = string
  default     = "brazilsouth"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "sandbox"

  validation {
    condition     = contains(["sandbox", "development", "staging", "production"], var.environment)
    error_message = "environment must be sandbox, development, staging or production."
  }
}

variable "registry_name" {
  description = "Globally unique lowercase Azure Container Registry name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{5,50}$", var.registry_name))
    error_message = "registry_name must contain 5-50 lowercase letters or digits."
  }
}

variable "tags" {
  description = "Required ownership and cost-allocation tags."
  type        = map(string)
  default     = {}
}