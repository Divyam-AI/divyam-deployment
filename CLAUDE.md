# divyam-deployment — CLAUDE.md

Provision cloud infrastructure and deploy the Divyam platform stack on Kubernetes. Two phases:

1. **Infrastructure** (`iac/`) — Terragrunt/OpenTofu modules that create cloud resources: VPC/VNet,
   NAT, bastion, **the K8s cluster (GKE/AKS)**, storage, secrets, monitoring, alerts, dashboards.
2. **Application** (`k8s/`) — a single **Helmfile** that installs the entire Divyam service stack
   onto the provisioned cluster.

Phase 1's `export_details` module writes `k8s/helm-values/provider.yaml`, which Phase 2's Helmfile
consumes. The Helmfile phase is run **from the bastion/jumphost VM** created in Phase 1.

> Sibling repo `../divyam_router_cd` owns the lightweight **sandbox** dev path (SkyPilot VM +
> single-node MicroK8s) and the feature build/deploy loop. This repo is the real GKE/AKS path. The
> alert closed loop (below) can target either cluster — whatever `kubectl` currently points at.

## Tooling (pin these versions)

| Tool | Version | Install |
|------|---------|---------|
| OpenTofu | 1.11.5 | via `tenv tofu install 1.11.5` |
| Terragrunt | 0.99.4 | via `tenv terragrunt install 0.99.4` |
| Helm | latest | helm.sh |
| Helmfile | v1.4.4 | github.com/helmfile/helmfile |
| Helm Diff plugin | v3.7.x | `helm plugin install https://github.com/databus23/helm-diff --version v3.7.0` |
| K9s | latest | k9scli.io |

Note Terragrunt 0.99 syntax: `terragrunt run plan` / `terragrunt run apply` (with `run`), and
`terragrunt init -reconfigure --all --filter ...`.

## Layout

```
iac/
  root.hcl                         # shared Terragrunt config (reads ARM_*/ADC)
  values/defaults.hcl              # config via get_env(...): CLOUD_PROVIDER, ENV, REGION, ZONE,
                                   #   ORG_NAME, VALUES_FILE, NOTIFICATION_WEBHOOK_URLS, alerts{},
                                   #   monitoring{}, datadog{}, k8s{}, *.create toggles
  values/example-custom-k8s-*.hcl  # bring-your-own-cluster profiles (k8s.create=false)
  sample_deploy.sh                 # wrapper for plan/apply/destroy/import
  0-foundation/                    # 0-apis, 0-resource_scope, 1-vnet, 2-nat,
                                   #   2-terraform_state_blob_storage, 3-bastion   (LOCAL state)
  1-platform/                      # 0-app_gw, 0-divyam_object_storage, 1-k8s (GKE/AKS),
                                   #   2-monitoring/{native,datadog}, 3-bastion-kubectl-setup
  2-app/
    0-divyam_secrets/              # secrets in Key Vault / Secret Manager (TF_VAR_* inputs)
    1-iam_bindings/  0-cloudsql/  0-agic/
    2-alerts/
      common/rules/*.json          # SINGLE SOURCE OF TRUTH for alert rules (PromQL + Datadog query)
      common/rules/README.md       # rule schema — READ before editing rules
      gcp/  azure/  datadog/       # per-backend translation + notification_channels (Zenduty webhooks)
    2-dashboards/                  # per-backend dashboards
    3-export_details/              # writes k8s/helm-values/provider.yaml
k8s/
  helmfile.yaml.gotmpl             # deploys the whole stack (namespaces, ordering, DNS wiring)
  helm-values/                     # provider.yaml (from TF), resources.yaml, config.yaml, artifacts.yaml
  releases/<yy.mm.dd>-artifacts.yaml  # versioned chart versions + image tags (preferred)
  sample_values/{gcp,azure}/       # starter resources.yaml; sample-config.yaml
  docs/cicd-overview.md            # forked-repo CI (helmfile diff) / CD (helmfile apply)
  pipeline/                        # Dockerfile + ci_validate.sh / cd_deploy.sh scaffolds
scripts/
  check_cloud_credentials.sh       # validates cloud auth before terragrunt
  write-outputs-yaml.sh            # TF outputs -> provider.yaml for Helm
  migration.sh                     # run before first 2-monitoring apply on existing envs
  gen-tf-env.sh                    # (this workflow) generate a TF secrets env file (random where safe)
  zenduty.py                       # (this workflow) confirm an incident was raised in Zenduty
test/alert-sim/                    # human-owned simulation specs: rule -> kubectl trigger -> signal
  README.md                        #   schema + conventions for adding app-specific scenarios
  <group>.yaml                     #   one file per rule group, mirrors common/rules/<group>.json
```

## Phase 1 — provision infrastructure (`iac/`)

All of Phase 1 runs through `make iac -- <cmd>` (the entrypoint; forwards to `scripts/iac.sh`, which
also runs directly without `--`). Add `-n` to any command to preview the exact `terragrunt` invocation.

1. **Config**: `make iac -- config -c <gcp|azure> -e <env>` (persists to `.iac.conf`). Optionally copy
   `values/defaults.hcl` → a custom values file and `export VALUES_FILE=…`; skip components with
   `create = false` in the values file.
2. **Secrets**: `make iac -- secrets` writes `iac/values/secrets.env` (auto-sourced by the CLI). Fill
   the real `FILL` values; randomized ones are fine for a sandbox. See the secrets stage below.
3. **Cloud auth** (interactive — the user runs these, not Claude):
   - Azure: `az login`; service principal exported as `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
     `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` (exactly these names). SP needs Contributor +
     User Access Administrator (+ Network Contributor if the VNet is in another RG).
   - GCP: `gcloud auth login` + `gcloud auth application-default login`, or
     `GOOGLE_APPLICATION_CREDENTIALS` (SA key path).
   - Validate: `make iac -- creds`.
4. **Apply layers in order** (review `plan` before every `apply`):
   ```bash
   make iac -- plan  -l <layer> && make iac -- apply -l <layer>
   ```
   - Layer order: **0-foundation → 1-platform → 2-app**. Target a whole layer (`-l 1-platform`) or a
     sub-unit (`-l 1-platform.1-k8s`).
   - **Ordering inside a layer is automatic** — the terragrunt dependency DAG runs `1-k8s` before
     `2-monitoring`, so a single `apply -l 1-platform` is correct.
   - **Cloud-unit selection is automatic** — the CLI emits a filter union that catches a cloud's units
     at any depth (incl. nested Azure/GCP `2-alerts`/`2-dashboards`); pass `-f/--filter` only for
     irregular units (e.g. the cloud-agnostic `2-alerts/datadog` when `datadog.enabled`).
5. **State caveats**: **0-foundation uses LOCAL state** — do NOT blindly re-`apply`; coordinate with
   the team on state location. 1-platform/2-app use **remote** state (the bucket/account from
   `2-terraform_state_blob_storage`). `TG_USE_LOCAL_BACKEND=1` only for debug.
6. **Destroy / re-harden**: `make iac -- destroy -l <layer>` (flips `prevent_destroy`→false, previews,
   type-confirms) and `make iac -- protect -l <layer>` (re-harden, then apply).
7. **Verify**: `2-app` writes `k8s/helm-values/provider.yaml`. Review env, cloud provider, and storage
   config before Phase 2.

Troubleshooting: clear caches with `find . -type d -name .terragrunt-cache -exec rm -rf {} +`;
inspect with `make iac -- show -l <layer>`; for "already exists" import the resource or set
`create = false` and fill in the existing values. API-enablement (`0-apis`) "already exists" errors are
safe to ignore.

## Phase 2 — deploy the stack (`k8s/`, Helmfile)

Run from the bastion, through `make k8s -- <cmd>` (forwards to `scripts/k8s.sh`). First fetch
kubeconfig — `make k8s -- kubeconfig` resolves the cluster from `terragrunt output` → `provider.yaml`
→ naming convention and runs `gcloud … get-credentials` (GCP) or `az login --service-principal` (from
`ARM_*`) + `az aks get-credentials` (Azure). Verify: `kubectl get ns`. (Interactive cloud login is the
user's job.)

Values live in `k8s/helm-values/` (or `-d <dir>`). **Merge priority**: `config.yaml` (highest) >
`resources.yaml` > `artifacts.yaml` (lowest). Image/chart versions resolve via `ARTIFACTS_VERSION`
(`-a`) → `releases/<VERSION>-artifacts.yaml` (preferred), else a local `artifacts.yaml`, else the latest
`releases/*-artifacts.yaml`.

```bash
make k8s -- config -d k8s/helm-values -e <env>   # remember once
make k8s -- diff                                  # ALWAYS diff before apply
make k8s -- install -a 26.04.01-rc1               # FIRST install only (helmfile sync — installs ALL releases)
make k8s -- upgrade                               # subsequent upgrades (helmfile apply — only changed)
make k8s -- upgrade -l clickhouse                 # single chart (→ -l name=clickhouse-<env>)
make k8s -- template -- --debug                   # render manifests locally
make k8s -- status                                # helm ls -A (+ --tui / --dashboard)
make k8s -- delete -l <chart>                     # tear down a release (type-to-confirm)
```

- `install` (=`sync`) reinstalls everything (can cause restarts) — use it only for the initial deploy;
  use `upgrade` (=`apply`) routinely.
- Namespaces/releases are `<chart>-<env>-ns` / `<chart>-<env>`, driven by `environment` in
  `provider.yaml`. Set `enabled: false` on a chart in `resources.yaml` to skip it.
- Private images require `TF_VAR_divyam_artifactory_docker_auth` (Phase 1) so pull secrets are
  injected; nodes/CI must reach Divyam's auth-restricted registry.

## Observability, alerts & the closed loop

Alert rules are a single source of truth in `iac/2-app/2-alerts/common/rules/*.json` — a neutral
`expr` (PromQL for GCP + Azure managed Prometheus) and an optional `datadog` block. Read
`common/rules/README.md` before editing. Backends (parameterized by `CLOUD_PROVIDER` +
`datadog.enabled`):
- **GCP Cloud Monitoring**: `google_monitoring_alert_policy` + `webhook_tokenauth` channels.
- **Azure Managed Grafana / Monitor**: `azurerm_monitor_alert_prometheus_rule_group` + action-group
  webhook receivers.
- **Datadog**: `datadog_monitor` + `datadog_webhook` (Zenduty-friendly payload).

Only `CRITICAL` rules notify `NOTIFICATION_WEBHOOK_URLS` (your **Zenduty** webhook). To prove an alert
really fires (manual closed loop): deploy the backend → simulate the failure in the cluster
(`test/alert-sim/*.yaml`) → confirm via the Zenduty API (`scripts/zenduty.py`, needs
`ZENDUTY_API_TOKEN`) → fix the query and re-apply if it didn't → repeat. (The former `/alert-loop`,
`/simulate`, `/verify-alert`, `/fix-alert-query` commands and the `scenario-simulator` agent have been
removed; the rules and sim specs remain.)

## The TF secrets-env stage (`gen-tf-env.sh`)

Terragrunt reads cloud creds and `TF_VAR_*` secrets from the environment. `make iac -- secrets`
generates `iac/values/secrets.env` — random for safe-to-randomize secrets, passthrough/`FILL` for real
ones — and the CLI **auto-sources it** on every `make iac -- …` (no manual `source`):

```bash
make iac -- secrets        # writes iac/values/secrets.env (chmod 600, gitignored); edit the FILL values
make iac -- creds          # validate cloud auth
```

- **Randomized (internal, safe for a sandbox)**: DB/ClickHouse/Superset-PG passwords, Superset &
  router-admin login passwords, JWT signing key, provider-keys encryption key.
- **Issued by Divyam** (random fallback for a standalone sandbox; use the real values if the env must
  register with Divyam): `TF_VAR_divyam_deployment_id`, `TF_VAR_divyam_deployment_api_key`.
- **Must be real** (passthrough; never randomized): cloud creds (`ARM_*` / `GOOGLE_APPLICATION_CREDENTIALS`),
  `TF_VAR_divyam_artifactory_docker_auth` (path to Divyam's registry cred file — needed to pull
  images), `NOTIFICATION_WEBHOOK_URLS` (Zenduty), `TF_VAR_datadog_api_key`/`_app_key`,
  `TF_VAR_grafana_api_token`, `TF_VAR_divyam_openai_billing_admin_api_key`.

`make iac -- secrets` → `make iac -- creds` → `make iac -- plan/apply -l <layer>` is the per-layer flow
(`/provision` and `/setup` drive it interactively). Use the **terrashark** skill for any HCL edit.

## Skills / plugins to use

Project skills (`.claude/skills/`), three types:
- **`divyam-platform-engineer`** (persona) — the SRE/DevOps operating mindset & safety rules for this
  repo. Adopt it whenever acting on `iac/` or `k8s/`.
- **`divyam-tooling`** (knowledge) — how to drive the Makefile, `iac.sh`/`k8s.sh`, helper scripts, and
  the underlying tools (terragrunt/tofu, helm/helmfile, kubectl, gcloud/az); has `references/` per tool.
- **`divyam-deploy`** (workflow) — the end-to-end deployment process (Phase 1 → Phase 2) with `references/`.

Global/general skills to pair with them:
- **`terrashark`** — *required* for every Terraform/OpenTofu/Terragrunt change.
- **`terraform-engineer`** / **`cloud-architect`** / **`sre-engineer`** / **`devops-engineer`** — generic
  depth the `divyam-*` skills defer to.
- **`security-review`** — before changes touching secrets, IAM, or notification config.
- **`code-review`** — review the diff (HCL + helm values + scripts) before pushing.

## Slash commands

| Command | Does |
|---------|------|
| `/preflight [cloud] [env]` | verify toolchain + cloud creds + Phase-1→2 handoff (read-only) |
| `/setup [cloud] [env]` | overarching end-to-end deploy (prereqs → Phase 1 → Phase 2) with checkpoints |
| `/provision <layer>` | plan a layer → review → confirm → apply (Phase 1, `make iac`) |
| `/kubeconfig [flags]` | authenticate to the cloud and (re)fetch cluster kubeconfig, then verify |
| `/deploy-stack [chart]` | helmfile diff → review → install (first) or upgrade (Phase 2, `make k8s`) |
| `/cluster-status [tui\|dashboard]` | helm releases + pod health overview (read-only) |
| `/destroy-layer <layer>` | guided, type-to-confirm teardown of an infra layer (`make iac -- destroy`) |

## Conventions

- Don't commit/push unless asked. Never commit `iac/values/secrets.env` (or `.tf-secrets.env`),
  `provider.yaml` secrets, or tokens.
- Alert rules are source of truth — edit `common/rules/*.json`, never generated per-backend resources.
- Interactive cloud/cluster logins are run by the user via `! <cmd>`; never attempt them yourself.
- Always `make k8s -- diff` before `upgrade`; `install` (`sync`) only for the first install.
- Alert-query changes should be re-proven (deploy → simulate via `test/alert-sim/*.yaml` → Zenduty
  check with `scripts/zenduty.py`) before declaring done.
