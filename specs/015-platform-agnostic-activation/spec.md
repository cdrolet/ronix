# Feature Specification: Platform-Agnostic Activation System

**Feature Branch**: `015-platform-agnostic-activation`\
**Created**: 2025-11-11\
**Status**: Draft\
**Input**: User description: "Implement platform-agnostic activation approach using nix build and manual activation scripts instead of platform-specific rebuild tools"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build Configuration Uniformly Across Platforms (Priority: P1)

A developer wants to build their system configuration to verify it compiles successfully before activating it, using the same command regardless of which operating system they're using.

**Why this priority**: Core functionality that enables the basic workflow and removes platform-specific knowledge requirements. This is the foundation for all other workflows.

**Independent Test**: Execute the build command and verify that the configuration is successfully compiled and available for activation, regardless of platform.

**Acceptance Scenarios**:

1. **Given** a valid macOS configuration, **When** user builds the configuration, **Then** system successfully compiles it and makes it available for activation
1. **Given** a valid Linux configuration, **When** user builds the configuration, **Then** system successfully compiles it and makes it available for activation
1. **Given** an invalid configuration, **When** user attempts to build, **Then** system shows clear error messages indicating what failed

______________________________________________________________________

### User Story 2 - Activate Configuration Uniformly Across Platforms (Priority: P1)

A developer wants to activate (apply) their system configuration using the same command regardless of which operating system they're using, without needing to remember platform-specific procedures.

**Why this priority**: Essential for applying configurations. Along with Story 1, forms the complete MVP for platform-agnostic system management.

**Independent Test**: Execute the install command and verify that the system configuration is activated and takes effect, regardless of platform.

**Acceptance Scenarios**:

1. **Given** a compiled macOS configuration, **When** user activates the configuration, **Then** system applies changes and updates the running system
1. **Given** a compiled Linux configuration, **When** user activates the configuration, **Then** system applies changes with appropriate permissions and updates the running system
1. **Given** activation errors, **When** activation fails, **Then** system shows clear error messages and maintains previous working state

______________________________________________________________________

### User Story 3 - Add New Platform Support Easily (Priority: P2)

A developer wants to add support for a new operating system platform by only defining platform-specific metadata, without needing to modify the build and activation logic.

**Why this priority**: Demonstrates true platform-agnostic design and scalability. Not required for MVP but validates the architecture.

**Independent Test**: Add a new platform configuration and verify that build and activation commands work immediately without modifying command logic.

**Acceptance Scenarios**:

1. **Given** a new platform configuration is defined, **When** developer specifies platform-specific metadata, **Then** all build and activation operations work for that platform
1. **Given** multiple platforms configured, **When** developer switches between platforms, **Then** all operations work consistently with uniform behavior

______________________________________________________________________

### User Story 4 - Delegate Platform Logic to Platform Libraries (Priority: P3)

A developer wants to add support for a new platform by creating a platform-specific library file, without needing to modify the central orchestration logic.

**Why this priority**: Further enhances platform-agnostic design by removing platform-specific logic from central files. Optional enhancement that could be deferred if infeasible.

**Independent Test**: Add a new platform with its own library defining flake inputs/outputs, verify that orchestration discovers and uses it automatically.

**Acceptance Scenarios**:

1. **Given** a platform library file exists in the platform's lib folder, **When** orchestration loads platforms, **Then** it automatically discovers and applies platform-specific configuration
1. **Given** multiple platforms with their own library files, **When** building configurations, **Then** each platform's specific logic is used without central orchestration changes

______________________________________________________________________

### Edge Cases

- What happens when activation process cannot proceed due to missing prerequisites?
- How does system handle permission errors during activation?
- What happens if a previous build output exists when starting a new build?
- How does system handle partial activation failures?
- What happens when platform configuration structure changes over time?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide uniform build command that works identically across all supported platforms
- **FR-002**: System MUST execute activation using built configuration outputs instead of requiring platform-specific external tools
- **FR-003**: System MUST centralize platform-specific configuration paths in a single location
- **FR-004**: System MUST handle permission requirements transparently based on platform security model
- **FR-005**: System MUST provide clear error messages when activation cannot proceed
- **FR-006**: System MUST maintain compatibility with all existing platform configurations
- **FR-007**: System MUST eliminate dependency on platform-specific management tools for build and activation workflows
- **FR-008**: System MUST preserve the established three-parameter interface (user, platform, profile)
- **FR-009**: System SHOULD investigate feasibility of delegating platform-specific flake logic to platform library files
- **FR-010**: If delegation is feasible, central orchestration SHOULD automatically discover and load platform-specific configurations from standard locations

### Key Entities

- **Configuration Path**: Platform-specific location identifier for system configuration
- **Activation Process**: Procedure that applies built configuration to the running system
- **Build Output**: Compiled configuration ready for activation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can build configurations on any platform using identical commands
- **SC-002**: Developers can activate configurations on any platform using identical commands
- **SC-003**: Adding a new platform requires configuration changes in only one centralized location
- **SC-004**: All existing workflows continue to function without user-visible changes
- **SC-005**: Build and activation are cleanly separated (can build without activating)
- **SC-006**: Error messages clearly indicate whether failure occurred during build or activation phase
- **SC-007**: Configuration build time remains within 10% of current performance baseline
- **SC-008**: If platform delegation is implemented, adding a new platform requires only creating platform-specific library file

## Assumptions

- Platform configurations provide their own activation procedures as part of the build output
- Users have appropriate system permissions for their respective platforms
- Build system is available and properly configured in the user's environment
- Platform-specific activation procedures follow consistent patterns across platforms

## Dependencies

- Modern build system with support for declarative configurations
- Existing platform configurations for macOS and Linux
- Command interface established in previous features
- Three-parameter interface (user, platform, profile) from previous refactoring

## Research Requirements

### Platform Delegation Feasibility Study

**Objective**: Determine if platform-specific flake inputs and outputs can be delegated to platform library files instead of being defined in central flake.nix.

**Current State**: flake.nix contains platform-specific logic for each platform (darwin, nixos)

**Desired State**: Platform-specific logic resides in `platform/{name}/lib/{standard-file}.nix`, automatically discovered by flake.nix

**Key Questions**:

1. Can flake.nix dynamically discover and load platform libraries from filesystem?
1. Can platform libraries define their own flake inputs (e.g., nix-darwin, nixpkgs pins)?
1. Can platform libraries export complete outputs without central orchestration knowing structure?
1. What is the performance impact of dynamic discovery vs static definitions?
1. How does this affect flake.lock and dependency management?
1. Is there a standard pattern in the Nix community for this approach?

**Decision Criteria**:

- **Feasible**: If can achieve ≥80% reduction in central flake.nix platform-specific code
- **Performance**: No measurable performance degradation (within 5%)
- **Maintainability**: Simpler to add new platforms than current approach
- **Community Alignment**: Approach aligns with Nix best practices

**Expected Outcomes**:

- Document feasibility assessment in research.md
- If feasible: Include in implementation plan
- If not feasible: Document why and keep current approach

## Out of Scope

- Adopting third-party unified configuration frameworks (evaluated and deferred)
- Remote activation over network
- Automated rollback mechanisms (handled by underlying platform capabilities)
- Standalone user environment activation (already handled by system activation)
- Build performance optimization
- Build output caching strategies
- Full implementation of platform delegation (if research shows significant complexity)

## Notes

This feature represents a significant simplification of the activation architecture by:

1. **Eliminating platform-specific knowledge requirements** from daily workflows
1. **Centralizing platform differences** to a single configuration point
1. **Enabling future platform support** with minimal code changes
1. **Maintaining backward compatibility** with existing configurations

The approach leverages the fact that compiled configuration outputs contain their own activation procedures, allowing a uniform "build then activate" pattern across all platforms instead of relying on platform-specific external management tools.
