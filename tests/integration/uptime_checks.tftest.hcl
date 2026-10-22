# The GCP native monitoring module's uptime checks for public HTTPS endpoints.
# Run against a mocked Google provider, so no credentials are needed.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "asia-south1"
}

run "no_check_is_created_by_default" {
  command = plan

  assert {
    condition     = length(google_monitoring_uptime_check_config.this) == 0
    error_message = "An environment that configures no uptime check must get none."
  }
  assert {
    condition     = length(output.uptime_check_ids) == 0
    error_message = "No checks means no ids."
  }
}

run "console_check_watches_the_host_over_https_and_validates_the_certificate" {
  command = plan
  variables {
    uptime_checks = {
      console = { host = "console.preview.divyam.ai" }
    }
  }

  assert {
    condition     = length(google_monitoring_uptime_check_config.this) == 1
    error_message = "One configured endpoint is one check."
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["console"].display_name == "divyam-console-uptime"
    error_message = "The display name is how the check is found in the console."
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["console"].monitored_resource[0].type == "uptime_url" && google_monitoring_uptime_check_config.this["console"].monitored_resource[0].labels["host"] == "console.preview.divyam.ai" && google_monitoring_uptime_check_config.this["console"].monitored_resource[0].labels["project_id"] == "test-project"
    error_message = "The check must watch the configured host in the configured project."
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["console"].http_check[0].use_ssl == true && google_monitoring_uptime_check_config.this["console"].http_check[0].validate_ssl == true && google_monitoring_uptime_check_config.this["console"].http_check[0].port == 443
    error_message = "It must use HTTPS on 443 and validate the certificate, which is what produces time_until_ssl_cert_expires and fails on a bad certificate."
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["console"].http_check[0].path == "/" && google_monitoring_uptime_check_config.this["console"].http_check[0].request_method == "GET"
    error_message = "The default is a GET of the root page."
  }
  assert {
    condition     = one(google_monitoring_uptime_check_config.this["console"].http_check[0].accepted_response_status_codes).status_class == "STATUS_CLASS_2XX"
    error_message = "Only a 2xx counts as available."
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["console"].period == "60s" && google_monitoring_uptime_check_config.this["console"].timeout == "10s"
    error_message = "Defaults are a check every 60 seconds with a 10 second timeout."
  }
}

run "path_period_and_timeout_can_be_set" {
  command = plan
  variables {
    uptime_checks = {
      api = { host = "api.example.com", path = "/api/v1/ready", period = "300s", timeout = "20s" }
    }
  }
  assert {
    condition     = google_monitoring_uptime_check_config.this["api"].http_check[0].path == "/api/v1/ready" && google_monitoring_uptime_check_config.this["api"].period == "300s" && google_monitoring_uptime_check_config.this["api"].timeout == "20s"
    error_message = "Per-check settings must reach the resource."
  }
}

run "checks_follow_the_module_switch" {
  command = plan
  variables {
    enabled = false
    uptime_checks = {
      console = { host = "console.preview.divyam.ai" }
    }
  }
  assert {
    condition     = length(google_monitoring_uptime_check_config.this) == 0
    error_message = "A disabled monitoring module must create nothing, including uptime checks."
  }
}
