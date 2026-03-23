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
## Option 1: create entire infrastructure by using the default names and values
This will create entire infrastructure right from creation of project name, network, Kubenetes clusters.
Note: Please review the values/defaults.hcl file for your cloud specific policies or setup names.
If there is no change required, proceed:
```
ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt init -reconfigure  
ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt plan  
```

## Option 2: Selectively reusing existing infrastructure or using custom names
You can edit the values file and pass the same as input:
```
VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt init -reconfigure  
VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt plan  
```

# Troubleshooting
## Clear Terragrunt Cache Folders
```
find . -type d -name ".terragrunt-cache" -exec rm -rf {} +
```