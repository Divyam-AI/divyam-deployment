
output "namespace_names" {
  value = [for ns in kubernetes_namespace.divyam_namespaces : ns.metadata[0].name]
}