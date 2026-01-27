variable "project_id" {
  description = "The host project ID where the Shared VPC resides"
  type        = string
}

variable "bastion_name" {
  description = "Name of the bastion instance"
  type        = string
  default     = "bastion-vm"
}

variable "region" {
  description = "GCP Region for the bastion VM"
  type        = string
}

variable "zone" {
  description = "GCP Zone for the bastion VM"
  type        = string
}

variable "network" {
  description = "Name of the VPC Network"
  type        = string 
}

variable "subnet" {
  description = "Name of the VPC subnet"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the bastion host"
  type        = string
  default     = "e2-micro"
}

variable "tags" {
  description = "Network tags to attach to the instance"
  type        = list(string)
  default     = ["bastion"]
}