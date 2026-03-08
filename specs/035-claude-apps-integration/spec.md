# Feature Specification: Claude Apps Integration

**Feature Branch**: `035-claude-apps-integration`\
**Created**: 2026-01-01\
**Status**: ⚠️ **BLOCKED** - Requires Feature 036 (Standalone Home-Manager Migration)\
**Input**: User description: "I want to integrate claude-code and potentially claude-desktop into my shared/apps using home-manager with a source similar to this: {...} from github: https://github.com/sadjow/claude-code-nix. Also ensure this will be set so darwin is not problematic. Although the following fix darwin, I don't think it's platform specific and can reside in shared/app: stable symlink for permissions. To be installed, user config should have secret configured."

## ⚠️ BLOCKING ISSUE

### Problem

During implementation, discovered that **lib.hm is not available** in home-manager modules when using nix-darwin module integration. This affects:

- All activation scripts using `lib.hm.dag.entryAfter`
- Settings modules in `system/*/settings/home/`
- Any module requiring home-manager's extended lib utilities

### Root Cause

The nix-darwin home-manager integration (`home-manager.darwinModules.home-manager`) does not automatically extend the `lib` parameter with home-manager's `lib.hm` utilities, unlike standalone home-manager which does this in `modules/lib/stdlib-extended.nix`.

### Impact on Feature 035

- ✅ Created claude-code app modules (darwin + shared)
- ❌ Cannot test build due to lib.hm errors in existing settings modules
- ❌ Cannot implement activation scripts for stable symlinks
- ❌ Cannot complete feature until lib.hm is available

### Resolution Path

**Feature 036 - Standalone Home-Manager Migration** must be completed first. This will:

1. Migrate from nix-darwin module integration to standalone home-manager
1. Properly extend lib with lib.hm for all user modules
1. Enable all activation scripts and settings to work correctly

See `specs/036-standalone-home-manager/research.md` for detailed analysis of the lib.hm issue and solution.

______________________________________________________________________

## User Scenarios & Testing

### User Story 1 - Basic Claude Code Installation (Priority: P1)

As a developer using the nix-config repository, I want to install Claude Code via Home Manager so that I can use the AI coding assistant in my development workflow.

**Why this priority**: Core functionality - provides immediate value by making Claude Code available to users who want it.

**Independent Test**: User adds "claude-code" to their applications list, runs `just install`, and can execute `claude` command from terminal.

**Acceptance Scenarios**:

1. **Given** user has added "claude-code" to their applications array, **When** they run `just install <user> <host>`, **Then** Claude Code is installed and available via `claude` command
1. **Given** Claude Code is installed, **When** user runs `claude --version`, **Then** version information is displayed
1. **Given** user configuration includes Claude Code, **When** system is rebuilt, **Then** Claude Code binary is accessible from user's PATH

______________________________________________________________________

### User Story 2 - Stable Symlink for macOS Permissions (Priority: P2)

As a macOS user, I want a stable symlink to the Claude binary so that I don't have to re-grant permissions after every Nix update.

**Why this priority**: Eliminates major UX friction on macOS where binary path changes cause repeated permission prompts.

**Independent Test**: After Nix updates Claude Code, user can still run `~/.local/bin/claude` without new permission prompts.

**Acceptance Scenarios**:

1. **Given** Claude Code is installed, **When** installation completes, **Then** a stable symlink is created at `~/.local/bin/claude` pointing to the current binary
1. **Given** stable symlink exists, **When** Nix updates Claude Code to a new version, **Then** symlink is automatically updated to point to new binary
1. **Given** stable symlink exists, **When** user runs `~/.local/bin/claude`, **Then** command executes without requesting new permissions
1. **Given** stable symlink directory exists, **When** user checks their PATH, **Then** `~/.local/bin` is included in PATH

______________________________________________________________________

### User Story 3 - Configuration Persistence (Priority: P2)

As a Claude Code user, I want my configuration and workspace data to persist across Nix updates so that I don't lose my settings and project history.

**Why this priority**: Essential for practical usability - users shouldn't lose their work or settings during updates.

**Independent Test**: User makes configuration changes, updates system, and verifies settings are preserved.

**Acceptance Scenarios**:

1. **Given** user has created `.claude.json` configuration, **When** system is updated, **Then** configuration file remains unchanged
1. **Given** user has `.claude/` directory with workspace data, **When** Nix rebuilds the environment, **Then** workspace data is preserved
1. **Given** user runs Claude from stable symlink, **When** they make configuration changes, **Then** changes are saved in persistent home directory location

______________________________________________________________________

### User Story 4 - Optional Claude Desktop Integration (Priority: P3)

As a user who prefers GUI applications, I want the option to install Claude Desktop in addition to or instead of Claude Code so that I can use the desktop interface.

**Why this priority**: Optional enhancement - provides alternative interface for users who prefer GUI over CLI.

**Independent Test**: User adds "claude-desktop" to applications, installs successfully, and can launch desktop application.

**Acceptance Scenarios**:

1. **Given** user adds "claude-desktop" to applications array, **When** they run `just install`, **Then** Claude Desktop application is installed
1. **Given** both claude-code and claude-desktop are in applications, **When** system is built, **Then** both applications are installed without conflicts
1. **Given** only claude-desktop is selected, **When** user installs configuration, **Then** only desktop app is installed (no CLI tools)

______________________________________________________________________

### User Story 5 - Cross-Platform Support (Priority: P2)

As a user who works on both Darwin and NixOS systems, I want Claude applications available on both platforms so that I have consistent tooling across my machines.

**Why this priority**: Aligns with repository's cross-platform philosophy - single app module should work everywhere.

**Independent Test**: Same app module works on both Darwin and NixOS without platform-specific modifications.

**Acceptance Scenarios**:

1. **Given** user config includes Claude apps on Darwin system, **When** `just install` runs, **Then** applications install successfully
1. **Given** user config includes Claude apps on NixOS system, **When** `just install` runs, **Then** applications install successfully with same functionality
1. **Given** app module is in `system/shared/app/`, **When** evaluated on either platform, **Then** installation succeeds without platform-specific code paths

______________________________________________________________________

### User Story 6 - Secret-Based Activation (Priority: P1)

As a security-conscious user, I want Claude applications to require proper authentication via secrets so that only authorized users can access the service.

**Why this priority**: Security requirement - prevents unauthorized usage and aligns with repository's secret management pattern (Feature 031).

**Independent Test**: User without configured secret cannot use Claude features; user with secret can authenticate successfully.

**Acceptance Scenarios**:

1. **Given** user has not configured Claude API secret, **When** they attempt to use Claude, **Then** they receive clear error message explaining secret requirement
1. **Given** user has configured secret via `just secrets-set <user> claude.apiKey "sk-..."`, **When** they use Claude, **Then** authentication succeeds
1. **Given** user secret is stored in `user/<name>/secrets.age`, **When** Home Manager activation runs, **Then** secret is properly resolved and configured for Claude applications

______________________________________________________________________

### Edge Cases

- What happens when the claude-code-nix flake input is unavailable or fails to fetch?
- How does the system handle situations where `~/.local/bin` doesn't exist?
- What if user has both CLI and desktop installed and they have conflicting configurations?
- How does the stable symlink behave when Claude binary is completely removed?
- What happens if user's secret is invalid or expired?
- How does system handle permission errors when creating stable symlink?
- What if PATH already contains a different `claude` command?

## Requirements

### Functional Requirements

- **FR-001**: System MUST integrate claude-code-nix flake as an input to the main flake configuration
- **FR-002**: System MUST apply claude-code overlay to nixpkgs for package availability
- **FR-003**: System MUST create app module at `system/shared/app/ai/claude-code.nix` following repository conventions
- **FR-004**: System MUST create stable symlink at `~/.local/bin/claude` pointing to Claude Code binary
- **FR-005**: System MUST ensure `~/.local/bin` is in user's PATH
- **FR-006**: System MUST preserve user's `.claude.json` and `.claude/` directory across updates
- **FR-007**: System MUST require Claude API key to be configured as a secret via `user.claude.apiKey`
- **FR-008**: Users MUST be able to install claude-code by adding it to their applications array
- **FR-009**: Users MUST be able to optionally install claude-desktop as a separate application
- **FR-010**: System MUST work on both Darwin and NixOS platforms without platform-specific code in app module
- **FR-011**: System MUST update stable symlink when Claude binary path changes (after Nix updates)
- **FR-012**: System MUST provide clear error messages when secret is not configured
- **FR-013**: System MUST use Home Manager activation scripts for symlink creation and secret resolution

### Key Entities

- **Claude Code Application**: CLI-based AI coding assistant installed via Home Manager
- **Claude Desktop Application**: Optional GUI version of Claude
- **API Key Secret**: User's Claude API key stored encrypted in `user/<name>/secrets.age`
- **Stable Symlink**: Persistent path at `~/.local/bin/claude` that survives Nix updates
- **User Configuration**: `.claude.json` and `.claude/` directory in user's home directory

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can install Claude Code by adding one line to their configuration and running one command
- **SC-002**: macOS users do not receive permission prompts after Nix updates (when using stable symlink)
- **SC-003**: User configuration and workspace data persists through 100% of system updates
- **SC-004**: Installation process completes in under 5 minutes (excluding download time)
- **SC-005**: App module contains fewer than 200 lines (constitutional requirement)
- **SC-006**: Same app module works on both Darwin and NixOS without modifications
- **SC-007**: Users without configured secrets receive clear setup instructions when attempting to use Claude
- **SC-008**: 100% of Claude's functionality is available after installation (no missing features due to Nix packaging)

## Scope

### In Scope

- Integration of claude-code-nix flake as input
- Creation of claude-code app module in system/shared/app/ai/
- Creation of optional claude-desktop app module
- Stable symlink creation and management via Home Manager
- PATH configuration for ~/.local/bin
- Secret-based authentication requirement
- Cross-platform support (Darwin + NixOS)
- Configuration persistence (.claude.json, .claude/ directory)
- Auto-discovery integration with existing app system

### Out of Scope

- Custom Claude configuration templates (users manage their own .claude.json)
- Claude API key generation or management (users obtain from Anthropic)
- Migration of existing Claude installations
- Integration with other AI coding assistants
- Custom Claude plugins or extensions
- Desktop application auto-launch configuration
- Workspace-specific Claude settings (handled by Claude itself)

## Assumptions

- Users have valid Claude API keys from Anthropic
- claude-code-nix flake remains maintained and compatible with current nixpkgs
- Users are comfortable storing API keys in agenix-encrypted secrets
- ~/.local/bin is a standard location acceptable for user binaries
- Home Manager activation scripts run with appropriate permissions
- Claude applications respect XDG directory conventions for configuration
- GitHub repository https://github.com/sadjow/claude-code-nix remains accessible

## Dependencies

- **Feature 031** (Per-User Secrets): Required for API key storage
- **Home Manager**: Required for user-level installation
- **agenix**: Required for secret encryption/decryption
- **claude-code-nix flake**: External dependency from GitHub
- **Existing app discovery system**: Apps must auto-discover from system/shared/app/

## Non-Functional Requirements

- **NFR-001**: Installation must not require manual intervention beyond adding app to configuration
- **NFR-002**: Symlink updates must occur automatically during Home Manager activation
- **NFR-003**: Error messages must include actionable steps (e.g., "Run: just secrets-set <user> claude.apiKey 'your-key'")
- **NFR-004**: Module must follow repository constitution (app-centric, \<200 lines, platform-agnostic)
- **NFR-005**: Documentation must include troubleshooting for common issues (permissions, PATH, secrets)
