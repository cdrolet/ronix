# Pure Data Application Configuration

**Feature**: 020-app-array-config\
**Status**: ✅ Active\
**Since**: 2025-11-30\
**Updated**: 2025-12-02 (Pure Data Pattern)

## Overview

User configurations are now pure data - no imports, no helper functions, just configuration. Platform libraries automatically handle all application imports based on the `user.applications` array.

## Quick Start

### Basic Usage

Simply declare your applications in the user configuration:

```nix
{ ... }:

{
  user = {
    name = "myusername";
    email = "my@email.com";
    fullName = "My Full Name";
    
    applications = [
      "git"
      "zsh"
      "helix"
    ];
  };
}
```

That's it! No imports needed.

### Import All Applications

Use the wildcard pattern to import all available applications:

```nix
{ ... }:

{
  user = {
    name = "myusername";
    email = "my@email.com";
    fullName = "My Full Name";
    applications = [ "*" ];  # Imports everything
  };
}
```

## Benefits

### Evolution of the Pattern

**Original Pattern** (13 lines):

```nix
{ config, pkgs, lib, userContext, ... }:

{
  imports =
    let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      ../shared/lib/home-manager.nix
      (discovery.mkApplicationsModule {
        applications = [ "git" "zsh" "helix" ];
        user = userContext.user;
        platform = userContext.platform;
        profile = userContext.profile;
      })
    ];
  
  user = { name = "myusername"; ... };
}
```

**Pure Data Pattern** (7 lines):

```nix
{ ... }:

{
  user = {
    name = "myusername";
    applications = [ "git" "zsh" "helix" ];
  };
}
```

**Result**: 56% reduction in code, zero Nix knowledge required!

## Features

### ✅ Fully Automatic

- **No imports needed**: Platform libs handle everything
- **No helper functions**: Just declare your data
- **No discovery knowledge**: The system figures it out
- **No let bindings**: Pure configuration only

### ✅ All Discovery Features Preserved

Platform libraries use the discovery system automatically, providing:

- **Application validation**: Typos are caught with helpful error messages
- **Platform awareness**: Platform-specific apps work seamlessly
- **Wildcard support**: `[ "*" ]` imports all available applications
- **Error handling**: Clear messages when apps don't exist

### ✅ DRY Principle

Applications declared once in the `user.applications` array. No need to duplicate in imports or other locations.

### ✅ 100% Backward Compatible

The old pattern with explicit discovery imports still works. This is purely additive.

## How It Works

Behind the scenes, platform libraries (darwin.nix, nixos.nix) implement this flow:

1. **Load user config as pure data**:

   ```nix
   userData = import ../../../user/${user} { };
   ```

1. **Extract applications before module evaluation**:

   ```nix
   userApps = userData.user.applications or [];
   ```

1. **Generate application imports**:

   ```nix
   appsModule = discovery.mkApplicationsModule {
     inherit lib;
     applications = userApps;
   };
   ```

1. **Combine in home-manager**:

   ```nix
   home-manager.users.${user}.imports = [
     userData            # Pure user data
     appsModule          # Generated imports
     home-manager.nix    # Bootstrap
   ];
   ```

This avoids the infinite recursion problem because data extraction happens **before** the module system evaluates config.

## Complete Example

### Development Environment

```nix
{ ... }:

{
  user = {
    name = "developer";
    email = "dev@example.com";
    fullName = "Senior Developer";
    
    # Locale preferences
    languages = [ "en-CA" "fr-CA" ];
    keyboardLayout = [ "us" "canadian-french" ];
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
    
    # Development applications
    applications = [
      # Version control
      "git"
      
      # Shell environment
      "zsh"
      "starship"
      "bat"
      "atuin"
      
      # Editors
      "helix"
      "vscode"
      
      # Languages
      "python"
      "nodejs"
      "rust"
      
      # Tools
      "docker"
      
      # macOS-specific (auto-skipped on other platforms)
      "aerospace"
    ];
  };
}
```

### Minimal Configuration

```nix
{ ... }:

{
  user = {
    name = "minimalist";
    email = "min@example.com";
    fullName = "Min User";
    applications = [ "git" ];  # Just git
  };
}
```

### Power User (Import Everything)

```nix
{ ... }:

{
  user = {
    name = "poweruser";
    email = "power@example.com";
    fullName = "Power User";
    applications = [ "*" ];  # All available apps
  };
}
```

## Migration Guide

### From Old Pattern

**Old** (explicit discovery):

```nix
{ config, pkgs, lib, userContext, ... }:

{
  imports =
    let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      ../shared/lib/home-manager.nix
      (discovery.mkApplicationsModule {
        applications = [ "git" "zsh" "helix" ];
        user = userContext.user;
        platform = userContext.platform;
        profile = userContext.profile;
      })
    ];
  
  user = {
    name = "username";
    email = "user@email.com";
    fullName = "User Name";
  };
}
```

**New** (pure data):

```nix
{ ... }:

{
  user = {
    name = "username";
    email = "user@email.com";
    fullName = "User Name";
    applications = [ "git" "zsh" "helix" ];
  };
}
```

### Migration Steps

1. Remove all function parameters except `{ ... }`
1. Remove `imports` section completely
1. Move applications array to `user.applications`
1. Remove any `let` bindings for mkApps or discovery
1. Test with `nix flake check` or build

That's it!

## Troubleshooting

### Error: "Application 'foo' not found"

**Problem**: Application doesn't exist in the registry

**Solution**: Check available apps in `platform/shared/app/` and `platform/{platform}/app/`. Fix typo or add the app module.

### Error: "attribute 'applications' missing"

**Problem**: Forgot to add applications field

**Solution**: Add `applications = [ ... ];` to your user configuration, or use `applications = null;` for no apps.

### Platform-Specific Apps Don't Load

**Behavior**: This is intentional and correct!

Platform-specific apps (like `aerospace` on Darwin) are automatically skipped on unsupported platforms. No error is raised - the system gracefully handles cross-platform configs.

### Old Pattern Still in Use

**Situation**: Existing configs with explicit discovery imports

**Status**: ✅ Still works! Backward compatible.

The old pattern continues to work. Migration is optional but recommended for cleaner configs.

## Technical Details

### Why This Works (No Infinite Recursion)

The key insight: we extract `user.applications` **before** module evaluation.

**Blocked approach** (infinite recursion):

```nix
# ❌ FAILS: Referencing config in imports
imports = lib.optionals (config.user.applications != null) [
  (mkApps config.user.applications)
];
```

**Pure data approach** (works):

```nix
# ✅ WORKS: Extract before module eval
let
  userData = import ./user.nix { };
  apps = userData.user.applications;  # Simple attribute access
in {
  imports = [ userData (mkApps apps) ];
}
```

The difference: `userData.user.applications` is plain attribute access on an imported file, not `config.user.applications` through the module system.

### Architecture

```
User Config (Pure Data)
    ↓
Platform Lib Loads File
    ↓
Extract .user.applications
    ↓
Generate mkApplicationsModule
    ↓
Combine in home-manager.users.${user}.imports
    ↓
Module System Evaluates
```

## See Also

- [Discovery System](../../platform/shared/lib/discovery.nix) - Application discovery internals
- [Darwin Platform Lib](../../platform/darwin/lib/darwin.nix) - Implementation reference
- [Feasibility Analysis](../../specs/020-app-array-config/FEASIBILITY-PURE-DATA.md) - Technical research
- [Feature Spec](../../specs/020-app-array-config/spec.md) - Full specification
