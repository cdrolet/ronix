# Feature Specification: Modularize Flake Configuration Libraries

**Feature Branch**: `011-modularize-flake-libs`\
**Created**: 2025-11-01\
**Status**: Implemented with Enhanced Architecture\
**Input**: User description: "In flake.nix, I can see specific portion for home manager, other for darwin, for nixos, for nixOnDroid, etc.. I would like to move these portion into isolated nix file under proper lib. by example, for homemanager, we alreadey have a home-manager.nix under user/shared/lib, all flake.nix specific to homenanager should be move there. for darwin, it should be under system/darwin/lib/darwin.nix. follow the same logic for the other (nixos, etc). also, the valid user and profile names should be scanned from the directory structure, not hardcoded."

**Enhanced Implementation**: The final implementation goes beyond the original spec to achieve true platform-agnostic design. Each platform lib now exports complete outputs (configurations, formatters, validations), and flake.nix only loads platforms that exist. This ensures no darwin code is loaded when only using NixOS, and vice versa.

## User Scenarios & Testing

### User Story 1 - Auto-Discover Users and Profiles (Priority: P1)

Repository maintainers need the system to automatically discover valid users and profiles from the directory structure, eliminating manual updates to flake.nix when adding new users or profiles.

**Why this priority**: Reduces maintenance burden and prevents errors from forgetting to update hardcoded lists. This is the foundation that enables the rest of the modularization - without it, moving code to lib files still requires manual flake.nix updates.

**Independent Test**: Can be fully tested by adding a new user directory under `user/` or a new profile directory under `system/{platform}/profiles/` and verifying that `nix flake show` and `just list-users`/`just list-profiles` commands automatically include the new entries without any flake.nix modifications.

**Acceptance Scenarios**:

1. **Given** I create a new directory `user/newuser/default.nix`, **When** I run `just list-users`, **Then** I see "newuser" in the list without editing flake.nix
1. **Given** I create a new directory `system/darwin/profiles/new-profile/`, **When** I run `just list-profiles`, **Then** I see "new-profile" under darwin profiles without editing flake.nix
1. **Given** I remove a user directory `user/olduser/`, **When** I run `just list-users`, **Then** "olduser" is no longer listed
1. **Given** the directory structure has 3 users and 2 darwin profiles, **When** flake evaluation runs, **Then** all 6 valid user-profile combinations (3×2) are automatically available as configurations

______________________________________________________________________

### User Story 2 - Modularize Darwin Configuration Logic (Priority: P2)

Repository maintainers need darwin-specific flake configuration code isolated in `system/darwin/lib/darwin.nix`, separating concerns and improving code organization.

**Why this priority**: Second priority because it builds on the auto-discovery foundation. Improves maintainability by colocating darwin logic with other darwin code, but doesn't block usage like auto-discovery does.

**Independent Test**: Can be fully tested by verifying that the `mkDarwinConfig` helper function and darwin-specific logic are defined in `system/darwin/lib/darwin.nix` and successfully imported/used by flake.nix, with all existing darwin configurations building successfully.

**Acceptance Scenarios**:

1. **Given** flake.nix imports `system/darwin/lib/darwin.nix`, **When** I build a darwin configuration, **Then** the build succeeds using the helper from darwin.nix
1. **Given** I need to modify darwin configuration logic, **When** I edit `system/darwin/lib/darwin.nix`, **Then** I don't need to touch flake.nix
1. **Given** darwin.nix exports `mkDarwinConfig`, **When** flake.nix uses this function, **Then** all darwin configurations are created correctly with proper Home Manager integration and primaryUser settings

______________________________________________________________________

### User Story 3 - Modularize NixOS Configuration Logic (Priority: P3)

Repository maintainers need nixos-specific flake configuration code isolated in `system/nixos/lib/nixos.nix`, following the same pattern as darwin modularization.

**Why this priority**: Third priority as NixOS configurations are currently empty (TODO placeholders). This prepares the structure for future NixOS implementation.

**Independent Test**: Can be fully tested by creating a sample NixOS configuration using the helper function from `system/nixos/lib/nixos.nix` and verifying it evaluates correctly (even if not deployed).

**Acceptance Scenarios**:

1. **Given** flake.nix imports `system/nixos/lib/nixos.nix`, **When** I define a nixos configuration, **Then** the configuration uses the `mkNixosConfig` helper from nixos.nix
1. **Given** I need to add NixOS-specific logic, **When** I edit `system/nixos/lib/nixos.nix`, **Then** the changes apply to all nixos configurations without flake.nix modifications

______________________________________________________________________

### User Story 4 - Modularize Home Manager Standalone Logic (Priority: P4)

Repository maintainers need home-manager-only configuration code (for non-NixOS Linux) added to the existing `user/shared/lib/home-manager.nix`, keeping all Home Manager logic in one place.

**Why this priority**: Fourth priority as standalone Home Manager is currently empty (TODO placeholder). Lower priority than darwin/nixos as it serves a smaller use case. Merging with existing home-manager.nix simplifies structure.

**Independent Test**: Can be fully tested by creating a sample standalone Home Manager configuration (e.g., for Kali Linux) using the `mkHomeConfig` helper function exported from home-manager.nix and verifying it evaluates correctly.

**Acceptance Scenarios**:

1. **Given** flake.nix imports `user/shared/lib/home-manager.nix`, **When** I define a standalone home configuration, **Then** the configuration uses the `mkHomeConfig` helper exported from home-manager.nix
1. **Given** I need to add standalone Home Manager logic, **When** I edit home-manager.nix, **Then** changes apply without flake.nix modifications

______________________________________________________________________

### Edge Cases

- What happens when a user directory exists but has no `default.nix` file? (Should be skipped from auto-discovery)
- What happens when a profile directory exists but has no `default.nix` file? (Should be skipped from auto-discovery)
- How does the system handle platform-specific profiles (darwin vs nixos) during auto-discovery? (Should scan platform-specific subdirectories: `system/darwin/profiles/`, `system/nixos/profiles/`, etc.)
- What happens when a user tries to build a configuration for a platform where no profiles exist? (Should provide clear error message)
- How does the system validate that discovered users/profiles are valid Nix modules? (Should attempt to import and catch evaluation errors)

## Requirements

### Functional Requirements

- **FR-001**: System MUST automatically discover all users by scanning directories under `user/` that contain a `default.nix` file
- **FR-002**: System MUST automatically discover darwin profiles by scanning directories under `system/darwin/profiles/` that contain a `default.nix` file
- **FR-003**: System MUST automatically discover nixos profiles by scanning directories under `system/nixos/profiles/` that contain a `default.nix` file
- **FR-004**: System MUST export discovered users in `validUsers` attribute for justfile validation
- **FR-005**: System MUST export discovered profiles in `validProfiles` attribute (keyed by platform) for justfile validation
- **FR-006**: System MUST provide `mkDarwinConfig` helper function in `system/darwin/lib/darwin.nix` that accepts `{user, profile, system?}` parameters
- **FR-007**: System MUST provide `mkNixosConfig` helper function in `system/nixos/lib/nixos.nix` that accepts `{user, profile, system?}` parameters
- **FR-008**: System MUST provide `mkHomeConfig` helper function in `user/shared/lib/home-manager.nix` that accepts `{user, system}` parameters (merged with existing bootstrap module)
- **FR-009**: Helper functions MUST handle Home Manager integration, setting `system.stateVersion` and `system.primaryUser` appropriately
- **FR-010**: flake.nix MUST import and use the modularized helper functions from lib files instead of defining them inline
- **FR-011**: System MUST maintain backward compatibility - all existing configurations must continue to build successfully after refactoring
- **FR-012**: Auto-discovery MUST skip directories that don't contain `default.nix` files
- **FR-013**: System MUST generate all valid user-profile combinations as darwin/nixos configurations based on discovered users and profiles

### Key Entities

- **User Directory**: Represents a user configuration under `user/{username}/default.nix`, contains user-specific app selections and settings
- **Profile Directory**: Represents a deployment context under `system/{platform}/profiles/{profile}/default.nix`, contains platform-specific settings and overrides
- **Helper Function**: Nix function that constructs a complete system configuration from user and profile parameters, handles integration with nix-darwin/nixos/home-manager
- **Platform Library**: Nix module under `system/{platform}/lib/` containing platform-specific helper functions and logic

## Success Criteria

### Measurable Outcomes

- **SC-001**: Adding a new user requires only creating a directory under `user/` - no flake.nix edits needed
- **SC-002**: Adding a new profile requires only creating a directory under `system/{platform}/profiles/` - no flake.nix edits needed
- **SC-003**: All 4 existing darwin configurations build successfully after modularization
- **SC-004**: flake.nix is reduced by at least 30% in line count through modularization
- **SC-005**: Running `nix flake show` displays all auto-discovered configurations correctly
- **SC-006**: Running `just list-users` displays all users discovered from directory structure
- **SC-007**: Running `just list-profiles [platform]` displays all profiles discovered from directory structure for the specified platform
- **SC-008**: All helper functions are defined in their respective lib files, not in flake.nix
- **SC-009**: Each platform's configuration logic is isolated to its own lib file (darwin.nix, nixos.nix, etc.)
- **SC-010**: Justfile validation commands correctly validate user/profile combinations against auto-discovered lists

## Assumptions

- Directory scanning will use `builtins.readDir` or similar Nix built-ins
- The presence of `default.nix` in a directory indicates it's a valid user/profile module
- Platform detection logic remains in flake.nix (determining aarch64-darwin vs x86_64-darwin, etc.)
- Existing `modules/shared/lib/` files don't need refactoring (they're already properly placed)
- The helper functions will use the same module system patterns as the current inline implementations
- Auto-discovery happens at flake evaluation time, not at build time
- Invalid or malformed directories will cause flake evaluation errors (failing fast is acceptable)
- Nix flake commands (`nix flake show`, `nix flake check`) must continue to work without errors
- Justfile commands depend on flake outputs for validation, so they will automatically benefit from auto-discovery

## Out of Scope

- Modularizing Nix-on-Droid configuration (currently a placeholder, can be addressed in future work)
- Adding new platforms beyond what currently exists (darwin, nixos, home-manager standalone)
- Changing the directory structure or naming conventions
- Refactoring existing modules outside of flake.nix and lib files
- Adding validation logic for module correctness (beyond checking for `default.nix` existence)
- Performance optimization of flake evaluation time
- Automatic generation of user/profile configurations
- Migration of existing configurations to new patterns (they already work, just refactoring the plumbing)

## Dependencies

- Nix flakes must be enabled
- Current directory structure (`user/`, `system/{platform}/profiles/`, lib files) must remain stable
- Existing helper functions in flake.nix must be preserved in their modular form
- Justfile must be updated to use auto-discovered lists instead of hardcoded values (if it currently hardcodes them)

## Risks

- **Risk**: Directory scanning at flake evaluation time might impact performance

  - **Mitigation**: Nix evaluations are typically cached; directory scanning is fast for small directory trees

- **Risk**: Auto-discovery might pick up invalid or test directories

  - **Mitigation**: Require `default.nix` to exist; document naming conventions clearly

- **Risk**: Refactoring might break existing configurations

  - **Mitigation**: Thorough testing of all 4 configurations before committing; maintain exact same logic, just moved to different files

## Notes

- This refactoring aligns with Constitutional principle of modularity (v2.0.0)
- The pattern of platform-specific lib files mirrors the existing `system/{platform}/` organization
- Auto-discovery eliminates a common source of errors (forgetting to update hardcoded lists)
- This enables easier expansion to new platforms in the future (just create the directory structure and lib file)
- The `user/shared/lib/home-manager.nix` file currently contains the Home Manager bootstrap module; the standalone logic should go in a separate file to keep concerns separated
