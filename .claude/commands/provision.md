---
description: Provision a Phase-1 infra layer safely — plan, review the diff, confirm, then apply.
argument-hint: "<layer>  e.g. 1-platform  or  1-platform.1-k8s"
allowed-tools: Bash(make:*), Read, Skill
---
Use the `divyam-deploy` workflow and `divyam-platform-engineer` safety rules; run everything via the
Makefile entrypoint. Target layer (from args): **$ARGUMENTS**

1. If no layer was given, ask which one (`0-foundation` | `1-platform[.<sub>]` | `2-app[.<sub>]`) and stop.
2. Confirm cloud/env are set: `make iac -- config` (if unset, ask the user for `-c`/`-e`). Respect
   layer order `0-foundation → 1-platform → 2-app`.
3. Run `make iac -- plan -l $ARGUMENTS` and **summarize** the plan: resources to create/update/destroy,
   and blast radius. Surface anything surprising (destroys, replacements, empty plan).
4. **STOP and ask the user to confirm** before applying. Do not auto-apply and never pass `-y` on a
   shared/prod environment.
5. On confirmation, run `make iac -- apply -l $ARGUMENTS`. Report the outcome and the recommended next
   layer/step. If this was `2-app`, note that `provider.yaml` should now exist for Phase 2.

If the layer is `0-foundation`, warn first that it uses **LOCAL state** — don't re-apply blindly; coordinate.
For the full end-to-end flow across all layers, use `/setup`.
