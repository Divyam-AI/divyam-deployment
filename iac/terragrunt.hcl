# Repo root unit: include shared root config (avoids using terragrunt.hcl as root config).
# See https://terragrunt.gruntwork.io/docs/migrate/migrating-from-root-terragrunt-hcl
include "root" {
  path   = "${get_repo_root()}/iac/root.hcl"
  expose = true
}
