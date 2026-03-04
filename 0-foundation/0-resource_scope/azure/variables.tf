variable "region" {
  description = "Azure provider location"
  type        = string
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
    name   = string
    create = bool
  })
}