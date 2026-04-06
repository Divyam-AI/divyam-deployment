variable "project_id" {
  description = "GCP project ID (scope for buckets)"
  type        = string
}

variable "location" {
  description = "GCP location (region or multi-region) for buckets"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

# Map of logical bucket group key -> { bucket_names = list, create = bool, type = optional string }.
# Same shape as Azure storage_accounts; on GCP each "container" is a GCS bucket.
# create = false uses data sources to fetch existing. type identifies usage (e.g. router-requests-logs).
variable "buckets" {
  description = "Map of logical key to { bucket_names = list, create = bool, type = optional string }. create = false uses data sources. type used for typed outputs (e.g. router-requests-logs)."
  type = map(object({
    bucket_names = list(string)
    create       = optional(bool, true)
    type         = optional(string) # e.g. "router-requests-logs"
  }))
  default = {}
}

variable "router_requests_logs_storage_key" {
  description = "Key in buckets that holds the router-requests-logs storage (set from config type). Used for router_requests_logs_* outputs."
  type        = string
  default     = null
}

variable "storage_class" {
  description = "GCS storage class"
  type        = string
  default     = "STANDARD"
}

variable "versioning_enabled" {
  description = "Enable object versioning on buckets"
  type        = bool
  default     = false
}

variable "force_destroy" {
  description = "Allow bucket deletion even when it contains objects (use with caution)"
  type        = bool
  default     = false
}

variable "hierarchical_namespace_enabled" {
  description = "Enable hierarchical namespace on buckets (object directory-style layout)"
  type        = bool
  default     = true
}
