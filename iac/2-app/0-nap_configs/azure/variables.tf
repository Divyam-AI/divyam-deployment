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
