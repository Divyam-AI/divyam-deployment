variable "region" {
  description = "Azure provider location (resource group). When empty and creating, a default is used from cloud where possible."
  type        = string
  default     = ""
}

variable "zone" {
  description = "Azure provider Zone"
  type        = string
}

variable "env_name" {
  description = "Deployment environment"
  type        = string
}

variable "resource_scope" {
  description = "If create=true, create the resource group; if false, use a data source to reference existing by resource_group_name"
  type = object({
    name            = string
    create          = bool
    billing_account = optional(string, "")
  })
}

variable "import_mode" {
  description = "Set to true (e.g. TF_VAR_import_mode=1) when running terraform import so the resource block exists; leave false for normal runs."
  type        = bool
  default     = false
}