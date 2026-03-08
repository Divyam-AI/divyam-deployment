############################################
# Cloud Agnostic Service Account Definitions
# Single source of truth; consumed by azure/ and gcp/ IAM bindings.
############################################

locals {

  ##########################################
  # 1️⃣ Base Service Accounts (No Env)
  ##########################################

  base_service_accounts = {
    prometheus = {
      namespace_prefix = "prometheus"
      roles            = ["metrics_publisher"]
    }

    kafka_connect = {
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

    db_upgrades = {
      namespace_prefix = "db_upgrades"
      roles            = ["secret_writer", "resource_reader"]
    }

    router_controller = {
      namespace_prefix = "router_controller"
      roles            = ["secret_writer", "resource_reader"]
    }

    eval = {
      namespace_prefix = "eval"
      roles            = ["secret_reader", "resource_reader"]
    }

    selector_training = {
      namespace_prefix = "selector_training"
      roles = [
        "secret_writer",
        "blob_writer",
        "resource_reader"
      ]
    }
  }

  ##########################################
  # 2️⃣ Final Service Accounts (Env Suffix)
  ##########################################
  service_accounts = {
    for sa_name, sa in local.base_service_accounts :
    "${sa_name}-${var.env_name}-sa" => {
      namespace = lookup(sa, "namespace", null) != null ? sa.namespace : "${sa.namespace_prefix}-${var.env_name}-ns"
      roles     = sa.roles
    }
  }
}
