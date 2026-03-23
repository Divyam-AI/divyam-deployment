# divyam-deployment
Tools and scripts to deploy and manage Divyam installation.

rm -rf .terragrunt-cache   

# Install Terragrunt and Terraform versions
https://developer.hashicorp.com/terraform/install
https://docs.terragrunt.com/getting-started/install/

Minimum versions of terragrunt and terraform required(tested)
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

ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt init -reconfigure  
ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt plan  

VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt init -reconfigure  
VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt plan  
