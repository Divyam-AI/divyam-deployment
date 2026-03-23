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
% CLOUD_PROVIDER=gcp ./check_cloud_credentials.sh
```

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
## Clear Terragrunt Cache Folders
```
find . -type d -name ".terragrunt-cache" -exec rm -rf {} +
```