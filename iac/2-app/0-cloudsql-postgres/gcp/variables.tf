variable "create" {
  description = "When true, create GCP Cloud SQL for PostgreSQL and supporting resources."
  type        = bool
  default     = false
}

variable "create_private_service_access" {
  description = "When true, create the private service access peering (global address + connection). Set false in a VPC that already has it (e.g. shared with the MySQL cloudsql unit) to reuse the existing peering."
  type        = bool
  default     = true
}

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
  description = "The VPC network self-link to deploy the Cloud SQL instance in"
  type        = string
}

# Names are prefixed divyam_selfserve_pg_* so they map to TF_VAR_divyam_selfserve_pg_* and do NOT
# collide with the deployment-wide TF_VAR_divyam_db_* (the general/MySQL DB credentials) that
# secrets.env exports — a collision there silently shadows these with the wrong password.
variable "divyam_selfserve_pg_user_name" {
  description = "The app username for the self-serve Cloud SQL Postgres instance"
  type        = string
}

variable "divyam_selfserve_pg_password" {
  description = "The password for the self-serve Postgres app user. Use TF_VAR."
  type        = string
  sensitive   = true
}

variable "divyam_selfserve_pg_root_password" {
  description = "Password for the built-in postgres superuser. Empty leaves it unmanaged."
  type        = string
  sensitive   = true
  default     = ""
}

variable "divyam_selfserve_pg_db_name" {
  description = "The name of the initial database to create"
  type        = string
  default     = "divyam"
}
