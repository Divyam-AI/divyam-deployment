locals {
  role_mapping = {
    metrics_publisher = {
      role_assignments = [
        {
          scope                = "resource_group"
          role_definition_name = "Monitoring Metrics Publisher"
        }
      ]
    }

    blob_writer = {
      role_assignments = [
        {
          scope                = "storage_account"
          role_definition_name = "Storage Blob Data Owner"
        }
      ]
    }

    # lakeFS blob storage writer (evalm8 lakeFS container).
    # Bound to the evalm8 lakeFS storage account scope, separate from the router-logs storage.
    lakefs_blob_writer = {
      role_assignments = [
        {
          scope                = "lakefs_storage_account"
          role_definition_name = "Storage Blob Data Contributor"
        }
      ]
    }

    blob_reader = {
      role_assignments = [
        {
          scope                = "storage_account"
          role_definition_name = "Storage Blob Data Reader"
        }
      ]
    }

    resource_reader = {
      role_assignments = [
        {
          scope                = "resource_group"
          role_definition_name = "Reader"
        }
      ]
    }

    secret_reader = {
      role_assignments = [
        {
          scope                = "key_vault"
          role_definition_name = "Key Vault Secrets User"
        }
      ]

      key_vault_access_policy = {
        secret_permissions = [
          "Get",
          "List"
        ]
      }
    }

    secret_writer = {
      role_assignments = [
        {
          scope                = "key_vault"
          role_definition_name = "Key Vault Secrets User"
        }
      ]

      key_vault_access_policy = {
        secret_permissions = [
          "Get",
          "List",
          "Set"
        ]
      }
    }
  }
}