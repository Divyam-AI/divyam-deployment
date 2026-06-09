---
description: Verify the workload-identity → Key Vault/Secret-Manager → ExternalSecret → image-pull chain is healthy (esp. after a cluster recreate). Read-only.
argument-hint: "[namespace]   (omit to check all)"
allowed-tools: Bash(kubectl get:*), Bash(kubectl describe:*), Bash(curl:*), Bash(jq:*), Read, Skill
---
You confirm pods can actually authenticate to the cloud secret store and pull images — the chain that
silently breaks when a cluster is recreated (OIDC issuer changes → stale federated creds). Adopt
`divyam-platform-engineer`. Read-only. Optional namespace: **$ARGUMENTS**.

1. **ExternalSecrets sync.** `kubectl get externalsecrets -A` — every one should be
   `STATUS=SecretSynced READY=True`. Any `SecretSyncError`/`False` means ESO can't read the store
   (workload-identity or access-policy problem). `kubectl describe` the failing one for the reason.
2. **SecretStores resolve.** `kubectl get secretstores -A` are Ready; the synced k8s Secrets exist
   (`kubectl get secret -n <ns>`), including the image-pull secret.
3. **Image pulls.** `kubectl get pods -A | grep -iE 'ImagePull|ErrImage'` — none. (If present, the
   docker-auth secret is missing/invalid — see known-gotchas §7.)
4. **Issuer match (Azure, the cluster-recreate trap).** Using REST (`ground-truth-rest.md`): compare
   the cluster's `oidcIssuerProfile.issuerURL` to a UAMI's federated-credential `issuer`. If they
   differ, the creds are stale → run `make iac -- apply -l 2-app.1-iam_bindings` (rebinds live), then
   re-check. Surface this as the fix, don't apply silently on a shared env without a go-ahead.
   (GCP: the binding is the GSA↔KSA `workloadIdentityUser` IAM member, not a per-cluster issuer.)
5. Report: ExternalSecrets state, any image-pull failures, and whether the issuer matches. Green when
   all ExternalSecrets are `SecretSynced` and no pods are stuck on pulls.
