variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "ci_cd" {
  type = object({
    create_iam = bool
    service_account = string
    bucket_access = bool
  })
  default = {
    create_iam      = false
    service_account = ""
    bucket_access   = false
  }
}

variable "artifact_registry" {
  type = object({
    create_iam = bool
    artifact_registry_project = string
    artifact_registry_project_region = string
    service_account = string
    artifact_repositories = list(string)
  })
}

variable "router_controller" {
  type = object({
    create_sa = bool
    namespace = string
    service_account = string
  })
}

variable "secrets_accessor" {
  type = object({
    create_sa = bool
    service_account = string
  })
}

variable "ksa_bindings_for_secret_access" {
  type = list(object({
    namespace = string
    name      = string
  }))
  default = [] # e.g., [{namespace = "default", name = "ksa-a"}]
}

variable "kafka_connect" {
  type = object({
    create_sa = bool
    namespace = string
    service_account = string
  })
}

variable "prometheus_metric_writer" {
  type = object({
    create_iam = bool
    service_account = string
  })
}

variable "default_node_service_account" {
  type = object({
    create_iam = bool
    service_account = string
  })
}

variable "billing" {
  type = object({
    create_sa = bool
    namespace = string
    service_account = string
    billing_project_id = string
    billing_dataset_id = string
  })
}

variable "eval" {
  type = object({
    create_sa = bool
    namespace = string
    service_account = string
  })
}

variable "selector_training" {
  type = object({
    create_sa        = bool
    service_account  = string
    namespace        = string
    bucket_name      = string
  })
}
