# The GCP native monitoring module's log-based metric for Cloud SQL automated backups.
# Run against a mocked Google provider, so no credentials are needed.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "asia-south1"
}

run "metric_counts_the_documented_backup_event_by_outcome_and_instance" {
  command = plan

  assert {
    condition     = length(google_logging_metric.cloudsql_automated_backup) == 1
    error_message = "The metric must be created by default."
  }
  assert {
    condition     = google_logging_metric.cloudsql_automated_backup[0].name == "divyam_cloudsql_automated_backup"
    error_message = "The metric name is what alert policies read it by."
  }
  assert {
    condition = google_logging_metric.cloudsql_automated_backup[0].filter == join("\n", [
      "logName=\"projects/test-project/logs/cloudaudit.googleapis.com%2Fsystem_event\"",
      "protoPayload.methodName=\"cloudsql.instances.automatedBackup\"",
      "resource.type=\"cloudsql_database\"",
    ])
    error_message = "The filter must be the three expressions Google documents for automated backup audit logs."
  }
  assert {
    condition = google_logging_metric.cloudsql_automated_backup[0].label_extractors == tomap({
      window_status = "EXTRACT(protoPayload.metadata.windowStatus)"
      database_id   = "EXTRACT(resource.labels.database_id)"
    })
    error_message = "The metric must be labelled by windowStatus and by instance."
  }
  assert {
    condition     = google_logging_metric.cloudsql_automated_backup[0].metric_descriptor[0].metric_kind == "DELTA" && google_logging_metric.cloudsql_automated_backup[0].metric_descriptor[0].value_type == "INT64"
    error_message = "A count of log entries is a DELTA INT64 metric."
  }
  assert {
    condition     = toset([for l in google_logging_metric.cloudsql_automated_backup[0].metric_descriptor[0].labels : l.key]) == toset(["window_status", "database_id"])
    error_message = "Every extractor needs a declared label, and no other label may exist."
  }
  assert {
    condition     = output.cloudsql_backup_metric_type == "logging.googleapis.com/user/divyam_cloudsql_automated_backup"
    error_message = "The output is the type an alert policy references."
  }
}

run "metric_can_be_switched_off" {
  command = plan
  variables {
    enable_cloudsql_backup_metric = false
  }
  assert {
    condition     = length(google_logging_metric.cloudsql_automated_backup) == 0
    error_message = "The metric flag must switch it off."
  }
  assert {
    condition     = output.cloudsql_backup_metric_type == null
    error_message = "No metric means no type to reference."
  }
}

run "metric_follows_the_module_switch" {
  command = plan
  variables {
    enabled = false
  }
  assert {
    condition     = length(google_logging_metric.cloudsql_automated_backup) == 0
    error_message = "A disabled monitoring module must create nothing, including this metric."
  }
}
