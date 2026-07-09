# GKE-Ingress input resources (GCP). Referenced BY NAME from the GKE Ingress / BackendConfig:
#   - global static IP        -> Ingress "kubernetes.io/ingress.global-static-ip-name"
#   - managed SSL certificate -> Ingress "ingress.gcp.kubernetes.io/pre-shared-cert"
#   - Cloud Armor policy      -> BackendConfig "spec.securityPolicy.name"
# The LB frontend (target proxies, url maps, backend services, forwarding rules) is owned by the GKE
# ingress controller and MUST NOT be managed here.

locals {
  # Keyed by resource name -> stable for_each keys (reordering the lists never churns state).
  ips   = { for x in var.ingress_inputs.static_ips : x.name => x }
  certs = { for x in var.ingress_inputs.ssl_certs : x.name => x }
  pols  = { for x in var.ingress_inputs.cloud_armor_policies : x.name => x }
}

resource "google_compute_global_address" "ip" {
  for_each = local.ips
  name     = each.key
  project  = var.project_id
  labels   = local.rendered_tags
}

resource "google_compute_managed_ssl_certificate" "cert" {
  for_each = local.certs
  name     = each.key
  project  = var.project_id

  managed {
    domains = each.value.domains
  }

  # Managed-cert domains are immutable: provision the replacement before dropping the old one.
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_security_policy" "armor" {
  for_each    = local.pols
  name        = each.key
  project     = var.project_id
  description = each.value.description

  dynamic "rule" {
    for_each = each.value.rules
    content {
      priority    = rule.value.priority
      action      = rule.value.action
      description = rule.value.description
      preview     = false

      match {
        versioned_expr = rule.value.src_ip_ranges != null ? "SRC_IPS_V1" : null
        dynamic "config" {
          for_each = rule.value.src_ip_ranges != null ? [1] : []
          content {
            src_ip_ranges = rule.value.src_ip_ranges
          }
        }
        dynamic "expr" {
          for_each = rule.value.expr != null ? [1] : []
          content {
            expression = rule.value.expr
          }
        }
      }

      dynamic "rate_limit_options" {
        for_each = rule.value.rate_limit != null ? [rule.value.rate_limit] : []
        content {
          conform_action = rate_limit_options.value.conform_action
          exceed_action  = rate_limit_options.value.exceed_action
          enforce_on_key = rate_limit_options.value.enforce_on_key

          rate_limit_threshold {
            count        = rate_limit_options.value.rate_limit_threshold.count
            interval_sec = rate_limit_options.value.rate_limit_threshold.interval_sec
          }

          ban_duration_sec = rate_limit_options.value.ban_duration_sec
          dynamic "ban_threshold" {
            for_each = rate_limit_options.value.ban_threshold != null ? [rate_limit_options.value.ban_threshold] : []
            content {
              count        = ban_threshold.value.count
              interval_sec = ban_threshold.value.interval_sec
            }
          }
        }
      }
    }
  }
}
