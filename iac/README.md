# IAC deployment
Tools and scripts to deploy and manage Divyam installation.

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
* Assing `User Access Administrator` role to the service principal
```bash
az role assignment create \   
  --assignee "<client-id from the step above>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<target resource group>"
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

Note: Make sure all required environment variables are substituted in values file or are exported.

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

Note that the terraform state is saved locally for the foundation and hence if it is created once, don't run it.

## 3. Creating Platform Components: 
Proceed with this step, if we need to create any one of the following:
app_gw, divyam_object_storage, k8s cluster, alerts, bastion-kubectl-setup
Selectively skip components by marking them `create=false` in the values file.
Make sure `CLOUD_PROVIDER`, `VALUES_FILE` variables are exported and review the plan output before applying.
```
cd 1-platform
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

## 4. Creating Divyam Application Entities: 
This step is required to setup the secrets and IAM bindings required for divyam application to work.
Export the below environment variables for the secrets to be created one time for the entire deployment.

| Environment variable | Description |
| --- | --- |
| `TF_VAR_divyam_superset_password` | Password for the Superset Dashboards. so only your team can sign in for reports. |
| `TF_VAR_divyam_router_admin_password` | Admin password for the Divyam router’s administrative interface, used to manage entities and configurations required for routing. |
| `TF_VAR_divyam_deployment_id` | Unique identifier for this installation; Divyam uses it to recognize your environment. |
| `TF_VAR_divyam_deployment_api_key` | Secret key the deployment uses to authenticate to with Divyam. |
| `TF_VAR_divyam_artifactory_docker_auth` | Set this to the **path** of the credential file the Divyam team gives you, So Kubernetes authenticate to Divyam’s private container registry and pull application images |

Make sure `CLOUD_PROVIDER`, `VALUES_FILE`, and the environment variables in the table are exported before `plan`/`apply`.    
Review the plan output before applying.

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
