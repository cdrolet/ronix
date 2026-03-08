# Feature Specification: Reusable Helper Library for Activation Scripts

**Feature Branch**: `006-reusable-helper-library`\
**Created**: 2025-10-26\
**Status**: Draft\
**Input**: User description: "Create reusable helper library for activation scripts with shared cross-platform utilities, platform-specific libraries (darwin, linux, nixos, kali), and module-specific script organization to eliminate code duplication and enable clean, declarative activation scripts"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Shared Cross-Platform Utilities (Priority: P1)

As a nix-config maintainer, I need a centralized library of pure cross-platform shell function generators (run as user, idempotent file operations, logging, conditional execution), so that common activation script patterns are consistent and maintainable across all modules without code duplication.

**Why this priority**: Foundation for all activation script work. Without shared utilities, every module duplicates common patterns, making maintenance error-prone and inconsistent.

**Independent Test**: Can be fully tested by creating a test activation script that imports the shared library and verifies each function generates correct shell code that executes identically on both darwin and linux platforms.

**Acceptance Scenarios**:

1. **Given** a module needs to execute a command as a specific user, **When** it imports `modules/shared/lib/shell.nix` and uses `mkRunAsUser`, **Then** it generates shell code that correctly executes as that user without reimplementing sudo logic
1. **Given** multiple modules need to create files idempotently, **When** they use `mkIdempotentFile` from shared library, **Then** all modules use identical implementation ensuring file is created only if missing or content differs
1. **Given** an activation script needs structured logging, **When** it uses `mkLoggedCommand`, **Then** all log messages follow consistent format with timestamp and status indicators
1. **Given** a developer adds a new activation script, **When** they review shared library documentation, **Then** they can discover and apply common patterns without duplicating code

______________________________________________________________________

### User Story 2 - Platform-Specific Helper Libraries (Priority: P1)

As a nix-config maintainer, I need platform-specific helper libraries (darwin/lib/mac.nix for macOS, linux/lib/systemd.nix for generic Linux, nixos/lib/nixos.nix for NixOS, kali/lib/kali.nix for Kali) that provide high-level declarative functions for platform-specific operations, so that activation scripts remain clean and readable while abstracting complex platform commands.

**Why this priority**: Enables implementation of unresolved migrations from spec 002 and provides clean abstractions for platform-specific activation. Essential for keeping activation scripts declarative rather than procedural.

**Independent Test**: Can be tested independently by verifying platform-specific functions (e.g., mkDockClear, mkNvramSet, mkSystemdEnable) work correctly on their target platform and produce expected system state changes.

**Acceptance Scenarios**:

1. **Given** a darwin module needs to manage Dock items, **When** it imports `modules/darwin/lib/mac.nix`, **Then** it has access to declarative functions `mkDockClear`, `mkDockAddApp`, `mkDockAddFolder`, `mkDockRestart` that generate correct dockutil commands
1. **Given** a darwin module needs to configure NVRAM, **When** it uses `mkNvramSet` from mac.nix, **Then** the function handles root privileges automatically and generates idempotent shell code
1. **Given** a linux module needs systemd service management, **When** it imports `modules/linux/lib/systemd.nix`, **Then** it has access to `mkSystemdEnable`, `mkSystemdStart`, `mkSystemdRestart` that work on any systemd-based Linux
1. **Given** a nixos module needs NixOS-specific functions, **When** it imports `modules/nixos/lib/nixos.nix`, **Then** it inherits all generic Linux functions plus NixOS-specific extensions

______________________________________________________________________

### User Story 3 - Module-Specific Script Organization (Priority: P2)

As a nix-config maintainer, I need a standard location for complex module-specific scripts (modules/<platform>/system/lib/scripts/) that are too large for inline activation scripts but not general enough for shared libraries, so that complex logic can be extracted, tested independently, and maintained separately.

**Why this priority**: Important for maintainability of complex activation workflows, but lower priority than establishing shared and platform-specific libraries which provide immediate duplication elimination.

**Independent Test**: Can be tested by extracting a complex activation script (>50 lines) to module-specific lib/scripts/ directory and verifying it can be sourced and executed from activation scripts with correct behavior.

**Acceptance Scenarios**:

1. **Given** an activation script exceeds 50 lines of inline shell code, **When** the complex logic is extracted to `modules/darwin/system/lib/scripts/dock.sh`, **Then** it can be sourced in activation scripts with `source ${./lib/scripts/dock.sh}` and functions remain accessible
1. **Given** module-specific scripts exist in lib/scripts/ directories, **When** reviewing codebase structure, **Then** it is immediately clear which scripts are module-specific versus shared platform utilities
1. **Given** a complex Dock configuration workflow, **When** implemented as bash functions in lib/scripts/dock.sh, **Then** the functions can be tested independently and activation script remains declarative by calling high-level functions
1. **Given** a new module-specific script needs to be created, **When** developer checks directory structure, **Then** the location `modules/<platform>/system/lib/scripts/` is obvious based on module scope

______________________________________________________________________

### Edge Cases

- **What happens when a shared utility function needs platform-specific behavior?**

  - Shared utilities must remain purely cross-platform
  - If behavior diverges by platform, function must be duplicated in platform-specific libraries (darwin/lib/mac.nix, linux/lib/systemd.nix)
  - Document the duplication reason in comments

- **How should module-specific scripts interact with shared libraries?**

  - Module-specific scripts can source/import both shared and platform-specific libraries
  - Shared libraries must never depend on module-specific scripts
  - Dependency direction: module scripts → platform libs → shared libs (unidirectional)

- **What if a helper function grows to require extensive platform-specific logic?**

  - Extract to appropriate platform library (darwin/lib/mac.nix, linux/lib/systemd.nix, nixos/lib/nixos.nix, kali/lib/kali.nix)
  - Remove from shared library if platform-agnostic version is not viable
  - Update all call sites to import from platform library instead

- **How to handle versioning and compatibility of helper libraries?**

  - Libraries version with repository (no separate versioning)
  - Breaking changes to library functions require updating all call sites in same commit
  - Document function signatures clearly to minimize breaking changes
  - Use deprecation warnings for gradual migrations when possible

- **What happens when NixOS and Kali both need the same Linux function?**

  - Function goes in `modules/linux/lib/systemd.nix` (generic Linux)
  - Both `nixos.nix` and `kali.nix` import and re-export it
  - No duplication between distro-specific libraries

## Requirements *(mandatory)*

### Functional Requirements

**Shared Library Structure**

- **FR-001**: System MUST create `modules/shared/lib/` directory for pure cross-platform helper libraries
- **FR-002**: System MUST provide `modules/shared/lib/default.nix` as main entry point that aggregates shell.nix
- **FR-003**: System MUST provide `modules/shared/lib/shell.nix` with cross-platform shell function generators
- **FR-004**: Shared libraries MUST be completely platform-agnostic with zero platform-specific logic or checks
- **FR-005**: All shared library functions MUST be documented with purpose, parameters, return value, and usage examples

**Linux Module Structure**

- **FR-006**: System MUST create `modules/linux/` directory as container for various Linux system type utilities
- **FR-007**: System MUST provide `modules/linux/lib/systemd.nix` for systemd-based distributions (systemd service management, firewall, user management)
- **FR-008**: Systemd library functions MUST work on any systemd-based Linux distribution (NixOS, Kali, Ubuntu, Debian, etc.)
- **FR-009**: Linux module MAY contain additional library files for other init systems in the future (e.g., openrc.nix, runit.nix, sysvinit.nix)
- **FR-010**: All linux library files MUST import and use shared library functions where applicable
- **FR-011**: Currently only systemd-based distributions are defined (NixOS and Kali)

**Darwin Platform Library**

- **FR-012**: System MUST create `modules/darwin/lib/mac.nix` for macOS-specific activation helpers
- **FR-013**: Darwin library MUST provide Dock management functions: mkDockClear, mkDockAddApp, mkDockAddFolder, mkDockAddSpacer, mkDockAddSmallSpacer, mkDockRestart
- **FR-014**: Darwin library MUST provide NVRAM functions: mkNvramSet, mkNvramGet with automatic root privilege handling
- **FR-015**: Darwin library MUST provide power management functions: mkPmsetSet supporting per-source settings (battery, AC, UPS)
- **FR-016**: Darwin library MUST provide firewall functions: mkFirewallEnable, mkFirewallSetStealthMode, mkFirewallAllowSigned
- **FR-017**: Darwin library MUST provide LaunchAgent/Daemon functions: mkLoadLaunchAgent, mkLoadLaunchDaemon
- **FR-018**: Darwin library MUST import and use shared library functions where applicable

**NixOS Platform Library**

- **FR-019**: System MUST create `modules/nixos/lib/nixos.nix` for NixOS-specific activation helpers
- **FR-020**: NixOS library MUST import `modules/linux/lib/systemd.nix` and re-export all systemd-based functions
- **FR-021**: NixOS library MUST extend systemd library with NixOS-specific functions (channel management, generation cleanup)
- **FR-022**: NixOS library MUST NOT duplicate any functionality available in linux/lib/systemd.nix

**Kali Linux Platform Library**

- **FR-023**: System MUST support future `modules/kali/lib/kali.nix` for Kali Linux-specific helpers
- **FR-024**: Kali library MUST import `modules/linux/lib/systemd.nix` and re-export all systemd-based functions
- **FR-025**: Kali library MUST extend systemd library with Kali-specific functions (apt repository setup, metapackage installation, pentest tools)
- **FR-026**: Kali library MUST NOT duplicate any functionality available in linux/lib/systemd.nix

**Module-Specific Scripts**

- **FR-027**: System MUST support `modules/<platform>/system/lib/scripts/` directories for module-specific bash scripts
- **FR-028**: Scripts exceeding 50 lines SHOULD be extracted to module-specific lib/scripts/ directory
- **FR-029**: Module-specific scripts MUST include header comments explaining purpose, parameters, and usage
- **FR-030**: Module-specific scripts CAN source both shared and platform-specific libraries

**Shell Function Generators (modules/shared/lib/shell.nix)**

- **FR-031**: shell.nix MUST provide `mkRunAsUser` for executing commands as specific user
- **FR-032**: shell.nix MUST provide `mkIdempotentFile` for safe file creation (create only if missing or content differs)
- **FR-033**: shell.nix MUST provide `mkIdempotentDir` for safe directory creation with ownership and permissions
- **FR-034**: shell.nix MUST provide `mkLoggedCommand` for consistent structured logging with timestamps and status
- **FR-035**: shell.nix MUST provide `mkConditional` for conditional command execution
- **FR-036**: shell.nix MUST provide `mkKillProcess` for safe process termination with existence check

**Library Import and Dependency Flow**

- **FR-037**: Platform libraries MUST import shared library using relative path `../../shared/lib`
- **FR-038**: Distro libraries (nixos, kali) MUST import linux library using relative path `../../linux/lib/systemd.nix`
- **FR-039**: Dependency flow MUST be unidirectional: module scripts → platform libs → linux libs → shared libs
- **FR-040**: Shared libraries MUST NOT import or depend on platform-specific or module-specific code

**Idempotency and Safety**

- **FR-041**: All helper functions generating activation scripts MUST produce idempotent shell code (safe to run multiple times)
- **FR-042**: Functions requiring root privileges MUST document this requirement clearly
- **FR-043**: Functions modifying system state MUST check current state before making changes when possible

### Key Entities

- **Shared Library**: Pure cross-platform helper functions in `modules/shared/lib/` (shell.nix, default.nix)
- **Linux Module**: Container directory `modules/linux/` for various Linux system type utilities (currently systemd-based, may include openrc, runit, sysvinit in future)
- **Systemd Library**: Functions for systemd-based distributions in `modules/linux/lib/systemd.nix`
- **Platform Library**: Platform-specific helper functions (darwin/lib/mac.nix, nixos/lib/nixos.nix, kali/lib/kali.nix)
- **Module Script**: Complex bash script (>50 lines) extracted to `modules/<platform>/system/lib/scripts/`
- **Activation Helper**: Nix function that generates shell script text for system.activationScripts or home.activation
- **Shell Generator**: Nix function in shell.nix that produces bash code strings

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Shared library (`modules/shared/lib/`) exists with 6 core cross-platform functions (mkRunAsUser, mkIdempotentFile, mkIdempotentDir, mkLoggedCommand, mkConditional, mkKillProcess)
- **SC-002**: Systemd library (`modules/linux/lib/systemd.nix`) exists with at least 10 systemd-based functions (systemd service management, firewall, user management)
- **SC-003**: Darwin library (`modules/darwin/lib/mac.nix`) exists with at least 15 macOS-specific functions covering Dock, NVRAM, power, firewall, LaunchAgent
- **SC-004**: NixOS library (`modules/nixos/lib/nixos.nix`) imports all systemd-based functions and adds NixOS-specific extensions
- **SC-005**: Zero code duplication across activation scripts for common patterns (all use shared/platform libraries)
- **SC-006**: All library functions have documentation with purpose, parameters, return value, and usage examples
- **SC-007**: At least 3 existing activation scripts refactored to use new libraries demonstrating value and patterns
- **SC-008**: Constitution updated with helper library organization standards and activation script best practices
- **SC-009**: All 5 unresolved migration items from spec 002 have corresponding helper functions enabling implementation (NVRAM, power management, firewall, security, Borders service)

## Assumptions

- Activation scripts run as root in nix-darwin (verified by nix-darwin documentation)
- User-specific commands require `sudo -u` wrapper or equivalent privilege escalation
- All activation scripts must be idempotent (can run multiple times safely without cumulative effects)
- Platform detection available via `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` at build time
- All generated shell code must be valid POSIX-compatible bash
- Libraries are imported and evaluated at build time, not runtime
- dockutil package available in nixpkgs for Dock management on darwin
- systemd is standard service manager on target Linux distributions (NixOS, Kali)

## Dependencies

- nix-darwin activation script system (`system.activationScripts`)
- home-manager activation system (`home.activation`) for user-level scripts
- Existing module structure from spec 002 (darwin/system/, nixos/system/)
- Understanding of macOS system tools: defaults, nvram, pmset, socketfilterfw, dockutil, launchctl
- Understanding of Linux system tools: systemctl, firewall-cmd, ufw, apt-get
- Access to test activation scripts on darwin, nixos, and future kali platforms
- nixpkgs package availability for platform-specific tools

## Out of Scope

- Implementing all unresolved migrations from spec 002 (this spec only creates helper functions, actual migration is separate work)
- Automated testing framework for activation scripts (could be future enhancement)
- Automatic migration/refactoring of existing activation scripts (manual refactoring required)
- GUI tools or interactive interfaces for activation script development
- Runtime library loading or dynamic function discovery (all imports are build-time static)
- Backwards compatibility with external codebases (libraries are internal to nix-config only)
- Creating wrappers for every possible system command (only common patterns and unresolved migration needs)
- Documenting every macOS defaults domain or Linux systemd service (only patterns and high-level helpers)

## Related Specifications

- **002-darwin-system-restructure**: This spec provides helpers for unresolved migrations identified in spec 002
- **005-nix-config-documentation**: Documentation work will include comprehensive library guides and examples
