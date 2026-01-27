output "bastion_vm_id" {
  description = "The ID of the Bastion virtual machine."
  value       = azurerm_linux_virtual_machine.bastion.id
}

output "bastion_vm_name" {
  description = "The name of the Bastion virtual machine."
  value       = azurerm_linux_virtual_machine.bastion.name
}

output "bastion_vm_private_ip" {
  description = "The private IP address of the Bastion virtual machine."
  value       = azurerm_network_interface.bastion_nic.private_ip_address
}

output "bastion_vm_public_ip" {
  description = "The public IP address of the Bastion virtual machine."
  value       = azurerm_public_ip.bastion_pip.ip_address
}

output "bastion_ssh_connection" {
  description = "SSH command to connect to the Bastion host."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.bastion_pip.ip_address}"
}
