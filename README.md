# Divyam Deployment

Provision cloud infrastructure and deploy the Divyam platform stack on Kubernetes.

> [!NOTE]
> This repository gives your team everything needed to set up a complete Divyam environment and maintain it through automation.

The setup has two phases:

1. **Infrastructure** ([`iac/`](iac/README.md)) — Terragrunt/OpenTofu modules that create cloud resources (VPC, K8s cluster, secrets, storage, etc.)
2. **Application** ([`k8s/`](k8s/README.md)) — A Helmfile that deploys the full Divyam service mesh onto the provisioned cluster

> [!TIP]
> Client SRE fork + PR-gated `helmfile diff` and post-merge `helmfile apply` are described in **[k8s/docs/cicd-overview.md](k8s/docs/cicd-overview.md)**.

## Supported Clouds

- **Azure** — AKS, Blob Storage, Key Vault, App Gateway, NAT Gateway
- **GCP** — GKE, GCS, Secret Manager, Cloud NAT, Cloud Armor

## Repository Layout

```
├── iac/                            # Infrastructure as Code
│   ├── root.hcl                    #   Shared Terragrunt configuration
│   ├── values/defaults.hcl         #   Configuration (resource names, toggles, CIDRs)
│   ├── 0-foundation/               #   VPC/VNet, NAT, bastion, state backend
│   ├── 1-platform/                 #   K8s cluster, load balancer, storage, alerts
│   ├── 2-app/                      #   Secrets, IAM, Cloud SQL, provider.yaml export
│   ├── sample_deploy.sh            #   Wrapper for plan/apply/destroy/import
│   └── terragrunt.hcl              #   Root Terragrunt entry point
├── k8s/                            # Kubernetes Deployment
│   ├── helmfile.yaml.gotmpl        #   Helmfile — deploys entire Divyam stack
│   ├── helm-values/                #   provider.yaml, resources.yaml
│   ├── docs/                       #   CI/CD and SRE-facing guides
│   ├── pipeline/                   #   Dockerfile + CI/CD script scaffolds
│   └── releases/                   #   Versioned artifact files
├── scripts/
│   ├── write-outputs-yaml.sh       #   OpenTofu outputs → YAML/JSON for Helm
└── └── check_cloud_credentials.sh  #   Cloud login validator
```

## Getting Started

### Prerequisite
Get the deployment key and access to Divyam Docker images that are hosted in a private registry, Contact **hello@divyam.ai**

### Phase 1 — Provision Infrastructure

Follow **[iac/README.md](iac/README.md)** to configure your cloud credentials, customize the values file, and provision resources across the three layers (foundation, platform, application).

After provisioning, the `export_details` module generates `provider.yaml` which is consumed by Helmfile in the next phase.

### Phase 2 — Deploy on Kubernetes

Follow **[k8s/README.md](k8s/README.md)** to configure Helm values, deploy the full Divyam stack with Helmfile, and set up a CD pipeline for ongoing updates.

## Image Access

> [!WARNING]
> Divyam Docker images and related OCI artifacts are hosted in an **auth-restricted registry**. Contact **support@divyam.io** to obtain access credentials before deploying the Kubernetes stack. CI/CD runners and cluster nodes must be able to reach this registry per your network design.

## Contact

For registry access, onboarding, or questions: **support@divyam.ai**
