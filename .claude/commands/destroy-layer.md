---
description: Safely tear down a Phase-1 infra layer — explain impact, plan-preview, type-to-confirm, then destroy.
argument-hint: "<layer>  e.g. 2-app.2-alerts"
allowed-tools: Bash(make:*), Read, Skill
---
Use `divyam-platform-engineer` — **destroy is dangerous and irreversible**. Run via the Makefile
entrypoint. Layer (from args): **$ARGUMENTS**

1. Require an explicit layer; if $ARGUMENTS is empty, ask and stop. If the layer is `0-foundation`,
   **refuse** unless the user explicitly insists — it uses LOCAL state and holds the network/state
   backend; warn loudly and require a clear go-ahead.
2. Explain exactly what `make iac -- destroy -l $ARGUMENTS` will do: flip `prevent_destroy → false`
   across the module (backups `*.pdbak`), plan-preview the destroy, and **type-to-confirm the layer name**.
3. Optionally show the impact first: `make iac -- plan -l $ARGUMENTS` (read-only).
4. Run `make iac -- destroy -l $ARGUMENTS`. **Do NOT pass `-y`** — let the type-to-confirm gate run.
5. Afterwards: remind the user to **restore the guards** (`make iac -- protect -l $ARGUMENTS`, or
   `scripts/set-prevent-destroy.sh -l $ARGUMENTS -c <cloud> --restore`, or `git checkout` modified `.tf`),
   and to verify removal in the cloud console.
