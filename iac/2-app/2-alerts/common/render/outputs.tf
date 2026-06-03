output "prometheus_rules" {
  description = "Flat list of rendered Prometheus alert rules, multi-tier expanded (warning + critical). Each object: alert, expr (fully rendered), for, interval, severity, enabled, group_enabled, auto_resolve, labels, summary, description, runbook_url, dashboard_url, notify, renotify_interval, group_name. Consumed by gcp/alerts and azure."
  value       = local.prom_expanded
}

output "datadog_monitors" {
  description = "Map (alert -> rule) for rules that yield a Datadog query. Carries the rendered `query` plus all neutral fields (thresholds, notification, severity, datadog overrides) and the merged labels/annotations. Consumed by the datadog module."
  value       = local.dd_monitors
}
