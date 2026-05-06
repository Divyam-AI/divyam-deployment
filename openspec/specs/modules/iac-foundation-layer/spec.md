# iac-foundation-layer Module Specification

## Purpose

Define behavior contracts for `iac/0-foundation` modules (`0-apis`, `0-resource_scope`, `1-vnet`, `2-nat`, `2-terraform_state_blob_storage`, `3-bastion`).

## Requirements

### Requirement: Ordered foundation execution
Foundation modules SHALL execute with Terragrunt in deterministic order for the selected cloud provider.

### Requirement: Credential gate before provisioning
Cloud credential checks SHALL pass before any foundation `plan` or `apply`.

### Requirement: Creation toggle compatibility
Modules configured with `create=false` SHALL be skippable without breaking downstream layer assumptions.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `iac/0-foundation`
  gap_action: Add a concrete validation command that verifies this file contract in CI.
