# Feature Specification: Host/Family Architecture Refactoring

**Feature Branch**: `021-host-family-refactor`\
**Created**: 2025-12-02\
**Status**: Draft\
**Input**: User description: "Refactor profiles to host/family architecture with pure data pattern"

**Terminology**: Using "family" for cross-platform shared configurations (in `platform/shared/family/`) - families group related platforms (e.g., "linux" family shared by nixos/kali, "gnome" desktop family)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define Host Configuration (Priority: P1)

A repository maintainer wants to define host-specific settings (hostname, hardware, system preferences) as pure data without managing imports or discovery logic, similar to how user configurations work.

**Why this priority**: This is the foundational change - establishing hosts as pure data entities is required before any profile system can be built. It provides immediate value by simplifying host configuration management.

**Independent Test**: Can be fully tested by creating a new host configuration with pure data structure, building the system, and verifying host settings are applied correctly.

**Acceptance Scenarios**:

1. **Given** a new host needs to be added, **When** maintainer creates a pure data host config with name and settings array, **Then** the system builds successfully with those settings applied
1. **Given** an existing profile-based host config, **When** migrated to pure data host config, **Then** the same settings and applications are applied
1. **Given** a host config without a profile field, **When** the system builds, **Then** only platform-specific and shared settings are applied

______________________________________________________________________

### User Story 2 - Use Shared Families (Priority: P2)

A repository maintainer wants to define reusable cross-platform families (linux, gnome, server) that can be referenced by multiple hosts across different platforms, avoiding duplication of common settings and applications that span platform boundaries.

**Why this priority**: Builds on P1 by adding the cross-platform reusability layer. Provides significant value when multiple platforms (nixos, kali, ubuntu) need to share common configurations, but hosts can function without families.

**Independent Test**: Can be tested by creating a shared family (e.g., "linux") with settings and apps, referencing it from multiple platform hosts (nixos, kali), and verifying all hosts receive the family's configuration.

**Acceptance Scenarios**:

1. **Given** a shared family "linux" with common Linux settings, **When** two hosts (nixos and kali) reference `family = ["linux"]`, **Then** both hosts receive the linux family settings and applications
1. **Given** a host with `family = ["gnome"]`, **When** the family includes default.nix for settings and apps, **Then** those defaults are automatically installed
1. **Given** a host defines its own settings and references a family, **When** the system builds, **Then** both host-specific and family settings are applied with host-specific taking precedence
1. **Given** a host with `family = ["linux", "gnome"]`, **When** the system builds, **Then** both family configurations are composed and applied

______________________________________________________________________

### User Story 3 - Application and Setting Discovery Hierarchy (Priority: P3)

A repository maintainer wants applications and settings to be resolved using a hierarchical search pattern (platform → family → shared) so that platform-specific implementations override more general ones while maintaining fallbacks.

**Why this priority**: Provides the complete flexibility of the system but builds on the foundation of P1 and P2. Hosts and families can work with simpler configurations before this sophisticated resolution is needed.

**Independent Test**: Can be tested by creating an app in multiple locations (platform, family, shared) and verifying the platform-specific version is used when available, falling back to family, then shared.

**Acceptance Scenarios**:

1. **Given** an app exists in both platform/darwin/app and shared/app, **When** a darwin host requests it, **Then** the platform-specific version is used
1. **Given** a setting exists in shared/family/linux/settings and shared/settings, **When** a host with `family = ["linux"]` requests it, **Then** the family version is used
1. **Given** a host requests "default" settings, **When** the system resolves settings, **Then** all settings in the platform are imported (similar to darwin/settings/default.nix)
1. **Given** a setting not found in platform or family, **When** the system searches shared/settings, **Then** the shared version is used as final fallback
1. **Given** a host with `family = ["linux", "gnome"]`, **When** resolving an app, **Then** system searches platform → linux family → gnome family → shared in order

______________________________________________________________________

### Edge Cases

- What happens when a host references a family that doesn't exist?
- What happens when a host requests a setting that doesn't exist in any search location (platform, families, shared)?
- How are conflicts resolved when both host arrays and family defaults define the same app or setting?
- What happens when a family's default.nix exists but is invalid or throws errors?
- How does the system behave when a host array contains duplicate app or setting names?
- What happens when "\*" is used in a settings array (should be rejected based on requirements)?
- How does resolution work when multiple families in the array provide the same app/setting?
- What happens when family array is empty `[]` vs not defined at all?

## Requirements *(mandatory)*

### Functional Requirements

**Directory Structure**:

- **FR-001**: System MUST rename `platform/{name}/profiles/*` directories to `platform/{name}/host/*`
- **FR-002**: System MUST create `platform/shared/family/` directory structure
- **FR-003**: All documentation MUST be updated to reflect host/family terminology
- **FR-004**: Justfile commands MUST be updated to use host terminology instead of profile

**Host Configuration**:

- **FR-005**: Host configurations MUST be pure data attribute sets with no imports
- **FR-006**: Host configurations MUST support a `name` field identifying the host
- **FR-007**: Host configurations MUST support an optional `family` field as an array of strings
- **FR-008**: Host configurations MUST support an `applications` array listing host-specific apps
- **FR-009**: Host configurations MUST support a `settings` array listing host-specific settings
- **FR-010**: Platform libraries MUST load host configurations as plain imports before module evaluation
- **FR-011**: Platform libraries MUST extract host data and generate appropriate imports automatically

**Family System**:

- **FR-012**: Families MUST reside in `platform/shared/family/{name}/`
- **FR-013**: Families MAY contain `settings/default.nix` which is auto-installed when family is referenced
- **FR-014**: Families MAY contain `app/default.nix` which is auto-installed when family is referenced
- **FR-015**: Families MAY contain subdirectories with individual settings and apps
- **FR-016**: Platform libraries MUST use discovery to resolve family paths when `family` field is present
- **FR-017**: When multiple families are specified, system MUST process them in array order
- **FR-018**: Family array MAY be empty `[]` to explicitly disable family resolution

**Application Resolution**:

- **FR-019**: Applications MUST be resolved in this order: `platform/{name}/app` → each family in `family` array → `platform/shared/app`
- **FR-020**: Application resolution MUST stop at first match (no merging across locations)
- **FR-021**: Application arrays MAY use "\*" wildcard to import all discovered applications
- **FR-022**: Platform libraries MUST generate application imports based on host's applications array

**Settings Resolution**:

- **FR-023**: Settings MUST be resolved in this order: `platform/{name}/settings` → each family in `family` array → `platform/shared/settings`
- **FR-024**: Settings resolution MUST stop at first match (no merging across locations)
- **FR-025**: Settings arrays MUST NOT accept "\*" wildcard
- **FR-026**: Settings arrays MAY use "default" to import all settings in the platform (platform-specific behavior)
- **FR-027**: When "default" is used, system MUST import all settings from `platform/{name}/settings/` directory
- **FR-028**: Platform libraries MUST generate settings imports based on host's settings array

**Auto-Installation**:

- **FR-029**: When `family` field contains family names and `platform/shared/family/{name}/settings/default.nix` exists, system MUST install it automatically for each family
- **FR-030**: When `family` field contains family names and `platform/shared/family/{name}/app/default.nix` exists, system MUST install it automatically for each family

**Error Handling**:

- **FR-031**: System MUST provide clear error messages when a referenced family doesn't exist
- **FR-032**: System MUST provide clear error messages when a requested app/setting cannot be found in any search location
- **FR-033**: System MUST validate that settings arrays do not contain "\*" and fail with helpful message if found

### Key Entities

- **Host**: Pure data configuration representing a physical/virtual machine, containing name, optional family array, arrays of applications and settings
- **Family**: Cross-platform reusable configuration bundle in shared/ representing shared functionality (linux, gnome, server, etc.), containing apps and settings that span multiple platforms
- **Application**: Installable program configured via Nix modules, searchable across platform/family/shared hierarchy
- **Setting**: System configuration (dock, displays, keyboard, etc.) searchable across platform/family/shared hierarchy
- **Platform**: Target operating system (darwin, nixos, kali) with platform-specific hosts, apps, and settings
- **Discovery System**: Mechanism for locating modules across hierarchical search paths

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All existing profile configurations can be migrated to host/family structure without loss of functionality
- **SC-002**: Host configurations contain zero import statements (pure data only)
- **SC-003**: Maintainers can create a new host configuration in under 15 lines of pure data
- **SC-004**: Cross-platform families (linux, gnome) can be defined once and reused across 3+ platforms
- **SC-005**: Application and setting resolution follows documented hierarchy 100% of the time
- **SC-006**: All documentation and command references updated to use host/family terminology
- **SC-007**: System provides helpful error messages when configuration errors occur (invalid family, missing app/setting)
- **SC-008**: Build times remain unchanged or improve after refactoring (no performance regression)
- **SC-009**: Family default.nix files are automatically installed when family is referenced
- **SC-010**: Hosts can compose multiple families (e.g., `family = ["linux", "gnome"]`) successfully

## Assumptions

- The pure data pattern established in feature 020-app-array-config for user configurations provides a proven model to follow for hosts
- Platform libraries are the appropriate place for orchestration logic (loading data, generating imports)
- The discovery system can be extended to support hierarchical search patterns
- The existing `darwin/settings/default.nix` pattern of importing all settings is valuable and should be generalized via the "default" keyword
- Families are for cross-platform sharing (linux, gnome, server) not deployment contexts (work, home, gaming) - hosts are specific enough for deployment
- Families are simpler than full inheritance and sufficient for most use cases (no family-extends-family scenarios)
- Migration from profiles to hosts is a one-time effort with manageable scope (currently 2 profiles per platform)
- Settings and applications are conceptually distinct enough to warrant separate arrays and resolution logic
- The search order (platform → families → shared) matches natural override expectations
- Automatic installation of family defaults (if they exist) provides good UX without surprises
- Darwin hosts typically won't use families since macOS configs aren't shared cross-platform
- Multiple Linux distributions (nixos, kali, ubuntu) will benefit from shared family configurations

## Constraints

- Must maintain backward compatibility during migration (or provide clear migration path)
- Cannot break existing user configurations (feature 020)
- Must work within Nix's module system evaluation constraints
- Should follow the constitutional requirement of \<200 lines per module
- Directory renames must preserve git history where possible
