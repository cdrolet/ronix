# Data Model: Darwin System Defaults Restructuring and Migration

**Feature**: Darwin System Defaults Restructuring and Migration\
**Date**: 2025-10-26\
**Purpose**: Define the structure of configuration modules, setting categories, and migration mappings

## Overview

This data model defines the organizational structure for macOS system defaults in the nix-config repository. It establishes topic-based modules, setting categories, and the relationships between bash `defaults` commands and nix-darwin options.

## Core Entities

### 1. TopicModule

A TopicModule represents a single Nix file containing related system defaults.

**Attributes**:

- `name`: string (e.g., "dock", "finder", "trackpad")
- `filePath`: absolute path (e.g., "/modules/darwin/system/dock.nix")
- `domain`: MacOSDomain (the macOS preference domain it manages)
- `settings`: list of SystemSetting
- `lineCount`: integer (must be ≤200 per constitution)
- `documentation`: ModuleDocumentation

**Relationships**:

- Contains many SystemSetting entities
- Belongs to one MacOSDomain
- Imported by SystemAggregator

**Validation Rules**:

- Name must match filename (dock.nix → name: "dock")
- LineCount must not exceed 200 (split into sub-modules if larger)
- Must include header documentation

**Example**:

```nix
# modules/darwin/system/dock.nix
{ config, lib, pkgs, ... }:
{
  # Dock settings - visual appearance and behavior of macOS Dock
  system.defaults.dock = {
    autohide = true;
    autohide-delay = 0.0;
    autohide-time-modifier = 0.2;
    show-recents = false;
    orientation = "bottom";
    tilesize = 48;
  };
}
```

______________________________________________________________________

### 2. SystemSetting

A SystemSetting represents a single macOS system default configuration.

**Attributes**:

- `domain`: string (e.g., "com.apple.dock", "NSGlobalDomain")
- `key`: string (e.g., "autohide", "AppleShowAllExtensions")
- `value`: boolean | integer | float | string
- `nixPath`: string (nix-darwin option path, e.g., "system.defaults.dock.autohide")
- `bashCommand`: string (original bash command if migrated)
- `requiresSudo`: boolean
- `deprecated`: boolean
- `supported`: boolean (can be expressed in nix-darwin)
- `category`: SettingCategory

**Relationships**:

- Belongs to one TopicModule
- Maps to one MacOSDomain
- Has one MigrationStatus

**Validation Rules**:

- If deprecated = true, should not be migrated
- If requiresSudo = true and no nix-darwin equivalent, document in unresolved-migration.md
- If supported = false, document in unresolved-migration.md

**Example**:

```
domain: "com.apple.dock"
key: "autohide"
value: true
nixPath: "system.defaults.dock.autohide"
bashCommand: "defaults write com.apple.dock autohide -bool true"
requiresSudo: false
deprecated: false
supported: true
category: VISUAL_APPEARANCE
```

______________________________________________________________________

### 3. MacOSDomain

Represents a macOS preference domain (com.apple.\* or NSGlobalDomain).

**Attributes**:

- `identifier`: string (e.g., "com.apple.dock", "NSGlobalDomain")
- `type`: DomainType enum (SYSTEM_DEFAULTS | CUSTOM_USER_PREFERENCES)
- `topicModule`: TopicModule (which module handles this domain)
- `nixDarwinPath`: string (where settings go in nix-darwin, e.g., "system.defaults.dock")

**Relationships**:

- Contains many SystemSetting entities
- Handled by one TopicModule

**Domain Type Enum**:

```
enum DomainType {
  SYSTEM_DEFAULTS,          // Has typed nix-darwin options (dock, finder, NSGlobalDomain)
  CUSTOM_USER_PREFERENCES   // Requires CustomUserPreferences (app-specific)
}
```

**Common Domains**:
| Identifier | Type | TopicModule | nixDarwinPath |
|------------|------|-------------|---------------|
| com.apple.dock | SYSTEM_DEFAULTS | dock | system.defaults.dock |
| com.apple.finder | SYSTEM_DEFAULTS | finder | system.defaults.finder |
| com.apple.driver.AppleBluetoothMultitouch.trackpad | SYSTEM_DEFAULTS | trackpad | system.defaults.trackpad |
| NSGlobalDomain | SYSTEM_DEFAULTS | Multiple (keyboard, ui, etc.) | system.defaults.NSGlobalDomain |
| com.apple.ActivityMonitor | CUSTOM_USER_PREFERENCES | applications | system.defaults.CustomUserPreferences."com.apple.ActivityMonitor" |
| com.apple.Safari | CUSTOM_USER_PREFERENCES | applications | system.defaults.CustomUserPreferences."com.apple.Safari" |

______________________________________________________________________

### 4. SystemAggregator

The main orchestration file that imports all topic modules.

**Attributes**:

- `filePath`: "/modules/darwin/system/default.nix"
- `importedModules`: list of TopicModule
- `role`: "import-only orchestrator"

**Responsibilities**:

- Import all topic-specific modules
- No settings definitions (purely imports)
- Provide single entry point for system defaults

**Structure**:

```nix
# modules/darwin/system/default.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ./dock.nix
    ./finder.nix
    ./trackpad.nix
    ./keyboard.nix
    ./screen.nix
    ./security.nix
    ./network.nix
    ./power.nix
    ./ui.nix
    ./accessibility.nix
    ./applications.nix
    ./system.nix
  ];
}
```

______________________________________________________________________

### 5. MigrationMapping

Represents the transformation from a bash defaults command to nix-darwin configuration.

**Attributes**:

- `bashCommand`: string (original command from system.sh)
- `domain`: string (extracted from bash command)
- `key`: string (extracted from bash command)
- `value`: any (extracted and type-converted)
- `nixExpression`: string (resulting Nix configuration)
- `migrationStatus`: MigrationStatus enum
- `notes`: string (migration notes, alternatives, etc.)

**Migration Status Enum**:

```
enum MigrationStatus {
  MIGRATED,              // Successfully converted to nix-darwin
  UNRESOLVED,            // Cannot be expressed in nix-darwin
  DEPRECATED,            // Setting no longer valid on modern macOS
  DUPLICATE,             // Already exists in current defaults.nix
  REQUIRES_ACTIVATION    // Needs activation script (sudo/service management)
}
```

**Example**:

```
bashCommand: "defaults write com.apple.dock autohide -bool true"
domain: "com.apple.dock"
key: "autohide"
value: true
nixExpression: "system.defaults.dock.autohide = true;"
migrationStatus: MIGRATED
notes: "Direct mapping to typed nix-darwin option"
```

______________________________________________________________________

### 6. ModuleDocumentation

Documentation requirements for each topic module.

**Attributes**:

- `purpose`: string (what this module configures)
- `examples`: list of string (usage examples)
- `options`: list of OptionDoc
- `dependencies`: list of string (other modules or packages required)

**Option Documentation**:

```
struct OptionDoc {
  name: string          # e.g., "system.defaults.dock.autohide"
  type: string          # e.g., "boolean"
  default: any          # e.g., false
  description: string   # e.g., "Enable dock auto-hiding"
  example: any          # e.g., true
}
```

**Example**:

```nix
# Dock Settings Module
#
# Purpose: Configure macOS Dock appearance, behavior, and functionality
#
# Examples:
#   # Enable auto-hiding with no delay
#   system.defaults.dock.autohide = true;
#   system.defaults.dock.autohide-delay = 0.0;
#
# Dependencies: None
```

______________________________________________________________________

## Topic Module Categories

### Primary Topic Modules

1. **dock.nix**

   - Domain: com.apple.dock
   - Scope: Dock visual appearance, auto-hide, size, position, app indicators
   - Settings: ~15-20

1. **finder.nix**

   - Domain: com.apple.finder
   - Scope: Finder windows, views, extensions, search, Finder-specific shortcuts
   - Settings: ~20-25

1. **trackpad.nix**

   - Domain: com.apple.driver.AppleBluetoothMultitouch.trackpad
   - Scope: Trackpad gestures, clicking, scrolling
   - Settings: ~8-10

1. **keyboard.nix**

   - Domain: NSGlobalDomain (KeyRepeat, InitialKeyRepeat)
   - Scope: System-wide keyboard repeat, modifier keys
   - Settings: ~5-8
   - Note: Application-specific shortcuts go in their respective app modules

1. **screen.nix**

   - Domain: com.apple.screencapture, WindowServer
   - Scope: Screenshots, display resolution, HiDPI modes
   - Settings: ~5-10

1. **security.nix**

   - Domain: Various (com.apple.screensaver, loginwindow)
   - Scope: Screen saver password, guest account, firewall
   - Settings: ~10-15

1. **network.nix**

   - Domain: com.apple.NetworkBrowser
   - Scope: AirDrop, network browsing
   - Settings: ~3-5

1. **power.nix**

   - Domain: com.apple.menuextra.battery, pmset
   - Scope: Battery display, sleep settings, standby
   - Settings: ~5-8

1. **ui.nix**

   - Domain: NSGlobalDomain (visual effects, menu bar)
   - Scope: Animations, transparency, scrollbars, menu bar
   - Settings: ~15-20

1. **accessibility.nix**

   - Domain: NSGlobalDomain (reduce motion, etc.)
   - Scope: Accessibility features, motion reduction
   - Settings: ~3-5

1. **applications.nix**

   - Domain: Various (com.apple.Safari, com.apple.Mail, com.apple.ActivityMonitor)
   - Scope: Application-specific defaults
   - Settings: ~50-100 (may need sub-modules)

1. **system.nix**

   - Domain: Various (NSGlobalDomain system-wide settings)
   - Scope: General system behavior, save panels, smart quotes
   - Settings: ~15-20

______________________________________________________________________

## Setting Placement Rules

Determine which TopicModule a setting belongs to:

1. **If setting affects a single application → applications.nix**

   - Example: Safari developer menu → applications.nix
   - Example: Mail keyboard shortcuts → applications.nix
   - Exception: Finder gets its own module due to size

1. **If setting is application-specific shortcut → that application's module**

   - Example: Finder keyboard shortcut → finder.nix (not keyboard.nix)
   - Example: Mail send shortcut → applications.nix (Mail section)

1. **If setting is system-wide input behavior → respective input module**

   - Example: Key repeat rate → keyboard.nix
   - Example: Trackpad clicking → trackpad.nix

1. **If setting affects visual appearance → ui.nix or specific module**

   - Example: Dock appearance → dock.nix
   - Example: Global animations → ui.nix
   - Example: Menu bar transparency → ui.nix

1. **If setting is security-related → security.nix**

   - Example: Screen saver password → security.nix
   - Example: Firewall → security.nix

1. **When in doubt, follow the macOS domain**

   - com.apple.dock → dock.nix
   - com.apple.finder → finder.nix
   - com.apple.\* (other apps) → applications.nix

______________________________________________________________________

## Migration Workflow

### Input: bash defaults command from system.sh

```bash
defaults write com.apple.dock autohide -bool true
```

### Step 1: Parse command

- Domain: com.apple.dock
- Key: autohide
- Value: true (boolean)
- Requires sudo: no

### Step 2: Determine migration status

- Check if domain has nix-darwin support → YES (system.defaults.dock)
- Check if key exists in nix-darwin → YES (autohide)
- Check if deprecated → NO
- Status: MIGRATED

### Step 3: Identify target module

- Domain com.apple.dock → dock.nix

### Step 4: Generate Nix expression

```nix
system.defaults.dock.autohide = true;
```

### Step 5: Document mapping

- Record in MigrationMapping table
- Original command preserved in comments if useful

______________________________________________________________________

## File Structure State Transitions

### Current State (Before)

```
modules/darwin/
├── default.nix
└── defaults.nix  [monolithic, contains all settings]
```

### Intermediate State (During Restructure)

```
modules/darwin/
├── default.nix
├── defaults.nix  [still has settings, being extracted]
└── system/
    ├── default.nix  [imports topic modules]
    └── dock.nix     [partial settings moved]
```

### Final State (After Restructure)

```
modules/darwin/
├── default.nix
├── defaults.nix  [import-only, references ./system]
└── system/
    ├── default.nix  [imports all topic modules]
    ├── dock.nix
    ├── finder.nix
    ├── trackpad.nix
    ├── keyboard.nix
    ├── screen.nix
    ├── security.nix
    ├── network.nix
    ├── power.nix
    ├── ui.nix
    ├── accessibility.nix
    ├── applications.nix
    └── system.nix
```

### Final State (After Migration)

```
modules/darwin/
├── default.nix
├── defaults.nix  [import-only]
└── system/
    ├── default.nix
    ├── dock.nix        [original + migrated settings]
    ├── finder.nix      [original + migrated settings]
    └── ...             [all files updated]

specs/002-darwin-system-restructure/
├── unresolved-migration.md    [settings that couldn't migrate]
└── deprecated-settings.md     [settings intentionally skipped]
```

______________________________________________________________________

## Validation Rules

### Module-Level Validation

- [ ] Each .nix file has header documentation
- [ ] Each module ≤200 lines (split if larger)
- [ ] All settings use `lib.mkDefault` where appropriate
- [ ] No duplicate settings across modules
- [ ] imports list in system/default.nix includes all modules

### Setting-Level Validation

- [ ] Each setting has correct type (bool, int, float, string)
- [ ] Application-specific settings in correct module
- [ ] System-wide settings in appropriate domain module
- [ ] No deprecated settings included
- [ ] Sudo-required settings either converted or documented

### Build Validation

- [ ] `nix flake check` passes
- [ ] `darwin-rebuild build` succeeds
- [ ] No warnings or errors in build output
- [ ] Build time does not increase significantly

### Runtime Validation

- [ ] Settings apply correctly (`defaults read` verification)
- [ ] No regressions in system behavior
- [ ] All hosts can build and apply configuration
- [ ] Rollback works (git revert)

______________________________________________________________________

## Metrics

Track these metrics throughout implementation:

| Metric | Current | Target | Actual |
|--------|---------|--------|--------|
| Topic modules created | 0 | 12 | TBD |
| Settings in original defaults.nix | ~50 | 0 (moved) | TBD |
| Settings migrated from system.sh | 0 | ~250 | TBD |
| Unresolved settings | 0 | \<50 | TBD |
| Deprecated settings skipped | 0 | ~20 | TBD |
| Lines per module (max) | N/A | ≤200 | TBD |
| Build time (seconds) | TBD | \<300 | TBD |

______________________________________________________________________

## Next Steps

1. Use this data model to generate tasks.md with specific implementation steps
1. Create each topic module with header documentation
1. Extract and categorize settings from defaults.nix and system.sh
1. Implement migration mapping for each setting
1. Validate against rules defined above
