############################################
# Cloud Agnostic Service Account Definitions
# Single source of truth; consumed by azure/ and gcp/ IAM bindings.
############################################

locals {

  ##########################################
  # 1️⃣ Base Service Accounts (No Env)
  ##########################################

# Note: GCP allows only ^[a-z]([-a-z0-9]*[a-z0-9])?$ (no underscores).

  router_service_accounts = {
    prometheus = {
      namespace_prefix = "prometheus"
      roles            = ["metrics_publisher"]
    }

    kafka-connect = {
      namespace_prefix = "kafka"
      service_account_name_override = "kafka-${var.env_name}-connect"
      roles            = ["blob_writer", "secret_reader"]
    }

    billing = {
      namespace_prefix = "billing"
      roles            = ["secret_reader", "blob_reader"]
    }

    clickhouse = {
      namespace_prefix = "clickhouse"
      roles            = ["secret_reader", "resource_reader"]
    }

    divyam-db-upgrades = {
      namespace_prefix = "db-upgrades"
      roles            = ["secret_reader", "resource_reader"]
    }

    divyam-router-controller = {
      namespace_prefix = "router-controller"
      service_account_name_override = "router-controller-${var.env_name}-sa"
      roles            = ["secret_reader", "resource_reader"]
    }

    divyam-evaluator = {
      namespace_prefix = "eval"
      roles            = ["secret_reader", "resource_reader"]
    }

    divyam-selector-training = {
      namespace_prefix = "selector-training"
      service_account_name_override = "selector-training-${var.env_name}-sa"
      roles = [ "secret_reader", "blob_writer", "resource_reader" ]
    }

    mysql = {
      namespace_prefix = "mysql"
      roles            = ["secret_reader", "resource_reader"]
    }

    superset-postgres = {
      namespace_prefix = "superset"
      roles            = ["secret_reader"]
    }

    divyam-route-selector = {
      namespace_prefix = "route-selector"
      service_account_name_override = "route-selector-${var.env_name}-sa"
      roles            = ["secret_reader","resource_reader", "blob_reader"]
    }

    divyam-control-plane-exporter = {
      namespace_prefix = "control-plane-exporter"
      service_account_name_override = "control-plane-exp-${var.env_name}-sa"
      roles            = ["secret_reader","resource_reader"]
    }

    divyam-e2e-test-runner = {
      namespace_prefix = "e2e-test-runner"
      service_account_name_override = "e2e-test-runner-${var.env_name}-sa"
      roles            = ["secret_reader","resource_reader","blob_reader", "blob_writer"]
    }
  }

  ##########################################
  # evalm8 Service Accounts (No Env)
  # Provisioned only when the stack is not router (gated below).
  # lakefs SA gets RW on the lakeFS bucket via lakefs_blob_writer.
  # OpenSearch snapshots are off for v1, so argilla needs no bucket access.
  # The server and wfs need only secret access. The lakefs and argilla charts also carry ExternalSecrets, so they take secret_reader too.
  ##########################################

  evalm8_service_accounts = {
    lakefs = {
      namespace_prefix = "lakefs"
      service_account_name_override = "lakefs-${var.env_name}-sa"
      roles            = ["secret_reader", "lakefs_blob_writer"]
    }

    argilla = {
      namespace_prefix = "argilla"
      service_account_name_override = "argilla-${var.env_name}-sa"
      roles            = ["secret_reader"]
    }

    evalm8-server = {
      namespace_prefix = "evalm8"
      service_account_name_override = "evalm8-server-${var.env_name}-sa"
      roles            = ["secret_reader"]
    }

    evalm8-wfs = {
      namespace_prefix = "evalm8"
      service_account_name_override = "evalm8-wfs-${var.env_name}-sa"
      roles            = ["secret_reader"]
    }
  }

  # Gate evalm8 accounts behind the stack selector, mirroring deployment_mode.
  # A router-only deployment omits them entirely so no evalm8 cloud identity is created.
  base_service_accounts = merge(
    local.router_service_accounts,
    var.stack != "router" ? local.evalm8_service_accounts : {}
  )

  ##########################################
  # 2️⃣ Final Service Accounts (Env Suffix)
  # Keys are GCP-safe (hyphens only) so they work as-is for both GCP account_id and Azure.
  ##########################################
  service_accounts = {
    for sa_name, sa in local.base_service_accounts :
    (lookup(sa, "service_account_name_override", null) != null ?
      sa.service_account_name_override :
      replace("${sa_name}-${var.env_name}-sa", "_", "-")
    ) => {
      namespace = lookup(sa, "namespace", null) != null ? sa.namespace : "${sa.namespace_prefix}-${var.env_name}-ns"
      roles     = sa.roles
    }
  }
}