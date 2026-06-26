variable "env_name" {
  description = "Deployment environment name (e.g. dev, prod)"
  type        = string
}

variable "stack" {
  description = "Divyam stack selector (evalm8, router, both). The evalm8 service accounts are added only when stack is not router."
  type        = string
  default     = "both"
}
