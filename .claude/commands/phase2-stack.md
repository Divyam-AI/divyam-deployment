---
description: Deploy Phase 2 (the Helmfile stack) end to end — kubeconfig → values → diff → first-install or upgrade, with Helm-3 and workload-identity checks.
argument-hint: "[chart]   (omit for the whole stack)"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl config:*), Bash(helm ls:*), Bash(helm version:*), Bash(helm plugin list:*), Read, Skill
---
You own **Phase 2 (the application stack)** standalone, onto an already-provisioned cluster. Adopt
`divyam-platform-engineer` and follow `divyam-deploy`. Optional release arg: **$ARGUMENTS**.
Runs through `make k8s -- …`. Stop before any mutation; never `-y` on shared/prod.

1. **Toolchain check.** `helm version` must be **Helm 3** and `helm plugin list` must show `diff`
   (≥ v3.10). If it's Helm 4 / diff errors, STOP and route to fixing it (known-gotchas / prerequisites)
   — Helm 4 breaks helmfile/diff.
2. **Reachability.** `kubectl config current-context` + `kubectl get ns`. If it fails and `az`/`gcloud`
   is present, `make k8s -- kubeconfig`; if interactive login is needed, hand it off and **verify**
   `kubectl get ns` on resume. (No CLI? pull kubeconfig from TF state — see ground-truth-rest.)
3. **Values + artifacts.** Confirm `k8s/helm-values/{provider,resources}.yaml` exist and an artifacts
   source is set (`-C stable|nightly` + `-a <id|latest>`, a local `artifacts.yaml`, or a `releases/`
   entry — see `k8s/releases/VERSIONING.md`). Ask if unsure.
4. **Decide install vs upgrade.** `helm ls -A`: if the stack's releases are absent → first
   **install** (`helmfile sync`); if present → **upgrade** (`helmfile apply`). Never re-`install` a
   live stack.
5. **Preview.** `make k8s -- diff -C <channel>` and summarize. A diff that fails only at the end with
   `no matches for kind "ExternalSecret"/"SecretStore"` is a **preview-only** limitation (ESO CRDs
   not yet present) — `install` resolves it via `needs` ordering; proceed.
6. **Checkpoint → deploy.** On go-ahead: for a first install of the whole stack prefer **staged** via
   `/deploy-stack-staged` (ESO → verify ExternalSecrets → rest). Otherwise
   `make k8s -- install -C <channel> -y` (first) or `make k8s -- upgrade [-l <chart>]` (routine).
   While it runs, ask the user how to track it: terminal (`! make k8s -- status --tui`, user-run)
   or web dashboard (background `make k8s -- status --dashboard`, share the URL) — /bringup-status step 5.
7. **Verify.** `make k8s -- status` + `kubectl get pods -A` (flag non-Running/Completed). Then
   `/verify-workload-identity` to confirm ExternalSecrets are `SecretSynced` and image pulls work.
   Watch for the known traps: pods Pending → NAP NodePools missing (`/apply-nap-configs`); Kafka
   NotReady → RF vs broker count (known-gotchas).

For one chart pass it as the arg. For diagnosis use `/debug-stack`; for status `/cluster-status`.
