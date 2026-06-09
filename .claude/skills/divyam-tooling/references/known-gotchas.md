# Known blockers & traps (with fixes)

Real blockers hit bringing the full Divyam stack up on AKS. Each lists the symptom, root cause, and
fix. Several are cloud-agnostic-by-design but bite differently on Azure vs GCP.

## 1. Toolchain — Helm 4 breaks helmfile/diff
- **Symptom:** `make k8s -- diff` → `plugin "diff" exited with error`; or
  `invalid argument "server" for "--dry-run" flag`.
- **Cause:** `make prereqs` installs Helm **"latest" = Helm 4**, but the stack (helmfile 1.4.4 +
  helm-diff, and `--dry-run=server` in `helmDefaults.diffArgs`) is Helm-3-era. Helm 4 also changed
  `plugin install` (it requires `--verify=false`).
- **Fix:** install Helm **3.x** as `~/.local/bin/helm3` and symlink `~/.local/bin/helm → helm3`
  (`~/.local/bin` is first in PATH; helmfile uses `helm` from PATH — `HELM_BINARY` is **not** honored
  here). Upgrade helm-diff to **≥ v3.10** (Helm-3 install: `helm plugin install … --version v3.10.0`,
  **no** `--verify` flag) so it accepts `--dry-run=server`. See `prerequisites.md`.
- **Also:** `kubectl` and `az`/`gcloud` are NOT installed by `make prereqs` (Phase 2 needs them). If
  `az` is absent, pull kubeconfig from TF state (`ground-truth-rest.md`).

## 2. Env-name length → Azure name overflow
- **Symptom:** storage-account / Key Vault create fails: name `…` can only be ≤ 24 chars / invalid.
- **Cause:** `deployment_prefix = divyam-[org-]env`; Azure storage accounts and Key Vaults cap at 24
  chars (dashes stripped for storage). A long `ENV` (e.g. `create-p0-alerts`) overflows
  `divyamcreatep0alertstfstate` (27).
- **Fix:** keep `ENV` short (≤ ~9 chars after `divyam-`). Validate env-name length before apply. The
  sandbox launcher should reject an over-long `--env-name`.

## 3. State key embeds the values-file FILENAME (silent state fork)
- **Symptom:** `apply` tries to create resources that already exist (cascading `already exists`),
  because the state Terragrunt reads is empty.
- **Cause:** `iac/root.hcl` builds the key as
  `cloud/deployment_prefix/<values_basename>/region/<unit>/terraform.tfstate` — the **filename**
  (`VALUES_FILE` basename) is part of the key. Renaming/swapping the values file (or a generated
  `secrets.env` carrying a stale `VALUES_FILE`) points at a *different, empty* key while the cloud
  resources persist. This is the root cause behind most "already exists" here.
- **Why it's there:** lets `defaults.hcl` and `pre-prod-defaults.hcl` coexist on one backend.
- **Industry practice:** key state on a **logical identity** (org/env/stack), not an editable local
  filename — e.g. Terraform/Terragrunt usually key by `path_relative_to_include()` under a
  per-environment prefix; the env/stack id comes from a deliberate variable, and multi-profile is an
  explicit opt-in, not a side effect of a filename.
- **Fix (this repo):** keep the scheme (re-keying migrates state) but make it loud and safe —
  config vars (`CLOUD_PROVIDER`/`ENV`/`VALUES_FILE`) belong in `.iac.conf`/`iac.env`/CLI, **not** in
  the secrets file; `VALUES_FILE` must point at an existing file (fail loudly otherwise); and warn
  when a resolved state is empty yet same-named cloud resources exist. See `recovery-and-imports.md`.

## 4. NAP NodePools missing → every pod Pending
- **Symptom:** all workload pods `Pending`; Karpenter event
  `label "divyam.ai/nodepool-name" does not have known values`.
- **Cause:** charts pin `nodeSelector: divyam.ai/nodepool-name`, satisfied only by the Karpenter
  NodePools created by **`iac/2-app/0-nap_configs`** (Azure-only; NAP). Easy to miss if you apply
  only part of `2-app`.
- **Fix:** apply `2-app/0-nap_configs` before/at deploy time (`make iac -- apply -l 2-app.0-nap_configs`,
  or the `/apply-nap-configs` command). A whole-layer `apply -l 2-app` includes it.

## 5. Kafka won't start — replication factor > broker count
- **Symptom:** Kafka CR `NotReady: default.replication.factor should be 1 because this cluster has
  only 1 Kafka broker`; no broker pods, no bootstrap svc; otel-collector + kafka-connect CrashLoop
  with `no resolvable bootstrap urls`.
- **Cause:** the `kafka-cluster` chart default ships `nodepool.replicaCount: 1` but
  `defaultReplicationFactor: 3` / `defaultMinInsyncReplicas: 2` and topics `replicas: 3` — Strimzi
  refuses to provision.
- **Fix:** make them consistent in `k8s/helm-values/config.yaml` →
  `kafka-cluster.values.nodepool.replicaCount: 3` (matches RF=3; one change), then
  `make k8s -- upgrade -l kafka-cluster`. (Single-broker alt = set RF/min-isr/all topic replicas to 1
  — more surface.) Dependent pods self-heal once Kafka is Ready.

## 6. App-Gateway subnet collision
- **Symptom:** app_gw apply → `ApplicationGatewaySubnetCannotHaveOtherResources: Subnet … cannot be
  used for application gateway since it has other resources deployed`.
- **Cause:** the app-gw subnet (delegated to `Microsoft.Network/applicationGateways`) contains a
  non-gateway NIC — classically the **sandbox VM's own NIC** placed in that subnet by the launcher.
- **Fix:** the VM must live in the **main** subnet, never the app-gw subnet (`vnet.subnet`, not
  `vnet.app_gw_subnet`) — set correctly in the launcher/defaults. Preflight should read the app-gw
  subnet (`ground-truth-rest.md`) and flag any non-gateway NIC as a human action item before apply.
  If you must proceed without ingress, defer app_gw/AGIC (the stack runs with internal services).

## 7. Image pulls (Azure) need a real GAR docker-auth file
- **Symptom:** `0-divyam_secrets` plan/apply errors `no file exists at …/no-encrypted`; or pods
  `ImagePullBackOff`.
- **Cause:** Azure stores `TF_VAR_divyam_artifactory_docker_auth` (a **path** to a dockerconfigjson)
  as a Key Vault secret → image-pull secret. The value must be a real, complete file. GCP does NOT
  need this (uses GAR via SA/metadata token; `secrets_input.hcl` gates it azure-only).
- **Fix:** delegate to the human: provide the Divyam GAR dockerconfigjson (validate with `jq empty`,
  watch for truncated/4096-byte pastes) and point `TF_VAR_divyam_artifactory_docker_auth` at it.

## Cross-cloud note
Designs/contracts must stay cloud-parameterized: docker-auth file, `image_pull_secret_enabled`,
`0-agic`, `0-nap_configs` are **Azure-only**; GCP uses native ingress, GKE node pools/Autopilot, and
SA/metadata for GAR. When adding config, gate per `CLOUD_PROVIDER` rather than assuming Azure.
