variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "shared_vpc_name" {
    type = string
}

variable "cloud_build" {
  type = object({
    shared_vpc = string
    service_account = string
  })
  default = {
    shared_vpc      = ""
    service_account = ""
  }
}