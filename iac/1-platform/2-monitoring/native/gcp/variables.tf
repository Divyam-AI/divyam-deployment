variable "enabled" {
  type    = bool
  default = true
}

variable "project_id" {
  type = string
}

variable "logs_retention_days" {
  type    = number
  default = 30
}

variable "manage_project_log_bucket" {
  type    = bool
  default = true
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "tag_globals" {
  type    = map(string)
  default = {}
}

variable "tag_context" {
  type    = map(string)
  default = {}
}
