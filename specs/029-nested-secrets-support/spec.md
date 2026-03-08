# Feature Specification: Nested Secrets Support

**Feature Branch**: `029-nested-secrets-support`\
**Created**: 2025-12-26\
**Status**: Draft\
**Input**: User description: "I would like you to implement the Approach: Multiple Keys with Nested Secrets"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Store Multiple SSH Keys Per User (Priority: P1)

A user needs to manage multiple SSH keys for different purposes (personal GitHub, work GitHub, deployment servers) and wants to store all of them securely in their age-encrypted secrets file as a nested structure.

**Why this priority**: This is the core capability that unblocks SSH key management. Without this, users cannot store multiple SSH keys, which is the primary use case driving this feature.

**Independent Test**: Can be fully tested by setting nested SSH keys via `just secrets-set user sshKeys.personal "key-content"` and verifying the JSON structure in `user/{name}/secrets.age` contains the nested `sshKeys` object. Delivers immediate value for users who need multiple SSH keys.

**Acceptance Scenarios**:

1. **Given** a user configuration file, **When** the user sets `user.sshKeys.personal = "<secret>"`, **Then** the system recognizes this as a secret placeholder at a nested path
1. **Given** encrypted secrets.age with nested structure `{"sshKeys": {"personal": "key1", "work": "key2"}}`, **When** the system decrypts the file, **Then** it can extract values from nested paths like `sshKeys.personal`
1. **Given** a user has `sshKeys.github = "<secret>"` in their config, **When** activation runs, **Then** the secret is resolved from the nested JSON path and deployed to the correct location

______________________________________________________________________

### User Story 2 - Configure Apps with Nested Secrets (Priority: P2)

An app developer wants to create an SSH module that reads multiple SSH keys from nested secrets and deploys them to appropriate locations during home-manager activation.

**Why this priority**: This enables practical use of the nested secrets infrastructure. Once users can store nested secrets (P1), apps need to be able to consume them. This is a direct dependency on P1 and delivers the end-to-end value.

**Independent Test**: Can be tested by creating a test SSH app module that references `config.user.sshKeys.personal` and verifying the activation script correctly resolves the nested secret and writes the key to `~/.ssh/id_ed25519`. Delivers value by enabling SSH key deployment.

**Acceptance Scenarios**:

1. **Given** an app module references `config.user.sshKeys.personal`, **When** the secrets helper checks if it's a secret, **Then** it correctly detects the `"<secret>"` placeholder at the nested path
1. **Given** an activation script uses `secrets.mkActivationScript` with nested field paths, **When** activation runs, **Then** the script extracts values from the correct JSON paths (e.g., `sshKeys.personal`)
1. **Given** an SSH app configured with nested secret fields, **When** home-manager activation completes, **Then** multiple SSH keys are deployed to their respective paths in `~/.ssh/`

______________________________________________________________________

### User Story 3 - Manage Nested Secrets via CLI (Priority: P3)

A user wants to set, edit, and list nested secrets using the existing justfile commands (`just secrets-set`, `just secrets-edit`, `just secrets-list`) with dotted path syntax.

**Why this priority**: This improves user experience but is not blocking - users can already manually edit JSON in `just secrets-edit`. This priority adds convenience for command-line workflows.

**Independent Test**: Can be tested by running `just secrets-set user sshKeys.personal "key"` and verifying it creates the nested JSON structure, then using `just secrets-list` to display the nested structure. Delivers UX improvement for CLI users.

**Acceptance Scenarios**:

1. **Given** a user runs `just secrets-set user sshKeys.personal "key-content"`, **When** the command executes, **Then** it creates/updates the nested JSON structure in secrets.age
1. **Given** nested secrets exist in secrets.age, **When** the user runs `just secrets-list`, **Then** the output shows nested paths (e.g., "sshKeys.personal: [encrypted]")
1. **Given** a user edits secrets via `just secrets-edit`, **When** they save the file, **Then** nested JSON structures are preserved and validated

______________________________________________________________________

### Edge Cases

- What happens when a user references a nested path that doesn't exist in secrets.age (e.g., `sshKeys.nonexistent`)?
- How does the system handle deeply nested paths (e.g., `config.tokens.api.github.readonly`)?
- What happens if the JSON structure in secrets.age has a nested object at a path that the config expects to be a string value?
- How does the system validate that nested paths don't conflict (e.g., both `sshKeys = "<secret>"` and `sshKeys.personal = "<secret>"` at the same time)?
- What happens when a user tries to set a nested secret for a field that doesn't have `"<secret>"` as its value?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect `"<secret>"` placeholder at nested attribute paths (e.g., `config.user.sshKeys.personal`)
- **FR-002**: System MUST resolve nested secrets from JSON paths in secrets.age using dotted notation (e.g., `sshKeys.personal` maps to `{"sshKeys": {"personal": "value"}}`)
- **FR-003**: Secrets helper library MUST provide a function to extract values from nested JSON paths
- **FR-004**: The `mkActivationScript` helper MUST support field names that correspond to nested config paths (e.g., field name `sshKeys.personal` extracts from `config.user.sshKeys.personal`)
- **FR-005**: System MUST validate that a nested path exists in secrets.age before attempting to extract it
- **FR-006**: CLI command `just secrets-set` MUST accept dotted path syntax (e.g., `just secrets-set user sshKeys.personal "value"`) and create the nested JSON structure
- **FR-007**: CLI command `just secrets-list` MUST display nested secret paths in a readable format
- **FR-008**: System MUST handle extraction of deeply nested paths (at least 4 levels deep, e.g., `config.tokens.api.github.readonly`)
- **FR-009**: System MUST provide clear error messages when a nested path doesn't exist in secrets.age
- **FR-010**: System MUST validate that nested paths don't create conflicts (e.g., both `sshKeys` and `sshKeys.personal` as secrets simultaneously)

### Key Entities

- **Nested Secret Path**: A dotted string representing the path to a value in the nested JSON structure (e.g., `"sshKeys.personal"`, `"tokens.api.github"`)
- **User Config Attribute Path**: The Nix attribute path in `config.user.*` that may contain nested attributes (e.g., `config.user.sshKeys.personal`)
- **JSON Structure**: The encrypted JSON object in secrets.age that contains nested objects and values
- **Field Mapping**: The relationship between a config attribute path, its JSON path in secrets.age, and the shell variable name used in activation scripts

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can store and retrieve nested secrets at least 4 levels deep (e.g., `config.tokens.api.github.readonly`)
- **SC-002**: App modules can resolve nested secrets during activation without requiring changes to the activation script pattern
- **SC-003**: Users can set nested secrets via CLI using dotted paths in under 10 seconds (same as current flat secrets)
- **SC-004**: System provides actionable error messages when nested paths are invalid or missing (error message includes the exact path and suggestion to fix)
- **SC-005**: The secrets helper library maintains backward compatibility with existing flat secret paths (e.g., `config.user.email` still works)
- **SC-006**: Nested secret detection and resolution adds less than 100ms to home-manager activation time

## Assumptions

- **A-001**: The existing secrets.age file format (JSON) will be preserved and extended to support nested objects
- **A-002**: The dotted path syntax (e.g., `sshKeys.personal`) will not conflict with existing config attribute names that contain periods
- **A-003**: Users understand JSON structure and can manually edit nested objects via `just secrets-edit`
- **A-004**: The `jq` tool (already used in the secrets system) supports nested path extraction
- **A-005**: App modules will adopt nested secrets gradually and backward compatibility with flat secrets is required
- **A-006**: The maximum nesting depth of 4 levels is sufficient for practical use cases (can be extended later if needed)

## Dependencies

- **D-001**: Feature 027 (User Colocated Secrets) - provides the base secrets infrastructure
- **D-002**: `jq` command-line tool - required for JSON path extraction
- **D-003**: Existing `user/shared/lib/secrets.nix` helper library - will be extended
- **D-004**: Justfile recipes for secrets management - may need updates for nested path syntax

## Constraints

- **C-001**: Must maintain backward compatibility with existing flat secret paths (e.g., `config.user.email = "<secret>"`)
- **C-002**: Changes to secrets.nix helper library must not break existing apps that use the current API
- **C-003**: Nested paths must use dotted notation (e.g., `sshKeys.personal`) to remain compatible with both Nix attribute paths and JSON paths
- **C-004**: The `mkActivationScript` function signature should remain backward compatible (existing calls should continue working)

## Out of Scope

- **OS-001**: Support for array indices in nested paths (e.g., `tokens[0].value`) - only object nesting is supported
- **OS-002**: Automatic migration of existing flat secrets to nested structure - users must manually reorganize if desired
- **OS-003**: Validation of secret content (e.g., checking if an SSH key is valid) - only path resolution is in scope
- **OS-004**: Support for multiple secrets files per user - only `user/{name}/secrets.age` is supported
- **OS-005**: Merging secrets from multiple sources - only single secrets.age file per user
