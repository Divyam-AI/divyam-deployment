# Google Cloud uptime checks for public HTTPS endpoints, such as the product console.
#
# One check per entry in var.uptime_checks. Each runs from Google's checker locations over HTTPS and produces:
#   monitoring.googleapis.com/uptime_check/check_passed               whether the endpoint answered with a 2xx
#   monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires  time left on the endpoint's HTTPS certificate
# These are the metrics behind the sheet's external-access (#93 row 7) and HTTPS certificate (#93 row 8) rows.
#
# validate_ssl makes the check fail when the certificate is invalid or expired, so a broken certificate also shows
# up as a failed check. No alert policy is created here.

locals {
  uptime_checks = var.enabled ? var.uptime_checks : {}
}

resource "google_monitoring_uptime_check_config" "this" {
  for_each = local.uptime_checks

  project      = var.project_id
  display_name = "divyam-${each.key}-uptime"
  period       = each.value.period
  timeout      = each.value.timeout

  http_check {
    path           = each.value.path
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }
}
