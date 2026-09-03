variable "env_name" {
  description = "Deployment environment name (e.g. dev, prod)"
  type        = string
}

variable "stack" {
  description = "Divyam stack selector: a comma-separated list of router, evalm8, self-serve — or all. The evalm8 service accounts are added only when stack is not router."
  type        = string
  default     = "all"
}
