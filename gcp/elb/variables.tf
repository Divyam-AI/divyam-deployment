variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "create_public_lb" {
  type        = bool
  default     = true
  description = "Toggle public vs private LB"
}

variable "ssl_certificate_id" {
  type        = string
  description = "SSL Certificate ID"
  default     = null
}

variable "static_ip_name" {
  type        = string
  description = "Name of pre-reserved global static IP"
}

variable "cloud_armor_policy_id" {
  type        = string
  description = "Cloud Armor policy ID"
}

variable "backend_service_name" {
  type    = string
  default = "gke-backend-service"
}

variable "target_proxy_name" {
  type    = string
  default = "gke-https-proxy"
}

variable "gke_neg_names" {
  type        = list(string)
  description = "List of GKE NEG names (one per zone)"
}

variable "gke_neg_zones" {
  type        = list(string)
  description = "List of zones matching the NEG names"
}

variable "subnetwork" {
  type        = string
  description = "Subnetwork for internal LB (only used if private)"
  default     = ""
}

variable "network" {
  type        = string
  description = "Network for internal LB (only used if private)"
  default     = ""
}