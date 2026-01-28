
variable "enabled" {
  description = "Enable GKE cluster creation"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "Default region for the provider"
  type        = string
}

variable "clusters" {
  description = "A map of cluster configurations. The key is the cluster name."
  type = map(object({
    region                   = string
    release_channel          = string # Allowed values: "REGULAR", "RAPID", "STABLE"
    enable_private_nodes     = bool
    enable_private_endpoint  = bool
    network                  = string
    subnetwork               = string
    master_authorized_networks_cidr = list(object({
      cidr_block   = string
      display_name = string
    }))
    cluster_ipv4_cidr        = string
    services_ipv4_cidr       = string
    additional_pod_range_names = list(string)
    binauthz_evaluation_mode = string # e.g., "DISABLED".
    dns_scope                = string
    dns_domain               = string
    enable_workload_logs     = bool
    enable_cluster_logs      = bool
  }))
}
