# Feature Specification: Application Desktop Metadata

**Feature Branch**: `019-app-desktop-metadata`\
**Created**: 2025-11-16\
**Status**: Draft\
**Input**: User description: "application nix files should contain additional desktop informations such as: desktop path by platform, file associations, and autostart configuration"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define File Associations for Applications (Priority: P1)

As a system administrator, I want to declare which file types should be handled by specific applications so that when users open files, they are automatically opened with the correct application.

**Why this priority**: This is the most fundamental desktop integration feature - users expect files to open with appropriate applications. Without this, the system cannot provide a seamless user experience for file handling.

**Independent Test**: Can be fully tested by declaring file associations for a single application (e.g., `.json` files with a text editor) and verifying that double-clicking those files opens the declared application.

**Acceptance Scenarios**:

1. **Given** an application configuration with file associations defined, **When** the system is activated, **Then** the declared file types are registered to open with that application
1. **Given** multiple applications declaring associations for the same file type, **When** the system is activated, **Then** the system applies the associations according to platform-specific precedence rules
1. **Given** an application with file associations but no desktop path, **When** the system is activated, **Then** the system returns a validation error

______________________________________________________________________

### User Story 2 - Configure Application Autostart (Priority: P2)

As a system administrator, I want to declare that certain applications should start automatically when a user logs in so that critical applications are always running when needed.

**Why this priority**: Autostart is essential for productivity and security applications (password managers, sync tools, communication apps), but the system can function without it initially.

**Independent Test**: Can be fully tested by enabling autostart for a single application and verifying it launches automatically after user login.

**Acceptance Scenarios**:

1. **Given** an application with autostart enabled, **When** a user logs in, **Then** the application starts automatically
1. **Given** an application with autostart disabled or not specified, **When** a user logs in, **Then** the application does not start automatically
1. **Given** an application with autostart enabled but no desktop path, **When** the system is activated, **Then** the system returns a validation error

______________________________________________________________________

### User Story 3 - Declare Platform-Specific Desktop Paths (Priority: P3)

As a system administrator, I want to declare where applications are installed on each platform so that file associations and autostart can reference the correct application location.

**Why this priority**: While critical for the other features to work, desktop paths alone provide no direct user value - they are infrastructure for the other features.

**Independent Test**: Can be fully tested by declaring a desktop path for an application on a specific platform and verifying the configuration is accessible to the system.

**Acceptance Scenarios**:

1. **Given** an application with desktop paths for multiple platforms, **When** the system activates on a specific platform, **Then** only that platform's desktop path is used
1. **Given** an application with desktop path for only one platform, **When** the system activates on a different platform, **Then** the desktop metadata features are not available but the application still installs normally
1. **Given** an application with incomplete desktop paths, **When** file associations or autostart are requested, **Then** the system validates the required desktop path exists for the active platform

______________________________________________________________________

### Edge Cases

- What happens when a desktop path is specified for a platform that doesn't have the application installed?
- How does the system handle conflicting file associations from multiple applications?
- What happens when an application's desktop path changes between versions?
- How does the system handle autostart for applications that require user interaction on launch?
- What happens when a user manually disables an autostart application through system settings?
- How does the system validate desktop paths at evaluation time vs activation time?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Application configuration files MUST support an optional desktop metadata section
- **FR-002**: Desktop metadata MUST include platform-specific desktop paths organized by platform name
- **FR-003**: Desktop metadata MUST support declaring file associations as a list of file extensions
- **FR-004**: Desktop metadata MUST support an autostart flag with a default value of false
- **FR-005**: System MUST validate that if file associations are declared, a desktop path exists for the active platform
- **FR-006**: System MUST validate that if autostart is enabled, a desktop path exists for the active platform
- **FR-007**: System MUST only read the desktop path corresponding to the currently active platform
- **FR-008**: Desktop metadata section MUST be entirely optional - applications without it continue to work normally
- **FR-009**: File extension declarations MUST support standard extension formats (e.g., ".json", ".xml", ".yaml")
- **FR-010**: System MUST provide clear error messages when desktop metadata validation fails
- **FR-011**: Each platform MUST be able to process desktop metadata according to its own conventions (e.g., Darwin uses launch agents for autostart, NixOS uses different mechanisms)
- **FR-012**: Desktop metadata configuration MUST remain platform-agnostic in shared application files while supporting platform-specific paths

### Key Entities

- **Application Configuration**: Represents an application's configuration file, now enhanced with optional desktop metadata
- **Desktop Metadata**: Contains platform paths, file associations, and autostart preferences for an application
- **Platform Desktop Path**: Maps a platform name to the installed location of an application on that platform
- **File Association**: Represents a file extension that should be handled by the application
- **Autostart Configuration**: Boolean flag indicating whether the application should launch at user login

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Configuration authors can add desktop metadata to any application configuration in under 5 minutes
- **SC-002**: System validates desktop metadata configuration and reports errors before activation
- **SC-003**: 100% of declared file associations are registered correctly after system activation
- **SC-004**: 100% of applications with autostart enabled launch successfully on user login
- **SC-005**: Applications without desktop metadata continue to function exactly as before (zero regression)
- **SC-006**: Platform-specific processing of desktop metadata is isolated to platform libraries (no shared code contains platform-specific logic)
- **SC-007**: Validation errors provide actionable messages that specify which application and which requirement failed

## Assumptions *(mandatory)*

- Applications are already installed at the declared desktop paths before system activation
- File extensions follow standard conventions (start with "." and contain only alphanumeric characters)
- Platform names match existing platform identifiers in the system (e.g., "darwin", "nixos")
- Each platform has its own mechanism for registering file associations and autostart applications
- Desktop paths are absolute paths on the target platform
- Users understand that desktop metadata features only work when the application is installed on that platform
- The configuration system can access platform context at evaluation time to select the correct desktop path
- Validation can occur at both evaluation time (structural) and activation time (path existence)

## Dependencies *(mandatory)*

- Existing platform libraries must be extended to process desktop metadata
- Platform-specific file association mechanisms (e.g., macOS Launch Services, Linux XDG)
- Platform-specific autostart mechanisms (e.g., macOS launch agents, Linux autostart desktop files)
- Configuration validation framework to check desktop metadata constraints
- Current application discovery system must remain compatible with enhanced application configurations

## Out of Scope *(mandatory)*

- GUI tools for managing desktop metadata
- Automatic detection of application installation paths
- Migrating existing file associations from system to Nix configuration
- Managing file association conflicts or priorities between applications
- Supporting non-standard file extension formats
- Providing user-level overrides for file associations or autostart preferences
- Runtime modification of desktop metadata (all changes require system rebuild/activation)
- Cross-platform abstraction of desktop paths (each platform uses its own native paths)
- Validation that applications actually exist at declared desktop paths during evaluation
- Automatic updates to desktop metadata when application paths change
