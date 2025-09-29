variable "location" {
  type        = string
  description = "The Azure region where all resources will be deployed (e.g., East US, West Europe)."
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all azure resources"
  type        = map(string)
}

variable "resource_group_name" {
  type        = string
  description = "The name of the existing Azure Resource Group in which to create resources."
}

variable "bastion_name" {
  type        = string
  description = "The name of the Bastion host VM and associated resources (NIC, NSG, etc.)."
}

variable "vm_size" {
  type        = string
  description = "The Azure VM size to use for the Bastion host (e.g., Standard_B1s, Standard_DS1_v2)."
  default     = "Standard_B1s"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the Bastion VM SSH access."
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "The path to the local SSH public key file to be used for VM login."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}

variable "subnet_ids" {
  description = "Map of subnet resource IDs"
  type        = map(string)
}

variable "subnet_names" {
  description = "List of subnet names"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Map of subnet CIDR prefixes"
  type        = map(string)
}

variable "vnet_subnet_name" {
  description = "The name of the subnet to use"
  type        = string
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type = string
}

variable "aks_kube_config_raw" {
  description = "AKS cluster raw kube configs"
  type        = string
}

