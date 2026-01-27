variable "instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
}

variable "project_id" {
  description = "The GCP Project to deploy the Cloud SQL instance in"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy the Cloud SQL instance in"
  type        = string
}

variable "vpc_network_name" {
  description = "The VPC network name to deploy the Cloud SQL instance in"
  type        = string
}

variable "vpc_network" {
  description = "The VPC network to deploy the Cloud SQL instance in"
  type        = string
}

variable "divyam_db_user" {
  description = "The username for the Cloud SQL instance"
  type        = string
}

variable "divyam_db_password" {
  description = "The password for the Cloud SQL user. Do: export TF_VAR_db_password=\"secure-password-123\""
  type        = string
  sensitive   = true
}

variable "divyam_db_name" {
  description = "The name of the initial database to create"
  type        = string
  default = "divyam"
}