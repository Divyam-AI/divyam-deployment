---
description: Show deployment status — Helm releases and pod health across the cluster. Read-only.
argument-hint: "[tui|dashboard]"
allowed-tools: Bash(make:*), Bash(helm ls:*), Bash(kubectl get:*), Skill
---
Use `divyam-tooling` (kubectl.md). Read-only status overview via the Makefile entrypoint. Optional view
(from args): **$ARGUMENTS**

1. Run `make k8s -- status` (`helm ls -A`). If $ARGUMENTS contains `tui`, add `--tui`; if it contains
   `dashboard`, add `--dashboard` (these launch `helm tui` / `helm dashboard`).
2. Run `kubectl get pods -A` and flag any pod not `Running`/`Completed` (e.g. `ImagePullBackOff`,
   `Pending`, `CrashLoopBackOff`), grouped by namespace.
3. Summarize: releases deployed (+ chart versions if visible), unhealthy pods, and the suggested next
   diagnostic (`kubectl describe pod …` / `kubectl logs …`). Don't mutate anything.
