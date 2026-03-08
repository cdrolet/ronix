# Feature Specification: Dotfiles to Nix Configuration Migration

**Feature Branch**: `001-dotfiles-migration`
**Created**: 2025-10-21
**Status**: Draft
**Input**: User description: "you need to do your best to convert my dotfile repo from ~/project/dotfile into this nix-config repo. include install script for both mac and nixos. use Determinate Systems installer for macOS in the install script."

## User Scenarios & Testing

### User Story 1 - Initial System Setup from Scratch (Priority: P1)

A user with a fresh macOS or NixOS installation wants to set up their complete development environment including all applications, configurations, and tools in a single command.

**Why this priority**: This is the primary use case - getting a new machine configured quickly and reliably. Without this, the migration has no value.

**Independent Test**: Can be fully tested by running the installation script on a fresh VM or new machine and verifying all tools and configurations are present and working.

**Acceptance Scenarios**:

1. **Given** a fresh macOS system without any configuration, **When** user runs the installation script, **Then** system installs all package managers, development tools, applications, shell configurations, and dotfiles with no manual intervention required
1. **Given** a fresh NixOS system, **When** user runs the system rebuild command, **Then** system configures all services, users, applications, and home environments declaratively
1. **Given** the installation completes successfully, **When** user opens a new terminal, **Then** shell prompt displays correctly with all aliases, functions, and environment variables configured
1. **Given** the installation completes, **When** user checks installed applications, **Then** all development tools (editors, terminals, CLI tools) are available and configured

______________________________________________________________________

### User Story 2 - Configuration Updates and Synchronization (Priority: P2)

A user makes changes to their configuration files and wants to apply those changes to their system, ensuring consistency across multiple machines.

**Why this priority**: Once the initial setup works, users need to maintain and update their configurations. This enables the declarative workflow that Nix provides.

**Independent Test**: Can be tested by modifying configuration files, running the update command, and verifying changes are applied without breaking existing functionality.

**Acceptance Scenarios**:

1. **Given** user modifies a configuration file in the repository, **When** user runs the update command, **Then** changes are applied to the system and take effect immediately
1. **Given** user has multiple machines with the same configuration, **When** user pulls configuration changes and rebuilds, **Then** all machines reflect the same configuration state
1. **Given** a configuration change causes an error, **When** the build fails, **Then** system provides clear error messages indicating what failed and why
1. **Given** user wants to test a configuration change, **When** user builds without switching, **Then** system validates the configuration without applying it

______________________________________________________________________

### User Story 3 - Cross-Platform Configuration Management (Priority: P3)

A user maintains both macOS and NixOS machines and wants to share common configurations while supporting platform-specific settings.

**Why this priority**: Enables efficient multi-platform workflow, but the system is still useful on a single platform.

**Independent Test**: Can be tested by verifying the same configuration repository can build successfully on both macOS and NixOS, with platform-specific features working correctly on each.

**Acceptance Scenarios**:

1. **Given** a configuration module used on both platforms, **When** system builds on macOS, **Then** macOS-specific settings are applied and NixOS-specific settings are ignored
1. **Given** a configuration module used on both platforms, **When** system builds on NixOS, **Then** NixOS-specific settings are applied and macOS-specific settings are ignored
1. **Given** user adds a platform-specific tool, **When** configuration builds on the correct platform, **Then** tool is installed and configured properly
1. **Given** user adds a platform-specific tool, **When** configuration builds on the wrong platform, **Then** system skips the tool without errors

______________________________________________________________________

### User Story 4 - System Rollback and Recovery (Priority: P2)

A user encounters issues after a configuration update and needs to quickly rollback to a previous working state.

**Why this priority**: Critical for confidence in making changes - knowing you can always go back prevents fear of experimentation.

**Independent Test**: Can be tested by applying a breaking change, rolling back to previous generation, and verifying system returns to working state.

**Acceptance Scenarios**:

1. **Given** user has a working configuration, **When** user applies a new configuration that breaks something, **Then** user can select a previous generation at boot and system functions normally
1. **Given** a configuration causes boot issues on NixOS, **When** user selects previous generation from boot menu, **Then** system boots successfully with old configuration
1. **Given** user wants to compare configurations, **When** user lists available generations, **Then** system shows all previous configurations with timestamps
1. **Given** user identifies a working configuration, **When** user rolls back to that generation, **Then** all settings return to that exact state

______________________________________________________________________

### Edge Cases

- What happens when a tool or application is not available on one platform but is specified in shared configuration?
- How does the system handle conflicts between existing manually-installed tools and Nix-managed tools?
- What happens when secret files (API keys, credentials) are referenced but don't exist yet?
- How does the system handle partial installation failures (some packages install, others fail)?
- What happens when the system runs out of disk space during installation?
- How does the system handle network interruptions during package downloads?
- What happens when a user runs the installation on a system with existing dotfiles?
- How does the system handle incompatible configurations between different Nix/nixpkgs versions?

## Requirements

### Functional Requirements

#### Installation and Setup

- **FR-001**: System MUST provide a single command installation script for macOS using Determinate Systems Nix installer
- **FR-002**: System MUST provide installation instructions for NixOS using standard NixOS installation workflow
- **FR-003**: System MUST detect the current platform (macOS or NixOS) and apply appropriate configurations
- **FR-004**: System MUST preserve existing dotfiles by creating backups before applying new configurations
- **FR-005**: System MUST install all development tools, CLI utilities, and applications specified in the current dotfiles repository
- **FR-006**: System MUST configure shell environment (zsh with modular configuration system) identically to current dotfiles

#### Directory Structure and Organization

- **FR-007**: System MUST follow the hierarchical directory layout defined in the project constitution: `common/`, `hosts/`, `modules/core/`, `modules/optional/`, `secrets/`
- **FR-008**: System MUST use flakes as the entry point with `flake.nix` at repository root
- **FR-009**: System MUST separate host-specific configurations in `hosts/` directory with subdirectories per machine
- **FR-010**: System MUST separate user configurations using Home Manager in `common/users/` for shared settings
- **FR-011**: System MUST organize modules by function: core modules applied universally, optional modules applied selectively

#### Configuration Migration

- **FR-012**: System MUST migrate all existing tool configurations to Nix-declarative equivalents: ghostty, starship, atuin, aerospace, lazygit, helix, zed, bat
- **FR-013**: System MUST preserve all custom zsh modules and maintain the numbered module loading system (10-90)
- **FR-014**: System MUST migrate zsh plugin management from git submodules to Nix packages
- **FR-015**: System MUST maintain all shell aliases, functions, and environment variables from current dotfiles
- **FR-016**: System MUST configure git globally with current settings (.gitconfig, .gitignore_global)

#### Application Management

- **FR-017**: System MUST install all CLI tools currently managed by Homebrew: zoxide, atuin, ripgrep, fd, bat, eza, delta, procs, xh, helix, lazygit
- **FR-018**: System MUST install all development language runtimes: Node.js, Python, Go, Rust, Ruby
- **FR-019**: System MUST install all GUI applications currently installed via Homebrew Cask on macOS
- **FR-020**: System MUST use Home Manager for user-level package installation and dotfile management
- **FR-021**: System MUST handle platform-specific applications: aerospace, borders on macOS only

#### Secrets Management

- **FR-022**: System MUST integrate sops-nix for encrypted secrets management
- **FR-023**: System MUST support age encryption for sensitive files
- **FR-024**: System MUST never commit unencrypted secrets to version control
- **FR-025**: System MUST document secrets management workflow for adding new secrets

#### Update and Maintenance

- **FR-026**: System MUST support updating all packages with a single command
- **FR-027**: System MUST allow testing configuration changes before applying them
- **FR-028**: System MUST provide rollback mechanism to previous configurations
- **FR-029**: System MUST implement automatic garbage collection to manage disk space
- **FR-030**: System MUST maintain pinned dependency versions in `flake.lock` for reproducibility

#### Cross-Platform Support

- **FR-031**: System MUST use conditional logic to apply platform-specific configurations
- **FR-032**: System MUST share common configurations across macOS and NixOS without code duplication
- **FR-033**: System MUST document which features are platform-specific and which are cross-platform
- **FR-034**: System MUST gracefully skip platform-specific tools when building on incompatible platforms

#### Documentation

- **FR-035**: System MUST provide comprehensive installation instructions for both macOS and NixOS
- **FR-036**: System MUST document the directory structure and module organization
- **FR-037**: System MUST include usage examples for common tasks: adding applications, modifying configurations, updating system
- **FR-038**: System MUST document migration path from current dotfiles to Nix-based configuration
- **FR-039**: System MUST document rollback and recovery procedures

### Key Entities

- **Host Configuration**: Represents a physical or virtual machine with specific hardware and system requirements, stored in `hosts/<hostname>/`
- **User Configuration**: Represents a user account with personal preferences, applications, and dotfiles, managed via Home Manager
- **Module**: A self-contained, reusable configuration unit that can be enabled/disabled, categorized as core (universal) or optional (selective)
- **Package Set**: Collection of applications and tools to be installed, differentiated by platform availability
- **Secret**: Encrypted sensitive data (API keys, credentials, SSH keys) managed via sops-nix
- **Flake**: The root configuration file (`flake.nix`) defining all inputs, outputs, and system builds
- **Generation**: A versioned snapshot of system configuration that can be rolled back to

## Success Criteria

### Measurable Outcomes

- **SC-001**: User can run a single installation command on fresh macOS and have a fully configured development environment in under 30 minutes
- **SC-002**: User can run NixOS rebuild and have all applications, services, and configurations applied in under 15 minutes
- **SC-003**: All 60+ applications and tools from current dotfiles are successfully migrated and functional in Nix configuration
- **SC-004**: User can modify any configuration file and apply changes with a single command, seeing results immediately
- **SC-005**: System builds successfully on both macOS and NixOS from the same repository without errors
- **SC-006**: User can rollback to any previous configuration generation in under 2 minutes
- **SC-007**: Shell startup time remains under 200ms after migration to Nix-managed configuration
- **SC-008**: 100% of custom shell functions, aliases, and environment variables work identically to current dotfiles
- **SC-009**: All editor configurations (Helix, Zed) work identically to current dotfiles setup
- **SC-010**: User can add a new machine configuration in under 10 minutes by copying and modifying an existing host config
- **SC-011**: Secrets are never exposed in version control, verified by pre-commit hooks or CI checks
- **SC-012**: System provides clear error messages for 90% of common configuration mistakes

## Assumptions

1. **Nix Knowledge**: User has basic understanding of Nix concepts (derivations, profiles, generations) or is willing to learn
1. **macOS Version**: User is running macOS 13 (Ventura) or later for compatibility with latest tools
1. **Disk Space**: User has at least 20GB free disk space for Nix store and package downloads
1. **Network Access**: User has stable internet connection for downloading packages and dependencies
1. **Git Repository**: User will maintain this nix-config in a git repository for version control
1. **Single User**: Initial implementation focuses on single-user configurations (multi-user can be added later)
1. **English Locale**: Documentation and error messages are in English
1. **Standard Filesystem**: User is using standard filesystem layout (APFS on macOS, ext4/btrfs on NixOS)
1. **No Existing Nix**: If user has existing Nix installation, they're willing to reinstall using Determinate Systems installer for consistency
1. **Tool Availability**: All current tools in dotfiles repository have Nix packages available or can be packaged
