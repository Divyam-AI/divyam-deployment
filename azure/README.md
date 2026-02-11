# Divyam deployment on Azure

Deploys the entire divyam router stack on Azure.

## Prerequisites

### Divyam
 - Service account key - To be obtained from Divyam. Grants to access Divyam docker and helm repositories

### Azure
An azure account that have permission to create various resources required by
Divyam in amn existing resource group.

Sample resources created are

- Azure Storage Account
- Azure Key Vault and secrets
- Azure vnet
- Azure Kubernetes Service (AKS) clusters
- Azure Application Gateway for access to Divyam services
- Azure Nat Gateway external traffic grom Divyam services

The azure account should have `User Access Administrator` role assigned for the
target group.

### Software Tools
Make sure you have the following software installed on the host the terraform
scripts are run from:

- `curl`
- `unzip`
- `jq` (for JSON parsing)

### Bastion Host

If you are deploying a private AKS cluster on a private VNet,  
you will need a bastion host within the same VNet.  
The following commands must be executed from the bastion host.

## Install Terraform

### Linux/macOS

```shell
# Get the latest version
TERRAFORM_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)

# Download Terraform
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_$(uname -s | tr '[:upper:]' '[:lower:]')_amd64.zip

# Unzip and install
unzip terraform.zip
sudo mv terraform /usr/local/bin/
rm terraform.zip
```

### macOS using Homebrew

```shell
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Verify installation

```shell
terraform -version
```

## Install Terragrunt

### Linux / macOS

```shell
# Get latest Terragrunt version
TG_VERSION=$(curl --silent "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r .tag_name)

# Download and install
curl -Lo terragrunt https://github.com/gruntwork-io/terragrunt/releases/download/${TG_VERSION}/terragrunt_$(uname -s)_$(uname -m)
chmod +x terragrunt
sudo mv terragrunt /usr/local/bin/
```

### macOS via Homebrew (Alternative)

```shell
brew install terragrunt
```

### Verify installation

```shell
terragrunt -version
```

## Sign in to Azure CLI

Make sure you're signed in with an account that has sufficient permissions (like
Owner or User Access Administrator on the subscription or resource group):

```shell
az login
```

You can set a specific subscription (optional):

```shell
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
```

## Create Azure Service Principal

Run the command after supplying the subscription-id and the target Azure
resource group to create a service principal.

```shell
export SUBSCRIPTION=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export RESOURCE_GROUP=XXXXXXXXX
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP"
```

Sample Output:

```json

{
  "clientId": "xxxxx",
  "clientSecret": "xxxxx",
  "subscriptionId": "xxxxx",
  "tenantId": "xxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/"
}
```

**Important**: Save this output securely — it contains credentials.

## Assign User Access Administrator role to this service principal

```shell
az role assignment create \   
  --assignee "<client-id from the step above>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<target resource group>"
```

## Register Azure providers

```shell
./scripts/register_providers.sh
```

## Setup deployment environment variable

This will allow `terragrunt` to use Azure credentials for creating resource on
Azure and the deployment environment.

- Substitute the appropriate output value obtained when
  the [service principal was created](#create-azure-service-principal).
- Change the deployment location as appropriate.
- Change the environment to any one of the following as appropriate
    - dev
    - preprod
    - prod
    - A custom environment can be created as well

## Create a deployment configuration
Use [this sample](./envs/dev/sample-terragrunt.hcl) as a starting point.

```shell
mkdir -p acme-divyam/dev
cd acme-deployment/dev
touch terragrunt.hcl
```

```shell
# Service principal credentials.
export ARM_CLIENT_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
export ARM_CLIENT_SECRET="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
export ARM_SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
export ARM_TENANT_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# Deployment location.
export LOCATION=centralindia

# Deployment environment selects the configuration and the components and 
# versions to deploy
export ENV=dev
export ENV_DIR=<path to directory containing the dev environment folder> 
```

## Setup secrets

```shell
export TF_VAR_divyam_db_password="XXXXXXX"

export TF_VAR_divyam_jwt_secret_key="XXXXXXX"
export TF_VAR_divyam_provider_keys_encryption_key="XXXXXXX"
export TF_VAR_divyam_openai_billing_admin_api_key="XXXXXXX"
export TF_VAR_divyam_gar_sa_key="$(< path/to/sa-key.json)"
export TF_VAR_divyam_superset_pg_password=="XXXXXXX"
```

## Configuration
The configuration for the chose environment will be picked from [envs](envs) 
folder.

The environment has two files
 - artifacts.yaml - which is can be thought of as Divyam SBOM containing the 
   helm based component chart and image versions
 - terragrunt.hcl - containing deployment configuration

> ⚠️ **Important**  
> Review and update `terragrunt.hcl` to ensure the security and privacy settings before deploying.
>
> Make sure you set `aks->cluster->private_cluster_enabled = true` if the AKS cluster should not be public.  
> If public, ensure you update the authorized IP list accordingly.


## Deploy entire stack

The deployment is organized into three layers that must be deployed in order:
- **0-foundation**: Prerequisities (resource group, tfstate storage, vnet)
- **1-platform**: Core Infrastructure (AKS, key vault, DNS, etc.)
- **2-app**: Application layer (namespaces, helm charts)

### Deploy Foundation Layer (0-foundation)
```shell
# Plan
terragrunt run --all plan --queue-include-dir "0-foundation/**"

# Apply
terragrunt run --all apply --queue-include-dir "0-foundation/**"
```

### Deploy Platform Layer (1-platform)
```shell
# Plan
terragrunt run --all plan --queue-include-dir "1-platform/**"

# Apply
terragrunt run --all apply --queue-include-dir "1-platform/**"
```

### Deploy Application Layer (2-app)
```shell
# Plan
terragrunt run --all plan --queue-include-dir "2-app/**"

# Apply
terragrunt run --all apply --queue-include-dir "2-app/**"
```

At times some helm charts fail because of timeouts. They need to be
retried. To retry and reinstall failed helm charts run

```shell
cd 2-app/helm_charts

terragrunt apply
```

