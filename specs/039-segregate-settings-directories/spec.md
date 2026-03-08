# Feature Specification: Segregate Settings Directories

**Feature Branch**: `039-segregate-settings-directories`\
**Created**: 2025-01-11\
**Status**: Draft\
**Input**: User description: "we currently prevent the system to read home-manager settings by using if lib.optionalAttrs ((options ? home)). this system seem fragile... in many place, we forgot to set them properly making the build fail when darwin or nixos read homemanager specific field and vice versa, when homemanager read system specific. I would like to solve this issue by segregating setting in a subfolder, either system or user then homemanager will then only automloads settings from user subfolder and system from system subfolder folder"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - System Configuration Builds Without User Settings (Priority: P1)

When building system-level configurations (darwin or nixos), the build process must succeed without encountering home-manager-specific settings that cause failures.

**Why this priority**: This is critical infrastructure - system builds must work reliably without manual guards on every setting. This enables reliable automated builds and reduces developer cognitive load.

**Independent Test**: Can be fully tested by running `nix build` for any system configuration (darwin or nixos) and verifying it completes without errors related to undefined home-manager options.

**Acceptance Scenarios**:

1. **Given** a NixOS system configuration, **When** building the system, **Then** no home-manager-specific settings are loaded or cause build failures
1. **Given** a Darwin system configuration, **When** building the system, **Then** no home-manager-specific settings are loaded or cause build failures
1. **Given** system settings in the `system/` directory, **When** discovery runs, **Then** only system-level settings are imported

______________________________________________________________________

### User Story 2 - Home Manager Builds Without System Settings (Priority: P1)

When building home-manager configurations, the build process must succeed without encountering system-specific settings that cause failures.

**Why this priority**: Equally critical as Story 1 - home-manager builds must work reliably in standalone mode without manual guards. This is essential for Feature 036 (standalone home-manager).

**Independent Test**: Can be fully tested by running `nix build` for any home-manager configuration and verifying it completes without errors related to undefined system options.

**Acceptance Scenarios**:

1. **Given** a home-manager configuration, **When** building the user environment, **Then** no system-specific settings are loaded or cause build failures
1. **Given** user settings in the `user/` directory, **When** discovery runs, **Then** only user-level settings are imported
1. **Given** a standalone home-manager installation, **When** activating, **Then** system settings are not required or referenced

______________________________________________________________________

### User Story 3 - Settings Automatically Discovered by Context (Priority: P2)

Settings must be automatically discovered and loaded based on the build context (system vs user) without requiring manual `options ? home` checks in every file.

**Why this priority**: This removes manual error-prone checks and enables automatic discovery, reducing maintenance burden and preventing forgotten guards.

**Independent Test**: Can be tested by adding a new setting file to either `system/` or `user/` subdirectory and verifying it's only loaded in the appropriate context without any manual guards.

**Acceptance Scenarios**:

1. **Given** a new setting in `settings/system/`, **When** system discovery runs, **Then** the setting is automatically included
1. **Given** a new setting in `settings/user/`, **When** home-manager discovery runs, **Then** the setting is automatically included
1. **Given** settings in both directories, **When** building, **Then** each context only loads its appropriate settings

______________________________________________________________________

### User Story 4 - Clear Organization and Documentation (Priority: P3)

Developers must understand where to place new settings based on whether they're system-level or user-level.

**Why this priority**: Prevents future mistakes and ensures maintainability, but doesn't block immediate functionality.

**Independent Test**: Can be tested by reviewing directory structure documentation and verifying new contributors can correctly categorize settings.

**Acceptance Scenarios**:

1. **Given** a new system-level setting need, **When** developer reviews structure, **Then** it's clear the file belongs in `settings/system/`
1. **Given** a new user-level setting need, **When** developer reviews structure, **Then** it's clear the file belongs in `settings/user/`
1. **Given** the directory structure, **When** reviewed by a new contributor, **Then** the separation is self-documenting

______________________________________________________________________

### Edge Cases

- What happens when a setting could logically be either system or user level? (e.g., timezone)
- How does the system handle settings that need to coordinate between system and user? (e.g., shell configuration)
- What if a setting file is placed in the wrong directory?
- How does migration work for existing settings with `options ? home` guards?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System-level settings MUST be organized in a `system/` subdirectory within each settings location
- **FR-002**: User-level settings MUST be organized in a `user/` subdirectory within each settings location
- **FR-003**: System discovery mechanisms MUST only load settings from `system/` subdirectories
- **FR-004**: Home-manager discovery mechanisms MUST only load settings from `user/` subdirectories
- **FR-005**: Settings MUST NOT require manual `options ? home` or similar guards when properly categorized
- **FR-006**: The directory structure MUST clearly communicate the purpose of each subdirectory
- **FR-007**: Migration path MUST exist for moving existing settings to new structure
- **FR-008**: Build errors related to context mismatches (system reading user settings or vice versa) MUST be eliminated

### Key Entities

- **System Settings**: Configuration modules that modify system-level behavior (services, users, system packages, display managers). Applied during system rebuild (nixos-rebuild/darwin-rebuild).
- **User Settings**: Configuration modules that modify user-level behavior (dconf preferences, shell aliases, user environment). Applied during home-manager activation.
- **Settings Directory**: A location containing setting files, now subdivided into `system/` and `user/` subdirectories.
- **Discovery Context**: The build context (system vs home-manager) that determines which subdirectory to scan.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All system builds (darwin and nixos) complete successfully without home-manager-related errors (100% success rate)
- **SC-002**: All home-manager builds complete successfully without system-specific errors (100% success rate)
- **SC-003**: Zero `options ? home` guards remain in setting files after migration
- **SC-004**: New settings can be added without manual context guards (zero guard requirements for new files)
- **SC-005**: Build failures due to context mismatches are reduced to zero
- **SC-006**: Developer documentation clearly explains system vs user categorization (verifiable through review)

## Assumptions *(mandatory)*

- Settings can be cleanly categorized as either "system-level" or "user-level" based on their purpose
- The discovery system can be modified to scan specific subdirectories based on context
- Existing settings with guards can be migrated without breaking functionality
- The distinction between system and user settings aligns with NixOS/nix-darwin vs home-manager boundaries

## Dependencies

- Feature 036 (standalone home-manager) - This feature enhances the separation already established
- Discovery system (`system/shared/lib/discovery.nix`) - Will need modification to support subdirectory filtering

## Out of Scope

- Changing the fundamental architecture of how settings are applied
- Merging system and user contexts into a single build
- Creating new settings categories beyond system/user
- Automated migration script (can be done manually as part of implementation)
