output "bastion_ip" {
  description = "Public IP address of the bastion instance"
  value       = var.create ? google_compute_instance.bastion[0].network_interface[0].access_config[0].nat_ip : null
}

output "bastion_name" {
  description = "Name of the bastion instance"
  value       = var.create ? google_compute_instance.bastion[0].name : null
}

output "bastion_zone" {
  description = "Zone where the bastion instance runs"
  value       = var.create ? google_compute_instance.bastion[0].zone : null
}
