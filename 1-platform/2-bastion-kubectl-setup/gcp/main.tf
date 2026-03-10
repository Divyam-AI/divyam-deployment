# Run setup-kubectl on the bastion host after the cluster exists.
# No dependency on bastion module: bastion name/zone/project from values; uses gcloud compute ssh (ADC).

variable "create" {
  description = "When true, run setup-kubectl on bastion (bastion.create and bastion.configure_kubectl from values)"
  type        = bool
  default     = false
}

variable "bastion_name" {
  description = "Bastion instance name from values"
  type        = string
  default     = ""
}

variable "bastion_zone" {
  description = "Bastion zone from values (e.g. us-central1-a)"
  type        = string
  default     = ""
}

variable "project_id" {
  description = "GCP project ID (resource_scope.name)"
  type        = string
  default     = ""
}

variable "cluster_trigger" {
  description = "Value from 1-k8s (e.g. cluster_endpoints json) used as trigger so this runs after cluster exists"
  type        = string
  default     = ""
}

resource "null_resource" "bastion_setup_kubectl" {
  count = var.create && var.bastion_name != "" && var.bastion_zone != "" && var.project_id != "" && var.cluster_trigger != "" ? 1 : 0

  triggers = {
    cluster_trigger = var.cluster_trigger
    bastion_name    = var.bastion_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ZONE=$(basename "${var.bastion_zone}")
      gcloud compute ssh "${var.bastion_name}" --zone="$ZONE" --project="${var.project_id}" --command='sudo setup-kubectl'
    EOT
    interpreter = ["bash", "-c"]
  }
}
