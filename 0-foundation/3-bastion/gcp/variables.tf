variable "create" {
  description = "Whether to create the bastion host and firewall"
  type        = bool
  default     = false
}

variable "project_id" {
  description = "The host project ID where the VPC resides"
  type        = string
}

variable "bastion_name" {
  description = "Name of the bastion instance"
  type        = string
  default     = "bastion-vm"
}

variable "region" {
  description = "GCP Region for the bastion VM"
  type        = string
}

variable "zone" {
  description = "GCP Zone for the bastion VM"
  type        = string
}

variable "network" {
  description = "Name of the VPC Network"
  type        = string
}

variable "subnet" {
  description = "Self link or identifier of the VPC subnet"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the bastion host"
  type        = string
  default     = "e2-micro"
}

variable "spot_instance" {
  description = "When true, create a spot (preemptible) VM; when false, regular on-demand."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Network tags to attach to the instance"
  type        = list(string)
  default     = ["bastion"]
}

# When true, kubectl is installed and a setup script is added; cluster details come from k8s section.
variable "configure_kubectl" {
  description = "If true, install kubectl and a setup script to fetch cluster credentials (cluster details from k8s section)"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Cluster name from k8s section"
  type        = string
  default     = ""
}

variable "cluster_region" {
  description = "Region of the cluster (from k8s/root)"
  type        = string
  default     = ""
}

variable "cluster_project_id" {
  description = "Project ID containing the cluster"
  type        = string
  default     = ""
}
