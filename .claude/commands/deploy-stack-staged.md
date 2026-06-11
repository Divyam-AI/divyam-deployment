---
description: First-time stack install in safe stages — external-secrets-operator first, verify the Key Vault chain, then the full stack — so a workload-identity break surfaces early, not after 20-min atomic timeouts.
argument-hint: "[-C stable|nightly]"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(helm ls:*), Bash(helm version:*), Read, Skill
---
You drive a **first-time** full-stack install in stages, so the highest-risk link
(workload-identity → Key Vault → ExternalSecret → image-pull) is proven on one cheap release before
committing the whole stack to long `--wait --atomic` timeouts. Adopt `divyam-platform-engineer` and
`divyam-deploy`. Optional channel arg: **$ARGUMENTS** (default `-C stable`). For routine changes use
`/deploy-stack` (upgrade) instead — this is for the initial sync.

1. **Pre-checks.** `helm version` = Helm 3 (else fix — known-gotchas). `kubectl get ns` reachable.
   Confirm this really is a first install (`helm ls -A` shows the stack absent) — otherwise stop and
   use `/deploy-stack`. Ensure NAP NodePools exist or pods will hang (`/apply-nap-configs`).
2. **Stage 1 — ESO.** `make k8s -- install -l external-secrets-operator -C <channel> -y`. Verify its
   pods are Running and the `external-secrets.io` CRDs exist.
3. **Stage 2 — prove the secret chain.** Wait for the first ExternalSecrets to appear and reach
   `SecretSynced=True` (`/verify-workload-identity`). If they error, STOP and fix workload identity
   (issuer drift / access policy) before going further — do **not** launch the full sync onto a broken
   chain.
4. **Checkpoint → Stage 3 — full sync.** On go-ahead, `make k8s -- install -C <channel> -y`
   (helmfile sync, `needs`-ordered). Run it in the background and **monitor**: ExternalSecrets
   `SecretSynced`, no `ImagePullBackOff`, NAP nodes scaling. Catch the known traps as they appear —
   Kafka `NotReady` (RF vs broker count → set `nodepool.replicaCount: 3` in config.yaml, upgrade
   kafka-cluster), pods Pending (NAP), a dependency-waiting CrashLoop (recovers once the dep is Ready;
   `kubectl delete pod` to skip the backoff).
5. **Verify.** `make k8s -- status` + `kubectl get pods -A` — all releases deployed, pods
   Running/Completed. Report the final state and anything deferred (e.g. App-GW/AGIC if the subnet is
   occupied).
