---
description: Adopt pre-existing cloud resources into Terraform state (recover from "already exists" / a prior lost-state deployment) — read ground truth, import, then converge. Don't recreate.
argument-hint: "[layer.unit]   e.g. 1-platform.0-app_gw"
allowed-tools: Bash(make:*), Bash(terragrunt import:*), Bash(terragrunt state:*), Bash(curl:*), Bash(jq:*), Read, Skill
---
You recover when `apply` hits **`A resource with the ID … already exists`** — the resources exist but
the current state doesn't track them (a prior deployment, a swapped `VALUES_FILE` that forked the
state key, or cleared 0-foundation LOCAL state). Adopt `divyam-platform-engineer`; follow
`divyam-tooling/references/recovery-and-imports.md`. **Adopt, never blindly recreate.** Optional
target: **$ARGUMENTS**.

1. **Establish ground truth first.** Before importing or deleting anything, read what actually exists
   (`/ground-truth` or `references/ground-truth-rest.md`): list the resources, and — critically — check
   for **duplicates** (e.g. two AKS clusters) and **staleness** (a cluster recreated → federated-cred
   issuer drift). Report findings.
2. **Decide adopt vs delete-recreate (get a go-ahead for anything destructive):**
   - Stateful / purge-protected (Key Vault with `enablePurgeProtection`, storage) → **import**.
   - Stateless and broken (e.g. `*-sa-uai` UAMIs with stale federated creds after a cluster recreate)
     → delete + let `apply` recreate cleanly — **only with explicit confirmation**.
3. **Import** each existing resource into the unit's state. The cloud ID is in the `already exists`
   error; use the exact address (incl. `[idx]`/`["key"]`). For Key Vault secrets use the versioned URL.
   If `terragrunt import` fails with `does not have an attribute "outputs"` / `Invalid count`, the
   unit's `mock_outputs_allowed_terraform_commands` lacks `import` — hand the one-line HCL edit
   (add `"import"`, then revert) to the human as an action item.
4. **Converge + verify.** `make iac -- plan -l <layer>` → expect **0 to add / only intended changes**.
   Apply, then verify the downstream effect (e.g. `kubectl get externalsecrets -A` → `SecretSynced`,
   or `/verify-workload-identity`).
5. If the cluster was recreated, rebind workload identity: `make iac -- apply -l 2-app.1-iam_bindings`
   reads the OIDC issuer live and fixes the federated creds. Report what was adopted vs recreated.

Note: most `already exists` here traces to the **state key embedding the values-file filename** — fix
the root cause too (config out of secrets.env; `VALUES_FILE` must exist) — see known-gotchas §3.
