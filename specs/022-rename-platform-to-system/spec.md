# Feature Specification: Rename Platform Directory to System

**Feature Branch**: `022-rename-platform-to-system`\
**Created**: 2025-12-05\
**Status**: Draft\
**Input**: User description: "rename directory platform to system, update all documentation accordingly. keep platform as field in the user definition since it's refer to something else."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Directory Structure Reflects System Organization (Priority: P1)

Developers working with the nix-config repository need the directory structure to accurately reflect its purpose. The current `platform/` directory contains system configurations (darwin, nixos, shared libraries), but the name "platform" is ambiguous since it's also used as a field in user definitions to mean something different (the target platform for a user's configuration).

**Why this priority**: This is a foundational change that improves code clarity and prevents confusion between directory naming and field naming. It's essential for maintainability and onboarding new contributors.

**Independent Test**: Can be fully tested by verifying the repository builds successfully with all configurations after the rename, and that documentation accurately describes the new structure.

**Acceptance Scenarios**:

1. **Given** the repository with `platform/` directory, **When** renaming to `system/`, **Then** all system configurations (darwin, nixos) remain accessible at their new paths
1. **Given** user configurations with `platform` field, **When** directory is renamed to `system/`, **Then** the `platform` field continues to work unchanged
1. **Given** documentation referencing `platform/` directory, **When** updates are applied, **Then** all documentation correctly references `system/` directory

______________________________________________________________________

### User Story 2 - Documentation Accurately Describes Repository Structure (Priority: P2)

Contributors and users reading documentation need accurate references to directory paths and architectural concepts to understand and use the repository effectively.

**Why this priority**: Accurate documentation is critical for usability, but can be updated after the structural change is verified working.

**Independent Test**: Can be tested by reviewing all documentation files and verifying they use "system" when referring to the directory and "platform" when referring to the user field.

**Acceptance Scenarios**:

1. **Given** CLAUDE.md with directory structure diagrams, **When** reviewing after update, **Then** diagrams show `system/` instead of `platform/`
1. **Given** README.md with architecture description, **When** reviewing after update, **Then** directory references use `system/` terminology
1. **Given** inline code comments referencing directories, **When** reviewing after update, **Then** comments accurately reflect `system/` paths

______________________________________________________________________

### User Story 3 - Code References Use Correct Directory Names (Priority: P1)

All code that constructs or references file paths needs to use the new directory name to maintain functionality.

**Why this priority**: Code must be updated simultaneously with the directory rename to prevent breakage. This is as critical as the rename itself.

**Independent Test**: Can be tested by running `nix flake check` and building all configurations successfully.

**Acceptance Scenarios**:

1. **Given** Nix files with path references to `platform/`, **When** updated to `system/`, **Then** all builds succeed
1. **Given** discovery functions looking for directories, **When** updated to search `system/`, **Then** hosts and families are discovered correctly
1. **Given** justfile commands with path validations, **When** updated to check `system/`, **Then** validation passes for all hosts

______________________________________________________________________

### Edge Cases

- What happens when old documentation links (external or in git history) reference `platform/`?

  - Git history remains unchanged (directory rename preserves history)
  - Documentation should include a note about the rename for anyone viewing old commits

- How does system handle references in spec files for previous features?

  - Previous spec files remain unchanged as historical artifacts
  - Only active/current documentation is updated

- What if some paths are missed during the rename?

  - Validation step (nix flake check) will catch broken path references
  - Comprehensive grep search ensures all references are found

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST rename the `platform/` directory to `system/` while preserving git history
- **FR-002**: System MUST update all Nix code references from `platform/` to `system/` paths
- **FR-003**: System MUST update all documentation files (CLAUDE.md, README.md, feature specs) to use `system/` when referring to the directory
- **FR-004**: System MUST preserve the `platform` field in user configurations unchanged (as it refers to target platform like "darwin" or "nixos")
- **FR-005**: System MUST update discovery functions to search in `system/` directory
- **FR-006**: System MUST update justfile path validations to check `system/` directory
- **FR-007**: System MUST maintain backwards compatibility for git history references
- **FR-008**: System MUST pass `nix flake check` validation after all changes
- **FR-009**: System MUST successfully build all existing configurations (darwin and nixos) after rename

### Key Entities

- **Directory Structure**: The top-level organization containing `system/darwin/`, `system/nixos/`, `system/shared/`
- **User Configuration**: Contains a `platform` field that specifies target platform (darwin/nixos) - this field name remains unchanged
- **Path References**: All code and documentation references to directory paths
- **Documentation Files**: CLAUDE.md, README.md, spec files, and inline comments

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All directory paths successfully renamed from `platform/` to `system/` with zero broken references
- **SC-002**: 100% of configurations build successfully after rename (`nix build` succeeds for all user-host combinations)
- **SC-003**: All documentation files updated to use `system/` terminology when referring to directories (verified by grep showing zero `platform/` directory references in docs)
- **SC-004**: User configuration `platform` field continues to function correctly (verified by evaluating user configs and confirming platform field values)
- **SC-005**: `nix flake check` passes without errors after all changes applied
- **SC-006**: Git history for renamed directory remains accessible (git log follows files correctly)

## Assumptions & Constraints

### Assumptions

- Git will preserve file history when directory is renamed (standard git mv behavior)
- All path references are absolute or relative in a consistent way that can be updated systematically
- No external tools or scripts outside the repository depend on the `platform/` directory name
- The distinction between "system directory" and "platform field" is clear enough to maintain separately

### Constraints

- Must not break any existing user configurations
- Must maintain git history visibility
- Cannot change the meaning or usage of the `platform` field in user configs
- All changes must be atomic (complete in one feature branch) to avoid inconsistent state

## Dependencies

- Current repository state (021-host-family-refactor or main branch)
- Git (for directory rename with history preservation)
- All existing Nix configurations must be in working state before rename

## Out of Scope

- Changing the `platform` field name in user configurations (explicitly preserved as-is)
- Updating external documentation or tools that reference this repository
- Renaming any other directories beyond `platform/` → `system/`
- Changing the semantic meaning of platform-related concepts (only changing directory name)

## Notes

This is a refactoring change focused on improving code clarity by renaming a directory to better reflect its contents. The key challenge is ensuring all references are updated consistently while preserving the distinct meaning of the `platform` field in user configurations.

The rename improves clarity because:

- Directory `system/` clearly indicates it contains system configurations
- User field `platform` clearly indicates the target platform for that user's configuration
- These two concepts no longer share the same name, reducing confusion
