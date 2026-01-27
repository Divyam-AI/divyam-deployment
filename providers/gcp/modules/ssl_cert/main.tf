resource "google_compute_managed_ssl_certificate" "global_managed_ssl" {
  count = var.enabled ? 1 : 0
  name = var.ssl_certificate_name # Change the name as needed

  managed {
    # List the domains that the certificate will cover.
    domains = var.ssl_certificate_domains
  }
}