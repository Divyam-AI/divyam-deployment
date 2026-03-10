# Run setup-kubectl on the bastion host after the cluster exists.
# No dependency on bastion module: bastion details are read from values and public IP is fetched from Azure.

variable "create" {
  description = "When true, run setup-kubectl on bastion (bastion.create and bastion.configure_kubectl from values)"
  type        = bool
  default     = false
}

variable "bastion_name" {
  description = "Bastion VM/public IP name from values (public IP resource name is bastion_name-pip)"
  type        = string
  default     = ""
}

variable "resource_group_name" {
  description = "Resource group containing the bastion (from resource_scope.name)"
  type        = string
  default     = ""
}

variable "bastion_admin_username" {
  description = "SSH user for the bastion (from bastion config)"
  type        = string
  default     = "azureuser"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key used to connect to the bastion"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "cluster_id" {
  description = "Cluster ID from 1-k8s (used as trigger so this runs after cluster exists)"
  type        = string
  default     = ""
}

# Fetch bastion public IP from Azure when bastion is configured for creation
data "azurerm_public_ip" "bastion" {
  count               = var.create && var.bastion_name != "" && var.resource_group_name != "" ? 1 : 0
  name                = "${var.bastion_name}-pip"
  resource_group_name = var.resource_group_name
}

resource "null_resource" "bastion_setup_kubectl" {
  count = var.create && var.cluster_id != "" && try(data.azurerm_public_ip.bastion[0].ip_address, "") != "" ? 1 : 0

  triggers = {
    cluster_id = var.cluster_id
    bastion_ip = data.azurerm_public_ip.bastion[0].ip_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      KEY_PATH=$(eval echo "${var.ssh_private_key_path}")
      chmod 600 "$KEY_PATH" 2>/dev/null || true
      ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -i "$KEY_PATH" ${var.bastion_admin_username}@${data.azurerm_public_ip.bastion[0].ip_address} 'sudo setup-kubectl'
    EOT
    interpreter = ["bash", "-c"]
  }
}
