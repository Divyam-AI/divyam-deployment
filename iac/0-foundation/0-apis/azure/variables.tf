variable "provider_namespaces" {
  type        = list(string)
  description = "List of Azure Resource Provider namespaces to register (e.g. Microsoft.Compute)"
  default     = []
}

variable "enabled" {
  type        = bool
  description = "Whether to register the listed resource providers"
  default     = true
}
