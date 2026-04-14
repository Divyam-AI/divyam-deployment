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

variable "nap_common_tags" {
  description = "Common tags passed from root values; rendered locally for this module."
  type        = map(string)
  default     = {}
}

variable "nap_tag_globals" {
  description = "Template globals used to render nap_common_tags."
  type        = map(string)
  default     = {}
}

variable "nap_tag_context" {
  description = "Per-module context used to render nap_common_tags."
  type        = map(string)
  default     = {}
}
