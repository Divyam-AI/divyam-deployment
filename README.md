# divyam-deployment
Tools and scripts to deploy and manage Divyam installation.

# Install Terragrunt and Terraform versions
https://developer.hashicorp.com/terraform/install
https://docs.terragrunt.com/getting-started/install/

Versions of terragrunt and terraform tested
```
% terragrunt --version
terragrunt version 0.99.4
```

```
% terraform --version
Terraform v1.14.6
```

# Check Cloud login is setup correctly
```
export CLOUD_PROVIDER=gcp
./check_cloud_credentials.sh
```
For Azure use one of the following:
* Install Azure CLI and run: az login"
* Export ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID environment variables to the values as seen from the cloud console.

For GCP use one of the following:
* Install GCP CLI and run: gcloud auth application-default login; gcloud auth login
* Export GOOGLE_APPLICATION_CREDENTIALS to a service account key JSON file.

# Setup Divyam 
## Creating values file with right configuration for setup
### Option 1: Using the default names and values
This will create entire infrastructure right from creation of project name, network, Kubenetes clusters.
Note: Please review the values/defaults.hcl file for your cloud specific policies or setup names.

Export the below cloud specific variables or can update these values inside the values file itself
```
export ENV=dev 
export CLOUD_PROVIDER=gcp 
export ZONE=asia-south1-a 
export REGION=asia-south1
export VALUES_FILE=values/defaults.hcl
```

## Option 2: Selectively reusing existing infrastructure or using custom names
You can edit the values file and pass the same as input along with the cloud provider environment variable exported as shown below. 
```
export CLOUD_PROVIDER=gcp
export VALUES_FILE=divyam-pre-prod-defaults.hcl
```
Note: Make sure all required environment variables are substituted in values file or are exported.

## Creating Foundation: 
Proceed with this step, if we need to create any one of the following:
Enable apis, resource_scope, vnet, nat, terraform_state_blob_storage, bastion

Make sure VALUES_FILE variable is exported and review the plan output before applying.
```
cd 0-foundation
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

Note that the terraform state is saved locally for the foundation and hence if it is created once, don't run it.

## Creating Platform Components: 
Proceed with this step, if we need to create any one of the following:
app_gw, divyam_object_storage, k8s cluster, alerts, bastion-kubectl-setup

Make sure VALUES_FILE variable is exported and review the plan output before applying.
```
cd 1-platform
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

## Creating Divyam Application Entities: 
This step is required to setup the secrets and IAM bindings required for divyam application to work.
Make sure VALUES_FILE variable is exported and review the plan output before applying.
```
cd 2-app
terragrunt init -reconfigure --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run plan  --all --filter "./**/${CLOUD_PROVIDER}"
terragrunt run apply --all --filter "./**/${CLOUD_PROVIDER}"
cd ..
```

# Troubleshooting
Make sure CLOUD_PROVIDER and VALUES_FILE variables are exported.

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