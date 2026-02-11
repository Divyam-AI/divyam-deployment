variable "enabled" {
  description = "Enable alerts"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region (e.g., us-central1)"
  type        = string
}

variable "rules" {
  type = list(object({
    name         = string
    display_name = string
    combiner     = string
    severity     = string
    condition = object({
      display_name        = string
      query               = string
      duration            = string
      evaluation_interval = string
      alert_rule          = optional(string)
      rule_group          = optional(string)
    })
    alert_strategy = object({
      auto_close           = string
      notification_prompts = list(string)
    })
  }))
}


variable "notification_channels" {
  description = "Notification channels for receiving alerts"
  type        = list(string)
}

