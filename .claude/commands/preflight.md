---
description: Verify the machine is ready to deploy Divyam — toolchain, cloud creds, and Phase-1→2 handoff. Read-only.
argument-hint: "[gcp|azure] [env]"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Bash(kubectl config:*), Bash(helm version:*), Bash(curl:*), Bash(jq:*), Read, Skill
---
Adopt the `divyam-platform-engineer` mindset and run a **read-only** readiness check via the Makefile
entrypoint. Optional args (cloud, env): $ARGUMENTS — if given, you may `make iac -- config -c <cloud>
-e <env>` first; else use the remembered `.iac.conf`.

Do, then report as a ✓/✗ checklist:
1. **Toolchain** — `make prereqs-check`. List any missing/unpinned tools (do NOT install unless asked).
   For Phase 2, also check `helm version` is **Helm 3** (Helm 4 breaks helmfile/diff — known-gotchas)
   and `kubectl`/`az`|`gcloud` are present (not installed by prereqs).
2. **Cloud creds** — `make iac -- creds`. Report pass/fail and which auth path (GCP ADC/SA-key, Azure SP/az-login).
3. **App-Gateway subnet (Azure, pre-`0-app_gw`)** — read the app-gw subnet and flag any **non-gateway
   NIC** in it: a VM NIC there makes `1-platform.0-app_gw` fail with
   `ApplicationGatewaySubnetCannotHaveOtherResources`. Use the REST recipe in
   `divyam-tooling/references/ground-truth-rest.md` (`subnet <app-gw-subnet>` → inspect
   `ipConfigurations`), the subnet name from the values file's `vnet.app_gw_subnet.name`. If occupied,
   report it as a **human action item** (move the VM to the main subnet / free the subnet, or defer
   App-GW) — don't silently proceed.
4. **Phase-1 handoff** — does `k8s/helm-values/provider.yaml` exist? If yes, read and report `environment` + `platform.provider`.
5. **Cluster reach** (only if provider.yaml exists) — `kubectl config current-context` then `kubectl get ns`; note if unreachable (likely need `/kubeconfig`). Then `kubectl get nodepool -A` — if empty, NAP NodePools are missing (`/apply-nap-configs`).

End with the single recommended next step (e.g. "run `/provision 0-foundation`", "`/setup` for the full
flow", or "`/kubeconfig` then `/deploy-stack`"). Change nothing.
