---
description: Deploy/upgrade the Helmfile stack (Phase 2) — diff, review, confirm, then install (first) or upgrade.
argument-hint: "[chart]  e.g. router  (omit for the whole stack)"
allowed-tools: Bash(make:*), Bash(helm ls:*), Bash(kubectl get:*), Read, Skill
---
Use the `divyam-deploy` workflow and `divyam-platform-engineer` safety rules; run everything via the
Makefile entrypoint. Target release (from args, empty = whole stack): **$ARGUMENTS**

1. Confirm the cluster is reachable: `kubectl get ns`. If it fails, tell the user to run `/kubeconfig` first and stop.
2. Decide first-install vs upgrade: run `helm ls -A`. If no Divyam releases exist → this is a **first
   install** (`make k8s -- install` = `helmfile sync`). Otherwise it's an **upgrade** (`make k8s -- upgrade` = `apply`).
3. Preview: run `make k8s -- diff`. If a chart was given in $ARGUMENTS, add `-l <chart>`. **Summarize** the diff.
4. **STOP and ask the user to confirm.** Never `install`/`sync` on an already-deployed stack — use `upgrade`.
5. On confirmation, run `make k8s -- install` (first time) or `make k8s -- upgrade` (routine), adding
   `-l <chart>` if a chart was given and `-a <version>` if the user specified one (else the resolved
   ARTIFACTS_VERSION applies).
6. Verify with `make k8s -- status` and flag any unhealthy releases/pods.

For the full provision-then-deploy flow from scratch, use `/setup`.
