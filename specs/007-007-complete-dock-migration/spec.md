# Feature Specification: Complete Dock Migration from Dotfiles

**Feature ID**: 007\
**Feature Name**: Complete Dock Migration from Dotfiles\
**Created**: 2025-10-27\
**Status**: Draft\
**Parent Spec**: 002-darwin-system-restructure

______________________________________________________________________

## Overview

Complete the unresolved Dock configuration migration (item #8) from spec 002's `unresolved-migration.md`. Replace the current placeholder Dock configuration in `modules/darwin/system/dock.nix` with the actual configuration from the dotfiles repository, using the helper library functions from spec 006. The dotfiles repository (`~/project/dotfiles/scripts/sh/darwin/system.sh`) is the source of truth for Dock configuration.

______________________________________________________________________

## Problem Statement

### Current State

- Spec 002 identified Dock configuration as "unresolved" because it wasn't expressible in nix-darwin defaults
- Current `dock.nix` contains placeholder/example configuration (iTerm, VS Code, Firefox)
- The actual Dock configuration from dotfiles has not been migrated
- Helper library functions (spec 006) are now available to handle Dock configuration

### Desired State

- `dock.nix` contains the exact Dock configuration from dotfiles `system.sh`
- All Dock items from dotfiles are migrated (apps, spacers, folders)
- All Dock settings/preferences from dotfiles are migrated
- Configuration uses helper library functions from `modules/darwin/lib/mac.nix`
- Dock configuration is idempotent and can be reapplied safely

### Why Now

- Helper library functions (spec 006) provide the necessary primitives
- Unresolved migration item #8 can now be completed
- Current placeholder configuration doesn't match actual user preferences

______________________________________________________________________

## User Stories

### User Story 1: Dock Items Migration

**As a** macOS user\
**I want** my Dock to contain the exact apps, spacers, and folders from my dotfiles\
**So that** my Dock layout matches my established workflow

**Acceptance Criteria**:

- All 17 items from dotfiles `dockItems` array are configured
- Apps are added in the correct order with positions
- Spacers are placed between app groups
- Downloads folder is added with correct view settings
- Configuration is idempotent (safe to rerun)

**Source Configuration** (from `~/project/dotfiles/scripts/sh/darwin/system.sh`):

```bash
declare -a dockItems=(
    '/Applications/Zen.app'
    '/Applications/Brave\ Browser.app'
    '/System/Applications/Mail.app'
    '/System/Applications/Maps.app'
    '/Applications/Bitwarden.app'
    '/Applications/Qobuz.app'
    'spacer'
    '/Applications/Zed.app'
    '/Applications/Ghostty.app'
    '/Applications/Obsidian.app'
    '/Applications/UTM.app'
    'spacer'
    '/System/Applications/System\ Settings.app'
    '/System/Applications/Utilities/Activity\ Monitor.app'
    '/System/Applications/Utilities/Print\ Center.app'
    'spacer'
    "$HOME/Downloads"
);
```

### User Story 2: Dock Preferences Migration

**As a** macOS user\
**I want** all Dock preferences from dotfiles migrated to nix-darwin configuration\
**So that** Dock behavior matches my preferences

**Acceptance Criteria**:

- All 14 Dock settings from dotfiles `dock_commands` are migrated
- Settings use nix-darwin `system.defaults.dock.*` where available
- Settings not available in nix-darwin use activation scripts
- All preferences take effect after `darwin-rebuild switch`

**Source Configuration**:

```bash
declare -A dock_commands=(
    ["Disable recent apps"]="disable_recent_apps_from_dock"
    ["Enable highlight hover effect"]="defaults write com.apple.dock mouse-over-hilte-stack -bool true"
    ["Enable spring loading"]="defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true"
    ["Show indicator lights"]="defaults write com.apple.dock show-process-indicators -bool true"
    ["Disable opening animations"]="defaults write com.apple.dock launchanim -bool false"
    ["Remove auto-hiding delay"]="defaults write com.apple.dock autohide-delay -float 0"
    ["Remove hiding animation"]="defaults write com.apple.dock autohide-time-modifier -float 0"
    ["Enable auto-hide"]="defaults write com.apple.dock autohide -bool true"
    ["Make hidden apps translucent"]="defaults write com.apple.dock showhidden -bool true"
    ["Set minimize animation"]="defaults write com.apple.dock mineffect -string scale"
    ["Set dock size"]="defaults write com.apple.dock tilesize -integer 36"
    ["Minimize to app icon"]="defaults write com.apple.dock minimize-to-application -bool true"
    ["Speed up Mission Control"]="defaults write com.apple.dock expose-animation-duration -float 0.1"
    ["Don't group by app"]="defaults write com.apple.dock expose-group-by-app -bool false"
    ["Don't rearrange Spaces"]="defaults write com.apple.dock mru-spaces -bool false"
)
```

______________________________________________________________________

## Functional Requirements

### FR-001: Dock Items Configuration

**Priority**: MUST\
**Description**: Configure all Dock items from dotfiles using helper library functions

**Details**:

- Use `macLib.mkDockClear` to clear existing items
- Use `macLib.mkDockAddApp` for each application with position
- Use `macLib.mkDockAddSpacer` for spacers
- Use `macLib.mkDockAddFolder` for Downloads folder
- Use `macLib.mkDockRestart` to apply changes

### FR-002: Dock Preferences via nix-darwin

**Priority**: MUST\
**Description**: Configure Dock preferences using nix-darwin `system.defaults.dock.*`

**Mappable Settings**:

- `autohide = true` → Enable auto-hide
- `autohide-delay = 0.0` → Remove auto-hiding delay
- `autohide-time-modifier = 0.0` → Remove hiding animation
- `show-process-indicators = true` → Show indicator lights
- `showhidden = true` → Make hidden apps translucent
- `mineffect = "scale"` → Set minimize animation
- `tilesize = 36` → Set dock size
- `minimize-to-application = true` → Minimize to app icon
- `expose-animation-duration = 0.1` → Speed up Mission Control
- `expose-group-by-app = false` → Don't group by app
- `mru-spaces = false` → Don't rearrange Spaces

### FR-003: Dock Preferences via Activation Scripts

**Priority**: MUST\
**Description**: Configure Dock preferences not available in nix-darwin defaults

**Non-mappable Settings**:

- `show-recents = false` → Disable recent apps
- `mouse-over-hilte-stack = true` → Enable highlight hover effect
- `enable-spring-load-actions-on-all-items = true` → Enable spring loading
- `launchanim = false` → Disable opening animations

**Implementation**: Use activation script with `defaults write` commands

### FR-004: Idempotency

**Priority**: MUST\
**Description**: All Dock configuration must be idempotent

**Details**:

- Helper library functions already provide idempotency for items
- Dock preferences are inherently idempotent (setting same value)
- Configuration can be rerun without side effects

### FR-005: Source of Truth

**Priority**: MUST\
**Description**: Dotfiles repository is the authoritative source for Dock configuration

**Details**:

- Completely replace placeholder configuration in current `dock.nix`
- Do not preserve any settings from current version
- All configuration comes from `~/project/dotfiles/scripts/sh/darwin/system.sh`

______________________________________________________________________

## Non-Functional Requirements

### NFR-001: Performance

- Dock configuration must complete within 10 seconds
- No noticeable delay when running `darwin-rebuild switch`

### NFR-002: Maintainability

- Clear separation between Dock items and Dock preferences
- Comments explain which settings are nix-darwin vs activation scripts
- Configuration structure matches dotfiles organization

### NFR-003: Documentation

- Update spec 002's `unresolved-migration.md` to mark item #8 as resolved
- Document which Dock preferences are available in nix-darwin
- Provide migration guide for future Dock changes

______________________________________________________________________

## Technical Constraints

### TC-001: Helper Library Dependency

- **Constraint**: Must use functions from `modules/darwin/lib/mac.nix`
- **Rationale**: Spec 006 provides tested, idempotent primitives
- **Impact**: No direct `dockutil` commands in activation scripts

### TC-002: nix-darwin Limitations

- **Constraint**: Not all Dock preferences are available in nix-darwin options
- **Rationale**: nix-darwin doesn't expose every macOS default
- **Impact**: Some settings require activation scripts with `defaults write`

### TC-003: Application Availability

- **Constraint**: Applications must be installed before Dock configuration
- **Rationale**: `dockutil` fails silently for non-existent apps
- **Impact**: Dock configuration runs after app installation phase

______________________________________________________________________

## Out of Scope

### Explicitly Excluded

1. **Spotlight Indexing Order** (unresolved item #6)

   - Reason: User explicitly requested abandonment
   - Complex nested structure difficult to maintain
   - Low value compared to implementation effort

1. **Other Unresolved Items** from spec 002

   - NVRAM modifications (items #1, #9)
   - Power management (item #2)
   - Firewall configuration (item #3)
   - Security & privacy (item #4)
   - HiDPI modes (item #5)
   - Startup applications (item #7)
   - Service management (item #9)
   - Reason: Not part of Dock migration scope

1. **New Dock Features**

   - No new Dock items beyond dotfiles
   - No additional Dock preferences beyond dotfiles
   - Reason: Strict dotfiles-only migration

______________________________________________________________________

## Dependencies

### Internal Dependencies

- **Spec 006**: Reusable helper library (COMPLETE)

  - Requires `modules/darwin/lib/mac.nix`
  - Requires helper functions: `mkDockClear`, `mkDockAddApp`, `mkDockAddSpacer`, `mkDockAddFolder`, `mkDockRestart`

- **Spec 002**: Darwin system restructure (COMPLETE)

  - Requires `modules/darwin/system/dock.nix` structure
  - Requires `modules/darwin/system/default.nix` imports

### External Dependencies

- **nix-darwin**: System configuration framework

  - Version: Latest (from flake.lock)
  - Provides: `system.defaults.dock.*` options

- **dockutil**: Dock management tool

  - Available via: nixpkgs
  - Used by: Helper library functions

### Configuration Dependencies

- **dotfiles repository**: Source of truth for configuration
  - Location: `~/project/dotfiles`
  - File: `scripts/sh/darwin/system.sh`
  - Section: `dockItems` array and `dock_commands` map

______________________________________________________________________

## Success Criteria

### Definition of Done

1. **Configuration Complete**:

   - [ ] All 17 Dock items from dotfiles are configured
   - [ ] All 14 Dock preferences from dotfiles are configured
   - [ ] Configuration uses helper library functions exclusively

1. **Testing Complete**:

   - [ ] `darwin-rebuild switch` completes successfully
   - [ ] Dock contains all specified apps in correct order
   - [ ] All Dock preferences are applied correctly
   - [ ] Configuration can be rerun without errors (idempotency)

1. **Documentation Complete**:

   - [ ] Spec 002's `unresolved-migration.md` updated (item #8 resolved)
   - [ ] Comments in `dock.nix` explain nix-darwin vs activation script split
   - [ ] README or guide documents Dock configuration approach

1. **Quality Gates**:

   - [ ] No syntax errors in Nix configuration
   - [ ] All helper library functions called correctly
   - [ ] Dock restarts cleanly after configuration

### Acceptance Tests

**Test 1**: Dock Items Present

```bash
# After darwin-rebuild switch
dockutil --list | grep -c "Zen.app"  # Should return 1
dockutil --list | grep -c "spacer"  # Should return 3
```

**Test 2**: Dock Preferences Applied

```bash
# Check auto-hide enabled
defaults read com.apple.dock autohide  # Should return 1

# Check dock size
defaults read com.apple.dock tilesize  # Should return 36

# Check recent apps disabled
defaults read com.apple.dock show-recents  # Should return 0
```

**Test 3**: Idempotency

```bash
# Run twice, should succeed both times
darwin-rebuild switch
darwin-rebuild switch  # No errors, no changes
```

______________________________________________________________________

## Risk Assessment

### High Risk

None identified

### Medium Risk

1. **Application paths changed**

   - Risk: App paths in dotfiles don't match actual installations
   - Mitigation: Verify paths before migration, update dotfiles if needed
   - Contingency: Use flexible path resolution in helper functions

1. **nix-darwin option changes**

   - Risk: nix-darwin updates change available dock options
   - Mitigation: Pin nix-darwin version in flake.lock
   - Contingency: Move settings to activation scripts if removed

### Low Risk

1. **Dock restart timing**
   - Risk: Dock restart happens before all items configured
   - Mitigation: `mkDockRestart` called last, all operations use `--no-restart`

______________________________________________________________________

## Implementation Notes

### Key Decisions

1. **Two-phase approach**: nix-darwin defaults first, then activation scripts
1. **Complete replacement**: Delete all current dock.nix content
1. **Dotfiles fidelity**: Match dotfiles exactly, no improvements/additions

### Migration Strategy

1. Read current `dock.nix` to understand structure
1. Extract all Dock configuration from dotfiles `system.sh`
1. Map settings to nix-darwin options where possible
1. Implement remaining settings via activation scripts
1. Test on development machine before committing
1. Update spec 002 documentation

______________________________________________________________________

## Glossary

- **dockutil**: Command-line utility for managing macOS Dock items
- **nix-darwin**: Nix-based system configuration for macOS
- **Helper library**: Reusable functions from spec 006 for activation scripts
- **Idempotent**: Safe to run multiple times without cumulative effects
- **Activation script**: Shell script that runs during `darwin-rebuild switch`

______________________________________________________________________

## References

- **Parent Spec**: [002-darwin-system-restructure](../002-darwin-system-restructure/spec.md)
- **Dependency Spec**: [006-reusable-helper-library](../006-reusable-helper-library/spec.md)
- **Unresolved Items**: [002/unresolved-migration.md](../002-darwin-system-restructure/unresolved-migration.md)
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- **Helper Library**: `modules/darwin/lib/mac.nix`
- **Target Module**: `modules/darwin/system/dock.nix`
