# AGENTS: OpenSpec Contribution Guide

Capture stable operator contracts with strict per file/module granularity.

## Authoring Rules

- Module-first and strict granularity: for each meaningful IaC/orchestration source file update, edit `openspec/specs/modules/<normalized-file-id>/spec.md`.
- Maintain separate module specs for terragrunt/terraform unit files, orchestration scripts, and key config-layer files.
- Describe order-of-operations and dependency constraints explicitly.
- Link each scenario to a runnable command sequence from project docs/scripts.
- Keep cloud differences (`azure` vs `gcp`) explicit and testable.
- Add verification mapping entries and tag each as `mapped` or `coverage_gap`.


## Verification Status Semantics

- `verification_status: mapped` means the evidence points to a concrete executable command/test/pipeline step currently present in repo workflows.
- `verification_status: coverage_gap` means the scenario is not yet backed by executable verification in current workflows.
- `gap_action` is required for every `coverage_gap` verification entry.
- Use only `evidence_type`: `command_case`, `pipeline_step`, `test_function`, or `test_file`.
- Include `artifact_ref` when verification evidence is artifacts-based (for example `artifacts.yaml` or `artifacts.<name>`).

## Required References For Deployment Changes

- `iac/README.md` for terragrunt flow
- `k8s/README.md` and `k8s/helmfile.yaml.gotmpl` for orchestration
- `scripts/write-outputs-yaml.sh` for IaC-to-Helm value export behavior

## Validation Expectations

- Run provider credential pre-check before IaC execution.
- Validate affected layer `terragrunt init/plan/apply` commands and helmfile `diff/apply` flow.
- Reconcile module boundaries whenever IaC units, helmfile templates, release artifacts, or output bridging scripts change.
