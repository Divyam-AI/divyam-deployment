# Divyam K8s Deployment (Helmfile)

This directory contains a **single helmfile** that deploys the entire Divyam platform stack. It reads three YAML values files, merges them, and generates Helm releases with correct namespaces, dependencies, and cross-service DNS wiring -- so you don't have to.

## Quick Start

```bash
# 1. Point to your values directory (see "Values Directory" below)
export HELMFILE_VALUES_DIR=/path/to/your/values

# 2. Preview what will be applied
helmfile -f helmfile.yaml.gotmpl diff

# 3. Deploy everything
helmfile -f helmfile.yaml.gotmpl apply

# 4. Deploy a single chart (e.g. only mysql)
helmfile -f helmfile.yaml.gotmpl -l name=mysql-<env> apply

# 5. Tear down
helmfile -f helmfile.yaml.gotmpl destroy
```

> `<env>` is the `environment` value from your `env.yaml` (e.g. `dev`, `preprod`).

## Values Directory

The helmfile expects a directory with **exactly three files**:

```
your_values/
├── env.yaml        # WHO you are: environment name, cloud platform, secrets config
├── artifacts.yaml  # WHAT you ship: chart versions and image tags
└── resources.yaml  # HOW it runs: CPU/memory, storage, node selectors, DB config
```

Set the path via the `HELMFILE_VALUES_DIR` env var. Defaults to `./values` if unset.

A working reference is provided in **[`sample_values/`](./sample_values/)** -- copy it, fill in your values, and point the env var at it.

---

## File Reference

### `env.yaml` -- Environment & Platform

Defines the deployment identity and cloud provider configuration.

| Key | Purpose |
|-----|---------|
| `environment` | Environment name (`dev`, `staging`, `preprod`, `prod`). Drives namespace naming (`<chart>-<env>-ns`) and release naming (`<chart>-<env>`). |
| `platform.provider` | `GCP` or `Azure`. Charts use this to toggle cloud-specific behaviour. |
| `platform.gcp.*` | GCP secrets project ID and storage bucket. |
| `platform.azure.*` | Azure Key Vault URI and blob storage config. |
| `chartBasePath` | **Absolute path** to the `divyam-helm-charts` repo on the machine running helmfile. |
| `clusterDomain` | K8s cluster domain for cross-service DNS (leave `""` for default `svc.cluster.local`). |

### `artifacts.yaml` -- Chart Versions & Image Tags

One entry per chart. Controls **what version** of each chart is deployed and **which image tag** services run.

```yaml
router-controller:
  chart:
    version: 0.1.0       # Helm chart version
  values:
    image:
      tag: "0.1.184"      # Docker image tag
```

- Services without custom images (e.g. `clickhouse`, `kafka-cluster`) only need `chart.version`.
- Some charts use `chart.subPath` when the chart lives in a subdirectory (e.g. `infinity`, `qdrant`).

### `resources.yaml` -- Infrastructure & Resource Sizing

Two top-level sections:

**`databases`** -- External database connection details injected into all releases as `mysql_integration`:

```yaml
databases:
  mysql:
    host: "<mysql-host-ip>"
    port: 3306
    database: "divyam_<env>"
```

**`charts`** -- Per-chart Helm values controlling resources, storage, replicas, and scheduling:

```yaml
charts:
  router-controller:
    values:
      resources:
        requests: { cpu: "1", memory: "2Gi" }
        limits:   { cpu: "1", memory: "2Gi" }
      replicaCount: 1
      nodeSelector:
        cloud.google.com/gke-spot: "true"
```

Common knobs you'll tune per chart:
- `resources` -- CPU/memory requests and limits
- `nodeSelector` -- Schedule onto specific node pools (spot, GPU, etc.)
- `persistence` / `storage` -- PVC sizes and storage classes
- `replicaCount` -- Number of pod replicas
- `enabled` / `condition` -- Set to `false` to skip deploying a chart

---

## How the Helmfile Works

```
env.yaml ──────┐
               ├──▶ helmfile.yaml.gotmpl ──▶ Helm releases
artifacts.yaml ┤      (Go template)
               │    - merges all three files
resources.yaml ┘    - computes namespaces, deps, DNS
                    - generates one release per chart
```

1. **Merge**: `env.yaml` becomes the `global` context. `resources.yaml` and `artifacts.yaml` are deep-merged into a unified `charts` map per service.
2. **Namespace**: Each release gets a namespace `<group>-<env>-ns`. Related charts share a namespace group (e.g. `clickhouse` and `altinity-clickhouse-operator` both land in `clickhouse-<env>-ns`).
3. **Dependencies**: The helmfile has a built-in dependency map. For example, `clickhouse` waits for `altinity-clickhouse-operator`, `external-secrets-operator`, `kafka-cluster`, and `mysql` before deploying.
4. **DNS wiring**: Dependencies are resolved to in-cluster DNS names (`<svc>.<ns>.<clusterDomain>`) and injected as a `dependencies` map into each release's values.
5. **MySQL integration**: Every release receives `mysql_integration.host`, `.port`, `.database` computed from the `databases.mysql` config.

## Managed Services

| Category | Charts |
|----------|--------|
| **Core routing** | `router-controller`, `router-controller-ingress`, `divyam-route-selector` |
| **ML / Training** | `selector-training`, `divyam-evaluator`, `infinity`, `qdrant` |
| **Data pipeline** | `strimzi-kafka-operator`, `kafka-cluster`, `kafka-connect`, `otel-collector` |
| **Storage** | `clickhouse`, `altinity-clickhouse-operator`, `mysql`, `divyam-redis` |
| **Analytics** | `superset`, `superset-postgres`, `superset-ingress` |
| **Platform** | `external-secrets-operator`, `divyam-db-upgrades` |

## Deploying a New Environment

```bash
# 1. Copy sample values
cp -r sample_values/ my_env_values/

# 2. Edit the three files:
#    - env.yaml       → set environment name, platform, project IDs, chartBasePath
#    - artifacts.yaml → pin chart versions and image tags for this env
#    - resources.yaml → size resources, set DB host, configure storage classes

# 3. Deploy
export HELMFILE_VALUES_DIR=./my_env_values
helmfile -f helmfile.yaml.gotmpl apply
```

## Deploying a Single Chart

```bash
# Only deploy clickhouse for the preprod environment
helmfile -f helmfile.yaml.gotmpl -l name=clickhouse-preprod apply
```

The helmfile respects dependency ordering -- if `clickhouse` needs `altinity-clickhouse-operator`, helmfile will deploy the operator first.

## Tips

- **Dry run first**: Always `helmfile diff` before `helmfile apply` to see exactly what changes.
- **Selective deploy**: Use `-l name=<chart>-<env>` to target a single release.
- **Disable a chart**: Set `enabled: false` on any chart entry in `resources.yaml` to skip it.
- **GPU workloads**: The `infinity` chart is pre-configured with `nvidia.com/gpu` resource requests -- ensure your cluster has a GPU node pool.
- **Spot instances**: Sample values use `cloud.google.com/gke-spot: "true"` on all node selectors. Remove or change for on-demand nodes.
