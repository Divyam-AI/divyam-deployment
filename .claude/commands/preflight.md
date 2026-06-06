---
description: Verify the machine is ready to deploy Divyam — toolchain, cloud creds, and Phase-1→2 handoff. Read-only.
argument-hint: "[gcp|azure] [env]"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl config:*), Read, Skill
---
Adopt the `divyam-platform-engineer` mindset and run a **read-only** readiness check via the Makefile
entrypoint. Optional args (cloud, env): $ARGUMENTS — if given, you may `make iac -- config -c <cloud>
-e <env>` first; else use the remembered `.iac.conf`.

Do, then report as a ✓/✗ checklist:
1. **Toolchain** — `make prereqs-check`. List any missing/unpinned tools (do NOT install unless asked).
2. **Cloud creds** — `make iac -- creds`. Report pass/fail and which auth path (GCP ADC/SA-key, Azure SP/az-login).
3. **Phase-1 handoff** — does `k8s/helm-values/provider.yaml` exist? If yes, read and report `environment` + `platform.provider`.
4. **Cluster reach** (only if provider.yaml exists) — `kubectl config current-context` then `kubectl get ns`; note if unreachable (likely need `/kubeconfig`).

End with the single recommended next step (e.g. "run `/provision 0-foundation`", "`/setup` for the full
flow", or "`/kubeconfig` then `/deploy-stack`"). Change nothing.
