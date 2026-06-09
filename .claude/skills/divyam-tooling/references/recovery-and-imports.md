# Adopting pre-existing resources & recovering state

Use this when a layer's `apply` fails with **`A resource with the ID … already exists`**, or when a
prior/lost-state deployment left real resources that the current state doesn't track. The rule:
**adopt (import) or delete-and-recreate deliberately — never blindly re-create.** Always read ground
truth first (`ground-truth-rest.md`) so you know what actually exists.

## Why this happens here

The remote-state key embeds the **values-file basename** (`cloud/deployment_prefix/<basename>/region/<unit>`,
see `known-gotchas.md`). Swapping `VALUES_FILE` (e.g. `defaults-dev.hcl` → `sandbox-defaults.hcl`) or
losing a prior state silently points Terragrunt at an **empty** state while the resources already
exist in the cloud → cascading `already exists`. 0-foundation also keeps **LOCAL** state inside
`.terragrunt-cache`, so clearing caches drops it.

## Import an existing resource into state

```bash
set -a; source iac/values/secrets.env; set +a
export CLOUD_PROVIDER=azure ENV=<env> VALUES_FILE=values/<file>.hcl
( cd iac/<layer>/<unit>/azure && terragrunt import '<address>' '<cloud-resource-id>' )
# then converge:
make iac -- apply -l <layer>.<unit>
```

- The cloud resource ID is printed verbatim in the `already exists` error — copy it.
- Indexed/`for_each` addresses need the key: `azurerm_storage_account.this["divyamprodstorage"]`,
  `azurerm_private_dns_zone.app[0]`, `azurerm_key_vault_secret.secrets["divyam-db-password"]`.
- Key Vault **secret** IDs are versioned URLs (`https://<vault>.vault.azure.net/secrets/<name>/<ver>`);
  the error gives the exact version. Import every pre-existing secret, then `apply` updates values to
  match `secrets.env`.

### The import dependency-mock gotcha
`terragrunt import` on a unit that has a `dependency` block can fail with
`This object does not have an attribute named "outputs"` (or `Invalid count argument`) because
`mock_outputs_allowed_terraform_commands` doesn't include `import`. Fix: temporarily add `"import"`
to that unit's `mock_outputs_allowed_terraform_commands`, run the import, then **revert the edit**.
(HCL edits go through the human / `terrashark` — surface it as an action item if you can't edit.)

## Purge-protected Key Vault → import, don't delete

If `enablePurgeProtection: true` (check via `ground-truth-rest.md`), you **cannot** delete+recreate
the vault by name within the retention window. Import the `azurerm_key_vault.this[0]` and its secrets.
Only delete+recreate a vault when purge protection is off.

## Cluster recreated → rebind workload identity (Azure)

If the AKS cluster was recreated, its **OIDC issuer URL changes**, so every pre-existing UAMI's
federated credential is now stale (points at the old issuer) → pods can't auth to Key Vault, and
ExternalSecrets fail. `iac/2-app/1-iam_bindings/azure` reads the issuer **live** (data source on the
cluster by name), so applying it rebinds the creds correctly. Two ways to reconcile the existing UAMIs:

- **Delete & recreate (clean, if they hold no data):** verify with REST that the federated-cred
  issuer ≠ the new cluster's issuer, then (with explicit go-ahead) delete the orphaned
  `*-sa-uai` UAMIs and `make iac -- apply -l 2-app.1-iam_bindings` — it creates fresh UAMIs +
  federated creds (new issuer) + role assignments. Their client-ids flow into `provider.yaml` via
  `3-export_details`, so the chart SA annotations stay consistent.
- **Import & repair (non-destructive):** import all UAMIs + their federated creds + role assignments,
  then `apply` updates the issuer in place. More steps; preserves principal-ids.

GCP doesn't have this problem (binding is the GSA↔KSA IAM member, not a per-cluster issuer).

## After adopting: prove it converged
Re-run `make iac -- plan -l <layer>` and confirm **0 to add / only expected changes**, then verify the
downstream effect (e.g. `kubectl get externalsecrets -A` shows `SecretSynced=True`). See
`verify-workload-identity` / the `/import-existing` command for the guided loop.
