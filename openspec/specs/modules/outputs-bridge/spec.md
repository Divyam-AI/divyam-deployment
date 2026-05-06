# outputs-bridge Module Specification

## Purpose

Define behavior contracts for IaC-to-Helm output bridging implemented by `scripts/write-outputs-yaml.sh`.

## Requirements

### Requirement: Layer/provider scoped output collection
Output bridge SHALL collect Terragrunt outputs only from selected layer (`0`, `1`, `2`) and selected cloud provider path.

### Requirement: Config-driven include/exclude filtering
Output bridge SHALL apply include/exclude module and output filters sourced from `root.hcl` (`locals.outputs_for_helm`).

### Requirement: Helm-consumable output generation
Output bridge SHALL produce Helm-consumable output payload under `terraform_outputs` in YAML or JSON based on configured output path.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `scripts/write-outputs-yaml.sh`
  gap_action: Add a concrete validation command that verifies this file contract in CI.
