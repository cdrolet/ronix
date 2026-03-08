# Feature Specification: Darwin Apps Migration - Complete App Modules

**Feature Branch**: `012-darwin-apps-migration`\
**Created**: 2025-11-01\
**Status**: Draft\
**Input**: User description: "continue to migrate old structure to the new one. migrate remaining app for darwin and include just.nix in the app dev category."

## User Scenarios & Testing

### User Story 1 - Complete Darwin Window Management Apps (Priority: P1)

As a macOS user, I need aerospace (tiling window manager) and borders (active window highlighter) to be fully functional with package installation and configuration, so that my window management workflow works immediately after system installation without manual setup.

**Why this priority**: These apps are already partially migrated with config files but missing package installation, making them non-functional. Completing them is the highest priority to make existing configurations actually work.

**Independent Test**: Can be fully tested by importing aerospace.nix and borders.nix in a user config, rebuilding the system, and verifying both apps are installed via Homebrew and their configurations are applied correctly.

**Acceptance Scenarios**:

1. **Given** a fresh macOS system with aerospace.nix imported, **When** system rebuilds, **Then** aerospace is installed via Homebrew and the toml configuration file is created at ~/.config/aerospace/aerospace.toml
1. **Given** borders.nix imported alongside aerospace.nix, **When** system rebuilds, **Then** borders (JankyBorders) is installed via Homebrew tap FelixKratz/formulae
1. **Given** both apps are configured, **When** user logs in, **Then** aerospace tiling works with configured keybindings (cmd+h/j/k/l for focus) and borders highlights the active window
1. **Given** borders configuration with custom colors, **When** user switches windows, **Then** active window shows colored border as configured

______________________________________________________________________

### User Story 2 - Add Just Task Runner to Dev Tools (Priority: P2)

As a developer using this nix-config repository, I need the just task runner available as a development tool in system/shared/app/dev/just.nix, so that I can use justfile commands for system management tasks without manual installation.

**Why this priority**: The justfile already exists and is used for system management (install, build, list commands), but the just runner itself isn't declaratively managed. This completes the tooling setup.

**Independent Test**: Can be tested by creating just.nix, importing it in a user config, rebuilding, and verifying the just command is available and can execute the repository's justfile.

**Acceptance Scenarios**:

1. **Given** just.nix exists in system/shared/app/dev/, **When** imported in user config and system rebuilds, **Then** just command is available in PATH
1. **Given** just is installed, **When** user runs `just --list` in nix-config directory, **Then** all available recipes from justfile are displayed
1. **Given** just is installed, **When** user runs `just list-users`, **Then** command executes successfully and shows discovered users
1. **Given** just.nix is in shared/app/dev/, **When** imported on both macOS and NixOS, **Then** just works identically on both platforms (cross-platform tool)

______________________________________________________________________

### Edge Cases

- What happens when aerospace or borders are already installed manually via Homebrew before nix manages them?
- How does the system handle Homebrew tap installation if FelixKratz/formulae tap doesn't exist?
- What happens when aerospace.toml configuration conflicts with existing user configuration?
- How does borders handle launch agent setup if user wants custom startup behavior?
- What happens when just is run outside the nix-config repository directory?
- How does the system handle Homebrew installation failures for aerospace or borders?

## Requirements

### Functional Requirements

**Darwin Window Management Apps**:

- **FR-001**: System MUST install aerospace via Homebrew in aerospace.nix
- **FR-002**: System MUST install borders (JankyBorders) via Homebrew tap FelixKratz/formulae in borders.nix
- **FR-003**: aerospace.nix MUST configure aerospace with the existing toml configuration at ~/.config/aerospace/aerospace.toml
- **FR-004**: aerospace configuration MUST include workspace definitions (1-5: main, web, code, term, chat)
- **FR-005**: aerospace configuration MUST include vi-style navigation keybindings (cmd+h/j/k/l for focus, cmd+shift+h/j/k/l for move)
- **FR-006**: aerospace configuration MUST include workspace switching (cmd+1-5) and window moving (cmd+shift+1-5) keybindings
- **FR-007**: borders.nix MUST configure borders with active/inactive window border colors and width settings
- **FR-008**: borders configuration MUST use light theme colors (active: 0xffe1e3e4, inactive: 0xff494d64) with 5.0pt width as default
- **FR-009**: Both aerospace.nix and borders.nix MUST remain in system/darwin/app/ (platform-specific location)
- **FR-010**: aerospace.nix MUST document that it works well with borders.nix but borders is optional

**Just Task Runner**:

- **FR-011**: System MUST create just.nix in system/shared/app/dev/ directory (cross-platform tool)
- **FR-012**: just.nix MUST install the just package from nixpkgs
- **FR-013**: just.nix MUST enable shell completion for zsh, bash, and fish
- **FR-014**: just.nix MUST work on both macOS and NixOS (cross-platform requirement)
- **FR-015**: just.nix MUST include documentation about the justfile location (repository root) and common commands
- **FR-016**: just.nix MUST configure shell alias `j` pointing to `just` for convenience

**Integration**:

- **FR-017**: All three app modules (aerospace, borders, just) MUST be self-contained with package installation and configuration
- **FR-018**: Each module MUST follow the app-centric pattern from 010-repo-restructure spec
- **FR-019**: aerospace and borders MUST handle Homebrew installation via home-manager's homebrew module
- **FR-020**: just MUST use nix package installation (not Homebrew) since it's in nixpkgs

### Key Entities

- **Aerospace App Module**: Darwin-specific window manager app

  - Homebrew package: nikitabobko/tap/aerospace
  - Configuration file: ~/.config/aerospace/aerospace.toml
  - Keybindings: Vi-style navigation, workspace switching
  - Dependencies: None (standalone)

- **Borders App Module**: Darwin-specific window border highlighter

  - Homebrew package: FelixKratz/formulae/borders
  - Configuration: Launch parameters (colors, width)
  - Dependencies: Works best with aerospace but optional
  - Launch: Via launchd agent or manual

- **Just App Module**: Cross-platform task runner

  - Nix package: pkgs.just
  - Configuration: Shell completions, alias
  - Justfile location: Repository root
  - Dependencies: None

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can import aerospace.nix and have a fully functional tiling window manager on macOS within 5 minutes of rebuild
- **SC-002**: Aerospace keybindings (cmd+h/j/k/l) work immediately after installation without additional configuration
- **SC-003**: Borders highlights active windows with configured colors immediately after installation
- **SC-004**: Just command is available system-wide and can execute justfile recipes from the nix-config repository
- **SC-005**: All three app modules (aerospace, borders, just) are self-contained - importing one file provides full functionality
- **SC-006**: Shell completion for just works in zsh without additional setup
- **SC-007**: Users can run `just list-users` and `just list-profiles` successfully after just.nix is installed
- **SC-008**: Configuration changes to aerospace.toml are applied on next system rebuild without manual steps

## Assumptions

- **Homebrew Available**: macOS systems have Homebrew installed and managed via home-manager or nix-darwin
- **User Permissions**: User has permissions to install Homebrew packages and taps
- **Aerospace Availability**: nikitabobko/tap/aerospace is available in Homebrew
- **Borders Availability**: FelixKratz/formulae/borders tap is accessible and maintained
- **Just in Nixpkgs**: just package is available in nixpkgs-unstable
- **XDG Config**: User's system respects XDG_CONFIG_HOME or uses ~/.config for configuration files
- **Repository Usage**: Users are actively using the justfile for system management
- **Single User**: Focus on single-user macOS installations (multi-user can work but not primary focus)
- **Vi-Style Users**: Users prefer vi-style navigation (hjkl) over arrow keys for window management
- **Light Theme**: Default borders colors assume light theme usage (can be customized by users)

## Dependencies

- 010-repo-restructure: Provides the app-centric directory structure and patterns
- Home Manager: Provides homebrew module for macOS package management
- Nix-darwin: Provides macOS system management
- Justfile: Already exists at repository root with management commands
- Homebrew: Required for aerospace and borders installation on macOS

## Out of Scope

- Automatic migration from manually-installed aerospace/borders to nix-managed versions
- Custom launch agent configuration for borders (users manually configure if needed)
- Alternative window managers (yabai, amethyst, etc.)
- Windows or Linux tiling window managers
- Just wrapper scripts or custom just commands
- Justfile modifications or new recipes
- Aerospace workspace auto-assignment rules
- Borders animation or advanced visual effects
- Shell completion for shells other than zsh, bash, fish
- Integration with other window management tools (Rectangle, Magnet, etc.)
