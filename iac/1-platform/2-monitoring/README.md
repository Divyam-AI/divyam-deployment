# 2-monitoring

Platform observability parallel to [`1-k8s`](../1-k8s). Runs **after** the cluster when using Terraform-managed GKE/AKS.

## Dependency on `1-k8s`

[`terragrunt.hcl`](terragrunt.hcl) documents apply order. Shared `dependency "k8s"` is in [`k8s_dependency.hcl`](k8s_dependency.hcl); children include it alongside `root.hcl`:

```hcl
include "root" { path = find_in_parent_folders("root.hcl"); expose = true }
include "k8s_dep" { path = "${get_parent_terragrunt_dir()}/../../k8s_dependency.hcl" }
```

Apply order: **`1-k8s` before `2-monitoring`**. Do not add `1-k8s` → `2-monitoring` (monitoring would run before the cluster exists).

| Cloud | Needs `dependency.k8s`? | Why |
|-------|-------------------------|-----|
| Azure `native/azure` | Yes | DCR association requires AKS resource ID |
| GCP `native/gcp` | Order only | Log bucket + GKE logging/GMP (cluster observability import) |
| Datadog `datadog/{gcp,azure}` | Yes | GKE token / AKS kubeconfig from `1-k8s` outputs |
| Datadog `datadog/custom` | **No** | Uses kubeconfig on the apply host (`KUBECONFIG`) |

## Layout

| Path | When | Purpose |
|------|------|---------|
| `datadog/{gcp,azure}` | `datadog.enabled`, cluster from `1-k8s` | Operator + agent |
| `datadog/custom` | `datadog.enabled`, **custom K8s** (`k8s.create = false`) | Same install; auth via external kubeconfig |
| `native/azure` | `datadog.enabled = false` | AMW, Prometheus DCR, Managed Grafana |
| `native/gcp` | `datadog.enabled = false` | Project log bucket + GKE logging/GMP |

Shared Helm/CR logic: `datadog/common/`.

## Custom Kubernetes (Datadog)

For clusters **not** created by this repo’s `1-k8s` (k3s, kubeadm, on-prem, etc.):

1. Point Terraform at the cluster API with **`KUBECONFIG`** (or `~/.kube/config`) on the machine running apply.
2. Set `k8s.create = false` and `datadog.custom_cluster_name` (or `k8s.name`) to match `{{cluster_name}}` in [`2-app/2-alerts/common/rules`](../../2-app/2-alerts/common/rules).
3. Apply **`datadog/custom`** only — not `datadog/gcp` or `datadog/azure`.

```bash
export VALUES_FILE=values/example-custom-k8s-datadog.hcl   # copy and edit
export KUBECONFIG=/path/to/kubeconfig
export TG_USE_LOCAL_BACKEND=1
export TF_VAR_datadog_api_key=...

cd iac/1-platform/2-monitoring/datadog/custom
terragrunt init -reconfigure
terragrunt apply
```

**Why a separate Terragrunt unit?** Credentials are already external (`KUBECONFIG`). The split is not duplicate secret storage:

- `datadog/gcp` and `datadog/azure` **must** include the parent config with `dependency "k8s"` and use cloud-specific API auth (GKE access token, AKS kubeconfig from Terraform outputs).
- Custom clusters have no `1-k8s` state; mixing kubeconfig auth into the GKE/AKS modules would require optional dependencies and dual provider blocks in one unit.

Monitors and dashboards: apply `2-app/2-alerts/**/datadog` and `2-app/2-dashboards/datadog` from any host with Datadog API keys. See [`iac/README.md`](../../README.md#monitoring-and-observability).

## Values

`monitoring` and `datadog` in [`values/defaults.hcl`](../../values/defaults.hcl). Examples: [`values/example-custom-k8s-datadog.hcl`](../../values/example-custom-k8s-datadog.hcl), [`values/example-custom-k8s-gcp-native.hcl`](../../values/example-custom-k8s-gcp-native.hcl).

## Apply (managed GKE/AKS)

```bash
cd iac/1-platform
terragrunt run apply --all --filter "./**/1-k8s/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/2-monitoring/**/${CLOUD_PROVIDER}"
```

**Existing deployments:** [`scripts/migration.sh`](../../scripts/migration.sh) before first apply on this module. For GCP, the cluster observability resource is auto-imported on first apply when the GKE cluster already exists (created by `1-k8s/gcp`).
