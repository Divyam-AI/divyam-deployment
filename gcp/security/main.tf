provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_security_policy" "divyam_router_api_cloud_armor_policy" {
  name        = var.cloud_armor_policy_name
  description = "Cloud Armor policy for Router API ${var.environment} environment on GCP"

  rule {
    priority    = 1000
    description = "Block abusive IP range"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.bad_ip_ranges
      }
    }
    action = "deny(403)"
  }

  rule {
    priority    = 2000
    description = "Rate limit rule"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.rate_limit_ip_ranges
      }
    }

    action = "rate_based_ban"

    rate_limit_options {
      rate_limit_threshold {
        count        = var.rate_limit_threshold_count
        interval_sec = var.rate_limit_threshold_interval_sec
      }
      ban_threshold {
        count        = var.rate_limit_ban_threshold_count
        interval_sec = var.rate_limit_ban_threshold_interval_sec
      }
      ban_duration_sec = var.rate_limit_ban_duration_sec

      conform_action = "allow"
      exceed_action  = "deny(429)"
    }
  }

  rule {
    priority    = 2147483647
    description = "Default allow rule"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    action = "allow"
  }
}
