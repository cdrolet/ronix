# Data Model: GNOME Family System Integration

**Feature**: 028-gnome-family-system-integration\
**Date**: 2025-12-25\
**Phase**: 1 (Design & Contracts)

## Overview

This document defines the data structures, module organization, and configuration flow for the GNOME family system integration feature.

______________________________________________________________________

## Module Structure

### Family Directory Layout

```
system/shared/family/
├── linux/
│   ├── settings/
│   │   ├── default.nix          # Auto-discovery (no cross-imports)
│   │   └── keyboard.nix         # Linux-specific settings
│   └── app/
│       └── cli/
│           └── caligula.nix     # Linux-only apps
│           # NO default.nix - hierarchical discovery
│
└── gnome/
    ├── settings/
    │   ├── default.nix          # Auto-discovery (no cross-imports)
    │   ├── desktop/
    │   │   ├── default.nix      # Auto-discovery for desktop modules
    │   │   ├── gnome-core.nix   # Core desktop environment
    │   │   ├── gnome-optional.nix
    │   │   └── gnome-exclude.nix
    │   ├── wayland.nix
    │   ├── shortcuts.nix
    │   ├── keyboard.nix
    │   ├── ui.nix
    │   ├── power.nix
    │   ├── dock.nix
    │   └── keyring.nix
    └── app/
        └── utility/
            ├── gnome-tweaks.nix
            └── dconf-editor.nix
            # NO default.nix - hierarchical discovery
```

______________________________________________________________________

## Configuration Data Structures

### Host Configuration (Pure Data)

**Location**: `system/{platform}/host/{hostname}/default.nix`

```nix
{
  name = "nixos-workstation";
  family = ["linux" "gnome"];  # Multiple families compose
  applications = ["*"];         # Wildcard includes family apps
  settings = ["default"];
}
```

**Fields**:

- `name` (string): Unique host identifier
- `family` (list of strings): Family names to apply (order matters for search hierarchy)
- `applications` (list of strings): System-level applications (optional, usually in user config)
- `settings` (list of strings): System-level settings modules

### User Configuration (Pure Data)

**Location**: `user/{username}/default.nix`

```nix
{
  user = {
    name = "username";
    email = "user@example.com";
    fullName = "User Name";
    
    applications = [
      "git"
      "zsh"
      "gnome-tweaks"  # Family app (available if family in host)
      # OR wildcard:
      # "*"  # Includes all available apps (shared + platform + families in host)
    ];
  };
}
```

**Fields**:

- `applications` (list): Apps to install for this user
  - Strings: Specific app names
  - `"*"`: Wildcard - all discoverable apps (respects family hierarchy)

______________________________________________________________________

## Module Interfaces

### Settings Module Interface

**Pattern**: System-level configuration modules

```nix
# system/shared/family/gnome/settings/desktop/gnome-core.nix
{ config, lib, pkgs, ... }:
{
  # NixOS system options (platform-agnostic declaration)
  services.xserver.desktopManager.gnome.enable = lib.mkDefault true;
  services.gnome.core-apps.enable = lib.mkDefault true;
  
  # Platform lib translates to appropriate mechanism:
  # - NixOS: Uses services.xserver.*
  # - Other distros: Platform-specific implementation
}
```

**Interface Contract**:

- **Input**: Standard NixOS module arguments (`config`, `lib`, `pkgs`)
- **Output**: NixOS options (services.*, environment.*, etc.)
- **Platform**: Generic (no platform-specific code in family modules)
- **Defaults**: All options use `lib.mkDefault` (user-overridable)
- **Size**: \<200 lines per module (constitutional requirement)

### App Module Interface

**Pattern**: User-level configuration modules

```nix
# system/shared/family/gnome/app/utility/gnome-tweaks.nix
{ config, pkgs, lib, ... }:
{
  # User-level package installation
  home.packages = [ pkgs.gnome-tweaks ];
  
  # Optional: Desktop metadata
  programs.gnome-tweaks = {
    enable = lib.mkDefault true;
    desktop.paths.nixos = "${pkgs.gnome-tweaks}/bin/gnome-tweaks";
  };
}
```

**Interface Contract**:

- **Input**: Standard home-manager module arguments
- **Output**: home-manager options (home.packages, programs.\*, dconf.settings, etc.)
- **Platform**: Cross-platform (home-manager works on all Linux distros)
- **Discovery**: Hierarchical (no default.nix, discovered by platform lib)
- **Selection**: User-selected via `user.applications`

______________________________________________________________________

## Data Flow

### 1. Host Configuration Loading

```
Platform Lib (nixos.nix)
  ↓
Load host config: system/nixos/host/{hostname}/default.nix
  ↓
Extract pure data:
  - hostName = "nixos-workstation"
  - hostFamily = ["linux" "gnome"]
  - hostSettings = ["default"]
```

### 2. Family Settings Discovery

```
For each family in hostFamily:
  ↓
Discover settings: system/shared/family/{family}/settings/
  ↓
Auto-import via default.nix:
  - system/shared/family/linux/settings/default.nix → keyboard.nix
  - system/shared/family/gnome/settings/default.nix → desktop/, wayland.nix, etc.
  ↓
Import at SYSTEM LEVEL (not home-manager)
```

**Key Behavior**:

- Each family's `settings/default.nix` is **independent**
- NO cross-family imports (gnome does NOT import linux)
- Both families' settings imported because both in `hostFamily`

### 3. Family App Discovery

```
User declares: applications = ["gnome-tweaks"]
  ↓
Platform lib calls discovery.resolveApplications:
  callerPath = user/{username}/
  apps = ["gnome-tweaks"]
  families = ["linux" "gnome"]
  ↓
Hierarchical search (first match wins):
  1. system/{platform}/app/**/*
  2. system/shared/family/linux/app/**/*
  3. system/shared/family/gnome/app/**/*
  4. system/shared/app/**/*
  ↓
Found: system/shared/family/gnome/app/utility/gnome-tweaks.nix
  ↓
Import in home-manager for this user
```

**Key Behavior**:

- NO `default.nix` in `family/{name}/app/` directories
- Apps discovered hierarchically (like system apps)
- Apps loaded ONLY when user selects them
- Wildcard `"*"` includes family apps if family in host

### 4. Wildcard Expansion

```
User declares: applications = ["*"]
  ↓
Platform lib discovers ALL apps:
  - system/darwin/app/**/*.nix (if darwin)
  - system/shared/family/linux/app/**/*.nix (if "linux" in hostFamily)
  - system/shared/family/gnome/app/**/*.nix (if "gnome" in hostFamily)
  - system/shared/app/**/*.nix
  ↓
Returns: ["git" "zsh" "caligula" "gnome-tweaks" "dconf-editor" ...]
  ↓
All apps imported in home-manager
```

______________________________________________________________________

## Module Composition

### NixOS System Configuration

```nix
nixpkgs.lib.nixosSystem {
  modules = [
    # Hardware configuration
    ./hardware-configuration.nix
    
    # Family settings (auto-discovered)
    # Imported at SYSTEM LEVEL
    .../system/shared/family/linux/settings/default.nix
    .../system/shared/family/gnome/settings/default.nix
    
    # Platform settings
    .../system/nixos/settings/default.nix
    
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.users.${user} = {
        imports = [
          # User configuration
          .../user/${user}/default.nix
          
          # User-selected apps (including family apps)
          .../system/shared/family/gnome/app/utility/gnome-tweaks.nix
          # ... other apps based on user.applications
        ];
      };
    }
  ];
}
```

**Module Levels**:

1. **System level**: Family settings, platform settings, hardware config
1. **User level** (home-manager): User config, user-selected apps

______________________________________________________________________

## Discovery Algorithm

### Settings Discovery

```nix
# For each family in hostFamily
familyDefaults = families: basePath: let
  collectDefaults = family: let
    familyPath = basePath + "/system/shared/family/${family}";
    settingsDefault = familyPath + "/settings/default.nix";
  in
    lib.optional (builtins.pathExists settingsDefault) settingsDefault;
in
  lib.flatten (map collectDefaults families);

# Result for family = ["linux" "gnome"]:
# [
#   .../system/shared/family/linux/settings/default.nix
#   .../system/shared/family/gnome/settings/default.nix
# ]
```

### App Discovery

```nix
# Hierarchical app resolution
resolveApplications = { apps, callerPath, basePath, system, families }: let
  # Search paths (order matters - first match wins)
  searchPaths = [
    "${basePath}/system/${system}/app"
  ] ++ (map (f: "${basePath}/system/shared/family/${f}/app") families)
    ++ [
    "${basePath}/system/shared/app"
  ];
  
  # For each app name, search in order
  resolveApp = appName: let
    findInPaths = paths:
      if paths == [] then null
      else if (findModuleInDir (head paths) appName) != null
        then findModuleInDir (head paths) appName
        else findInPaths (tail paths);
  in findInPaths searchPaths;
in
  map resolveApp apps;
```

**Hierarchical Search Order**:

1. `system/{platform}/app/**/*`
1. `system/shared/family/{family1}/app/**/*`
1. `system/shared/family/{family2}/app/**/*`
1. `system/shared/app/**/*`

First match wins (no merging).

______________________________________________________________________

## State Management

### Build-Time State

**Configuration State** (Pure, Immutable):

- Host configuration: `{ name, family, applications, settings }`
- User configuration: `{ user.name, user.applications, ... }`
- Discovered paths: List of .nix file paths

**Evaluation State** (During Nix evaluation):

- Module system combines all imported modules
- Options set via `lib.mkDefault` (overridable)
- Final configuration evaluated to derivations

### Runtime State

**System State** (NixOS):

- `/etc/nixos/configuration.nix` symlink (system generation)
- `/run/current-system` (active configuration)
- GNOME desktop environment installed system-wide

**User State** (home-manager):

- `~/.config/` (dconf settings, GTK themes)
- `~/.nix-profile` (user packages)
- Per-user GNOME customizations

______________________________________________________________________

## Validation Rules

### 1. Family Existence Validation

```nix
validateFamilyExists = families: basePath:
  lib.all (family:
    builtins.pathExists (basePath + "/system/shared/family/${family}")
  ) families;

# Assert in platform lib:
assert hostFamily != [] -> validateFamilyExists hostFamily repoRoot;
```

### 2. No default.nix in family/\*/app/

```nix
validateNoAppDefaults = basePath:
  let
    familyAppDirs = builtins.readDir (basePath + "/system/shared/family");
    checkFamily = family:
      ! builtins.pathExists (
        basePath + "/system/shared/family/${family}/app/default.nix"
      );
  in
    lib.all checkFamily (builtins.attrNames familyAppDirs);

# Assert during build:
assert validateNoAppDefaults repoRoot;
```

### 3. Module Size Limit

```nix
# Constitutional requirement: <200 lines per module
validateModuleSize = modulePath:
  let
    content = builtins.readFile modulePath;
    lines = lib.splitString "\n" content;
    lineCount = builtins.length lines;
  in
    assert lineCount < 200
      || throw "Module ${modulePath} exceeds 200 lines (${toString lineCount})";
```

______________________________________________________________________

## Cross-Platform Considerations

### Platform-Agnostic Family Modules

**Family modules declare intent, not implementation**:

```nix
# GOOD: Platform-agnostic (in family module)
services.xserver.desktopManager.gnome.enable = lib.mkDefault true;

# BAD: Platform-specific code (don't do this in family)
if pkgs.stdenv.isLinux then
  services.xserver.desktopManager.gnome.enable = true
else
  throw "GNOME only works on Linux";
```

**Platform lib handles translation**:

```nix
# NixOS platform lib (system/nixos/lib/nixos.nix)
# Accepts family settings modules with services.* options
# Translates to NixOS system configuration

# Kali platform lib (future: system/kali/lib/kali.nix)
# Might translate services.xserver.* to apt packages
# Implementation TBD
```

______________________________________________________________________

## Performance Considerations

### Evaluation Performance

**Discovery Optimization**:

- Cache discovered module paths (no re-scanning)
- Use `builtins.pathExists` checks before imports
- Lazy evaluation of family modules (only if family in host)

**Module Import Optimization**:

- Import only selected apps (not all discovered apps)
- Auto-discovery uses `map` (lazy) not eager iteration
- Wildcard expansion cached per user

### Build Performance

**Shared Derivations**:

- GNOME desktop packages shared across users
- System-level installation reduces duplication
- Family settings evaluated once per system

______________________________________________________________________

## Security Considerations

### Secrets Management

**NOT in family modules**:

- Family modules should not contain secrets
- Use agenix for secrets: `user/{username}/secrets.age`
- Family modules can reference secrets via `config.age.secrets.*`

### System-Level Permissions

**GNOME desktop installation**:

- Requires system-level configuration (root privileges)
- Family settings imported at system level (trusted)
- User apps run with user privileges only

______________________________________________________________________

## Error Handling

### Invalid Family Reference

```nix
# User declares: family = ["nonexistent"]
# Error: Family 'nonexistent' does not exist at system/shared/family/nonexistent
# Validation: validateFamilyExists assertion fails
```

### App Not Found

```nix
# User declares: applications = ["missing-app"]
# Error: Application 'missing-app' not found in search paths
# Fallback: resolveApplications returns null, filtered out
```

### Module Evaluation Errors

```nix
# Module has syntax error
# Error: Nix evaluation fails with parse error
# Validation: nix flake check catches before deployment
```

______________________________________________________________________

## Migration Path

### From Current State

**Current**: `gnome/app/default.nix` exists with auto-discovery

**Migration Step 1**: Delete `gnome/app/default.nix`

```bash
rm system/shared/family/gnome/app/default.nix
rm system/shared/family/linux/app/default.nix  # if exists
```

**Migration Step 2**: Verify hierarchical discovery

```nix
# Test that apps still resolve:
nix eval .#darwinConfigurations.cdrokar-home-macmini-m4.config.home-manager.users.cdrokar.home.packages
```

**Migration Step 3**: Test wildcard includes family apps

```nix
# Host with family = ["gnome"]
# User with applications = ["*"]
# Should include gnome-tweaks, dconf-editor
```

### To Future State

**Future**: Other Linux distros (Kali, Ubuntu)

**Extension Point**: Create platform lib for new distro

```nix
# system/kali/lib/kali.nix
# Translates family settings to Kali-specific commands
# Families remain unchanged (platform-agnostic)
```

______________________________________________________________________

## Summary

**Key Design Decisions**:

1. **No default.nix in family/\*/app/** - Apps discovered hierarchically like system apps
1. **Independent family settings** - Each family's default.nix auto-discovers only its own modules
1. **System-level settings import** - Family settings imported at system level (not home-manager)
1. **User-level app import** - Family apps imported in home-manager when user selects them
1. **Platform-agnostic families** - Generic configuration, platform libs translate

**Data Flow**:

```
Host declares families → Settings auto-discovered → Imported at system level
User selects apps → Apps resolved hierarchically → Imported in home-manager
```

**Validation**:

- Family existence checked at evaluation
- No default.nix in app/ directories enforced
- Module size \<200 lines (constitutional)
