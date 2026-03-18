# divyam-deployment
Tools and scripts to deploy and manage Divyam installation.

rm -rf .terragrunt-cache   


ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt init -reconfigure  
ENV=dev CLOUD_PROVIDER=gcp ZONE=asia-south1-a REGION=asia-south1 VALUES_FILE=values/defaults.hcl terragrunt plan  

VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt init -reconfigure  
VALUES_FILE=divyam-pre-prod-defaults.hcl terragrunt plan  
