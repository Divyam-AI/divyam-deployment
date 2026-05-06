# OpenSpec Project: divyam-deployment

This OpenSpec space defines deployment behavior contracts from infrastructure provisioning through Helmfile orchestration.

## Scope

- IaC layer sequencing (`0-foundation` -> `1-platform` -> `2-app`)
- Strict per-source-file/module onboarding policy for IaC and orchestration units
- Helmfile release orchestration and dependency behavior
- Environment and values layering contracts
- Validation command paths and release artifact references

## Canonical Inputs

- IaC guides and layer commands in `iac/README.md`
- Helmfile behavior in `k8s/helmfile.yaml.gotmpl` and `k8s/README.md`
- Output bridge script `scripts/write-outputs-yaml.sh`

## Where To Start

- Contributor guidance: `openspec/AGENTS.md`
- Module specs (primary): `openspec/specs/modules/<normalized-file-id>/spec.md`
- Capability specs (cross-module): `openspec/specs/`

## Spec Model

- Module specs are strict per file/unit and are the primary onboarding and maintenance unit.
- For IaC, maintain module specs for terragrunt/terraform unit files and key orchestration/config files.
- Capability specs remain for end-to-end behavior spanning IaC and Kubernetes orchestration.
- Changes to IaC commands, helmfile behavior, or output bridging must update affected module specs and verification mappings together.
