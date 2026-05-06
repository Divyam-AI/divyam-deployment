# iac-platform-layer Module Specification

## Purpose

Define behavior contracts for `iac/1-platform` modules (object storage, app gateway, k8s cluster, alerts, bastion kubectl setup).

## Requirements

### Requirement: Platform layer dependency on foundation
Platform provisioning SHALL assume foundation outputs already exist and are consumable.

### Requirement: Provider-scoped module execution
Platform Terragrunt operations SHALL target cloud-specific module paths using provider filters.

### Requirement: Operational alerts and cluster resources continuity
Platform resources and alert modules SHALL remain provisionable from the same values and provider context.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `iac/1-platform`
  gap_action: Add a concrete validation command that verifies this file contract in CI.
