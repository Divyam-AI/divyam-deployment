locals {
  role_mapping = {

    # -----------------------------------
    # Publish metrics (Cloud Monitoring)
    # -----------------------------------
    metrics_publisher = {
      role_bindings = [
        {
          scope = "project"
          role  = "roles/monitoring.metricWriter"
        }
      ]
    }

    # -----------------------------------
    # Blob storage writer (GCS)
    # -----------------------------------
    blob_writer = {
      role_bindings = [
        {
          scope = "storage_bucket"
          role  = "roles/storage.objectAdmin"
        }
      ]
    }

    # -----------------------------------
    # Blob storage reader (GCS)
    # -----------------------------------
    blob_reader = {
      role_bindings = [
        {
          scope = "storage_bucket"
          role  = "roles/storage.objectViewer"
        }
      ]
    }

    # -----------------------------------
    # Resource metadata reader
    # -----------------------------------
    resource_reader = {
      role_bindings = [
        {
          scope = "project"
          role  = "roles/viewer"
        }
      ]
    }

    # -----------------------------------
    # Secret Manager reader
    # -----------------------------------
    secret_reader = {
      role_bindings = [
        {
          scope = "project"
          role  = "roles/secretmanager.secretAccessor"
        }
      ]
    }

    # -----------------------------------
    # Secret Manager writer
    # -----------------------------------
    secret_writer = {
      role_bindings = [
        {
          scope = "project"
          role  = "roles/secretmanager.secretVersionAdder"
        },
        {
          scope = "project"
          role  = "roles/secretmanager.secretAccessor"
        }
      ]
    }
  }
}