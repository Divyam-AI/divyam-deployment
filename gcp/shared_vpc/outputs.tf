output "network_name" {
  description = "The name of the Shared VPC network"
  value       = google_compute_network.shared_vpc.name
}

output "network_self_link" {
  description = "The self-link of the Shared VPC network"
  value       = google_compute_network.shared_vpc.self_link
}

output "subnet_names" {
  description = "The names of the created subnets"
  value       = [for s in google_compute_subnetwork.subnets : s.name]
}

output "subnet_ids" {
  description = "The IDs of the created subnets"
  value       = { for k, s in google_compute_subnetwork.subnets : k => s.id }
}

output "host_project" {
  description = "The host project ID enabled for Shared VPC"
  value       = google_compute_shared_vpc_host_project.host.project
}