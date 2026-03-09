resource "google_compute_firewall" "iap_ssh" {
  count   = var.create || var.import_mode ? 1 : 0
  name    = "allow-ssh-${var.bastion_name}"
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
  count        = var.create || var.import_mode ? 1 : 0
  name         = var.bastion_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags
  project      = var.project_id

  labels = local.rendered_tags

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

  metadata_startup_script = templatefile("${path.module}/scripts/init.tpl", {
    configure_kubectl   = var.configure_kubectl
    cluster_name        = var.cluster_name
    cluster_region     = var.cluster_region
    cluster_project_id  = var.cluster_project_id
  })

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
