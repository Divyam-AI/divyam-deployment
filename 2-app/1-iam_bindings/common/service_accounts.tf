############################################
# Cloud Agnostic Service Account Definitions
# Single source of truth; consumed by azure/ and gcp/ IAM bindings.
############################################

locals {

  ##########################################
  # 1️⃣ Base Service Accounts (No Env)
  ##########################################

# Note: GCP allows only ^[a-z]([-a-z0-9]*[a-z0-9])?$ (no underscores).

  base_service_accounts = {
    prometheus = {
      namespace_prefix = "prometheus"
      roles            = ["metrics_publisher"]
    }

    kafka-connect = {
      namespace_prefix = "kafka"
      roles            = ["blob_writer"]
    }

    billing = {
      namespace_prefix = "billing"
      roles            = ["secret_reader", "blob_reader"]
    }

    clickhouse = {
      namespace_prefix = "clickhouse"
      roles            = ["secret_writer", "resource_reader"]
    }

    db-upgrades = {
      namespace_prefix = "db-upgrades"
      roles            = ["secret_writer", "resource_reader"]
    }

    router-controller = {
      namespace_prefix = "router-controller"
      roles            = ["secret_writer", "resource_reader"]
    }

    eval = {
      namespace_prefix = "eval"
      roles            = ["secret_reader", "resource_reader"]
    }

    selector-training = {
      namespace_prefix = "selector-training"
      roles = [
        "secret_writer",
        "blob_writer",
        "resource_reader"
      ]
    }

    mysql = {
      namespace_prefix = "mysql"
      roles            = ["secret_writer", "resource_reader"]
    }

    superset-postgres = {
      namespace_prefix = "superset"
      roles            = ["secret_reader"]
    }

    route-selector = {
      namespace_prefix = "route-selector"
      roles            = ["secret_reader"]
    }
  }

  ##########################################
  # 2️⃣ Final Service Accounts (Env Suffix)
  # Keys are GCP-safe (hyphens only) so they work as-is for both GCP account_id and Azure.
  ##########################################
  service_accounts = {
    for sa_name, sa in local.base_service_accounts :
    replace("${sa_name}-${var.env_name}-sa", "_", "-") => {
      namespace = lookup(sa, "namespace", null) != null ? sa.namespace : "${sa.namespace_prefix}-${var.env_name}-ns"
      roles     = sa.roles
    }
  }
}
