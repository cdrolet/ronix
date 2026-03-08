# Feature Specification: Refactor System Structure

**Feature Branch**: `013-refactor-system-structure`\
**Created**: 2025-01-27\
**Status**: Draft\
**Input**: User description: "improve system structure"

## Clarifications

### Session 2025-01-27

- Q: Should auto-discovery recursively scan subdirectories or only include direct children? → A: Recursive for all: Both settings and apps discover all `.nix` files in subdirectories
- Q: Should hostSpec validation fail the build (strict) or only warn (permissive) when required fields are missing? → A: Strict: Build fails immediately with clear error message if required hostSpec fields are missing
- Q: If system.stateVersion is set both centrally and in a profile, which value should take precedence? → A: Profile overrides central: If a profile explicitly sets system.stateVersion, it takes precedence over the central value
- Q: Is system.stateVersion Darwin-specific or cross-platform? → A: Darwin-specific; should be placed in system/darwin/lib/darwin.nix
- Q: When auto-discovery encounters an invalid Nix module, should it fail the build or skip the file with a warning? → A: Let Nix evaluation fail: Invalid modules cause normal Nix evaluation errors (no special handling needed)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Standardize Profile Host Configuration (Priority: P1)

A developer needs to create a new system profile (Darwin or future NixOS). They should be able to define host identification details (hostname, display name, platform) using a standard structure that automatically configures the appropriate networking and platform settings. This eliminates repetitive platform-specific configuration code and ensures consistency across all profiles.

**Why this priority**: This is foundational to making profiles truly reusable templates. Without standardization, each profile requires platform-specific knowledge and duplicate configuration, making onboarding new systems difficult.

**Independent Test**: Can be fully tested by creating a new profile with only a hostSpec structure and verifying that networking.hostName, networking.computerName, and nixpkgs.hostPlatform are correctly set without any manual configuration.

**Acceptance Scenarios**:

1. **Given** a new Darwin profile file, **When** a developer defines a hostSpec structure with name, display, and platform fields, **Then** the system automatically configures networking.hostName, networking.computerName, and nixpkgs.hostPlatform from those values
1. **Given** an existing profile with manual host configuration, **When** it is refactored to use hostSpec, **Then** the generated configuration remains identical to the previous manual configuration
1. **Given** a profile without hostSpec defined, **When** the system attempts to build the profile, **Then** appropriate validation errors are shown indicating required hostSpec fields

______________________________________________________________________

### User Story 2 - Centralize System State Version Configuration (Priority: P1)

A developer manages multiple system profiles. They need system.stateVersion to be set consistently across all Darwin profiles without duplicating the value in each profile file. This ensures all profiles stay synchronized when stateVersion needs updating.

**Why this priority**: Having stateVersion duplicated in each profile creates maintenance burden and risk of inconsistency. Centralizing it ensures all profiles use the same compatibility version.

**Independent Test**: Can be fully tested by verifying that all Darwin profiles automatically receive the same system.stateVersion value from a central location without explicitly setting it in profile files.

**Acceptance Scenarios**:

1. **Given** a Darwin profile without system.stateVersion defined, **When** the profile is built, **Then** it automatically receives the stateVersion from the central configuration
1. **Given** the central stateVersion configuration, **When** it is updated to a new version, **Then** all Darwin profiles automatically use the new version
1. **Given** system.stateVersion is Darwin-specific, **When** evaluating the configuration location, **Then** it is placed in system/darwin/lib/darwin.nix, with profile-level settings allowed to override the central value

______________________________________________________________________

### User Story 3 - Automate Settings and Apps Discovery (Priority: P2)

A developer adds a new settings module (e.g., `system/darwin/settings/bluetooth.nix`) or app module. They should not need to manually update any `defaults.nix` file to include the new module. The system should automatically discover and import all relevant modules.

**Why this priority**: Manual import maintenance is error-prone and creates friction when adding new modules. Auto-discovery reduces maintenance overhead and ensures new modules are immediately available.

**Independent Test**: Can be fully tested by creating a new settings file in the appropriate directory and verifying it is automatically imported by the corresponding defaults.nix without any manual import statement updates.

**Acceptance Scenarios**:

1. **Given** a new settings file in `system/darwin/settings/bluetooth.nix`, **When** the defaults.nix is evaluated, **Then** it automatically imports bluetooth.nix without manual import statement
1. **Given** a new app file in `system/darwin/app/new-app.nix`, **When** an app defaults.nix is evaluated (if applicable), **Then** it automatically discovers and imports the new app
1. **Given** a defaults.nix file that imports itself, **When** auto-discovery runs, **Then** it excludes the defaults.nix file from the import list to prevent circular dependencies
1. **Given** auto-discovery is implemented in `system/shared/lib/discovery.nix`, **When** any defaults.nix file uses it, **Then** all settings/apps in the same directory are automatically imported

______________________________________________________________________

### User Story 4 - Consolidate Shared Discovery Functions (Priority: P2)

A developer needs to understand or modify how users and profiles are discovered. Currently, discovery functions are embedded in flake.nix, making it difficult to locate, test, and reuse these functions across the codebase. They should be in a dedicated shared library.

**Why this priority**: Centralizing discovery logic makes the codebase more maintainable and allows reuse of discovery patterns in other contexts (e.g., auto-discovery for settings).

**Independent Test**: Can be fully tested by verifying that flake.nix imports discovery functions from shared/lib/discovery.nix and that all existing discovery behavior remains unchanged.

**Acceptance Scenarios**:

1. **Given** discovery functions are moved to `system/shared/lib/discovery.nix`, **When** flake.nix imports from that location, **Then** user and profile discovery continues to work identically
1. **Given** the discovery library, **When** settings/apps auto-discovery is implemented, **Then** it reuses the same discovery patterns and functions
1. **Given** discovery functions are in a shared library, **When** a developer wants to understand discovery logic, **Then** they can find it in one clear location

______________________________________________________________________

### User Story 5 - Refactor Darwin Library Functions (Priority: P3)

A developer reviews Darwin-specific helper functions to identify which are redundant (already provided by nix-darwin) versus which are custom additions needed for activation scripts. They want a clean, minimal library with only essential custom functions.

**Why this priority**: Maintaining redundant functions increases maintenance burden. Reviewing and removing unnecessary functions simplifies the codebase and reduces confusion about what's actually needed.

**Independent Test**: Can be fully tested by verifying that all Darwin profiles continue to work after removing redundant functions and that only custom functions required for activation remain.

**Acceptance Scenarios**:

1. **Given** existing Darwin lib functions, **When** they are reviewed against nix-darwin capabilities, **Then** redundant functions are identified and documented
1. **Given** redundant functions are identified, **When** they are removed, **Then** all profiles continue to build and activate successfully
1. **Given** mac.nix is evaluated for necessity, **When** it's determined to be an unnecessary intermediary, **Then** dock.nix and other modules can be imported directly without mac.nix as a re-export layer

______________________________________________________________________

### Edge Cases

- When a profile defines hostSpec but omits required fields (name, display, platform): Build fails immediately with a clear error message indicating which fields are missing
- When auto-discovery finds a file that is not a valid Nix module: Normal Nix evaluation errors occur (no special handling needed; invalid modules cause evaluation to fail naturally)
- What happens when discovery.nix functions are called with non-existent directory paths?
- What happens when a defaults.nix file is missing but modules exist in the directory?
- When system.stateVersion is set both centrally and in a profile file: Profile-level value takes precedence over central value (profile overrides central)
- System.stateVersion is Darwin-specific and located in system/darwin/lib/darwin.nix (NixOS profiles would have separate stateVersion handling when implemented)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a hostSpec configuration structure (or appropriately named alternative) that captures hostname, display name, and platform information
- **FR-002**: System MUST automatically configure `networking.hostName`, `networking.computerName`, and `nixpkgs.hostPlatform` from the hostSpec structure
- **FR-003**: System MUST provide a host configuration module in `system/shared/lib/host.nix` (or appropriately named alternative) that processes hostSpec and sets the appropriate variables
- **FR-004**: System MUST centralize `system.stateVersion` configuration so it is not duplicated across individual Darwin profiles
- **FR-005**: System MUST place `system.stateVersion` in `system/darwin/lib/darwin.nix` (Darwin-specific), with profile-level settings allowed to override the central value
- **FR-006**: System MUST move all discovery functions (`discoverUsers`, `discoverProfiles`, `discoverAllProfilesPrefixed`) from `flake.nix` to `system/shared/lib/discovery.nix`
- **FR-007**: System MUST update `flake.nix` to import discovery functions from the shared library location
- **FR-008**: System MUST provide auto-discovery functionality in `system/shared/lib/discovery.nix` that can recursively discover and import all `.nix` files in a directory and its subdirectories
- **FR-009**: System MUST implement auto-discovery in `system/darwin/settings/default.nix` to automatically import all settings files (excluding defaults.nix itself)
- **FR-010**: System MUST make auto-discovery the standard pattern for all defaults.nix files at the app and settings level
- **FR-011**: System MUST review all functions in `system/darwin/lib/` to identify and remove any that are redundant with nix-darwin built-in capabilities
- **FR-012**: System MUST evaluate `darwin/lib/mac.nix` to determine if it serves a necessary purpose or if modules can be imported directly
- **FR-013**: System MUST remove `mac.nix` if it is determined to be an unnecessary intermediary layer that only re-exports functions
- **FR-014**: System MUST ensure all profile refactoring maintains backward compatibility (existing profiles continue to work after changes)
- **FR-015**: System MUST validate hostSpec structure and fail the build immediately with clear error messages if required fields (name, display, platform) are missing

### Key Entities

- **hostSpec**: Configuration structure containing host identification information

  - **name** (string): Hostname identifier (e.g., "home-macmini")
  - **display** (string): Human-readable display name (e.g., "Home Mac Mini")
  - **platform** (string): Target platform architecture (e.g., "aarch64-darwin")
  - *Note: Entity name may be refined during implementation if a more appropriate term is identified*

- **Discovery Functions**: Shared utilities for automatically finding and loading modules

  - **discoverUsers**: Finds user directories from file system structure
  - **discoverProfiles**: Finds profile directories for a specific platform
  - **discoverAllProfilesPrefixed**: Finds all profiles across platforms with prefixes
  - **discoverModules**: Generic function to discover and import all modules in a directory (new)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Creating a new profile requires defining only the hostSpec structure (or equivalent), reducing profile boilerplate by at least 3 lines of platform-specific configuration code
- **SC-002**: System.stateVersion is defined in exactly one location for Darwin profiles, eliminating duplication across all existing and future profiles
- **SC-003**: Adding a new settings or app module requires zero manual import statement updates in defaults.nix files (100% auto-discovery coverage)
- **SC-004**: All discovery-related code is consolidated in a single location (`system/shared/lib/discovery.nix`), reducing discovery logic duplication
- **SC-005**: Darwin library contains only functions not available in nix-darwin, resulting in removal of at least one redundant function or elimination of unnecessary intermediary modules
- **SC-006**: All existing Darwin profiles successfully build and activate after refactoring, maintaining 100% backward compatibility
- **SC-007**: Developer can understand the host configuration pattern by reading one file (`system/shared/lib/host.nix`), reducing time to onboard new system platforms

## Assumptions

- `system.stateVersion` is Darwin-specific and must be placed in `system/darwin/lib/darwin.nix`; profile-level values override the central value
- The hostSpec structure name is acceptable, though alternatives like "hostConfig" or "machineSpec" may be considered during implementation
- Auto-discovery recursively handles subdirectories for both settings and apps, discovering all `.nix` files in directory trees
- The hostSpec structure should be extensible to accommodate future fields beyond name, display, and platform
- All existing Darwin profiles (home-macmini-m4, work) will be refactored to use the new hostSpec pattern as part of this feature

## Dependencies

- Existing Darwin profiles must remain functional during refactoring
- nix-darwin library capabilities must be reviewed to identify redundant functions
- The flake.nix structure must remain compatible with existing tooling (justfile commands, etc.)

## Out of Scope

- Creating NixOS profiles (this refactoring prepares the structure for future NixOS onboarding but does not implement it)
- Migrating user configurations to use hostSpec (only system profiles are in scope)
- Adding new settings or app modules (only refactoring the structure to support them)
- Changing the overall flake.nix output structure or platform detection logic beyond moving discovery functions
