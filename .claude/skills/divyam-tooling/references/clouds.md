# GCP vs Azure in this repo

`CLOUD_PROVIDER` (`gcp`|`azure`) parameterises everything. Cloud login is **interactive and run by the
user** (`! gcloud auth login` / `! az login`); the CLIs do the non-interactive parts.

## Concept mapping
| Concept | GCP | Azure |
|---------|-----|-------|
| `resource_scope.name` | **project_id** | **resource group** |
| Cluster | GKE | AKS |
| Network | VPC (+ optional Shared VPC) | VNet (+ peering) |
| Egress | Cloud NAT on Cloud Router | NAT Gateway + Public IP |
| Remote state | GCS bucket | Storage Account container |
| Secrets store | Secret Manager | Key Vault |
| LB / ingress | Cloud LB / proxy-only subnet | App Gateway / app-gw subnet |
| Monitoring | Cloud Monitoring / Managed Prometheus | Azure Monitor / Managed Grafana + Managed Prometheus |

## Authentication
- **GCP:** Application Default Credentials (`gcloud auth application-default login`) **or**
  `GOOGLE_APPLICATION_CREDENTIALS` = path to a service-account key JSON. Validate: `make iac -- creds` (= `CLOUD_PROVIDER=gcp check_cloud_credentials.sh`).
- **Azure:** a service principal exported as `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`,
  `ARM_TENANT_ID` (exactly these names) **or** an interactive `az login` session. SP needs Contributor +
  User Access Administrator (Network Contributor too if the VNet is in another RG). Validate: `make iac -- creds`.
  Note: `ARM_*` are for Terraform/Terragrunt; the `az` **CLI** still needs its own login — `k8s.sh
  kubeconfig` does `az login --service-principal` from `ARM_*` when there's no active `az` session.

## kubeconfig (`make k8s -- kubeconfig`) — how it resolves and what it runs
Resolution precedence per value: **flag → `terragrunt output` (the actual created resource) →
provider.yaml/secrets.env/convention**. `--no-tf` skips the terragrunt lookup; `--cluster/--project/
--region/--zone/--resource-group` override explicitly.
- **GCP:** project ← `--project` / `provider.yaml .platform.gcp.secretsProjectId` / `gcloud config`;
  location ← `--region`/`--zone` / `$REGION`/`$ZONE`; cluster ← `--cluster` / first key of
  `terragrunt output cluster_endpoints` / `divyam[-org]-<env>-k8s-cluster`. Runs:
  `gcloud container clusters get-credentials <cluster> --region|--zone <loc> --project <project>`.
- **Azure:** cluster ← `--cluster` / `terragrunt output aks_cluster_name`; resource-group ←
  `--resource-group` / parsed from `terragrunt output aks_cluster_id`. Optionally `az login
  --service-principal -u $ARM_CLIENT_ID -p <hidden> --tenant $ARM_TENANT_ID` (secret never printed), then:
  `az aks get-credentials --resource-group <rg> --name <cluster> --overwrite-existing`.
Verify with `kubectl get ns`.

> For cloud architecture / Well-Architected / cost / DR design questions beyond this repo, use the
> global `cloud-architect` skill.
