# Phase 1 — infrastructure (iac/)

Provision in strict order **0-foundation → 1-platform → 2-app** using `iac.sh` (or `make iac -- …`).
Each `apply` is preceded by a reviewed `plan`. Within a layer, sub-unit ordering is automatic (DAG).

## Config + secrets + creds (before any apply)
1. `make iac -- config -c <cloud> -e <env>` — persists to `.iac.conf`. (Optionally copy
   `iac/values/defaults.hcl` → a custom values file and `export VALUES_FILE=…`; toggle components with
   `create = false`.)
2. `make iac -- secrets` — writes `iac/values/secrets.env` (auto-sourced). **Fill the `FILL` values**: cloud
   creds (`ARM_*` or `GOOGLE_APPLICATION_CREDENTIALS`), `TF_VAR_divyam_artifactory_docker_auth` (path to
   the Divyam registry cred file — required to pull images), `NOTIFICATION_WEBHOOK_URLS` (Zenduty), and
   `TF_VAR_datadog_*` / `TF_VAR_grafana_api_token` if used. Randomised secrets are fine for a sandbox;
   use real Divyam-issued `deployment_id`/`deployment_api_key` if the env must register with Divyam.
3. `make iac -- creds` — validate cloud auth.

## 0-foundation (LOCAL state)
Units: `0-apis`, `0-resource_scope`, `1-vnet`, `2-nat`, `2-terraform_state_blob_storage`, `3-bastion`.
Creates (or looks up, when `create=false`) the project/RG, network, NAT, remote-state bucket, and the
bastion. **LOCAL state** — do NOT blindly re-apply/destroy; coordinate with the team on state location.
`0-apis` "already exists" is safe to ignore.

## 1-platform (remote state)
Units: `0-app_gw`, `0-divyam_object_storage`, `1-k8s` (GKE/AKS), `2-monitoring/{native,datadog}`,
`3-bastion-kubectl-setup`. `apply -l 1-platform` provisions the cluster before monitoring automatically
(`2-monitoring` depends on `1-k8s`). You can target `-l 1-platform.1-k8s` first, then
`-l 1-platform.2-monitoring`, if iterating.

## 2-app (remote state)
Units: `0-divyam_secrets`, `1-iam_bindings`, `0-cloudsql`, `0-agic`, `2-alerts`, `2-dashboards`,
`3-export_details`. Needs the `2-app` secrets present (from `secrets.env`). `3-export_details` **writes
`k8s/helm-values/provider.yaml`** — the Phase-2 handoff. The 4-filter union covers Azure's & GCP's
nested alert/dashboard units automatically.

## Observability (after 1-k8s exists)
Alert rules are the single source of truth in `iac/2-app/2-alerts/common/rules/*.json` (neutral PromQL
+ optional Datadog block). Backends are chosen by `CLOUD_PROVIDER` + `datadog.enabled`. Deploy:
`make iac -- apply -l 1-platform.2-monitoring`, then `make iac -- apply -l 2-app.2-alerts` and
`make iac -- apply -l 2-app.2-dashboards`. Only CRITICAL rules page `NOTIFICATION_WEBHOOK_URLS` (Zenduty). For Datadog,
export `TF_VAR_datadog_api_key`/`_app_key` first. (One-time after the observability refactor on an
existing env: run `iac/scripts/migration.sh` to move state from `1-k8s` → `2-monitoring`.)

## Verify Phase 1
Confirm `k8s/helm-values/provider.yaml` exists and shows the right `environment`, `platform.provider`,
storage/DB config before starting Phase 2.
