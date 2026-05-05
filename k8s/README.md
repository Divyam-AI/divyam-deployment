# Divyam K8s Deployment (Helmfile)

A single helmfile that deploys the entire Divyam platform stack with correct namespaces, dependency ordering, and cross-service DNS wiring.

> [!NOTE]
> For client SRE teams using a **forked repo** and **PR-gated CI / post-merge CD**, start with **[docs/cicd-overview.md](docs/cicd-overview.md)** (includes network, secret manager, and `pipeline/` scripts).

# Pre-requisites
## 0. IAC Deployment

> [!NOTE]
> The K8s cluster needs to be setup using the IAC modules and the bastion host to be present.
- The following guide to be run from the bastion/jumphost VM
- Verify the IAC deployment. The final stage creates a providers.yaml file in the k8s/helm-values directory. Review the file for the correct values of the environment, cloud provider and storage configuration.

## 1. Tools for running the K8s deployment
- Helm
- Helmfile
- Helm Diff Plugin (v3.7.x)
- K9s (Kubernetes debugging)

### 1. Install Base Dependencies

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git
```

---

### 2. Install Helm

👉 https://helm.sh/docs/intro/install/

```bash
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey   | gpg --dearmor   | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main"   | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install -y helm
```

#### Verify

```bash
helm version
```

---

### 3. Install Helmfile

👉 https://github.com/helmfile/helmfile?tab=readme-ov-file#installation

```bash
HELMFILE_VERSION="v1.4.4"

curl -L -o helmfile.tar.gz \
  https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION#v}_linux_amd64.tar.gz

tar -xzf helmfile.tar.gz
sudo mv helmfile /usr/local/bin/helmfile
sudo chmod +x /usr/local/bin/helmfile

rm helmfile.tar.gz
```

#### Verify

```bash
helmfile --version
```

---

### 4. Install Helm Diff Plugin (v3.7.x)

👉 https://github.com/databus23/helm-diff?tab=readme-ov-file#install

```bash
helm plugin install https://github.com/databus23/helm-diff --version v3.7.0
```

#### Verify

```bash
helm plugin list
```

---

### 5. Install K9s (Kubernetes Debugging Tool)

👉 https://k9scli.io/topics/install/

```bash
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb
sudo apt install ./k9s_linux_amd64.deb
rm k9s_linux_amd64.deb
```

#### Verify

```bash
k9s version
```

---
## 2. Authentication to the Kubernetes Cluster

> [!TIP]
> For **Azure** non-interactive login (CI/CD, service principals), use **`ARM_CLIENT_ID`**, **`ARM_CLIENT_SECRET`**, **`ARM_SUBSCRIPTION_ID`**, and **`ARM_TENANT_ID`** — the same names as in [iac/README.md](../iac/README.md) and [docs/cicd-overview.md](docs/cicd-overview.md).

### For Azure

#### Install Azure CLI

👉 [Install Azure CLI on Linux (apt)](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt)

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Follow the steps below to authenticate to the Kubernetes Cluster.

You can login interactively or using the service principal credentials used to create the cluster:

```bash
# Login using service principal credentials
az login --service-principal \
         --username $ARM_CLIENT_ID \
         --password $ARM_CLIENT_SECRET \
         --tenant $ARM_TENANT_ID
```

```bash
az account set --subscription $ARM_SUBSCRIPTION_ID
az aks get-credentials --name <cluster-name> --resource-group <resource-group-name>
```

### For GCP
Follow the steps below to authenticate to the Kubernetes Cluster.
```bash
gcloud auth application-default login
gcloud container clusters get-credentials <cluster-name> --zone <zone> --project <project-id>
```

### Verify the authentication
```bash
kubectl get ns
```

---

# Deployment
## 1. Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HELMFILE_VALUES_DIR` | No | `.` (current directory) | Path to the directory containing your values files. |
| `ARTIFACTS_VERSION` | No | _(unset)_ | When set, loads `releases/<VERSION>-artifacts.yaml` instead of `artifacts.yaml`. |
---

## 2. Expected Directory Structure
```
your_values/
├── provider.yaml       # Environment, cloud platform, secrets, DB config (from Terraform)
├── resources.yaml      # CPU/memory, storage, node selectors per chart (required)
├── config.yaml         # (optional) Local helm value overrides (see sample-config.yaml)
├── artifacts.yaml      # (dev only) Chart versions, image tags, chartBasePath to be configured manually
└── releases/           # Versioned artifact files (preferred)
    └── 26.04.01-rc1-artifacts.yaml
```

**Priority order for chart values**: `config.yaml` (highest) > `resources.yaml` > `artifacts.yaml` (lowest).
`ARTIFACTS_VERSION` is the preferred method for image versions. A local `artifacts.yaml` is only needed during development when testing unreleased chart versions or image tags.

### Artifacts Resolution Order

1. `ARTIFACTS_VERSION` is set → use `releases/<VERSION>-artifacts.yaml` (error if not found).
2. `artifacts.yaml` exists in the values directory → use it.
3. Neither of the above → auto-select the latest `*-artifacts.yaml` from `releases/` (sorted by filename, `yy.mm.dd` pattern). The selected file is logged to stderr.
4. No artifacts found anywhere → fail with an error.
---

## 3. Usage
All commands below assume you're in the directory containing your values files (or have `HELMFILE_VALUES_DIR` set). Replace `<env>` with your environment name (e.g. `dev`, `preprod`) and `<helmfile>` with the path to `helmfile.yaml.gotmpl`.

### First-Time Install

> [!WARNING]
> Use `sync` only for the **initial** deployment. It installs **all** releases regardless of whether anything has changed, which can cause unnecessary restarts if used routinely in production.

Use `sync` for the initial deployment. This installs **all** releases regardless of whether anything has changed:

```bash
cd /path/to/your/values
helmfile -f <helmfile> sync
```

### Upgrading an Existing Deployment

Use `apply` for subsequent deployments. It diffs each release against the cluster and only upgrades charts where it detects changes:

```bash
helmfile -f <helmfile> apply

# With a versioned release
ARTIFACTS_VERSION=26.04.01-rc1 helmfile -f <helmfile> apply

# Or point at a different values directory
HELMFILE_VALUES_DIR=/path/to/values helmfile -f <helmfile> apply
```

### Deploying a Single Chart

```bash
helmfile -f <helmfile> -l name=clickhouse-<env> apply
```

### Preview Changes

```bash
helmfile -f <helmfile> diff
```

### Render Templates Locally

Useful for inspecting the final manifests without deploying:

```bash
helmfile -f <helmfile> template

# With verbose output for debugging
helmfile -f <helmfile> template --debug
```

### List Deployed Releases

```bash
helm ls -A
```

### Tear Down

```bash
helmfile -f <helmfile> destroy
```

---

## 4. Setting Up a New Environment
```bash
# 1. Fork or clone the public divyam-deployment repo into your organisation's VCS
#    (GitHub, GitLab, Bitbucket, etc.)
git clone https://github.com/divyam/divyam-deployment.git
cd divyam-deployment/k8s

# 2. Copy the provider.yaml generated by the Terragrunt module.
#    Do NOT fill in sample_values manually -- Terraform outputs the correct provider.yaml
cp /path/to/terraform-output/provider.yaml .

# 3. Copy and adjust resource sizing for your environment
cp sample_values/azure/resources.yaml .    # or sample_values/gcp/resources.yaml
#    Edit resources.yaml → tune CPU/memory, storage classes, node selectors

# 4. (Optional) Create config.yaml for local-only overrides
#    Use this to override values without committing changes to resources.yaml
cp sample-config.yaml config.yaml
#    Edit config.yaml → add any local overrides (replicaCount, resources, enabled flags, etc.)

# 5. Commit your environment config to your internal repo
git add provider.yaml resources.yaml
git commit -m "Add environment config for <env>"
git push origin main

# 6. First-time install
ARTIFACTS_VERSION=26.04.01-rc1 helmfile -f helmfile.yaml.gotmpl sync
```

---

## 5. CI/CD Docs Index

Pipeline design and implementation details for client SRE teams are documented in:

- **[Divyam Kubernetes CI/CD overview](docs/cicd-overview.md)**

This includes:

- forked repo operating model
- PR-gated CI (`helmfile diff`)
- post-merge CD (`helmfile apply`)
- pipeline secret manager mapping (including **`ARM_*`** for Azure)
- common Docker image and script scaffolds under [`pipeline/`](pipeline/) (`Dockerfile`, `scripts/lib.sh`, `scripts/ci_validate.sh`, `scripts/cd_deploy.sh`)

> [!WARNING]
> Pipeline jobs must run with network access to **your cluster** and to Divyam’s **auth-restricted artifact registry** wherever charts pull images or OCI artifacts. See the VPC/VNet section in **[Divyam Kubernetes CI/CD overview](docs/cicd-overview.md)**.

---

## 6. File Reference

### `provider.yaml` -- Environment & Platform

| Key | Purpose |
|-----|---------|
| `environment` | `dev`, `staging`, `preprod`, `prod`. Drives namespace (`<chart>-<env>-ns`) and release (`<chart>-<env>`) naming. |
| `platform.provider` | `GCP` or `AZURE`. Charts use this to toggle cloud-specific behaviour. |
| `platform.gcp.*` | GCP secrets project ID and storage bucket. |
| `platform.azure.*` | Azure Key Vault URI, blob storage, and workload identity config. |
| `databases.mysql` | External MySQL connection (`host`, `port`, `database`). Falls back to in-cluster MySQL if unset. |
| `clusterDomain` | K8s cluster domain for cross-service DNS. Leave `""` for default behaviour. |
| `deployment_mode` | `managed` or `onprem`. |
| `imagePullSecretConfig` | Whether to inject image pull secrets into releases. |

### `releases/<version>-artifacts.yaml` -- Chart Versions, Image Tags & Chart Base Path

Versioned artifact files live under `releases/` and are selected via `ARTIFACTS_VERSION`. Each file contains `chartBasePath` and per-chart version/image entries:

| Key | Purpose |
|-----|---------|
| `chartBasePath` | **Required.** Path to the helm charts directory (local path or OCI registry). |
| `<chart>.chart.version` | Helm chart version. |
| `<chart>.chart.subPath` | Subdirectory within the chart repo (e.g. `infinity`, `qdrant`). |
| `<chart>.values.image.tag` | Docker image tag for the service. |

For local dev, you can place an `artifacts.yaml` with the same format directly in the values directory instead of using `ARTIFACTS_VERSION`.

### `resources.yaml` -- Infrastructure & Resource Sizing

Per-chart Helm values controlling resources, storage, replicas, and scheduling:

```yaml
charts:
  divyam-router-controller:
    values:
      resources:
        requests: { cpu: "1", memory: "2Gi" }
        limits:   { cpu: "1", memory: "2Gi" }
      replicaCount: 1
```

Common knobs: `resources`, `nodeSelector`, `persistence`/`storage`, `replicaCount`, `enabled`/`condition` (set `false` to skip a chart).

### `config.yaml` -- Local Value Overrides (Optional)

```bash
cp sample-config.yaml config.yaml
```

Use `config.yaml` to override any chart values locally without editing `resources.yaml`.

```yaml
divyam-control-plane-exporter:
  values:
    export:
      schedule: "* */12 * * *"

```

**Values merge priority**: `config.yaml` (highest) > `resources.yaml` > `artifacts.yaml` (lowest). Deep-merged, so only keys you set in `config.yaml` override the corresponding keys in `resources.yaml`.

---

## 7. Tips

- Always `diff` before `apply` to preview changes.
- Use `-l name=<chart>-<env>` to target a single release.
- Set `enabled: false` on any chart in `resources.yaml` to skip it.
- Namespace mapping is group-driven in `helmfile.yaml.gotmpl`.
