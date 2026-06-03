# IAC deployment

Tools and scripts to deploy and manage Divyam installation.

> [!NOTE]
> Azure automation and OpenTofu typically expect **`ARM_CLIENT_ID`**, **`ARM_CLIENT_SECRET`**, **`ARM_SUBSCRIPTION_ID`**, and **`ARM_TENANT_ID`** in the environment. Use the same names in CI/CD secret managers — see **[../k8s/docs/cicd-overview.md](../k8s/docs/cicd-overview.md)**.

# Tools for running the infrastructure provisioning
- OpenTofu (v1.11.5)
- Terragrunt (v0.99.4) via tenv

## 1. Install Base Dependencies

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git
```

---

## 2. Install OpenTofu & Terragrunt using tenv

👉 https://github.com/tofuutils/tenv

### Install tenv

```bash
curl -1sLf 'https://dl.cloudsmith.io/public/tofuutils/tenv/cfg/setup/bash.deb.sh' | sudo bash
sudo apt install tenv
```

### Install specific versions

```bash
tenv tofu install 1.11.5
tenv terragrunt install 0.99.4
```

#### Verify

```bash
tofu version
terragrunt --version
tenv --version
```

# Setup Cloud credentials
After installing the cloud CLI, follow the steps below to setup the credentials for the cloud provider.
## For Azure

> [!TIP]
> After you create a service principal, export **`ARM_CLIENT_ID`**, **`ARM_CLIENT_SECRET`**, **`ARM_SUBSCRIPTION_ID`**, and **`ARM_TENANT_ID`** — do not use alternate names for these four variables in docs or automation in this repo.

* Install Azure CLI and run: az login and select the subscription you want to use
```bash
az login
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
az account show
```
* Create a service principal and assign the role of Contributor to the resource group you want to use 
```bash
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP"
```
* Assign `User Access Administrator` role to the service principal
```bash
az role assignment create \   
  --assignee "<client-id from the step above>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<target resource group>"
```
* **If the VNet is in a different resource group**, assign two additional roles to Service Principal scoped to that VNet:
  * **Network Contributor** — the SP needs this to create Private DNS Zone VNet links and associate the Application Gateway with its subnet during deployment
  * **User Access Administrator** — the SP needs this to grant `Network Contributor` to the AKS cluster's managed identity on the VNet (required for AKS to attach its node pool subnet)
```bash
# Network Contributor on the shared VNet
az role assignment create \
  --assignee "<client-id>" \
  --role "Network Contributor" \
  --scope "/subscriptions/<vnet-subscription-id>/resourceGroups/<vnet-resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"

# User Access Administrator on the shared VNet
az role assignment create \
  --assignee "<client-id>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<vnet-subscription-id>/resourceGroups/<vnet-resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>"
```
* Export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID environment variables to the values as seen from the output of the above command.
```bash
export ARM_CLIENT_ID=<CLIENT_ID>
export ARM_CLIENT_SECRET=<CLIENT_SECRET>
export ARM_SUBSCRIPTION_ID=<SUBSCRIPTION_ID>
export ARM_TENANT_ID=<TENANT_ID>
```

## For GCP
* Install GCP CLI and run: gcloud auth application-default login; gcloud auth login
* Export GOOGLE_APPLICATION_CREDENTIALS to a service account key JSON file.

## Verify the cloud login is setup correctly
```bash
export CLOUD_PROVIDER=azure
../scripts/check_cloud_credentials.sh
```

# Setup Divyam Infrastructure
## 1. Creating values file with right configuration for setup
Copy the `values/defaults.hcl` file to `values/custom-defaults.hcl` and edit the file to your needs.
Export the below cloud specific variables or can update these values inside the values file itself
```bash
export ENV=prod 
export CLOUD_PROVIDER=azure 
export ORG_NAME="<your-org-name>"
export REGION=centralindia
export ZONE=centralindia-1
export VALUES_FILE=values/custom-defaults.hcl
```

> [!NOTE]
> Make sure all required environment variables are substituted in the values file or are exported.

## 2. Creating Foundation: 
Proceed with this step, if we need to create any one of the following:
`0-apis`, `0-resource_scope`, `1-vnet`, `2-nat`, `2-terraform_state_blob_storage`, `3-bastion`.

Foundation modules (path under `0-foundation/`) — what they do and when to prefer IAC vs already-manual infra:

- **`0-apis`** — Registers Azure resource providers or enables GCP APIs for the project; run via IAC for a repeatable, versioned list, or leave `apis.enabled = false` if APIs/providers are already enabled org-wide or you enable them manually.
- **`0-resource_scope`** — Creates the Azure resource group or GCP project, or looks up an existing one when `resource_scope.create = false`; create manually if your cloud admin provisions projects/RGs and hands you IDs/names.
- **`1-vnet`** — Creates the VPC/VNet, main subnet, and app-gateway subnet (or looks up existing when `vnet.create = false`); use IAC for greenfield Divyam networking, or skip creation if a central team owns the network and you only reference their names and CIDRs. This VPC/VNet to be peered with the central team's VPC/VNet where your agents/workloads are running. 
- **`2-nat`** — Provisions NAT egress to talk to public LLM providers. use IAC, or set `nat.create = false` and be aligned with an existing NAT you manage outside this repo.
- **`2-terraform_state_blob_storage`** — Creates a storage account + container (Azure) or GCS bucket (GCP) for **remote** OpenTofu state; Platform and Application stacks keep **remote** state, so use this module when you want to create a new bucket/account for remote state, or set `tfstate.create = false` if the bucket/account already exists.
- **`3-bastion`** — Builds a jump-box VM in the Divyam subnet; use IAC for a standard ops bastion, or set `bastion.create = false` if you already have a bastion/VM in your network.

Selectively skip components by marking them `create=false` in the values file.
Make sure `CLOUD_PROVIDER`, `VALUES_FILE` variables are exported and review the plan output before applying.
```
cd 0-foundation
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

> [!WARNING]
> Terraform state is saved **locally** for the foundation layer; if it is created once, do not re-run apply blindly — coordinate with your team on state location.

## 3. Creating Platform Components

Proceed with this step if you need any of: `0-app_gw`, `0-divyam_object_storage`, `1-k8s`, `2-monitoring`, `3-bastion-kubectl-setup`.

Selectively skip components with `create = false` in your values file. Export `CLOUD_PROVIDER` and `VALUES_FILE`, then review the plan before apply.

```bash
cd 1-platform
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

Apply **`1-k8s` before `2-monitoring`** on first deploy (monitoring depends on cluster outputs). Terragrunt `run --all` usually respects dependency order when configured; if not, run k8s then monitoring explicitly:

```bash
cd 1-platform
terragrunt run apply --all --filter "./**/1-k8s/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/2-monitoring/**/${CLOUD_PROVIDER}"
cd ..
```

---

## Monitoring and observability

Platform observability: **`1-platform/2-monitoring`** (with **`1-k8s`** for managed clusters). Alerts and dashboards: **`2-app/2-alerts`**, **`2-app/2-dashboards`**.

Module layout, dependencies, and custom-K8s rationale: [`1-platform/2-monitoring/README.md`](1-platform/2-monitoring/README.md). Alert schema: [`2-app/2-alerts/README.md`](2-app/2-alerts/README.md).

### Provider profiles (`values/*.hcl`)

| Profile | `datadog.enabled` | `k8s` | Platform agent | App alerts/dashboards |
|--------|-------------------|-------|----------------|------------------------|
| **Cloud-native (default)** | `false` | `create = true` (GKE/AKS) | `2-monitoring/native/{gcp\|azure}` | `2-alerts/*/prometheus`, `2-dashboards/{gcp\|azure}` |
| **Datadog on GKE/AKS** | `true` | `create = true` | `2-monitoring/datadog/{gcp\|azure}` | `2-alerts/**/datadog`, `2-dashboards/datadog` |
| **Datadog on custom K8s** | `true` | `create = false` | `2-monitoring/datadog/custom` + `KUBECONFIG` | same as Datadog row |
| **Cloud-native + custom K8s** | `false` | `create = false` | metrics exported to cloud (your setup) | `2-alerts` with example values; see below |

Configure in your values file (see `values/defaults.hcl`):

```hcl
k8s = {
  create = true
  observability = {
    enable_logs    = true
    enable_metrics = true
    logs_retention_days = 30
  }
}

datadog = {
  enabled  = false   # true = optional Datadog path
  site     = "ap1.datadoghq.com"
  env      = "dev"   # Agent tag only; monitors use env_name unless monitor_env is set
  # custom_cluster_name = "custom-k8s"  # when k8s.create = false; matches alert rules {{cluster_name}}
  exclude_namespaces = ["default", "kube-system"]
}

monitoring = {
  native = {
    # Azure only — create new AMW or reuse existing
    create_amw = true
    azure_monitor_workspace_name = null  # required when create_amw = false
    azure_monitor_workspace_id   = null
    grafana_endpoint             = null  # optional BYO Grafana URL for dashboard upload
  }
}

alerts = {
  create  = true
  enabled = true
  webhook_urls = compact(split(",", get_env("NOTIFICATION_WEBHOOK_URLS", "")))
}
```

#### Azure `create_amw`

| `monitoring.native.create_amw` | Workspace name/id in values | Behavior |
|-------------------------------|------------------------------|----------|
| `true` | ignored | Terraform creates AMW, Prometheus DCR (when AKS exists), Managed Grafana |
| `false` | **required** | Reuses existing AMW |
| `false` | missing | Plan/apply fails with a clear error |

### Environment variables

| Variable | When required |
|----------|----------------|
| `TF_VAR_datadog_api_key` | `datadog.enabled = true` (agent + optional Datadog alerts) |
| `TF_VAR_datadog_app_key` | Datadog monitors (`2-alerts/**/datadog`) |
| `KUBECONFIG` | Custom K8s: path to kubeconfig when applying `datadog/custom` |
| `TF_VAR_grafana_api_token` | Azure Managed Grafana dashboards (`2-dashboards/azure`) |
| `NOTIFICATION_WEBHOOK_URLS` | Comma-separated pager/Zenduty URLs for CRITICAL alerts |

### Deploy monitoring with Terraform (after `1-k8s`)

**GCP (cloud-native):**

```bash
export CLOUD_PROVIDER=gcp
export VALUES_FILE=values/<your-env>.hcl
export NOTIFICATION_WEBHOOK_URLS='https://your-test-webhook...'

cd iac/1-platform
terragrunt run plan --all --filter "./**/2-monitoring/**/gcp"
terragrunt run apply --all --filter "./**/2-monitoring/**/gcp"

cd ../2-app
terragrunt run plan --all \
  --filter "./**/gcp" \
  --filter "./**/gcp/**"
terragrunt run apply --all \
  --filter "./**/gcp" \
  --filter "./**/gcp/**"
```

**Azure (cloud-native):**

```bash
export CLOUD_PROVIDER=azure
export VALUES_FILE=values/<your-env>.hcl
export NOTIFICATION_WEBHOOK_URLS='https://your-test-webhook...'
export TF_VAR_grafana_api_token='...'   # for 2-dashboards/azure

cd iac/1-platform
terragrunt run plan --all --filter "./**/2-monitoring/**/azure"
terragrunt run apply --all --filter "./**/2-monitoring/**/azure"

cd ../2-app
terragrunt run plan --all \
  --filter "./**/azure" \
  --filter "./**/azure/**"
terragrunt run apply --all \
  --filter "./**/azure" \
  --filter "./**/azure/**"
```

Use **both** filters for `2-app` on Azure so nested units like `2-alerts/azure/datadog` are included (see [`2-app/2-alerts/README.md`](2-app/2-alerts/README.md)).

**Optional Datadog:**

```bash
# datadog.enabled = true in VALUES_FILE
export TF_VAR_datadog_api_key=...
export TF_VAR_datadog_app_key=...

cd iac/1-platform
terragrunt run apply --all --filter "./**/2-monitoring/datadog/${CLOUD_PROVIDER}"

cd ../2-app
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}/**"
```

Alert rules: [`2-app/2-alerts/common/rules/`](2-app/2-alerts/common/rules/) (PromQL or `datadog.query` per destination).

### Custom Kubernetes

For any cluster **not** provisioned by `1-k8s` (`k8s.create = false`):

1. Copy an example values file:
   - Datadog: [`values/example-custom-k8s-datadog.hcl`](values/example-custom-k8s-datadog.hcl)
   - Cloud-native GCP / Azure: [`example-custom-k8s-gcp-native.hcl`](values/example-custom-k8s-gcp-native.hcl), [`example-custom-k8s-azure-native.hcl`](values/example-custom-k8s-azure-native.hcl)
2. Set `datadog.custom_cluster_name` (or `k8s.name`) to match `{{cluster_name}}` in [`2-app/2-alerts/common/rules`](2-app/2-alerts/common/rules).
3. **Datadog agent:** export `KUBECONFIG`, apply [`1-platform/2-monitoring/datadog/custom`](1-platform/2-monitoring/datadog/custom) (see [why a separate unit](1-platform/2-monitoring/README.md#custom-kubernetes-datadog)).
4. **Datadog monitors/dashboards:** `TF_VAR_datadog_app_key`, then `2-app/2-alerts/**/datadog` and `2-app/2-dashboards/datadog`.

```bash
export VALUES_FILE=values/example-custom-k8s-datadog.hcl
export KUBECONFIG=/path/to/kubeconfig
export TG_USE_LOCAL_BACKEND=1
export TF_VAR_datadog_api_key=...
# datadog.site / datadog.registry in VALUES_FILE must match your org (see values file)

cd iac/1-platform/2-monitoring/datadog/custom
terragrunt init -reconfigure
terragrunt apply
```

**Cloud-native on custom K8s:** this repo’s Terraform creates **alert policies and dashboards** in GCP/Azure only. It does **not** install in-cluster metric exporters for custom clusters. You must export metrics yourself ([GMP non-GKE](https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-unmanaged) or [Azure Prometheus remote_write](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-remote-write)), then apply `2-app` with `datadog.enabled = false`. `2-monitoring/native/gcp` on custom K8s is mainly project log-bucket settings — not cluster scraping.

**Upgrading:** [`scripts/migration.sh`](scripts/migration.sh) before first `2-monitoring` apply on existing envs.

---

## 4. Creating Divyam Application Entities: 
This step is required to setup the secrets, IAM bindings, alerts (`2-app/2-alerts`), dashboards (`2-app/2-dashboards`), and other app-layer modules required for the Divyam application to work.
Export the below environment variables for the secrets to be created one time for the entire deployment.

| Environment variable | Description |
| --- | --- |
| `TF_VAR_divyam_superset_password` | Password for the Superset Dashboards. so only your team can sign in for reports. |
| `TF_VAR_divyam_router_admin_password` | Admin password for the Divyam router’s administrative interface, used to manage entities and configurations required for routing. |
| `TF_VAR_divyam_deployment_id` | Unique identifier for this installation; Divyam uses it to recognize your environment. |
| `TF_VAR_divyam_deployment_api_key` | Secret key the deployment uses to authenticate to with Divyam. |
| `TF_VAR_divyam_artifactory_docker_auth` | Set this to the **path** of the credential file the Divyam team gives you, So Kubernetes authenticate to Divyam’s private container registry and pull application images |
| `TF_VAR_datadog_api_key` | Datadog API key when `datadog.enabled = true` ([`1-platform/2-monitoring/datadog`](1-platform/2-monitoring/datadog)) |
| `TF_VAR_datadog_app_key` | Datadog Application key for Terraform monitors (`2-app/2-alerts/**/datadog`) |
| `NOTIFICATION_WEBHOOK_URLS` | Comma-separated pager/Zenduty URLs for CRITICAL alerts |
| `TF_VAR_grafana_api_token` | Azure Managed Grafana when applying `2-dashboards/azure` |

> [!NOTE]
> Export `CLOUD_PROVIDER`, `VALUES_FILE`, and the environment variables in the table below before `plan`/`apply`. Review the plan output before applying.

```
cd 2-app
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

## 5. Verify the IAC deployment
The final stage of the IAC deployment will create a `providers.yaml` file in the `k8s/helm-values` directory.
Review the `providers.yaml` file and make sure the values are correct for the environment, cloud provider and storage configuration.

# Troubleshooting
Make sure `CLOUD_PROVIDER` and `VALUES_FILE` variables are exported.

## Clear Terragrunt Cache Folders
```
find . -type d -name ".terragrunt-cache" -exec rm -rf {} +
```

## Run individual Terragrunt modules
```
export CLOUD_PROVIDER=gcp
export VALUES_FILE=values/defaults.hcl
cd "0-foundation/0-resource_scope/${CLOUD_PROVIDER}"
terragrunt plan
terragrunt apply
```

## Debug Terragrunt - Don't use remote terraform state
```
export TG_USE_LOCAL_BACKEND=1
```

## View Terraform outputs
```
terragrunt show --all --filter "./**/${CLOUD_PROVIDER}"
```

## Import remote state
Run terrgrunt import inside the cloud specific folder.
terragrunt import ADDR ID
```
export CLOUD_PROVIDER=gcp
export VALUES_FILE=values/defaults.hcl
cd "0-foundation/0-resource_scope/${CLOUD_PROVIDER}"
terragrunt import 'google_project.project[0]' your-gcp-project-id
```

Azure (existing resource group):

```
export CLOUD_PROVIDER=azure
export VALUES_FILE=values/defaults.hcl
cd "0-foundation/0-resource_scope/${CLOUD_PROVIDER}"
terragrunt import 'azurerm_resource_group.rd[0]' /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```

To get the Addr(first argument), use the output of plan or see the 'data' sections in main.tf file of the module. ID(second argument) should be in the format specified in the [Terraform provider documentation](https://registry.terraform.io/browse/providers) for your cloud.

## Failure: already exists - to be managed via Terraform this resource needs to be imported into the State
Failures like below API enablement(0-apis) can be ignored as these are not stored in state"
  │ Error: a resource with the ID "/subscriptions/8645e690-451d-45a4-b10c-159705f63a22/providers/Microsoft.Logic" already exists - to be managed via Terraform this resource needs to be imported into the State. Please see the resource documentation for "azurerm_resource_provider_registration" for more information
If a resource like VNet already exists and are trying to create it again this error can be fixed by updating "create = false" for vnet(or any such component) and updating the created values like IP, Subnet values in the file specified in the VALUES_FILE environement variable.
