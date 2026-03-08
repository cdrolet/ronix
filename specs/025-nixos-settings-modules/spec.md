# Feature Specification: NixOS Settings Modules

**Feature Branch**: `025-nixos-settings-modules`
**Created**: 2025-12-20
**Status**: Draft
**Input**: Create NixOS settings modules inspired by Darwin settings structure, with GNOME-specific settings in shared/family/gnome/settings

## Background

The Darwin platform has a comprehensive set of system settings modules in `system/darwin/settings/` covering keyboard, locale, security, power, network, UI, and more. These modules use an auto-discovery pattern via `default.nix` that automatically imports all `.nix` files in the directory.

This feature brings NixOS to parity by creating equivalent settings modules that:

1. Mirror applicable Darwin settings for cross-platform consistency
1. Follow NixOS-specific best practices
1. Place desktop-specific settings (GNOME) in `system/shared/family/gnome/settings/`
1. Use the same auto-discovery pattern for maintainability

______________________________________________________________________

## User Scenarios & Testing *(mandatory)*

### User Story 1 - NixOS Core System Settings (Priority: P1)

A system administrator wants NixOS machines to have sensible default settings for security, networking, and system behavior that mirror the Darwin configuration philosophy.

**Why this priority**: Core system settings are foundational and apply to all NixOS installations regardless of desktop environment.

**Independent Test**: Deploy a minimal NixOS configuration with the settings modules and verify security, network, and system defaults are applied correctly.

**Acceptance Scenarios**:

1. **Given** a NixOS host configuration, **When** the system is built, **Then** security defaults (firewall, sudo, etc.) are applied
1. **Given** a NixOS host configuration, **When** the system is built, **Then** locale and timezone settings from user config are applied
1. **Given** a NixOS host configuration, **When** the system is built, **Then** keyboard repeat and behavior settings are configured

______________________________________________________________________

### User Story 2 - Linux Keyboard Layout Matching Mac (Priority: P1)

A user switching between macOS and Linux wants the same keyboard layout behavior, with modifier keys (Ctrl, Alt, Super) matching the Mac layout for muscle memory consistency.

**Why this priority**: Keyboard layout is fundamental to user experience and affects every interaction with the system.

**Independent Test**: Deploy a Linux host with `family = ["linux"]`, verify modifier keys are remapped to match Mac layout.

**Acceptance Scenarios**:

1. **Given** a host with `family = ["linux"]`, **When** activated, **Then** keyboard modifier keys are remapped to match Mac layout
1. **Given** a Linux system with Mac-style keyboard, **When** user presses Super key, **Then** it behaves like Command on Mac
1. **Given** a Linux system, **When** user types common shortcuts (copy, paste, etc.), **Then** they work with Mac-like key positions

______________________________________________________________________

### User Story 3 - GNOME Desktop Settings (Priority: P2)

A user with a GNOME desktop wants consistent UI preferences, keyboard shortcuts, and desktop behavior that work across any Linux distribution using GNOME.

**Why this priority**: GNOME settings are shared across platforms and belong in the family/ directory for reuse.

**Independent Test**: Deploy a GNOME host, verify dconf settings for UI preferences, keyboard, and desktop behavior are applied.

**Acceptance Scenarios**:

1. **Given** a host with `family = ["gnome"]`, **When** activated, **Then** GNOME UI settings (dark mode, fonts, animations) are applied
1. **Given** a host with `family = ["gnome"]`, **When** activated, **Then** GNOME keyboard settings (shortcuts, input sources) are configured
1. **Given** a host with `family = ["gnome"]`, **When** activated, **Then** GNOME power settings (screen timeout, suspend) are applied

______________________________________________________________________

### User Story 4 - Auto-Discovery Pattern (Priority: P1)

A developer wants to add new settings modules without manually updating import lists, following the same pattern used in Darwin settings.

**Why this priority**: Maintainability is critical - the pattern enables easy extension without configuration overhead.

**Independent Test**: Add a new `.nix` file to the settings directory and verify it's automatically imported on next build.

**Acceptance Scenarios**:

1. **Given** a new settings file in `system/nixos/settings/`, **When** the flake is built, **Then** the module is automatically imported
1. **Given** a new settings file in `system/shared/family/gnome/settings/`, **When** a GNOME host is built, **Then** the module is automatically imported
1. **Given** `default.nix` in settings directories, **When** it uses discovery, **Then** circular imports are prevented

______________________________________________________________________

### Edge Cases

- What happens when a setting conflicts between NixOS and GNOME modules? The more specific (GNOME) should take precedence via `lib.mkDefault`.
- How does the system handle settings that don't apply (e.g., GNOME settings on a server)? Settings are only imported when family includes "gnome".
- What if a user wants to override a default setting? Use `lib.mkForce` in their host configuration.

______________________________________________________________________

## Requirements *(mandatory)*

### Functional Requirements

**NixOS Core Settings (system/nixos/settings/)**:

- **FR-001**: System MUST create `system/nixos/settings/default.nix` with auto-discovery pattern matching Darwin
- **FR-002**: System MUST create `system/nixos/settings/security.nix` with firewall enabled by default, sudo configuration
- **FR-003**: System MUST create `system/nixos/settings/locale.nix` reading `user.timezone` and `user.locale` from user config
- **FR-004**: System MUST create `system/nixos/settings/keyboard.nix` with keyboard repeat settings matching Darwin values
- **FR-005**: System MUST create `system/nixos/settings/network.nix` with NetworkManager and sensible defaults
- **FR-006**: System MUST create `system/nixos/settings/system.nix` with boot loader, Nix settings, and garbage collection

**Linux Family Settings (system/shared/family/linux/settings/)**:

- **FR-007**: System MUST create `system/shared/family/linux/settings/default.nix` with auto-discovery pattern
- **FR-008**: System MUST create `system/shared/family/linux/settings/keyboard.nix` with Mac-style keyboard layout remapping

**GNOME Family Settings (system/shared/family/gnome/settings/)**:

- **FR-009**: System MUST update `system/shared/family/gnome/settings/default.nix` to use auto-discovery pattern
- **FR-010**: System MUST create `system/shared/family/gnome/settings/ui.nix` with dark mode, font rendering, animations
- **FR-011**: System MUST create `system/shared/family/gnome/settings/keyboard.nix` with GNOME keyboard shortcuts and input sources
- **FR-012**: System MUST create `system/shared/family/gnome/settings/power.nix` with screen timeout and suspend settings

**Cross-Platform Consistency**:

- **FR-013**: Keyboard repeat rate settings MUST use equivalent values to Darwin (KeyRepeat=2, InitialKeyRepeat=10)
- **FR-014**: Locale settings MUST read from the same `user.*` fields as Darwin (timezone, locale, languages, keyboardLayout)
- **FR-015**: All settings modules MUST use `lib.mkDefault` to allow user overrides
- **FR-016**: Linux keyboard layout MUST remap modifier keys to match Mac layout (Super as Command equivalent)

### Key Entities

- **Settings Module**: A `.nix` file containing related system configuration options
- **Auto-Discovery**: Pattern that automatically imports all `.nix` files in a directory
- **Family Settings**: Cross-platform settings shared via the family/ directory structure
- **dconf Settings**: GNOME configuration stored in the dconf database

______________________________________________________________________

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: NixOS hosts build successfully with all new settings modules
- **SC-002**: 100% of applicable Darwin settings have NixOS equivalents documented
- **SC-003**: GNOME hosts have UI, keyboard, and power settings applied via dconf
- **SC-004**: Adding a new settings file requires 0 manual import changes (auto-discovery works)
- **SC-005**: All modules stay under 200 lines (constitutional requirement)
- **SC-006**: `nix flake check` passes with no errors

______________________________________________________________________

## Assumptions

- NixOS hosts will use Home Manager for user-specific settings
- The existing `user.*` options (timezone, locale, languages, keyboardLayout) work on NixOS
- GNOME hosts will have the dconf Home Manager module available
- NetworkManager is the preferred network management solution for desktop NixOS

## Out of Scope

- KDE Plasma or other desktop environment settings (future feature)
- Server-specific settings (no desktop environment)
- Hardware-specific settings (graphics drivers, etc.)
- NixOS installation/partitioning configuration
