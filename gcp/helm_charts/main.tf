resource "kubernetes_namespace" "divyam_namespaces" {
  for_each = toset(var.namespace_names)

  metadata {
    name = each.key
  }
}
