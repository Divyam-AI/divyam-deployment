output "bastion_vm_id" {
  description = "The ID of the Bastion virtual machine."
  value       = var.create ? azurerm_linux_virtual_machine.bastion[0].id : null
}

output "bastion_vm_name" {
  description = "The name of the Bastion virtual machine."
  value       = var.create ? azurerm_linux_virtual_machine.bastion[0].name : null
}

output "bastion_vm_private_ip" {
  description = "The private IP address of the Bastion virtual machine."
  value       = var.create ? azurerm_network_interface.bastion_nic[0].private_ip_address : null
}

output "bastion_vm_public_ip" {
  description = "The public IP address of the Bastion virtual machine."
  value       = var.create ? azurerm_public_ip.bastion_pip[0].ip_address : null
}

output "bastion_ssh_connection" {
  description = "SSH command to connect to the Bastion host."
  value       = var.create ? "ssh ${var.admin_username}@${azurerm_public_ip.bastion_pip[0].ip_address}" : null
}
