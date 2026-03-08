# Data Model: Complete Dock Migration from Dotfiles

**Feature**: 007-complete-dock-migration\
**Date**: 2025-10-27\
**Status**: Complete

______________________________________________________________________

## Overview

This document defines the data structures, entities, and relationships for the Dock configuration migration. It describes the logical organization of Dock items and preferences, and how they map to nix-darwin configuration.

______________________________________________________________________

## Entity Model

### Entity 1: DockItem

Represents a single item in the macOS Dock (application, spacer, or folder).

**Attributes**:

```nix
{
  type: enum { Application, Spacer, Folder }
  path: string?                    # Required for Application and Folder, null for Spacer
  position: integer                # Order in Dock (1-based index)
  name: string                     # Display name (extracted from path)
  
  # Folder-specific attributes (null for Application and Spacer)
  view: enum { "fan", "grid", "list", "automatic" }?
  display: enum { "folder", "stack" }?
  sort: enum { "name", "dateadded", "datemodified", "datecreated", "kind" }?
}
```

**Validation Rules**:

- `type = Application` → `path` must be non-null and end with `.app`
- `type = Folder` → `path` must be non-null and be a directory
- `type = Spacer` → `path` must be null
- `position` must be unique across all items
- `position` must be sequential (no gaps)
- Application `path` must be absolute path starting with `/`
- Folder `path` can use `~` or `$HOME` (will be expanded)

**Examples**:

```nix
# Application item
{
  type = "Application";
  path = "/Applications/Zen.app";
  position = 1;
  name = "Zen";
}

# Spacer item
{
  type = "Spacer";
  path = null;
  position = 7;
  name = "spacer";
}

# Folder item
{
  type = "Folder";
  path = "/Users/charles/Downloads";
  position = 17;
  name = "Downloads";
  view = "fan";
  display = "stack";
  sort = "dateadded";
}
```

______________________________________________________________________

### Entity 2: DockPreference

Represents a Dock behavior or appearance setting.

**Attributes**:

```nix
{
  name: string                     # Setting identifier
  value: union { bool, int, float, string }
  nixOption: string?               # nix-darwin option path (if available)
  defaultsKey: string?             # macOS defaults key (if not in nix-darwin)
  defaultsDomain: string           # Usually "com.apple.dock"
  description: string              # Human-readable description
}
```

**Configuration Method**:

- If `nixOption` is non-null → use `system.defaults.dock.<nixOption>`
- If `nixOption` is null → use activation script with `defaults write <defaultsDomain> <defaultsKey>`

**Examples**:

```nix
# nix-darwin preference
{
  name = "autohide";
  value = true;
  nixOption = "autohide";
  defaultsKey = "autohide";
  defaultsDomain = "com.apple.dock";
  description = "Enable auto-hide";
}

# Activation script preference
{
  name = "spring-loading";
  value = true;
  nixOption = null;
  defaultsKey = "enable-spring-load-actions-on-all-items";
  defaultsDomain = "com.apple.dock";
  description = "Enable spring loading for all items";
}
```

______________________________________________________________________

### Entity 3: DockConfiguration

The complete Dock configuration containing all items and preferences.

**Attributes**:

```nix
{
  items: list<DockItem>            # All Dock items in order
  preferences: list<DockPreference> # All Dock settings
  
  # Computed properties
  applicationCount: integer        # Count of Application items
  spacerCount: integer             # Count of Spacer items
  folderCount: integer             # Count of Folder items
  nixPreferenceCount: integer      # Count of preferences via nix-darwin
  scriptPreferenceCount: integer   # Count of preferences via activation script
}
```

**Invariants**:

- `items` must be sorted by `position`
- No duplicate positions in `items`
- All preferences must have unique `name`
- `applicationCount + spacerCount + folderCount = length(items)`
- `nixPreferenceCount + scriptPreferenceCount = length(preferences)`

______________________________________________________________________

## Complete Configuration Instance

### Dock Items (17 total)

```nix
items = [
  # Position 1-6: Main applications
  { type = "Application"; path = "/Applications/Zen.app"; position = 1; }
  { type = "Application"; path = "/Applications/Brave Browser.app"; position = 2; }
  { type = "Application"; path = "/System/Applications/Mail.app"; position = 3; }
  { type = "Application"; path = "/System/Applications/Maps.app"; position = 4; }
  { type = "Application"; path = "/Applications/Bitwarden.app"; position = 5; }
  { type = "Application"; path = "/Applications/Qobuz.app"; position = 6; }
  
  # Position 7: Spacer
  { type = "Spacer"; position = 7; }
  
  # Position 8-11: Development applications
  { type = "Application"; path = "/Applications/Zed.app"; position = 8; }
  { type = "Application"; path = "/Applications/Ghostty.app"; position = 9; }
  { type = "Application"; path = "/Applications/Obsidian.app"; position = 10; }
  { type = "Application"; path = "/Applications/UTM.app"; position = 11; }
  
  # Position 12: Spacer
  { type = "Spacer"; position = 12; }
  
  # Position 13-15: System utilities
  { type = "Application"; path = "/System/Applications/System Settings.app"; position = 13; }
  { type = "Application"; path = "/System/Applications/Utilities/Activity Monitor.app"; position = 14; }
  { type = "Application"; path = "/System/Applications/Utilities/Print Center.app"; position = 15; }
  
  # Position 16: Spacer
  { type = "Spacer"; position = 16; }
  
  # Position 17: Downloads folder
  {
    type = "Folder";
    path = "/Users/charles/Downloads";
    position = 17;
    view = "fan";
    display = "stack";
    sort = "dateadded";
  }
]
```

**Counts**: 14 applications, 3 spacers, 1 folder = 17 items total

### Dock Preferences (15 total: 13 nix-darwin + 2 script)

```nix
preferences = [
  # nix-darwin preferences (13)
  { name = "show-recents"; value = false; nixOption = "show-recents"; description = "Disable recent apps"; }
  { name = "show-process-indicators"; value = true; nixOption = "show-process-indicators"; description = "Show indicator lights for running apps"; }
  { name = "launchanim"; value = false; nixOption = "launchanim"; description = "Disable app opening animations"; }
  { name = "autohide-delay"; value = 0.0; nixOption = "autohide-delay"; description = "Remove auto-hide delay"; }
  { name = "autohide-time-modifier"; value = 0.0; nixOption = "autohide-time-modifier"; description = "Remove auto-hide animation time"; }
  { name = "autohide"; value = true; nixOption = "autohide"; description = "Enable auto-hide Dock"; }
  { name = "showhidden"; value = true; nixOption = "showhidden"; description = "Make hidden apps translucent"; }
  { name = "mineffect"; value = "scale"; nixOption = "mineffect"; description = "Set minimize animation to scale"; }
  { name = "tilesize"; value = 36; nixOption = "tilesize"; description = "Set Dock icon size to 36px"; }
  { name = "minimize-to-application"; value = true; nixOption = "minimize-to-application"; description = "Minimize windows into app icon"; }
  { name = "expose-animation-duration"; value = 0.1; nixOption = "expose-animation-duration"; description = "Speed up Mission Control animations"; }
  { name = "expose-group-apps"; value = false; nixOption = "expose-group-apps"; description = "Don't group windows by application in Mission Control"; }
  { name = "mru-spaces"; value = false; nixOption = "mru-spaces"; description = "Don't automatically rearrange Spaces"; }
  
  # Activation script preferences (2)
  { name = "mouse-over-hilite-stack"; value = true; nixOption = null; defaultsKey = "mouse-over-hilite-stack"; description = "Enable highlight hover effect for stacks"; }
  { name = "spring-loading"; value = true; nixOption = null; defaultsKey = "enable-spring-load-actions-on-all-items"; description = "Enable spring loading for Dock items"; }
]
```

**Counts**: 13 via nix-darwin, 2 via activation script = 15 preferences total

______________________________________________________________________

## Module Structure

### File: `modules/darwin/system/dock.nix`

```nix
{ config, lib, pkgs, ... }:

let
  # Import helper library
  macLib = import ../lib/mac.nix { inherit pkgs lib config; };
  
  # Primary user for path expansion
  primaryUser = config.users.primaryUser or "charles";
  
  # Helper to generate Dock item configuration
  mkDockItem = item:
    if item.type == "Application" then
      macLib.mkDockAddApp { path = item.path; position = item.position; }
    else if item.type == "Spacer" then
      macLib.mkDockAddSpacer
    else if item.type == "Folder" then
      macLib.mkDockAddFolder {
        path = item.path;
        view = item.view;
        display = item.display;
        sort = item.sort;
      }
    else
      throw "Unknown DockItem type: ${item.type}";

in
{
  # Section 1: nix-darwin Dock preferences (13 settings)
  system.defaults.dock = {
    show-recents = false;
    show-process-indicators = true;
    launchanim = false;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.0;
    autohide = true;
    showhidden = true;
    mineffect = "scale";
    tilesize = 36;
    minimize-to-application = true;
    expose-animation-duration = 0.1;
    expose-group-apps = false;
    mru-spaces = false;
  };

  # Section 2: Activation script for Dock items and additional preferences
  system.activationScripts.configureDock = {
    text = ''
      # Additional Dock preferences (2 settings not in nix-darwin)
      defaults write com.apple.dock mouse-over-hilite-stack -bool true
      defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
      
      # Configure Dock items (17 items using helper functions)
      ${macLib.mkDockClear}
      
      # Applications and spacers (configured via helper functions)
      ${concatMapStrings mkDockItem dockItems}
      
      # Restart Dock to apply changes
      ${macLib.mkDockRestart}
    '';
  };
}
```

______________________________________________________________________

## Relationships

### Item Ordering

```
DockConfiguration 1 ──→ * DockItem
                   │
                   └─ position attribute defines order
```

**Constraint**: Items must be added in sequential position order for correct visual layout.

### Preference Application

```
DockConfiguration 1 ──→ * DockPreference
                   │
                   ├─ nixOption != null ──→ system.defaults.dock.*
                   └─ nixOption == null ──→ activation script (defaults write)
```

**Strategy**: Apply nix-darwin preferences first (declarative), then activation script (imperative fallback).

______________________________________________________________________

## State Transitions

### Dock Configuration Lifecycle

```
[Initial State]
    │
    ├─ nix-darwin applies system.defaults.dock.* settings
    │  (13 preferences applied declaratively)
    │
    ├─ Activation script runs:
    │  ├─ Additional preferences (defaults write × 2)
    │  ├─ Clear existing Dock items (mkDockClear)
    │  ├─ Add items in order (mkDockAddApp/Spacer/Folder × 17)
    │  └─ Restart Dock (mkDockRestart)
    │
    └─→ [Final State: Dock configured]
```

**Idempotency**: If configuration is reapplied:

1. nix-darwin settings are idempotent (setting same value has no effect)
1. Helper functions check before modifying (only add if not present)
1. Dock restart is safe (kills and relaunches Dock process)

______________________________________________________________________

## Validation Rules

### Pre-Execution Validation

Before applying configuration, verify:

1. **Application Existence**:

   ```bash
   for app in <all Application items>; do
     [ -d "$app" ] || echo "Warning: $app not found"
   done
   ```

1. **Folder Existence**:

   ```bash
   [ -d "/Users/charles/Downloads" ] || echo "Error: Downloads folder not found"
   ```

1. **Helper Library Available**:

   ```bash
   [ -f "modules/darwin/lib/mac.nix" ] || echo "Error: Helper library missing"
   ```

### Post-Execution Validation

After applying configuration, verify:

1. **Dock Items Present**:

   ```bash
   dockutil --list | wc -l  # Should be 14 (apps + folders, no spacers counted)
   ```

1. **Preferences Applied**:

   ```bash
   defaults read com.apple.dock autohide  # Should return 1
   defaults read com.apple.dock tilesize  # Should return 36
   ```

1. **Dock Running**:

   ```bash
   pgrep -x Dock  # Should return PID
   ```

______________________________________________________________________

## Summary

### Data Model Statistics

- **Entities**: 3 (DockItem, DockPreference, DockConfiguration)
- **Total Items**: 17 (14 applications, 3 spacers, 1 folder)
- **Total Preferences**: 15 (13 nix-darwin, 2 activation script)
- **Configuration Method**: 2 (nix-darwin defaults + activation script)
- **Helper Functions Used**: 5 (mkDockClear, mkDockAddApp, mkDockAddSpacer, mkDockAddFolder, mkDockRestart)

### Key Properties

- **Deterministic**: Same inputs always produce same Dock configuration
- **Idempotent**: Safe to reapply without side effects
- **Declarative**: Prefers nix-darwin options over imperative commands
- **Validated**: Pre and post-execution checks ensure correctness
- **Maintainable**: Clear separation between items and preferences

______________________________________________________________________

## References

- **Feature Spec**: [spec.md](./spec.md)
- **Implementation Plan**: [plan.md](./plan.md)
- **Research**: [research.md](./research.md)
- **Helper Library**: `modules/darwin/lib/mac.nix` (spec 006)
- **Target Module**: `modules/darwin/system/dock.nix`
