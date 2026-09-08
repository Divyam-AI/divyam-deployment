
# google-managed-services-<vpc> and the private service networking connection are VPC-scoped
# singletons. Gated on create_private_service_access so a VPC that already has the peering (e.g.
# one shared with the MySQL 0-cloudsql unit) reuses it instead of colliding on the same range.
resource "google_compute_global_address" "private_ip_address" {
  count         = var.create && var.create_private_service_access ? 1 : 0
  name          = "google-managed-services-${var.vpc_network_name}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network
  project       = var.project_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  count                   = var.create && var.create_private_service_access ? 1 : 0
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address[0].name]
}

resource "google_sql_database_instance" "default" {
  count            = var.create ? 1 : 0
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  name             = var.instance_name
  database_version = "POSTGRES_16"
  project          = var.project_id
  region           = var.region

  settings {
    # Postgres defaults to ENTERPRISE_PLUS, which rejects shared-core tiers; pin ENTERPRISE for db-f1-micro.
    tier    = "db-f1-micro"
    edition = "ENTERPRISE"
    user_labels = {
      for k, v in local.rendered_tags : k => v
    }
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network
    }
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00" # UTC
      point_in_time_recovery_enabled = true
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

# The postgres superuser already exists on the instance; this sets its password. Skipped when
# no root password is supplied, leaving the user unmanaged.
resource "google_sql_user" "postgres" {
  count    = var.create && var.divyam_db_root_password != "" ? 1 : 0
  name     = "postgres"
  instance = google_sql_database_instance.default[0].name
  password = var.divyam_db_root_password
  project  = var.project_id
}

resource "google_sql_database" "default" {
  count    = var.create ? 1 : 0
  name     = var.divyam_db_name
  instance = google_sql_database_instance.default[0].name
  project  = var.project_id
}
