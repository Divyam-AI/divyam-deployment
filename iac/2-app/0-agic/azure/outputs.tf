output "agic_release_name" {
  description = "AGIC Helm release name."
  value       = helm_release.agic.name
}

output "agic_release_status" {
  description = "AGIC Helm release status."
  value       = helm_release.agic.status
}

output "agic_namespace" {
  description = "Namespace where AGIC is deployed."
  value       = helm_release.agic.namespace
}
