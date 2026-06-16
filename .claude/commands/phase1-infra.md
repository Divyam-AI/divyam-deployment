---
description: Provision Phase 1 infrastructure end to end (0-foundation → 1-platform → 2-app) with per-layer checkpoints and handoff/verify. Stops at provider.yaml.
argument-hint: "[gcp|azure] [env]   e.g. azure prod"
allowed-tools: Bash(make:*), Bash(kubectl get:*), Read, Skill
---
You own **Phase 1 (infrastructure)** standalone — the Terragrunt layers up to `provider.yaml`. Adopt
`divyam-platform-engineer` (esp. the action-item handoff loop) and follow `divyam-deploy`. Optional
args (cloud, env): **$ARGUMENTS**. Everything runs through `make iac -- …`. Never pass `-y` on a
shared/prod env; stop at every checkpoint.

1. **Resolve cloud+env.** From args → `make iac -- config -c <cloud> -e <env>`; else read `.iac.conf`.
   If unset, ask. `iac.sh` now validates naming (so a bad value fails fast, even at `config` time):
   `ENV` must be one of `dev|prod|preprod|stage|sandbox`, and on Azure `len(org)+len(env) ≤ 10` (the
   Key Vault / storage 24-char cap). If a client needs a different env, widen `ALLOWED_ENVS` in
   `scripts/iac.sh` — see known-gotchas §2.
2. **Creds (handoff).** Run `make iac -- creds`. If it fails, hand the user the action item to run
   `! az login` / `! gcloud auth login` (+ `gcloud auth application-default login`) and **pause**.
   On resume, re-run `make iac -- creds` to verify before continuing.
3. **Secrets (handoff).** Ensure `iac/values/secrets.env` exists and real `FILL` values are set —
   route to `/secrets-setup` if not. Verify presence (never print values), then continue.
4. **Apply layers in order** `0-foundation → 1-platform → 2-app`. For each:
   a. `make iac -- plan -l <layer>`; summarize creates/updates/**destroys** and blast radius.
   b. If the plan errors `already exists` (a prior/lost-state deployment), STOP and route to
      `/import-existing` — adopt, don't recreate.
   c. **Checkpoint:** get explicit go-ahead, then `make iac -- apply -l <layer>`. Report, then stop
      between layers. `0-foundation` is **LOCAL state** — never blindly re-apply.
   - On AKS, `2-app` includes **`0-nap_configs`** (NAP NodePools) — required later or pods stay
     Pending. A whole-layer `apply -l 2-app` covers it; confirm it ran.
5. **Handoff check.** Confirm `k8s/helm-values/provider.yaml` exists; report its `environment`,
   `platform.provider`, Key Vault URI / storage, and WIF client-ids. Hand off to `/phase2-stack`.

Read-only preview anytime with `-n`. For one layer use `/provision <layer>`; to recover a prior
deployment use `/import-existing`; to inspect real cloud state use `/ground-truth`.
