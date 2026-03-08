# Feature Specification: Simplified Application Configuration

**Feature Branch**: `020-app-array-config`\
**Created**: 2025-11-30\
**Status**: Draft\
**Input**: User description: "in user/default.nix, can we only specify the applications in the user structure into an array and let the home-manager bootstrap library do the imports with the discovery?"

**Implementation Approach**: Pure data pattern (refined from UNRESOLVED.md feasibility analysis). User configurations are pure data attribute sets with no imports. Platform libraries load user data, extract the applications array before module evaluation, and automatically generate imports. This achieves the original "automatic" vision while avoiding infinite recursion through pre-evaluation data extraction.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Application Declaration (Priority: P1)

A user wants to configure which applications their environment includes by simply listing application names in their user configuration, without writing any import logic or understanding the discovery system internals.

**Why this priority**: This is the core value proposition - simplifying the most common user configuration task. Every user needs to declare applications, making this the foundational use case.

**Independent Test**: Can be fully tested by creating a new user configuration that declares applications in a simple array structure and verifying the applications are properly imported and configured.

**Acceptance Scenarios**:

1. **Given** a user configuration file with `user.applications = ["git" "zsh" "helix"]` and no imports, **When** the configuration is built, **Then** all specified applications are imported and available in the user's environment
1. **Given** a pure data user configuration with only a user attribute set containing applications, **When** the platform library processes it, **Then** the discovery system automatically resolves and imports each application module
1. **Given** a user configuration with `user.applications = []` or `null`, **When** the configuration is built, **Then** the build succeeds with no applications imported (base home-manager only)

______________________________________________________________________

### User Story 2 - Migration from Explicit Discovery (Priority: P2)

An existing user with a configuration using explicit discovery imports wants to migrate to the pure data approach without changing their application set.

**Why this priority**: Ensures backward compatibility concerns are addressed and provides a clear migration path for existing users, but doesn't block new users from starting with the simpler approach.

**Independent Test**: Can be tested by taking an existing user configuration with explicit discovery calls and converting it to use the array-based approach, then verifying identical application imports.

**Acceptance Scenarios**:

1. **Given** an existing user configuration with explicit `mkApplicationsModule` imports, **When** the user removes all imports and moves applications to `user.applications`, **Then** the same applications are imported
1. **Given** a user configuration that previously imported the discovery library directly, **When** migrated to pure data approach, **Then** all import logic can be removed (platform libs handle it automatically)

______________________________________________________________________

### User Story 3 - Platform-Specific Application Handling (Priority: P3)

A user declares applications that may not be available on all platforms, and the system handles this gracefully without manual platform checks.

**Why this priority**: Enhances user experience but builds on the core functionality. Users can still accomplish multi-platform setups manually if needed.

**Independent Test**: Can be tested by creating a user configuration with mixed shared and platform-specific apps, building on different platforms, and verifying graceful handling.

**Acceptance Scenarios**:

1. **Given** a user configuration declaring both shared and platform-specific applications, **When** built on a platform where some apps are unavailable, **Then** the system gracefully skips unavailable apps (following existing discovery behavior)
1. **Given** a user configuration with platform-specific apps like `"aerospace"` (Darwin-only), **When** the same configuration is used across platforms, **Then** each platform imports only available applications without errors

______________________________________________________________________

### Edge Cases

- What happens when a user specifies an application name that doesn't exist anywhere in the repository?
- How does the system handle duplicate application names in the array?
- What happens if the applications field is not provided at all (null or missing)?
- How does the system behave if a user provides non-string values in the applications array?
- What happens when the home-manager bootstrap library is used without the user structure being defined?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: User configurations MUST be pure data attribute sets with `user.applications` array
- **FR-002**: Platform libraries MUST load user configurations as plain imports before module evaluation
- **FR-003**: Platform libraries MUST extract `user.applications` via attribute access (not through config)
- **FR-004**: Platform libraries MUST automatically generate application imports using the discovery system
- **FR-005**: Platform libraries MUST combine user data and generated imports in home-manager configuration
- **FR-006**: The system MUST maintain 100% backward compatibility with existing user configurations that use explicit discovery imports
- **FR-007**: The applications array MUST accept a list of application name strings (e.g., `["git" "zsh" "helix"]`)
- **FR-008**: The system MUST validate that application names are valid strings (delegated to discovery system)
- **FR-009**: The system MUST provide clear error messages when application names cannot be resolved (delegated to discovery system)
- **FR-010**: The `user.applications` option MUST be available for introspection and tooling purposes
- **FR-011**: Users MUST NOT need to import any helper functions or discovery libraries

### Key Entities

- **User Configuration**: Pure data attribute set containing user identity fields (name, email, fullName) and optional configuration fields like applications array, languages, keyboard layout, etc.
- **Applications Array**: List of application name strings in `user.applications` that the user wants in their environment
- **Platform Library**: Platform-specific library (darwin.nix, nixos.nix) that loads user data and orchestrates imports
- **Home Manager Bootstrap Library**: Module that provides standard Home Manager initialization and the `user.applications` option for introspection
- **Discovery System**: Existing library (`platform/shared/lib/discovery.nix`) that resolves application names to module paths and handles imports

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can declare their complete application set in a pure data attribute set with zero imports
- **SC-002**: User configuration files are reduced by 9+ lines (~45%) when migrating from explicit discovery to pure data approach
- **SC-003**: New users can create a working configuration without writing any import statements or understanding the discovery system
- **SC-004**: 100% of existing user configurations continue to work without modification after the feature is implemented
- **SC-005**: Configuration build time remains unchanged (no performance regression from the pure data pattern)
- **SC-006**: Users can successfully add or remove applications by editing only the `user.applications` array
- **SC-007**: The `user.applications` field is correctly populated for introspection
- **SC-008**: Platform libraries successfully extract applications before module evaluation without infinite recursion

## Assumptions

- The existing discovery system's `mkApplicationsModule` function provides all necessary functionality for resolving application names to module paths
- Platform libraries can import user files and access attributes before module evaluation begins
- Application name validation and error handling from the discovery system is sufficient and doesn't need enhancement
- Users are familiar with basic Nix attribute set syntax for declaring configuration data
- The Nix module system's constraint that `config` cannot be referenced in `imports` is fundamental and cannot be worked around
- Pre-evaluation data extraction (via plain import and attribute access) avoids the infinite recursion problem
- Platform libraries are the appropriate place for orchestration logic that users shouldn't see
- The home-manager bootstrap library is automatically included by platform libs, providing the `user.applications` option
