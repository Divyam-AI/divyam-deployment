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

variable "location" {
  description = "GKE cluster + node pool location. A single zone (e.g. asia-south1-c) makes a zonal cluster; null falls back to region (regional)."
  type        = string
  default     = null
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
    use_spot                = optional(bool, false)             # Spot VMs for the default pool; standard clusters only
    # GKE cost allocation: stamps cluster name and namespace onto the BigQuery billing export, so spend
    # can be attributed per workload rather than per node.
    enable_cost_allocation = optional(bool, false)
    remove_default_node_pool = optional(bool, false)
    # Cluster-wide growth cap for node auto-provisioning. Required to enable it on a standard
    # cluster; GKE expresses the cap as total cores and memory, not a node count.
    node_auto_provisioning = optional(object({
      max_cpu       = number
      max_memory_gb = number
      # Accelerator type -> ceiling. Auto-provisioning cannot create GPU nodes for a type that has
      # no entry here, however a Pod asks for one.
      max_accelerators = optional(map(number), {})
    }), null)
    enable_private_nodes    = bool
    enable_private_endpoint = bool
    network                 = string
    subnetwork              = string
    master_authorized_networks_cidr = list(object({
      cidr_block   = string
      display_name = string
    }))
    # Unset lets GKE allocate the ranges itself.
    cluster_ipv4_cidr          = optional(string, null)
    services_ipv4_cidr         = optional(string, null)
    additional_pod_range_names = list(string)
    binauthz_evaluation_mode   = string
    dns_scope    = string
    dns_domain   = string
  }))
  default = {}
}

variable "additional_node_pools" {
  description = "Additional node pools (e.g. GPU). Used only when cluster enable_autopilot = false. Key = pool name."
  type = map(object({
    machine_type = string
    use_spot     = optional(bool, false) # when true, use Spot VMs for this pool
    node_count   = optional(number, 1)
    auto_scaling = optional(bool, false)
    min_count    = optional(number, null)
    max_count    = optional(number, null)
    node_taints  = optional(list(string), []) # "key=value:NoSchedule" format, converted to GCP taint block
    node_labels  = optional(map(string), {})
  }))
  default = {}
}

