variable "enabled" {
  description = "When true, create GKE cluster(s). When false, fetch existing by name and output details."
  type        = bool
  default     = true
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "Default region for the provider"
  type        = string
}

variable "cluster_name" {
  description = "Cluster name to look up when enabled = false (must match k8s.name in defaults)."
  type        = string
  default     = null
}

variable "clusters" {
  description = "Map of cluster configurations. Key = cluster name. Empty when enabled = false (existing cluster fetched by cluster_name)."
  type = map(object({
    region                  = string
    release_channel         = string                            # REGULAR, RAPID, STABLE
    enable_autopilot        = bool                              # true = GKE Autopilot (node_provisioning_mode Auto), false = standard with node_config
    machine_type            = optional(string, "e2-standard-4") # for standard GKE when enable_autopilot = false
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    network                 = string
    subnetwork              = string
    master_authorized_networks_cidr = list(object({
      cidr_block   = string
      display_name = string
    }))
    cluster_ipv4_cidr          = string
    services_ipv4_cidr         = string
    additional_pod_range_names = list(string)
    binauthz_evaluation_mode   = string
    dns_scope                  = string
    dns_domain                 = string
    enable_workload_logs       = bool
    enable_cluster_logs        = bool
  }))
  default = {}
}

variable "additional_node_pools" {
  description = "Additional node pools (e.g. GPU). Used only when cluster enable_autopilot = false. Key = pool name."
  type = map(object({
    machine_type = string
    node_count   = optional(number, 1)
    auto_scaling = optional(bool, false)
    min_count    = optional(number, null)
    max_count    = optional(number, null)
    node_taints  = optional(list(string), []) # "key=value:NoSchedule" format, converted to GCP taint block
    node_labels  = optional(map(string), {})
  }))
  default = {}
}

variable "logs_retention_days" {
  description = "Retention in days for the project _Default log bucket (GKE, LB, and other project logs). GCP max = 3650; values above 3650 are capped at 3650."
  type        = number
  default     = 7
}
