variable "env_name" {
  description = "Deployment environment (e.g. dev, prod)"
  type        = string
}

variable "resource_scope" {
  description = "If create=true, create the resource group; if false, use a data source to reference existing by resource_group_name"
  type = object({
    name   = string
    create = bool
  })
}

variable "org_id" {
  description = "Numeric organization ID (use when project is under an org)"
  type        = string
  default     = ""
}

variable "folder_id" {
  description = "Folder ID (use when project is under a folder instead of org)"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID to associate with the project"
  type        = string
  default     = ""
}