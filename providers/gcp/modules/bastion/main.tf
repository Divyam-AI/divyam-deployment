resource "google_compute_firewall" "iap_ssh" {
  name    = "allow-ssh"
  network = var.network
  project = var.project_id

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = var.tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "bastion" {
  name         = var.bastion_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = var.subnet

    access_config {      
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
  EOT

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
  }
}