# Phase 2 — application stack (k8s/)

Run from the bastion. Deploy the whole Divyam stack with Helmfile via `k8s.sh` (or `make k8s -- …`).
Prereq: Phase 1 wrote `k8s/helm-values/provider.yaml`.

## 1. kubeconfig + auth
```
make k8s -- kubeconfig     # resolves cluster identifiers (terragrunt output → provider.yaml → convention)
kubectl get ns             # verify reachable
```
GCP runs `gcloud … get-credentials`; Azure does `az login --service-principal` (from `ARM_*`, secret
masked) when needed, then `az aks get-credentials … --overwrite-existing`. Override resolution with
`--cluster/--project/--region/--zone/--resource-group`; `--no-tf` skips the terragrunt lookup. Details:
`divyam-tooling/references/clouds.md`.

## 2. values files (in `k8s/helm-values/`, or `-d <dir>`)
- `provider.yaml` — from Phase 1 (required).
- `resources.yaml` — per-chart sizing/persistence/replicas/nodeSelector; `enabled: false` skips a chart.
  Start from `k8s/sample_values/{gcp,azure}/` and edit. (required)
- `config.yaml` — optional local overrides (highest priority); start from `sample-config.yaml`.
- Artifacts: set `ARTIFACTS_VERSION` (`make k8s -- config -a <v>` or `-a` per command) → uses
  `k8s/releases/<v>-artifacts.yaml`; else a local `artifacts.yaml`; else latest `releases/*`.
Merge priority: `config.yaml` > `resources.yaml` > `artifacts.yaml`.

## 3. deploy
```
make k8s -- config -d k8s/helm-values -e <env>   # remember once (env also auto-read from provider.yaml)
make k8s -- diff                                  # ALWAYS preview first
make k8s -- install -a <version>                  # FIRST install only (helmfile sync — all releases, may restart)
# routine thereafter:
make k8s -- diff && make k8s -- upgrade -l <chart>   # helmfile apply — only changed; -l for a single release
```
- Single chart: `make k8s -- upgrade -l router` → `helmfile -l name=router-<env> apply`. Raw selector via `-f`.
- Render locally without applying: `make k8s -- template -- --debug`.

## 4. verify
```
make k8s -- status                            # helm ls -A; add --tui or --dashboard for detail
kubectl get pods -A | grep -vE 'Running|Completed'   # anything left is unhealthy
```

## Teardown
`make k8s -- delete -l <chart>` (type-to-confirm) removes one release; omit `-l` for the whole stack
(`helmfile destroy`). Prefer disabling a chart (`enabled: false` in `resources.yaml`) + `upgrade` over
ad-hoc `kubectl delete`.
