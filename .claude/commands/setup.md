---
description: End-to-end Divyam setup — drive the whole deploy (prereqs → Phase 1 infra → Phase 2 stack) with checkpoints. The overarching workflow; the per-step commands are the pieces.
argument-hint: "[gcp|azure] [env]   e.g. gcp dev"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl config:*), Bash(helm ls:*), Read, Skill
---
You are the conductor for a **full Divyam deployment**, end to end. Adopt `divyam-platform-engineer`
and follow the `divyam-deploy` workflow; everything runs through the Makefile entrypoint
(`make iac -- <args>` / `make k8s -- <args>`). Optional args (cloud, env): **$ARGUMENTS**.

This is a guarded, multi-phase runbook — **stop at every checkpoint** and get the user's go-ahead
before any mutation. Never pass `-y`. If a step fails, stop and consult `divyam-deploy` → troubleshooting.

Drive these phases in order, reporting status after each:

**A. Preflight**
1. `make prereqs-check` — report toolchain gaps (offer `make prereqs` only if the user agrees).
2. Resolve cloud+env: if given in args, `make iac -- config -c <cloud> -e <env>`; else read `.iac.conf`. If unset, ask.
3. **Cloud login is the user's job** — if `make iac -- creds` fails, ask them to run `! az login` /
   `! gcloud auth login` (+ `gcloud auth application-default login`) and pause until done.
4. Secrets: ensure `iac/values/secrets.env` exists (`make iac -- secrets` if not) and the `FILL` values
   (cloud creds, registry auth, webhooks) are filled. Ask the user to confirm they're set; never print them.

**B. Phase 1 — infrastructure (one layer at a time)**
For each layer in order `0-foundation → 1-platform → 2-app`:
5. `make iac -- plan -l <layer>`, summarize the diff (creates/updates/destroys, blast radius).
6. **Checkpoint:** ask the user to confirm, then `make iac -- apply -l <layer>`.
7. Warn that `0-foundation` is LOCAL state. Stop and report between layers.

**C. Handoff**
8. Confirm `k8s/helm-values/provider.yaml` now exists; report its `environment` + `platform.provider`.

**D. Phase 2 — stack**
9. `make k8s -- kubeconfig` then `kubectl get ns` to confirm reachability.
10. Ensure `k8s/helm-values/resources.yaml` and an artifacts source are set; ask if unsure. The artifacts
    source is a channel/version (`-C stable|nightly` + `-a <id|latest>`), a local `artifacts.yaml`, or a
    `releases/<channel>/` entry — see `k8s/releases/VERSIONING.md`.
11. `make k8s -- diff`, summarize. **Checkpoint:** confirm, then `make k8s -- install -C stable` (first
    install; or `-a <version>`). If releases already exist (`helm ls -A`), use `make k8s -- upgrade` instead — never re-`install`.

**E. Verify**
12. `make k8s -- status` and `kubectl get pods -A`; flag anything not Running/Completed and summarize the result.

End with a short report of what was applied and any follow-ups. Prefer `-n` dry-runs when the user wants
a preview-only walkthrough. For a single phase, point them at `/provision`, `/deploy-stack`, etc.
