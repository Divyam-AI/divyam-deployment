output "alert_policy_urls" {
  value = {
    for name, alert in google_monitoring_alert_policy.prometheus_alerts :
    name => "https://console.cloud.google.com/monitoring/alerting/policies/${alert.name}?project=${var.project_id}"
  }
}
