variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The region where resources will be created."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "cloud_armor_policy_name" {
  description = "Cloud Armor Policy Name"
  type        = string
}

variable "rate_limit_ip_ranges" {
  description = "List of IP ranges to apply Rate Limit"
  type        = list(string)
  default     = ["*"]  # IP range
}

variable "bad_ip_ranges" {
  description = "List of IP ranges to block"
  type        = list(string)
  default     = ["203.0.113.0/24"]  # Example bad IP range
}

variable "rate_limit_threshold_count" {
  description = "Rate limit threshold count"
  type        = number
  default     = 100
}

variable "rate_limit_threshold_interval_sec" {
  description = "Rate limit threshold interval in seconds"
  type        = number
  default     = 60
}

variable "rate_limit_ban_threshold_count" {
  description = "Rate Limit Ban threshold count"
  type        = number
  default     = 200
}

variable "rate_limit_ban_threshold_interval_sec" {
  description = "Rate Limit Ban threshold interval in seconds"
  type        = number
  default     = 300
}

variable "rate_limit_ban_duration_sec" {
  description = "Duration for which the IP will be banned in seconds"
  type        = number
  default     = 600
}