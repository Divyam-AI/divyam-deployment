variable "resource_group_name" {
  description = "Resource group containing the AKS and App Gateway resources."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "OIDC issuer URL from AKS for workload identity federation."
  type        = string
}

variable "kube_config" {
  description = "AKS kubeconfig object from the 1-k8s dependency (kube_config[0] block)."
  type = object({
    host                   = string
    client_certificate     = string
    client_key             = string
    cluster_ca_certificate = string
  })
  sensitive = true
}

variable "app_gateway_name" {
  description = "Application Gateway name used by AGIC."
  type        = string
}

variable "app_gateway_id" {
  description = "Application Gateway resource ID."
  type        = string
}

variable "gateway_subnet_id" {
  description = "Subnet ID where the Application Gateway is attached."
  type        = string
}

variable "agic_identity_id" {
  description = "Resource ID of the AGIC user-assigned identity."
  type        = string
}

variable "agic_identity_client_id" {
  description = "Client ID of the AGIC user-assigned identity."
  type        = string
}

variable "agic_identity_principal_id" {
  description = "Principal (object) ID of the AGIC user-assigned identity."
  type        = string
}

variable "agic_helm_version" {
  description = "AGIC helm chart version."
  type        = string
}

variable "namespace" {
  description = "Namespace for AGIC deployment."
  type        = string
  default     = "kube-system"
}

variable "release_name" {
  description = "Helm release name for AGIC. Defaults to <cluster_name>-ingress-azure."
  type        = string
  default     = null
}

variable "verbosity_level" {
  description = "AGIC log verbosity level."
  type        = number
  default     = 3
}
