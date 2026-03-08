# Feature Specification: Niri Family Desktop Environment

**Feature Branch**: `041-niri-family`\
**Created**: 2026-01-29\
**Status**: Draft\
**Input**: User description: "I would like a new linux family alternative to gnome for a niri-noctalia desktop shell"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure Host to Use Niri Desktop (Priority: P1)

A user wants to set up a NixOS machine with the Niri desktop environment instead of GNOME. They declare `family = ["linux", "niri"]` in their host configuration, and the system automatically installs and configures Niri compositor and supporting infrastructure.

**Why this priority**: This is the core functionality - without the ability to declare and install the Niri family, nothing else works. Users need a working desktop environment from first boot.

**Independent Test**: Can be tested by creating a host with `family = ["linux", "niri"]`, building the system, and verifying the Niri compositor launches at login.

**Acceptance Scenarios**:

1. **Given** a NixOS host configuration with `family = ["linux", "niri"]`, **When** the system is built and activated, **Then** Niri compositor is installed and configured as the default session.
1. **Given** a user logs in to a Niri-configured host, **When** the graphical session starts, **Then** the user sees a functional Niri desktop with tiling window management.
1. **Given** a host declares `family = ["linux", "niri"]`, **When** `nix flake check` is run, **Then** validation passes without errors.

______________________________________________________________________

### User Story 2 - Customize Niri Appearance (Priority: P2)

A user wants their Niri desktop to respect their appearance preferences (dark mode, fonts, wallpaper). The family should integrate with existing user configuration options for consistent theming.

**Why this priority**: While the desktop works without customization, appearance consistency improves user experience and leverages existing configuration patterns.

**Independent Test**: Can be tested by setting `user.wallpaper` and font preferences, then verifying the Niri desktop displays them correctly.

**Acceptance Scenarios**:

1. **Given** a user has configured `user.wallpaper`, **When** the Niri session starts, **Then** the configured wallpaper is displayed.
1. **Given** a user has configured `user.fonts.defaults`, **When** applications render text in the Niri session, **Then** the configured fonts are used.
1. **Given** dark mode is enabled in user preferences, **When** the Niri session starts, **Then** the desktop uses dark theming.

______________________________________________________________________

### User Story 3 - Manage Windows with Keyboard (Priority: P2)

A user wants to navigate and manage windows efficiently using keyboard shortcuts. Niri provides tiling window management with intuitive key bindings for common operations.

**Why this priority**: Keyboard-driven window management is a core value proposition of tiling compositors. Users choosing Niri expect efficient keyboard workflows.

**Independent Test**: Can be tested by opening multiple windows and using keyboard shortcuts to move, resize, and close them.

**Acceptance Scenarios**:

1. **Given** multiple windows are open, **When** the user presses the window focus shortcut, **Then** focus moves to the next window.
1. **Given** a window is focused, **When** the user presses the close window shortcut, **Then** the window closes.
1. **Given** a window is focused, **When** the user presses the move shortcut, **Then** the window moves in the tiling layout.

______________________________________________________________________

### User Story 4 - Configure Dock Favorites (Priority: P3)

A user wants quick access to their favorite applications. If they have configured `user.docked`, those applications should be accessible (via a panel/bar, as appropriate for the Niri environment).

**Why this priority**: Dock functionality is a convenience feature that builds on the core desktop. This is a lower priority enhancement.

**Independent Test**: Can be tested by configuring `user.docked` and verifying favorite applications are easily accessible.

**Acceptance Scenarios**:

1. **Given** a user has configured `user.docked = ["firefox", "ghostty"]`, **When** the Niri session starts, **Then** those applications are pinned or highlighted in an accessible location.
1. **Given** a user has not configured `user.docked`, **When** the Niri session starts, **Then** no dock/favorites are configured (graceful degradation).

______________________________________________________________________

### Edge Cases

- What happens when a user declares both `family = ["gnome", "niri"]`? (Family conflict - should fail validation with clear error)
- How does the system handle missing Niri packages in nixpkgs? (Should fail at evaluation with dependency error)
- What happens when a user's wallpaper file doesn't exist? (Should log warning and use default, matching GNOME behavior)
- How does login work without a display manager? (Niri may use greetd or similar - must have working login flow)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST install Niri compositor as the window manager when host declares `family = ["niri"]`
- **FR-002**: System MUST configure a display manager or login method compatible with Niri (such as greetd)
- **FR-003**: System MUST set up default keyboard shortcuts for window management operations (focus, move, close, resize)
- **FR-004**: System MUST integrate with user wallpaper configuration (`user.wallpaper`)
- **FR-005**: System MUST integrate with user font configuration (`user.fonts.defaults`)
- **FR-006**: System MUST support dark mode theming from user preferences
- **FR-007**: System MUST validate that conflicting desktop families are not combined (e.g., cannot use both `gnome` and `niri`)
- **FR-008**: Family MUST follow existing architecture patterns (context-segregated settings in `system/` and `user/` subdirectories)
- **FR-009**: System MUST compose correctly with the `linux` family for shared Linux settings (keyboard layout, XDG directories)

### Key Entities

- **Niri Family**: A cross-platform family configuration at `system/shared/family/niri/` following the established pattern
- **System Settings**: Desktop environment installation, display manager, compositor configuration (in `settings/system/`)
- **User Settings**: Appearance, keyboard shortcuts, wallpaper, fonts (in `settings/user/`)
- **Apps Directory**: Optional Niri-specific applications (in `app/`)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can boot into a functional Niri desktop with a single configuration change (`family = ["linux", "niri"]`)
- **SC-002**: All configured user preferences (wallpaper, fonts, dark mode) apply correctly on first login
- **SC-003**: Window management operations (focus, move, close) respond instantly to keyboard input
- **SC-004**: Build validation (`nix flake check`) passes for all host configurations using the Niri family
- **SC-005**: Users can transition from GNOME to Niri by changing one line in their host configuration

## Dependencies

- **Linux family**: Niri family should compose with `linux` family for shared Linux settings
- **Standalone home-manager**: User-level settings use home-manager (Feature 036)
- **Context-segregated settings**: Must follow Feature 039 architecture (system/ and user/ subdirectories)
- **Discovery system**: Must integrate with existing discovery.nix for module auto-loading
- **Nixpkgs Niri package**: Depends on Niri being available in nixpkgs or via overlay

## Assumptions

- Niri is available in nixpkgs or can be added via a flake input
- greetd is a suitable display manager for Niri sessions (standard for Wayland compositors)
- Users choosing Niri expect a keyboard-driven tiling workflow (minimal/no mouse dependency)
- The Niri family is mutually exclusive with GNOME family (desktop environments cannot coexist)
- Default keyboard shortcuts should follow common tiling compositor conventions
- Wayland is the display protocol (Niri is Wayland-only)
- Users will configure their preferred application launcher as an app (e.g., rofi, fuzzel, or other Wayland-compatible launcher)

## Out of Scope

- macOS/Darwin support (Niri is Linux-only, this is a NixOS family)
- X11 support (Niri is Wayland-only)
- Multi-monitor configuration beyond basic mirroring (can be added in future iterations)
- Custom Niri plugins or extensions (core functionality only)
- Migration tooling from other desktop environments (users manually change host config)
