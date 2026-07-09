# Names/addresses consumed by the GKE Ingress annotations (k8s side) and DNS.

output "static_ip_addresses" {
  description = "Map of reserved global address name -> IP address (for DNS A records)."
  value       = { for k, v in google_compute_global_address.ip : k => v.address }
}

output "ssl_cert_names" {
  description = "Managed SSL cert names (Ingress ingress.gcp.kubernetes.io/pre-shared-cert)."
  value       = keys(local.certs)
}

output "security_policy_names" {
  description = "Cloud Armor policy names (BackendConfig spec.securityPolicy.name)."
  value       = keys(local.pols)
}
