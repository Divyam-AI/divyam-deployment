variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "divyam_db_user_name" {
  type = string  
}

variable "divyam_db_password" {
  type = string
  sensitive = true
}

variable "divyam_clickhouse_user_name" {
  type = string  
}

variable "divyam_clickhouse_password" {
  type = string
  sensitive = true
}

variable "divyam_jwt_secret_key" {
  type = string
  sensitive = true
}

variable "divyam_provider_keys_encryption_key" {
  type = string
  sensitive = true
}


variable "divyam_openai_billing_api_key" {
  type = string
  sensitive = true
}