# Cloud Armor (WAF): create in-module when create_waf, else fetch existing by waf_policy_name when waf_enabled.
# Attached to backend service via security_policy.

resource "google_compute_security_policy" "waf" {
  count       = var.waf_enabled && var.create_waf && var.cloud_armor_policy_id == null ? 1 : 0
  name        = coalesce(var.waf_policy_name, "${var.backend_service_name}-cloud-armor")
  project     = var.project_id
  description = "Cloud Armor policy for load balancer (created in 0-app_gw)"

  # Allow list (if set): allow only these IPs first
  dynamic "rule" {
    for_each = length(var.waf_allow_ip_ranges) > 0 ? [1] : []
    content {
      priority    = 500
      description = "Allow listed IP ranges"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.waf_allow_ip_ranges
        }
      }
      action = "allow"
    }
  }

  # Deny list: block these IPs
  dynamic "rule" {
    for_each = length(var.waf_deny_ip_ranges) > 0 ? [1] : []
    content {
      priority    = 1000
      description = "Block denied IP ranges"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.waf_deny_ip_ranges
        }
      }
      action = "deny(403)"
    }
  }

  rule {
    priority    = 2147483647
    description = "Default rule (allow if no allowlist; deny if allowlist set)"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    action = length(var.waf_allow_ip_ranges) > 0 ? "deny(403)" : "allow"
  }
}

data "google_compute_security_policy" "waf_existing" {
  count   = var.waf_enabled && !var.create_waf && var.cloud_armor_policy_id == null ? 1 : 0
  name    = var.waf_policy_name
  project = var.project_id
}

locals {
  security_policy_id = var.cloud_armor_policy_id != null ? var.cloud_armor_policy_id : (
    var.waf_enabled && var.create_waf && length(google_compute_security_policy.waf) > 0 ? google_compute_security_policy.waf[0].id : (
      var.waf_enabled && !var.create_waf && length(data.google_compute_security_policy.waf_existing) > 0 ? data.google_compute_security_policy.waf_existing[0].id : null
    )
  )
}
