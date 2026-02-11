provider "google" {
  project = var.project_id
  region = var.region
}

resource "google_secret_manager_secret" "db_secret_name" {
  secret_id = "divyam_db_user_name_password_secret_key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_secret_name_secret_version" {
  secret      = google_secret_manager_secret.db_secret_name.id
  secret_data_wo = "${var.divyam_db_user_name}:${var.divyam_db_password}"
}

resource "google_secret_manager_secret" "billing_secret_name" {
  secret_id = "divyam_billing_secrets"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "billing_secret_name_secret_version" {
  secret      = google_secret_manager_secret.billing_secret_name.id
  secret_data_wo = <<-EOT
llm_keys:
  OpenAI:
    billing_api_key: "${var.divyam_openai_billing_api_key}"
clickhouse:
  user: "${var.divyam_clickhouse_user_name}"
  password: "${var.divyam_clickhouse_password}"
mysql:
  user: "${var.divyam_db_user_name}"
  password: "${var.divyam_db_password}"
EOT
}

resource "google_secret_manager_secret" "jwt_secret_name" {
  secret_id = "divyam_jwt_secret_key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jwt_secret_name_secret_version" {
  secret      = google_secret_manager_secret.jwt_secret_name.id
  secret_data_wo = var.divyam_jwt_secret_key
}



resource "google_secret_manager_secret" "keys_secret_name" {
  secret_id = "divyam_provider_keys_encryption_key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "keys_secret_name_secret_version" {
  secret      = google_secret_manager_secret.keys_secret_name.id
  secret_data_wo = var.divyam_provider_keys_encryption_key
}



resource "google_secret_manager_secret" "openai_billing_secret_name" {
  secret_id = "divyam_openai_billing_api_key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "openai_billing_secret_name_version" {
  secret      = google_secret_manager_secret.openai_billing_secret_name.id
  secret_data_wo = var.divyam_openai_billing_api_key
}
