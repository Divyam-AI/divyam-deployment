# deployment-capabilities Specification

## Purpose

Define behavior contracts for IaC layer sequencing, helmfile orchestration, and environment-value layering.

## Requirements

### Requirement: Ordered IaC layer execution
Infrastructure provisioning SHALL run in deterministic layer order: `0-foundation`, `1-platform`, then `2-app`.

#### Scenario: Planning and apply flow by provider
- **WHEN** infrastructure changes are prepared
- **THEN** credential checks SHALL pass before Terragrunt execution
- **AND** each layer SHALL run in order using provider-filtered targets
- **AND** later layers SHALL assume outputs from earlier layers

### Requirement: Helmfile deployment orchestration
Kubernetes deployment SHALL be orchestrated through `k8s/helmfile.yaml.gotmpl` with deterministic artifact resolution and environment mapping.

#### Scenario: Diff and apply lifecycle
- **WHEN** pull-request validation runs
- **THEN** helmfile SHALL run in diff mode using environment values
- **AND** apply mode SHALL be used only during deployment runs
- **AND** artifact resolution SHALL follow release/version rules documented in `k8s/README.md`

### Requirement: Environment and value layering
Runtime configuration SHALL follow explicit precedence and preserve environment identity propagation.

#### Scenario: Values precedence and output bridging
- **WHEN** deployment values are assembled
- **THEN** precedence SHALL remain `config.yaml` > `resources.yaml` > `artifacts.yaml`
- **AND** IaC outputs SHALL be exported in a Helm-consumable format
- **AND** environment identifiers (`ENV`, `ORG_NAME`, provider) SHALL drive naming and release resolution
