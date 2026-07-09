# Inputs for the GKE-Ingress-referenced GCP resources: reserved global IPs, Google-managed SSL certs,
# and Cloud Armor policies. The LB frontend itself (proxies/url-maps/backend services/forwarding rules)
# is created and owned by the GKE ingress controller — intentionally NOT managed here.

variable "project_id" {
  description = "GCP project ID for the ingress input resources."
  type        = string
}

variable "ingress_inputs" {
  description = "Named resources the GKE Ingress / BackendConfig reference by name."
  type = object({
    # Reserved global external IPs (one per external endpoint).
    static_ips = optional(list(object({
      name = string
    })), [])
    # Google-managed SSL certificates (domains are immutable; module uses create_before_destroy).
    ssl_certs = optional(list(object({
      name    = string
      domains = list(string)
    })), [])
    # Cloud Armor policies. When rules are managed here they are authoritative — include an explicit
    # default-allow rule (priority 2147483647) or the policy will deny everything.
    cloud_armor_policies = optional(list(object({
      name        = string
      description = optional(string, "")
      rules = optional(list(object({
        priority      = number
        action        = string                 # allow | deny(403|404|429|502) | rate_based_ban | throttle
        description   = optional(string, "")
        src_ip_ranges = optional(list(string)) # SRC_IPS_V1 match; use ["*"] for all
        expr          = optional(string)       # alternative to src_ip_ranges: a CEL / preconfigured-WAF expression
        rate_limit = optional(object({         # required for rate_based_ban / throttle
          conform_action       = string
          exceed_action        = string
          enforce_on_key       = optional(string, "ALL")
          rate_limit_threshold = object({ count = number, interval_sec = number })
          ban_duration_sec     = optional(number)                                    # rate_based_ban only
          ban_threshold        = optional(object({ count = number, interval_sec = number }))
        }))
      })), [])
    })), [])
  })
  default = {}
}
