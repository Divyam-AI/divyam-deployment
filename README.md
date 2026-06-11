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
│   ├── values/secrets.env          #   Config + TF_VAR_* secrets (generated; gitignored)
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
│   ├── iac.sh                      #   Phase-1 infra CLI (config/plan/apply/destroy/...)
│   ├── k8s.sh                      #   Phase-2 stack CLI (install/upgrade/delete/status/...)
│   ├── set-prevent-destroy.sh      #   Flip lifecycle.prevent_destroy across a module (backups)
│   ├── install-prerequisites.sh    #   Install/verify the pinned toolchain
│   ├── gen-tf-env.sh               #   Generate iac/values/secrets.env
│   ├── write-outputs-yaml.sh       #   OpenTofu outputs → YAML/JSON for Helm
│   └── check_cloud_credentials.sh  #   Cloud login validator
└── Makefile                        # Setup shortcuts + orchestrates scripts/iac.sh & scripts/k8s.sh
```

## Getting Started

### Prerequisite
Get the deployment key and access to Divyam Docker images that are hosted in a private registry, Contact **hello@divyam.ai**

### Install tooling

Install (and pin) the toolchain both phases need — OpenTofu, Terragrunt, Helm, Helmfile, the
helm-diff plugin, K9s, `jq`, and `yq`:

```bash
make prereqs          # install anything missing, then verify
make prereqs-check    # verify only — no install; non-zero exit if gaps (CI-friendly)
```

Cloud CLIs (`gcloud` / `az`), `kubectl`, and `python3` are *checked* but not installed for you, and
cloud login stays interactive — run `az login` / `gcloud auth login` yourself. Versions are pinned in
[`scripts/install-prerequisites.sh`](scripts/install-prerequisites.sh) (kept in sync with the
**Tooling** table in `CLAUDE.md`).

> [!TIP]
> Run the workflows via `make iac -- <args>` / `make k8s -- <args>` — the **`--`** is required so make
> passes `-l/-c/-e` flags through (e.g. `make iac -- plan -l 1-platform.1-k8s`,
> `make k8s -- upgrade -l router`). Running `./scripts/iac.sh …` / `./scripts/k8s.sh …` directly is
> identical and needs no `--`.

### Phase 1 — provision (`make iac`)

The whole Terragrunt workflow runs through `make iac -- <cmd>` with standard args (`-x` / `--xxx`),
dotted layer addressing (`layer1.layer2`), and a **remembered cloud/env** so you set them once. Every
command prints the exact `terragrunt` invocation it runs; add `-n`/`--dry-run` to preview.

```bash
make iac -- config -c gcp -e dev          # remember cloud + env (set once)
make iac -- secrets                        # generate iac/values/secrets.env (fill the FILL values)
make iac -- creds                          # validate cloud credentials
make iac -- plan    -l 1-platform.1-k8s    # plan one sub-unit
make iac -- apply   -l 1-platform          # apply a whole layer (correct order is automatic)
make iac -- destroy -l 0-foundation        # plan preview + type-to-confirm
```

| Command | Does |
|---------|------|
| `config` | show / set the remembered `cloud` + `env` |
| `secrets` · `creds` | generate `iac/values/secrets.env` / validate cloud credentials |
| `init` · `plan` · `apply` · `show` | run terragrunt for a layer |
| `destroy` | tear a layer down (plan preview + type-to-confirm) |
| `protect` | re-harden a layer's `prevent_destroy` guards, then apply |

Target a `layer1[.layer2]` (e.g. `1-platform` or `1-platform.1-k8s`); omit `.layer2` for the whole layer.
Add `-n/--dry-run` to preview the exact command. Run `make iac -- help` for all options.

> [!NOTE]
> `secrets` writes `iac/values/secrets.env` (gitignored) and the Phase-1 flow auto-loads it — no manual
> `source` needed. `destroy`/`protect` edit `prevent_destroy` in tracked `.tf` files (backed up as
> `*.pdbak`); restore with `make iac -- protect -l <layer>` or `scripts/set-prevent-destroy.sh … --restore`.

After Phase 1, the `export_details` module writes `k8s/helm-values/provider.yaml`, consumed by Phase 2.
See **[iac/README.md](iac/README.md)** for cloud-auth setup and the full provisioning walkthrough.

### Phase 2 — deploy (`make k8s`)

Deploy the stack with Helmfile through `make k8s -- <cmd>`. It remembers the values-dir/env and
prints every command (`-n` to preview).

```bash
make k8s -- config -d k8s/helm-values -e prod   # remember once
make k8s -- diff                                 # preview changes
make k8s -- install -a 26.04.01-rc1              # first install (all releases)
make k8s -- upgrade -l router                    # upgrade one release
make k8s -- status                               # helm ls -A, then optional TUI / dashboard
make k8s -- delete  -l clickhouse                # uninstall one release (type-to-confirm)
```

| Command | Does |
|---------|------|
| `config` | show / set the remembered values-dir, env, artifacts-version |
| `kubeconfig` | authenticate to the cloud and (re)fetch the cluster kubeconfig |
| `diff` | `helmfile diff` (preview) |
| `install` · `upgrade` | first install (`sync`) / routine upgrade (`apply`); auto-diff first |
| `delete` | uninstall (`destroy`) with type-to-confirm |
| `template` | render manifests locally |
| `status` | `helm ls -A`, then optionally the **`helm tui`** terminal UI or **`helm dashboard`** web UI |

`-l <release>` targets one chart (→ `name=<release>-<env>`); omit it for the whole stack. Run
`make k8s -- help` for all options. See **[k8s/README.md](k8s/README.md)** for values layering,
`ARTIFACTS_VERSION`, and the CD pipeline.

## Image Access

> [!WARNING]
> Divyam Docker images and related OCI artifacts are hosted in an **auth-restricted registry**. Contact **support@divyam.io** to obtain access credentials before deploying the Kubernetes stack. CI/CD runners and cluster nodes must be able to reach this registry per your network design.

## Contact

For registry access, onboarding, or questions: **support@divyam.ai**
