# Feature Specification: User Wallpaper Configuration

**Feature Branch**: `033-user-wallpaper-config`\
**Created**: 2025-12-30\
**Status**: Draft\
**Input**: User description: "I would like to allow the user to specify his desktop wallpapers for darwin or gnome desktop with a file path."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Wallpaper Configuration (Priority: P1)

A user wants to set their desktop wallpaper by providing a file path to an image stored on their system. This should work consistently across both macOS (Darwin) and GNOME desktop environments.

**Why this priority**: This is the core functionality - enabling users to declaratively set their wallpaper. Without this, the feature has no value.

**Independent Test**: Can be fully tested by setting `user.wallpaper = "/path/to/image.jpg"` in user config, rebuilding the system, and verifying the wallpaper is applied on both Darwin and GNOME.

**Acceptance Scenarios**:

1. **Given** a user has an image file at `/Users/alice/Pictures/mountain.jpg` on Darwin, **When** they set `user.wallpaper = "/Users/alice/Pictures/mountain.jpg"` and rebuild, **Then** the macOS desktop wallpaper changes to that image
1. **Given** a user has an image file at `/home/bob/Pictures/beach.png` on NixOS with GNOME, **When** they set `user.wallpaper = "/home/bob/Pictures/beach.png"` and rebuild, **Then** the GNOME desktop wallpaper changes to that image
1. **Given** a user does not specify a wallpaper, **When** they rebuild the system, **Then** the system default wallpaper remains unchanged

______________________________________________________________________

### User Story 2 - Relative Path Support (Priority: P2)

A user wants to specify wallpaper paths relative to their home directory for portability across different machines.

**Why this priority**: Enhances usability by allowing portable configurations (e.g., `~/Pictures/wallpaper.jpg` works on any machine regardless of username).

**Independent Test**: Can be tested by setting `user.wallpaper = "~/Pictures/wallpaper.jpg"` and verifying it resolves correctly on both platforms.

**Acceptance Scenarios**:

1. **Given** a user has `~/Pictures/wallpaper.jpg`, **When** they set `user.wallpaper = "~/Pictures/wallpaper.jpg"`, **Then** the path resolves to `/Users/username/Pictures/wallpaper.jpg` on Darwin
1. **Given** a user has `~/Pictures/wallpaper.jpg`, **When** they set `user.wallpaper = "~/Pictures/wallpaper.jpg"`, **Then** the path resolves to `/home/username/Pictures/wallpaper.jpg` on NixOS

______________________________________________________________________

### User Story 3 - Per-Monitor Wallpapers (Priority: P3)

A user with multiple monitors wants to set different wallpapers for each display, with each monitor showing a unique image.

**Why this priority**: Essential for users with multi-monitor setups who want customized wallpapers per screen. Improves user experience for productivity and aesthetics.

**Independent Test**: Can be tested by configuring different wallpapers for each monitor and verifying each display shows its assigned wallpaper.

**Acceptance Scenarios**:

1. **Given** a user has 2 monitors on Darwin, **When** they set `user.wallpapers = [{ monitor = 0; path = "~/left.jpg"; } { monitor = 1; path = "~/right.jpg"; }]` and rebuild, **Then** monitor 0 displays left.jpg and monitor 1 displays right.jpg
1. **Given** a user has 3 monitors on GNOME, **When** they configure different wallpapers for each monitor, **Then** each monitor displays its assigned wallpaper independently
1. **Given** a user specifies both `user.wallpaper` and `user.wallpapers`, **When** they rebuild, **Then** per-monitor wallpapers override the default, with unspecified monitors using the default wallpaper

______________________________________________________________________

### Edge Cases

- What happens when the wallpaper file path doesn't exist? System should log a warning but not fail the build.
- What happens when the file exists but is not a valid image format? System should validate common formats (jpg, png, jpeg, heic, webp) and log a warning for invalid formats.
- What happens when the user doesn't have read permissions on the wallpaper file? System should log a permission error but not fail the build.
- What happens when a user switches from Darwin to GNOME (or vice versa) with the same config? The wallpaper should apply correctly on the new platform.
- What happens when the wallpaper path contains special characters or spaces? System should properly escape/quote the path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to specify wallpaper via a file path in their user configuration
- **FR-002**: System MUST support absolute file paths (e.g., `/Users/alice/wallpaper.jpg`)
- **FR-003**: System MUST support home-relative paths (e.g., `~/Pictures/wallpaper.jpg`)
- **FR-004**: System MUST apply wallpaper configuration on Darwin using macOS wallpaper tools (desktoppr or osascript)
- **FR-005**: System MUST apply wallpaper configuration on GNOME using appropriate wallpaper setter (nitrogen, feh, or dconf)
- **FR-006**: System MUST validate that the wallpaper file exists before applying configuration
- **FR-007**: System MUST validate that the wallpaper file is a supported image format (jpg, png, jpeg, heic, webp)
- **FR-008**: System MUST apply the wallpaper to all connected monitors when using single wallpaper config
- **FR-009**: System MUST support per-monitor wallpaper configuration via `user.wallpapers` list
- **FR-010**: System MUST allow fallback to default wallpaper for monitors not specified in per-monitor config
- **FR-011**: System MUST gracefully handle missing or invalid wallpaper files without failing the build
- **FR-012**: System MUST be platform-agnostic at the user config level (same syntax works on both platforms)

### Key Entities

- **User Wallpaper Configuration (Single)**: File path attribute in user configuration (`user.wallpaper`)

  - Type: String (file path)
  - Optional: Yes (users can omit to keep system defaults)
  - Validation: File existence, image format, read permissions
  - Platform support: Darwin (macOS), NixOS (GNOME)
  - Behavior: Applies same wallpaper to all monitors

- **User Wallpapers Configuration (Per-Monitor)**: List of monitor-wallpaper mappings (`user.wallpapers`)

  - Type: List of attribute sets `[{ monitor = <int>; path = <string>; }]`
  - Optional: Yes (falls back to `user.wallpaper` or system default)
  - Monitor: 0-indexed monitor number
  - Path: File path (absolute or home-relative)
  - Validation: File existence, image format, monitor index validity
  - Platform support: Darwin (macOS), NixOS (GNOME)
  - Behavior: Each monitor gets its specified wallpaper, unspecified monitors use `user.wallpaper` default

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can set a wallpaper by specifying a single file path in their user configuration
- **SC-002**: Wallpaper applies correctly on both Darwin and GNOME without platform-specific syntax
- **SC-003**: Invalid wallpaper paths log warnings but do not prevent system activation
- **SC-004**: Wallpaper persists across system reboots and re-activations
- **SC-005**: Configuration syntax is documented in CLAUDE.md with clear examples
