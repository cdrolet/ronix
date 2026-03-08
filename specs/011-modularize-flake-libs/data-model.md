# Data Model: Modularize Flake Configuration Libraries

**Feature**: 011-modularize-flake-libs\
**Date**: 2025-11-01\
**Status**: Complete

## Overview

This feature involves minimal data modeling - primarily structural entities representing discovery results and helper function signatures. No domain data or persistent storage involved.

______________________________________________________________________

## Entity 1: Discovered User

**Purpose**: Represents a user configuration discovered from the directory structure

**Structure**:

```nix
{
  name = "cdrokar";                    # String: directory name
  path = /path/to/nix-config/user/cdrokar;  # Path: absolute path to user directory
  hasDefault = true;                   # Boolean: user/cdrokar/default.nix exists
}
```

**Discovery Logic**:

```nix
# Scan user/ directory
basePath = ./user;
entries = builtins.readDir basePath;  # { cdrokar = "directory"; cdrolet = "directory"; ... }

# Filter for directories with default.nix
discoveredUsers = builtins.attrNames (
  lib.filterAttrs (name: type:
    type == "directory" &&
    builtins.pathExists (basePath + "/${name}/default.nix")
  ) entries
);
# Result: [ "cdrokar" "cdrolet" "cdrixus" ]
```

**Validation**:

- `type == "directory"`: Ensures only directories are considered
- `builtins.pathExists`: Verifies `default.nix` exists
- Invalid Nix syntax in `default.nix` will cause flake evaluation error (acceptable fail-fast behavior)

**Usage**:

- Exported in `flake.outputs.validUsers` for justfile validation
- Used to generate user-profile combinations for configurations
- Passed to helper functions as `user` parameter

______________________________________________________________________

## Entity 2: Discovered Profile

**Purpose**: Represents a system profile discovered from platform-specific directory structure

**Structure**:

```nix
{
  name = "home-macmini-m4";            # String: directory name
  platform = "darwin";                 # String: parent platform (darwin/nixos)
  path = /path/to/nix-config/system/darwin/profiles/home-macmini-m4;  # Path: absolute path
  hasDefault = true;                   # Boolean: has default.nix
}
```

**Discovery Logic**:

```nix
# Scan platform-specific profiles directory
discoverProfiles = platform:
  let
    basePath = ./system/${platform}/profiles;
    entries = builtins.readDir basePath;
  in
    builtins.attrNames (
      lib.filterAttrs (name: type:
        type == "directory" &&
        builtins.pathExists (basePath + "/${name}/default.nix")
      ) entries
    );

darwinProfiles = discoverProfiles "darwin";
# Result: [ "home-macmini-m4" "work" ]

nixosProfiles = discoverProfiles "nixos";
# Result: [] (currently no nixos profiles exist)
```

**Validation**:

- Same pattern as user discovery
- Platform-specific paths ensure darwin/nixos profiles don't mix
- Empty lists acceptable (future-proofing for platforms not yet implemented)

**Usage**:

- Exported in `flake.outputs.validProfiles` keyed by platform
- Used to generate user-profile combinations for platform
- Passed to helper functions as `profile` parameter

______________________________________________________________________

## Entity 3: Configuration Combination

**Purpose**: Represents a valid user-profile pairing that becomes a system configuration

**Structure**:

```nix
{
  name = "cdrokar-home-macmini-m4";    # String: configuration name (user-profile format)
  user = "cdrokar";                    # String: discovered user
  profile = "home-macmini-m4";         # String: discovered profile
  platform = "darwin";                 # String: inferred from profile location
  system = "aarch64-darwin";           # String: target architecture (default or explicit)
}
```

**Generation Logic**:

```nix
# Generate all valid user-profile combinations for darwin
let
  users = [ "cdrokar" "cdrolet" "cdrixus" ];
  darwinProfiles = [ "home-macmini-m4" "work" ];
  
  # Specific combinations (not full cartesian product)
  darwinCombinations = [
    { user = "cdrokar"; profile = "home-macmini-m4"; }
    { user = "cdrokar"; profile = "work"; }
    { user = "cdrolet"; profile = "work"; }
    { user = "cdrixus"; profile = "home-macmini-m4"; }
  ];
  
  # Convert to attrset for flake outputs
  darwinConfigs = builtins.listToAttrs (
    map (cfg: {
      name = "${cfg.user}-${cfg.profile}";
      value = darwinLib.mkDarwinConfig cfg;
    }) darwinCombinations
  );
in
{
  darwinConfigurations = darwinConfigs;
}
```

**Naming Convention**:

- Format: `{user}-{profile}`
- Examples: `cdrokar-home-macmini-m4`, `cdrolet-work`
- Ensures unique names across all platforms
- CLI-friendly: `nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system`

**Usage**:

- Becomes flake output configuration
- Used by `darwin-rebuild` and `nix build` commands
- Visible in `nix flake show` output

______________________________________________________________________

## Entity 4: Helper Function (mkDarwinConfig)

**Purpose**: Constructs a complete nix-darwin system configuration from user and profile parameters

**Function Signature**:

```nix
mkDarwinConfig :: {
  user :: String,           # Discovered user name
  profile :: String,        # Discovered profile name
  system :: String          # Optional: target architecture (default "aarch64-darwin")
} -> Derivation            # nix-darwin system derivation
```

**Implementation Structure**:

```nix
# system/darwin/lib/darwin.nix
{ inputs, ... }:
{
  mkDarwinConfig = { user, profile, system ? "aarch64-darwin" }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        # System profile: settings + platform apps
        ../profiles/${profile}
        
        # Multi-user support: set primary user for system.defaults
        { system.primaryUser = user; }
        
        # Home Manager integration
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = {
            # User config: app selections + overrides
            imports = [ ../../../user/${user} ];
          };
        }
      ];
    };
}
```

**Inputs**:

- `user`: String name from discovered users (e.g., "cdrokar")
- `profile`: String name from discovered profiles (e.g., "home-macmini-m4")
- `system`: Optional architecture string (defaults to aarch64-darwin)

**Outputs**:

- Complete nix-darwin system derivation
- Includes: system settings, apps, Home Manager integration, user config

**Dependencies**:

- `inputs.nix-darwin.lib.darwinSystem`: nix-darwin builder
- `inputs.home-manager.darwinModules.home-manager`: Home Manager module
- Profile module: `system/darwin/profiles/${profile}/default.nix`
- User module: `user/${user}/default.nix`

**Path Resolution**:

- Relative paths from `system/darwin/lib/darwin.nix`:
  - `../profiles/${profile}` → `system/darwin/profiles/${profile}`
  - `../../../user/${user}` → `user/${user}`

______________________________________________________________________

## Entity 5: Helper Function (mkNixosConfig)

**Purpose**: Constructs a complete NixOS system configuration (future implementation)

**Function Signature**:

```nix
mkNixosConfig :: {
  user :: String,           # Discovered user name
  profile :: String,        # Discovered profile name
  system :: String          # Optional: target architecture (default "x86_64-linux")
} -> Derivation            # NixOS system derivation
```

**Implementation Structure** (placeholder):

```nix
# system/nixos/lib/nixos.nix
{ inputs, ... }:
{
  mkNixosConfig = { user, profile, system ? "x86_64-linux" }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        # NixOS profile: system config
        ../profiles/${profile}
        
        # Home Manager integration (NixOS module)
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = {
            imports = [ ../../../user/${user} ];
          };
        }
      ];
    };
}
```

**Status**: Placeholder (NixOS profiles currently empty)

______________________________________________________________________

## Entity 6: Helper Function (mkHomeConfig)

**Purpose**: Constructs standalone Home Manager configuration (for non-NixOS Linux)

**Function Signature**:

```nix
mkHomeConfig :: {
  user :: String,           # Discovered user name
  system :: String          # Target architecture
} -> Derivation            # Home Manager configuration derivation
```

**Implementation Structure** (merged with bootstrap module):

```nix
# user/shared/lib/home-manager.nix
{ config, pkgs, lib, inputs, ... }:

{
  # Existing bootstrap module options and config...
  options = { ... };
  config = { ... };
  
  # NEW: Exported helper for standalone Home Manager
  mkHomeConfig = { user, system }:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      modules = [
        ../${user}  # User config (relative to lib location)
      ];
      extraSpecialArgs = { inherit inputs; };
    };
}
```

**Note**: This merges the standalone helper with the existing bootstrap module, keeping all Home Manager logic in one file.

**Status**: Placeholder (standalone Home Manager currently empty)

______________________________________________________________________

## Entity Relationships

```text
┌─────────────────┐
│ Discovered User │  (from user/ directory scan)
└────────┬────────┘
         │
         │ paired with
         │
         ▼
┌─────────────────────┐
│ Discovered Profile  │  (from system/{platform}/profiles/ scan)
└────────┬────────────┘
         │
         │ creates
         │
         ▼
┌─────────────────────────┐
│ Configuration          │  (user-profile combination)
│ Combination            │
└────────┬────────────────┘
         │
         │ passed to
         │
         ▼
┌─────────────────────────┐
│ Helper Function        │  (mkDarwinConfig / mkNixosConfig / mkHomeConfig)
│ (in platform lib)      │
└────────┬────────────────┘
         │
         │ produces
         │
         ▼
┌─────────────────────────┐
│ System Derivation      │  (nix-darwin / nixos / home-manager)
└─────────────────────────┘
```

______________________________________________________________________

## Data Transformations

### Discovery Flow

```text
1. Directory Scan
   ./user/* → builtins.readDir → { "cdrokar" = "directory"; "cdrolet" = "directory"; ... }

2. Filtering
   Filter entries → Check for default.nix → [ "cdrokar", "cdrolet", "cdrixus" ]

3. Export
   validUsers = [ "cdrokar", "cdrolet", "cdrixus" ]
```

### Configuration Generation Flow

```text
1. Combination Definition
   users = [ "cdrokar", "cdrolet", "cdrixus" ]
   profiles = [ "home-macmini-m4", "work" ]
   combinations = [ {user="cdrokar", profile="home-macmini-m4"}, ... ]

2. Name Generation
   map (cfg => "${cfg.user}-${cfg.profile}") → [ "cdrokar-home-macmini-m4", ... ]

3. Config Generation
   map (cfg => darwinLib.mkDarwinConfig cfg) → [ <derivation>, <derivation>, ... ]

4. Attrset Conversion
   builtins.listToAttrs → { cdrokar-home-macmini-m4 = <derivation>; ... }

5. Export
   darwinConfigurations = { cdrokar-home-macmini-m4 = <derivation>; ... }
```

______________________________________________________________________

## Validation Rules

### User Validation

- MUST be directory in `user/`
- MUST contain `default.nix`
- Name MUST match directory name
- MUST be valid Nix module (syntax errors fail flake evaluation)

### Profile Validation

- MUST be directory in `system/{platform}/profiles/`
- MUST contain `default.nix`
- Name MUST match directory name
- MUST be valid Nix module
- MUST set `system.stateVersion` (nix-darwin requirement)

### Configuration Validation

- User MUST exist in discovered users
- Profile MUST exist in discovered profiles for that platform
- User-profile combination MUST be explicitly defined (not all combinations valid)
- Configuration name MUST be unique across all platforms

______________________________________________________________________

## State Management

**All state is implicit in directory structure**:

- No database or persistent storage
- Directory presence = entity exists
- File presence (`default.nix`) = entity valid
- Changes to directories immediately reflected on next flake evaluation

**Nix Caching**:

- Flake evaluation results cached by Nix
- Directory contents cached (invalidated on file system changes)
- Derivations cached (only rebuilt if inputs change)

______________________________________________________________________

## Example Data Flow

**Scenario**: Add new user "testuser"

```text
1. File System Change
   mkdir user/testuser
   echo '{ }' > user/testuser/default.nix

2. Discovery (on next flake eval)
   builtins.readDir ./user → includes "testuser"
   Filter → "testuser" has default.nix → included

3. Export
   validUsers = [ "cdrokar", "cdrolet", "cdrixus", "testuser" ]

4. Configuration Generation (if defined)
   Combination: { user = "testuser"; profile = "home-macmini-m4"; }
   Name: "testuser-home-macmini-m4"
   Config: darwinLib.mkDarwinConfig { user = "testuser"; profile = "home-macmini-m4"; }

5. Available in Flake
   nix flake show → includes darwinConfigurations.testuser-home-macmini-m4
   just list-users → includes "testuser"
```

______________________________________________________________________

## Constraints and Assumptions

**Constraints**:

- User/profile names MUST be valid Nix identifiers (alphanumeric + dash/underscore)
- Directory structure MUST match expectations (user/, system/{platform}/profiles/)
- `default.nix` files MUST be valid Nix modules
- No spaces or special characters in names (bash-friendly)

**Assumptions**:

- Small scale: \<100 users, \<20 profiles per platform
- Directory operations are fast (filesystem cached)
- Flake evaluation happens infrequently (on-demand, not continuous)
- Invalid modules fail evaluation immediately (acceptable error behavior)

______________________________________________________________________

## Summary

This data model is structural and lightweight:

- **Entities**: Discovered users, profiles, configurations, helper functions
- **Storage**: Implicit in directory structure
- **Validation**: Built into discovery logic
- **Transformations**: Pure functional (readDir → filter → map → listToAttrs)
- **State**: Stateless (directory presence = current state)

All entities are derived from filesystem structure and transformed through pure Nix functions into flake outputs.
