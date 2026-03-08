# Feature Specification: User Font Configuration

**Feature Branch**: `030-user-font-config`\
**Created**: 2025-12-26\
**Status**: Draft\
**Input**: User description: "user can now specify fonts to be installed in their user config with default, packages (public), and repositories (private). Configure default font on desktop environments."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare Fonts in User Config (Priority: P1)

A user wants to declare which fonts should be installed on their system through their user configuration. They specify a default font for desktop use and a list of package fonts from nixpkgs.

**Why this priority**: Core functionality that enables users to manage fonts declaratively. Without this, no font management is possible.

**Independent Test**: Can be fully tested by adding a `fonts` block to user config, running activation, and verifying fonts are installed and available to applications.

**Acceptance Scenarios**:

1. **Given** a user config with `fonts.default = "fira-code"`, **When** the system activates, **Then** the Fira Code font is installed and available system-wide.
1. **Given** a user config with `fonts.packages = ["source-code-pro", "jetbrains-mono"]`, **When** the system activates, **Then** both fonts are installed and available.
1. **Given** a user specifies a font name that doesn't exist in nixpkgs, **When** the system activates, **Then** the invalid font is skipped with a warning and other valid fonts are still installed.
1. **Given** a user config with no `fonts` block, **When** the system activates, **Then** no fonts are installed and the system uses platform defaults.

______________________________________________________________________

### User Story 2 - Install Private Fonts from Git Repositories (Priority: P2)

A user with access to private font repositories wants those proprietary fonts automatically downloaded and installed. Users without the deploy key should have this step gracefully skipped.

**Why this priority**: Extends font management to proprietary/private fonts. Depends on US1 being functional first.

**Independent Test**: Can be tested by configuring `sshKeys.fonts` secret, adding repositories to config, running activation, and verifying private fonts are cloned and installed.

**Acceptance Scenarios**:

1. **Given** a user has `sshKeys.fonts = "<secret>"` configured and `fonts.repositories` defined, **When** the system activates, **Then** fonts from the private repositories are cloned to a local directory and installed.
1. **Given** a user has `fonts.repositories` defined but NO `sshKeys.fonts` configured, **When** the system activates, **Then** the private font download is skipped silently without errors.
1. **Given** a user has the deploy key but a repository is unreachable, **When** the system activates, **Then** a warning is logged but activation continues without failure.
1. **Given** the private fonts were previously cloned, **When** the system activates again, **Then** the repository is updated (git pull) rather than re-cloned.
1. **Given** a user has multiple repositories in `fonts.repositories`, **When** the system activates, **Then** all repositories are cloned/updated and their fonts installed.

______________________________________________________________________

### User Story 3 - Configure Default Desktop Font (Priority: P3)

On desktop environments (macOS or GNOME), the user's specified default font should be configured as the system/interface font automatically.

**Why this priority**: Enhances user experience by applying the default font to the desktop. Depends on US1 for font installation.

**Independent Test**: Can be tested by setting `fonts.default`, activating on a desktop environment, and verifying system font settings reflect the choice.

**Acceptance Scenarios**:

1. **Given** a user on macOS with `fonts.default = "berkeleymono-medium"`, **When** the system activates, **Then** the macOS system font preferences are updated to use Berkeley Mono.
1. **Given** a user on GNOME with `fonts.default = "fira-code"`, **When** the system activates, **Then** GNOME's monospace font setting is configured to Fira Code.
1. **Given** a user on a headless/server system with `fonts.default` set, **When** the system activates, **Then** the font is installed but no desktop configuration is attempted.
1. **Given** a user specifies a default font that isn't installed, **When** the system activates, **Then** the desktop font configuration is skipped with a warning.

______________________________________________________________________

### User Story 4 - Apps Reference Default Font (Priority: P4)

Application modules can reference the user's default font setting to provide a consistent font experience across all apps without requiring per-app configuration.

**Why this priority**: Convenience feature that builds on US1. Apps work without this, but it improves consistency.

**Independent Test**: Can be tested by setting `fonts.default`, checking that terminal/editor apps use that font.

**Acceptance Scenarios**:

1. **Given** a user has `fonts.default = "fira-code"` and uses a terminal app, **When** the system activates, **Then** the terminal app is configured to use Fira Code.
1. **Given** a user has no `fonts.default` set and uses a terminal app, **When** the system activates, **Then** the terminal app uses its own default (e.g., "monospace").
1. **Given** an app explicitly overrides the font, **When** the system activates, **Then** the app's explicit setting takes precedence over `fonts.default`.

______________________________________________________________________

### Edge Cases

- What happens when a font name in `packages` matches one from a private repo? (Private repo version takes precedence)
- How does the system handle font name variations? (Use lowercase-hyphenated canonical names for packages)
- What happens if a private repo contains non-font files? (Only .ttf, .otf, .woff, .woff2 files are installed)
- What happens if `fonts.default` is set but not in `packages` list? (Default font is automatically included for installation)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST support a `fonts` configuration block in user config with `default`, `packages`, and `repositories` fields
- **FR-002**: System MUST install all valid fonts specified in `fonts.packages` array
- **FR-003**: System MUST automatically include `fonts.default` in the installation list if not already present
- **FR-004**: System MUST skip invalid/unknown font names with a warning rather than failing
- **FR-005**: System MUST clone private font repositories when `sshKeys.fonts` secret is configured
- **FR-006**: System MUST skip private font repository download silently when deploy key is not configured
- **FR-007**: System MUST install fonts from private repositories after successful clone/update
- **FR-008**: System MUST configure desktop default font on macOS when `fonts.default` is set
- **FR-009**: System MUST configure GNOME monospace font when `fonts.default` is set and GNOME family is active
- **FR-010**: System MUST use the deploy key stored at `~/.ssh/id_fonts` for private repository access
- **FR-011**: System MUST support font file formats: .ttf, .otf, .woff, .woff2
- **FR-012**: System MUST update (pull) existing private font repositories rather than re-clone on subsequent activations
- **FR-013**: System MUST support multiple repositories in `fonts.repositories` array
- **FR-014**: Application modules MUST be able to reference `config.user.fonts.default` for consistent font configuration
- **FR-015**: Applications MUST fall back to a sensible default (e.g., "monospace") when `fonts.default` is not set

### Key Entities

- **Font Configuration**: User-declared font preferences with structure:
  ```
  fonts = {
    default = "font-name";
    packages = ["font1", "font2", ...];
    repositories = ["git@github.com:user/repo.git", ...];
  }
  ```
- **Deploy Key**: SSH private key (`sshKeys.fonts`) enabling read-only access to private font repositories
- **Private Font Repository**: Git repository containing proprietary font files
- **Font Cache Directory**: Local directory where private fonts are cloned and stored

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can declare fonts in config and have them installed in under 60 seconds during activation
- **SC-002**: 100% of valid font names from nixpkgs are successfully installed
- **SC-003**: Users without deploy key experience zero errors or warnings related to private fonts
- **SC-004**: Private font repositories are cloned/updated in under 30 seconds on standard network
- **SC-005**: Default font is applied to desktop environment immediately after activation (no logout required for GNOME, may require logout on macOS)
- **SC-006**: Invalid font names produce clear warning messages identifying the problematic font

## Assumptions

- Font names in `packages` array use lowercase-hyphenated format matching nixpkgs naming conventions
- Private repositories use SSH URL format (git@github.com:user/repo.git)
- Home Manager's font installation mechanism is sufficient for cross-platform support
- macOS font configuration can be done via defaults commands or similar declarative approach
- GNOME font configuration uses gsettings/dconf as established in existing GNOME family modules
- The deploy key is shared across all repositories in the `repositories` array
