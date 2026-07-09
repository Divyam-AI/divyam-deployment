# GCP provisioning IAM — roles the provisioning principal needs

Roles that must be granted (on the **target project**, e.g. `divyam-production`) to the principal
that runs the Terragrunt/OpenTofu layers — whether that's a human's ADC or a dedicated provisioning
service account. This list was derived while provisioning the evalm8 stack on GCP; each apply that
failed did so with a `403 … Required '<permission>'`, so the set below is effectively the
least-privilege union for a full provision.

> Grant these **up front**. Discovering them one failed-apply at a time (as happened here) turns a
> provision into a stop-start "grant → retry" loop.

## Role → what it unblocks

| Role | Enables | Gating permission(s) | Unit(s) |
|------|---------|----------------------|---------|
| `roles/secretmanager.admin` | Create/manage Secret Manager secrets + versions | `secretmanager.secrets.*`, `secretmanager.versions.add` | `2-app/0-divyam_secrets` |
| `roles/storage.admin` | Create/look up GCS buckets **and** read/write the Terraform state bucket | `storage.buckets.create`, `storage.buckets.get`, `storage.objects.*` | `1-platform/0-divyam_object_storage`; the GCS state backend |
| `roles/iam.serviceAccountAdmin` | Create service accounts + set their IAM (Workload Identity bindings) | `iam.serviceAccounts.create`, `iam.serviceAccounts.setIamPolicy` | `2-app/1-iam_bindings` |
| `roles/resourcemanager.projectIamAdmin` | Add project-level IAM bindings (`google_project_iam_member`) | `resourcemanager.projects.setIamPolicy` | `2-app/1-iam_bindings` |
| `roles/compute.loadBalancerAdmin` | Reserve global static IPs + create Google-managed SSL certs | `compute.globalAddresses.create`, `compute.sslCertificates.create` | `2-app/4-ingress_inputs` |
| `roles/compute.securityAdmin` | Create/manage Cloud Armor security policies | `compute.securityPolicies.create` | `2-app/4-ingress_inputs` |
| `roles/container.admin` | GKE cluster access (kubeconfig / kubectl); GKE Ingress-generated LB objects | `container.*` | `1-platform/1-k8s`, Phase-2 Helmfile, ingress |

### Notes / gotchas
- **`iam.serviceAccountAdmin` ≠ project IAM.** It lets you *create* SAs and set IAM *on the SAs*, but
  **not** edit the project's IAM policy — that's `resourcemanager.projectIamAdmin`
  (`resourcemanager.projects.setIamPolicy`). Both are required for `2-app/1-iam_bindings`.
- **`compute.loadBalancerAdmin` does not cover Cloud Armor.** Static IPs and SSL certs come with it;
  security policies need `compute.securityAdmin` (or `compute.orgSecurityPolicyAdmin` / `compute.admin`).
- **State bucket in a different project.** If the tfstate bucket lives in another project than the
  resources (here the bucket is `divyam-production-terraform-state-bucket`, project `divyam-production`,
  set via `tfstate.scope_name`), the principal needs GCS access **on the bucket's project** too. GCS
  bucket names are global, so backend *access* only needs `storage.objects.*` + `storage.buckets.get`
  on the bucket; `storage.buckets.create` is only needed if the bucket itself is created via IaC.
- **`divyam-artifactory-docker-auth`** is gated on `image_pull_secret_enabled` — on GCP with an
  in-project GAR it's `false`, so no extra registry-pull role is required.

## Simpler alternatives (if least-privilege isn't required)
- A single **`roles/editor`** covers most, but **not** `setIamPolicy` — you still need
  `roles/resourcemanager.projectIamAdmin` and `roles/iam.serviceAccountAdmin` (and `compute.securityAdmin`
  for Cloud Armor).
- **`roles/owner`** covers everything (use only where a broad grant is acceptable).
- Or define a **custom provisioning role** bundling exactly the gating permissions in the table above.

## Recommended for a provisioning service account (least-privilege)
```
roles/secretmanager.admin
roles/storage.admin
roles/iam.serviceAccountAdmin
roles/resourcemanager.projectIamAdmin
roles/compute.loadBalancerAdmin
roles/compute.securityAdmin
roles/container.admin
```
