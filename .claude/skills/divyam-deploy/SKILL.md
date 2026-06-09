---
name: divyam-deploy
description: >
  The end-to-end deployment workflow for the Divyam platform in THIS repo — what to run, in what
  order, with which checks — from a clean machine to a running stack, across GCP or Azure. Use to
  drive or explain a full or partial deploy, decide the next step, or recover when a step fails.
  TRIGGER on: "deploy Divyam end to end", "provision then deploy", "what's the next step", "set up a
  new environment", layer ordering questions, Phase 1 → Phase 2 handoff, kubeconfig→helmfile sequence,
  CI/CD for the fork. Pairs with divyam-tooling (command/flag details) and divyam-platform-engineer (safety mindset).
---

# Divyam deployment workflow

Two phases: **Phase 1** provisions cloud infra incl. the GKE/AKS cluster (`iac/`, via `make iac`);
**Phase 2** deploys the whole app stack onto it (`k8s/`, via `make k8s`). Phase 1 ends by writing
`k8s/helm-values/provider.yaml`, which Phase 2 consumes. Run Phase 2 from the bastion created in
Phase 1. Always preview (`plan`/`diff`) before mutating; see `divyam-platform-engineer` for the safety
rules and `divyam-tooling` for exact flags.

## The path (happy path, condensed)

Run everything through the Makefile entrypoint — `make iac -- <args>` / `make k8s -- <args>` (the `--`
passes flags through). Add `-n` to any step to preview the command without running it.

```
make prereqs                                          # 0. toolchain (once)
# user runs:  ! az login   /   ! gcloud auth login + gcloud auth application-default login
make iac -- config -c <gcp|azure> -e <env>            # 1. remember cloud+env
make iac -- secrets       # 2. generate iac/values/secrets.env, then FILL real values (creds, registry, webhooks)
make iac -- creds         # 3. validate cloud auth
make iac -- plan -l 0-foundation && make iac -- apply -l 0-foundation   # 4. foundation (LOCAL state — careful)
make iac -- plan -l 1-platform   && make iac -- apply -l 1-platform     # 5. platform (k8s before monitoring = automatic)
make iac -- plan -l 2-app        && make iac -- apply -l 2-app          # 6. app (writes provider.yaml)
# review k8s/helm-values/provider.yaml                                   # 7. Phase-1 handoff check
make k8s -- kubeconfig && kubectl get ns                                 # 8. auth + kubeconfig
# ensure k8s/helm-values/resources.yaml + artifacts (ARTIFACTS_VERSION) are set                        # 9.
make k8s -- diff                                                         # 10. preview
make k8s -- install -a <version>                                         # 11. FIRST install (helmfile sync)
make k8s -- status                                                       # 12. verify (helm ls -A / pods)
# later, routine changes:
make k8s -- diff && make k8s -- upgrade -l <chart>                       # helmfile apply, only changed
```

> The `make iac/k8s --` commands forward verbatim to `./scripts/iac.sh` / `./scripts/k8s.sh`, which are
> identical and run directly **without** `--` (used by the slash commands and CI). See `divyam-tooling`
> for the full flag reference and `divyam-platform-engineer` for the safety rules.

## Decision points
- **Cloud:** `-c gcp` vs `-c azure` (set once via `config`). Differences (project vs RG, auth,
  get-credentials) → `divyam-tooling/references/clouds.md`.
- **Whole layer vs sub-unit:** `apply -l 1-platform` is correct (DAG orders sub-units). Use
  `-l 1-platform.1-k8s` when iterating on just the cluster.
- **Observability backend:** cloud-native (default) vs Datadog (`datadog.enabled=true` + `TF_VAR_datadog_*`).
- **First install vs upgrade:** `install` (=`sync`, all releases) only the first time; then `upgrade` (=`apply`).
- **Single chart:** `make k8s -- upgrade -l router` → `helmfile -l name=router-<env> apply`.

## Reference guide — load for detail

| Need | Reference |
|------|-----------|
| Phase 1 detail: layer/sub-layer contents, ordering, LOCAL-state caveat, secrets, observability deploy | `references/phase1-infra.md` |
| Phase 2 detail: kubeconfig, values files, artifacts resolution, helmfile ops, single-chart, destroy | `references/phase2-stack.md` |
| Forked-repo CI/CD: PR-gated `diff`, post-merge `apply` | `references/cicd.md` |
| When a step fails: already-exists, state, missing layer, filter misses, kubeconfig/auth, image pull | `references/troubleshooting.md` |
| Adopting a prior/lost-state deployment, imports, cluster-recreate workload-identity rebind | `divyam-tooling/references/recovery-and-imports.md` |
| Known blockers + fixes (Helm 4, env-name length, NAP NodePools, Kafka RF, App-GW subnet, state-key fork) | `divyam-tooling/references/known-gotchas.md` |
| Read cloud ground truth without az/gcloud (verify a handoff, count resources, inspect a subnet) | `divyam-tooling/references/ground-truth-rest.md` |

## Human handoffs in this flow (delegate → pause → verify)
This flow is run *with* a DevOps/SRE/dev team (see `divyam-platform-engineer`). Treat these as
action items you hand off and then **verify before resuming**, not steps you silently do or assume:
cloud login (step 0/1 → verify `make iac -- creds`); filling real secrets incl. the Azure GAR
docker-auth file (step 2 → verify file exists + `jq empty`); approving each layer/stack apply (steps
4-6, 11); reviewing `provider.yaml` (step 7); kubeconfig if `az`/`gcloud` is interactive (step 8 →
verify `kubectl get ns`). On AKS, `apply -l 2-app` must include **`0-nap_configs`** (NAP NodePools) or
all pods stay `Pending` — see known-gotchas. For a large first install, prefer staged: ESO →
verify ExternalSecrets `SecretSynced` → rest (`/deploy-stack-staged`).

## Guardrails
- Never skip the `plan`/`diff` before `apply`/`install`/`upgrade`; never `sync` after first install.
- `0-foundation` is LOCAL state — never blindly re-apply/destroy; coordinate.
- Don't proceed to Phase 2 until `provider.yaml` exists and looks right (env, cloud, storage).
- Cloud login is the user's step — pause, ask them to run it, then verify; don't attempt interactive login yourself.
- Phase 2 needs **Helm 3** (Helm 4 breaks helmfile/diff) — see known-gotchas / prerequisites.
