# Feature Specification: GNOME Dock Module

**Feature Branch**: `024-gnome-dock-module`
**Created**: 2025-12-19
**Status**: Draft
**Input**: User description: "implements docking logic for gnome shared library"
**Parent Feature**: 023-user-dock-config (Darwin implementation complete)

## Background

Feature 023 implemented dock configuration for Darwin using the `user.docked` field. This feature extends that work to GNOME desktop environments, allowing the same user configuration to work on both platforms.

The shared dock parsing library (`system/shared/lib/dock.nix`) already exists and handles syntax parsing. This feature implements the GNOME-specific resolution and activation logic.

## Problem Statement

Users want their dock configuration to work on GNOME desktop environments using the same `user.docked` syntax that works on Darwin. The GNOME implementation must:

1. Resolve application names to `.desktop` file references
1. Set the GNOME Shell favorites via gsettings/dconf
1. Handle the `<trash>` system item by creating a trash.desktop file
1. Gracefully handle GNOME-specific limitations (no separators, no folders in favorites)

______________________________________________________________________

## User Scenarios & Testing *(mandatory)*

### User Story 1 - GNOME Dock Shows User's Favorite Apps (Priority: P1)

A user with a GNOME desktop wants their favorite applications to appear in the GNOME dock (dash-to-dock or Ubuntu dock) based on their `user.docked` configuration.

**Why this priority**: Core value proposition - the same configuration works on GNOME as on Darwin.

**Independent Test**: Add `docked = ["firefox" "nautilus" "terminal"]` to user config, activate on a GNOME system, verify those apps appear as favorites.

**Acceptance Scenarios**:

1. **Given** a user configuration with `docked = ["firefox" "nautilus"]`, **When** the system is activated on GNOME, **Then** the GNOME dock displays Firefox and Nautilus as favorites
1. **Given** `docked = ["firefox" "nonexistent" "terminal"]`, **When** activated on GNOME, **Then** only Firefox and Terminal appear (nonexistent skipped)
1. **Given** `docked = []` (empty array), **When** activated on GNOME, **Then** favorites are cleared

______________________________________________________________________

### User Story 2 - Trash in GNOME Dock (Priority: P2)

A user wants the system trash to appear in their GNOME dock at a specific position.

**Why this priority**: Trash is a common dock item and GNOME requires special handling (creating a .desktop file).

**Independent Test**: Add `docked = ["firefox" "<trash>"]` and verify trash icon appears in GNOME dock.

**Acceptance Scenarios**:

1. **Given** `docked = ["firefox" "<trash>"]`, **When** activated on GNOME, **Then** Firefox and Trash appear in the dock
1. **Given** `docked = ["<trash>" "firefox"]`, **When** activated on GNOME, **Then** Trash appears before Firefox
1. **Given** no `<trash>` in docked array, **When** activated on GNOME, **Then** no trash.desktop is created

______________________________________________________________________

### User Story 3 - Graceful Handling of Unsupported Features (Priority: P2)

A user's docked configuration may include separators and folders which work on Darwin but are not supported by GNOME favorites.

**Why this priority**: Cross-platform compatibility requires graceful degradation.

**Independent Test**: Add `docked = ["firefox" "|" "terminal" "/Downloads"]` and verify only apps appear (separators and folders silently ignored).

**Acceptance Scenarios**:

1. **Given** `docked = ["firefox" "|" "terminal"]`, **When** activated on GNOME, **Then** Firefox and Terminal appear (separator ignored)
1. **Given** `docked = ["/Downloads" "firefox"]`, **When** activated on GNOME, **Then** only Firefox appears (folder ignored)
1. **Given** `docked = ["firefox" "||" "terminal"]`, **When** activated on GNOME, **Then** Firefox and Terminal appear (thick separator ignored)

______________________________________________________________________

### Edge Cases

- Application not found: `.desktop` file doesn't exist → skip silently
- Multiple .desktop files match: Use first match from search path
- Duplicate entries: Keep first occurrence only
- Unknown system items (e.g., `<launchpad>`): Skip silently (darwin-specific)
- No GNOME Shell running: Configuration still written to dconf (applies on next login)

______________________________________________________________________

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST create `system/shared/family/gnome/lib/dock.nix` with GNOME-specific resolution functions
- **FR-002**: System MUST create `system/shared/family/gnome/settings/dock.nix` to apply dock configuration
- **FR-003**: GNOME dock module MUST resolve app names to `.desktop` file names by searching XDG application directories
- **FR-004**: Module MUST search `.desktop` files in this order: `~/.local/share/applications/`, `/run/current-system/sw/share/applications/`, `/usr/share/applications/`
- **FR-005**: Resolution MUST support partial matching (e.g., "firefox" matches "firefox.desktop" or "org.mozilla.firefox.desktop")
- **FR-006**: Module MUST set GNOME favorites using dconf at path `org/gnome/shell/favorite-apps`
- **FR-007**: When `<trash>` is in docked array, module MUST create `~/.local/share/applications/trash.desktop` file
- **FR-008**: The trash.desktop file MUST use `nautilus trash://` as the Exec command
- **FR-009**: Separators (`|` and `||`) MUST be silently ignored on GNOME (not supported in favorites)
- **FR-010**: Folder entries (starting with `/`) MUST be silently ignored on GNOME (not supported in favorites)
- **FR-011**: Module MUST import and use the shared parsing library from `system/shared/lib/dock.nix`
- **FR-012**: Module MUST execute in Home Manager activation phase after packages are installed
- **FR-013**: If `user.docked` is empty or not specified, module MUST NOT modify GNOME favorites

### Key Entities

- **Desktop File**: A `.desktop` file in XDG application directories (e.g., `firefox.desktop`)
- **Favorites Array**: The gsettings/dconf array at `org.gnome.shell.favorite-apps`
- **Trash Desktop**: A custom `.desktop` file that opens the Nautilus trash view
- **XDG App Dirs**: Standard locations for .desktop files (`~/.local/share/applications`, etc.)

______________________________________________________________________

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Same `user.docked` configuration works on both Darwin and GNOME (minus platform-specific items)
- **SC-002**: 100% of resolvable applications appear in GNOME favorites in correct order
- **SC-003**: 0% of configuration errors or warnings for unsupported items (separators, folders)
- **SC-004**: Trash icon appears in GNOME dock when `<trash>` is specified
- **SC-005**: Module files stay under 200 lines each (constitutional requirement)

______________________________________________________________________

## Assumptions

- The GNOME family (`system/shared/family/gnome/`) already exists with app/ and settings/ directories
- Home Manager's dconf module is available for setting GNOME preferences
- NixOS systems with GNOME have standard XDG directory structure
- The shared dock parsing library from feature 023 is available and working
- Users on GNOME systems have Nautilus installed for trash functionality

## Out of Scope

- KDE Plasma dock support (future feature)
- GNOME extension installation (e.g., Dash-to-Dock)
- Dock position, size, or behavior settings
- Custom icons for dock items
- Folder shortcuts in GNOME dock (not supported by GNOME Shell favorites)
