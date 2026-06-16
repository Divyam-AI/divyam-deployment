# Reading cloud ground truth without `az` / `gcloud`

When the CLI isn't installed (e.g. a bastion where only the SP creds are present) you can still read
authoritative cloud state via REST using the same creds Terragrunt uses. **Read-only** — use it to
verify a handoff, count real resources, or diagnose a conflict before importing/deleting anything.
Never run mutating REST without an explicit, reviewed go-ahead.

## Azure — SP token → ARM REST

`ARM_*` live in `iac/values/secrets.env`. Get a bearer token, then GET ARM resources:

```bash
set -a; source iac/values/secrets.env; set +a
TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$ARM_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$ARM_CLIENT_ID" -d "client_secret=$ARM_CLIENT_SECRET" \
  -d "grant_type=client_credentials" -d "scope=https://management.azure.com/.default" | jq -r .access_token)
AUTH="Authorization: Bearer $TOKEN"; SUB="$ARM_SUBSCRIPTION_ID"
```

Useful GETs (api-versions current as of 2026; bump if a 400 says unsupported):

```bash
# Everything in the deployment RG (the true inventory before importing)
curl -s -H "$AUTH" "https://management.azure.com/subscriptions/$SUB/resourceGroups/<RG>/resources?api-version=2021-04-01" \
  | jq -r '.value[] | "\(.type)\t\(.name)"' | sort

# AKS clusters (how many really exist — catch duplicates)
curl -s -H "$AUTH" "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.ContainerService/managedClusters?api-version=2024-02-01" \
  | jq -r '.value[] | "\(.name) state=\(.properties.provisioningState)"'

# A cluster's OIDC issuer (needed to validate workload-identity federated creds)
curl -s -H "$AUTH" ".../managedClusters/<cluster>?api-version=2024-02-01" | jq -r .properties.oidcIssuerProfile.issuerURL

# What's actually in a subnet (catch a VM NIC squatting the app-gw subnet)
curl -s -H "$AUTH" ".../virtualNetworks/<vnet>/subnets/<subnet>?api-version=2023-09-01" \
  | jq '{delegations:[.properties.delegations[]?.properties.serviceName], ipConfigs:[.properties.ipConfigurations[]?.id]}'

# A UAMI's federated credentials (compare .issuer to the cluster's issuerURL above)
curl -s -H "$AUTH" ".../userAssignedIdentities/<uami>/federatedIdentityCredentials?api-version=2023-01-31" \
  | jq -r '.value[]? | "subject=\(.properties.subject) issuer=\(.properties.issuer)"'

# Key Vault soft-delete / purge-protection (decides import vs delete+recreate)
curl -s -H "$AUTH" ".../vaults/<vault>?api-version=2023-07-01" \
  | jq '{enablePurgeProtection:.properties.enablePurgeProtection, enableRbacAuthorization:.properties.enableRbacAuthorization}'
```

A non-gateway `ipConfigs` entry in the app-gw subnet, or a federated-cred `issuer` that differs from
the cluster's `issuerURL`, is the smoking gun for the two classic AKS deploy failures (see
`known-gotchas.md` and `recovery-and-imports.md`).

## GCP — ADC/SA token → REST

```bash
TOKEN=$(gcloud auth print-access-token 2>/dev/null) \
  || TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
       "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | jq -r .access_token)
AUTH="Authorization: Bearer $TOKEN"
# GKE clusters in a region
curl -s -H "$AUTH" "https://container.googleapis.com/v1/projects/<PROJECT>/locations/<REGION>/clusters" \
  | jq -r '.clusters[]? | "\(.name) \(.status)"'
```

GCP's workload-identity binding is the GSA↔KSA `iam.workloadIdentityUser` member, not a per-cluster
OIDC issuer, so a cluster recreate does **not** break it the way AKS federated creds break (see
`recovery-and-imports.md`).

## Kubeconfig without the cloud CLI

If `make k8s -- kubeconfig` can't run (no `az`/`gcloud`), pull the admin kubeconfig from the cluster's
Terraform output instead:

```bash
set -a; source iac/values/secrets.env; set +a
export CLOUD_PROVIDER=azure ENV=<env> VALUES_FILE=values/<file>.hcl
( cd iac/1-platform/1-k8s/azure && terragrunt output -raw aks_kube_config_raw ) > ~/.kube/config
chmod 600 ~/.kube/config && kubectl get ns
```

(GCP output name differs — check `terragrunt output` in `iac/1-platform/1-k8s/gcp`.) Prefer the
real `kubeconfig` command when the CLI is present; this is the no-CLI fallback.
