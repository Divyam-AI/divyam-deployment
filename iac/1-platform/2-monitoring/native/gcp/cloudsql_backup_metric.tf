# Log-based metric for Cloud SQL automated backups.
#
# Cloud SQL has no Cloud Monitoring metric for "a backup succeeded or failed". Each backup window writes one
# system event audit entry instead, and its windowStatus says how the window ended. This turns those entries into
# a counter an alert policy can read. It covers every Cloud SQL instance in the project, so the label database_id
# (project:instance) is what an alert uses to pick the Switch database.
#
# windowStatus values, from Google's page "View audit logs for automated backups":
#   STATUS_SUCCEEDED       the backup completed
#   STATUS_ATTEMPT_FAILED  an attempt did not start or failed
#   STATUS_FAILED          the backup could not finish within its window
#   STATUS_SKIPPED         the instance was stopped, so no backup was made
#
# Cloud Monitoring can only alert on the latest 25 hours of a user-defined log-based metric. That is enough for the
# failure alerts but not for "no successful backup for 26 or 48 hours". See Metrics.txt, row 20.
#
# The metric counts from the day it is created. It is not filled in from older log entries.

locals {
  cloudsql_backup_metric_enabled = var.enabled && var.enable_cloudsql_backup_metric
}

resource "google_logging_metric" "cloudsql_automated_backup" {
  count   = local.cloudsql_backup_metric_enabled ? 1 : 0
  project = var.project_id
  name    = var.cloudsql_backup_metric_name

  description = "Cloud SQL automated backup windows, counted by how each ended (windowStatus) and by instance (database_id)."

  filter = join("\n", [
    "logName=\"projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Fsystem_event\"",
    "protoPayload.methodName=\"cloudsql.instances.automatedBackup\"",
    "resource.type=\"cloudsql_database\"",
  ])

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "window_status"
      value_type  = "STRING"
      description = "How the backup window ended: STATUS_SUCCEEDED, STATUS_ATTEMPT_FAILED, STATUS_FAILED or STATUS_SKIPPED."
    }

    labels {
      key         = "database_id"
      value_type  = "STRING"
      description = "The Cloud SQL instance, as project:instance."
    }
  }

  label_extractors = {
    window_status = "EXTRACT(protoPayload.metadata.windowStatus)"
    database_id   = "EXTRACT(resource.labels.database_id)"
  }
}
