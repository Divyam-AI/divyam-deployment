
resource "google_compute_global_address" "private_ip_address" {
  count         = var.create ? 1 : 0
  name          = "google-managed-services-${var.vpc_network_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.create ? 1 : 0
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
}

resource "google_sql_database_instance" "default" {
  count            = var.create ? 1 : 0
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  name             = var.instance_name
  database_version = "MYSQL_8_0"
  project          = var.project_id
  region           = var.region

  settings {
    tier = "db-f1-micro"
    user_labels = {
      for k, v in local.rendered_tags : k => v
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network
    }
    backup_configuration {
      enabled            = true
      start_time         = "03:00" # UTC
      binary_log_enabled = true
    }
  }
}

resource "google_sql_user" "default" {
  count    = var.create ? 1 : 0
  name     = var.divyam_db_user
  instance = google_sql_database_instance.default[0].name
  password = var.divyam_db_password
  project  = var.project_id
}

resource "google_sql_database" "default" {
  count    = var.create ? 1 : 0
  name     = var.divyam_db_name
  instance = google_sql_database_instance.default[0].name
  project  = var.project_id
}
