# iac-0-foundation-1-vnet-azure-main-tf Module Specification

## Purpose

Define per-validation-case behavior contract for `iac/0-foundation/1-vnet/azure/main.tf`.

## Requirements

### Requirement: IaC static validation command cases
`iac/0-foundation/1-vnet/azure/main.tf` SHALL keep Terraform/Terragrunt syntax and reference contracts valid for module directory `iac/0-foundation/1-vnet/azure`.

### Requirement: Coverage-gap closure command cases
No direct automated case currently asserts `iac/0-foundation/1-vnet/azure/main.tf` behavior; these concrete cases SHALL be added.

#### Scenario: proposed_tf_fmt_check_iac_0_foundation_1_vnet_azure_main_tf
- **WHEN** CI executes proposed case `proposed_tf_fmt_check_iac_0_foundation_1_vnet_azure_main_tf`
- **THEN** command `terraform fmt -check iac/0-foundation/1-vnet/azure` validates `iac/0-foundation/1-vnet/azure/main.tf` directly.

#### Scenario: proposed_tf_validate_iac_0_foundation_1_vnet_azure_main_tf
- **WHEN** CI executes proposed case `proposed_tf_validate_iac_0_foundation_1_vnet_azure_main_tf`
- **THEN** command `terraform -chdir=iac/0-foundation/1-vnet/azure init -backend=false && terraform -chdir=iac/0-foundation/1-vnet/azure validate` validates `iac/0-foundation/1-vnet/azure/main.tf` directly.

## Verification Mapping




- verification_status: coverage_gap
  evidence_type: test_file
  evidence_ref: File path: `iac/0-foundation/1-vnet/azure/main.tf`
  gap_action: Add a concrete validation command that verifies this file contract in CI.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tf_fmt_check_iac_0_foundation_1_vnet_azure_main_tf` command: `terraform fmt -check iac/0-foundation/1-vnet/azure`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.

- verification_status: coverage_gap
  evidence_type: command_case
  evidence_ref: Scenario `proposed_tf_validate_iac_0_foundation_1_vnet_azure_main_tf` command: `terraform -chdir=iac/0-foundation/1-vnet/azure init -backend=false && terraform -chdir=iac/0-foundation/1-vnet/azure validate`
  gap_action: Implement this command case in an executable workflow and capture pass/fail evidence.
