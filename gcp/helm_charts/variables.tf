variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "Default region for the provider"
  type        = string
}

variable "environment" {
  description = "environment name"
  type        = string
}

variable "k8s_cluster_name" {
  description = "K8s Cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "K8s Cluster endpoint"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "K8s Cluster Certificate"
  type        = string
}

variable "namespace_names" {
  type    = list(string)
}

variable "chart_path" {
  description = "Chart path"
  type        = string
}

variable "values_file_path" {
  description = "File path of the Values YAML"
  type        = string
}