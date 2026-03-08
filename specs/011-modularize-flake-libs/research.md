# Research: Modularize Flake Configuration Libraries

**Feature**: 011-modularize-flake-libs\
**Date**: 2025-11-01\
**Status**: Complete

## Overview

This document consolidates research findings for modularizing flake.nix configuration by implementing auto-discovery of users/profiles and moving platform-specific helpers to lib files.

______________________________________________________________________

## R1: Nix Directory Scanning in Flakes

### Decision: Use `builtins.readDir` with filtering

**Pattern**:

```nix
let
  # Read directory and filter for subdirectories with default.nix
  discoverUsers = basePath:
    let
      entries = builtins.readDir basePath;
      # Filter for directories only
      dirs = lib.filterAttrs (name: type: type == "directory") entries;
      # Check each directory for default.nix
      hasDefault = name:
        builtins.pathExists (basePath + "/${name}/default.nix");
    in
      builtins.attrNames (lib.filterAttrs (name: _: hasDefault name) dirs);

  users = discoverUsers ./user;
  # Result: [ "cdrokar" "cdrolet" "cdrixus" ]
in
```

**Rationale**:

- `builtins.readDir` returns attrset: `{ name = "directory"|"regular"|"symlink"|... }`
- Pure function, deterministic (same dirs → same output)
- Fast: directory listing is O(n) where n = number of entries
- Already used in nixpkgs for similar discovery patterns

**Performance**:

- Minimal overhead: directory listing is cached by Nix
- Benchmarks from nixpkgs show \<100ms for hundreds of entries
- Our use case: \<10 users, \<10 profiles per platform → negligible

**Error Handling**:

- `builtins.pathExists` safely checks for default.nix (returns false if missing)
- Invalid Nix files will cause flake evaluation errors (fail-fast is acceptable)
- Missing directories handled by readDir (empty attrset)

**Alternatives Considered**:

- ❌ Manual list maintenance: Rejected (defeats purpose of auto-discovery)
- ❌ External script scanning: Rejected (violates purity, requires IFD)
- ✅ builtins.readDir: Standard Nix approach, pure, fast

______________________________________________________________________

## R2: Flake Lib Module Patterns

### Decision: Export attrset with functions

**Pattern** (from nix-darwin, home-manager):

```nix
# system/darwin/lib/darwin.nix
{ inputs, lib, ... }:

{
  # Primary export: configuration builder
  mkDarwinConfig = { user, profile, system ? "aarch64-darwin" }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./profiles/${profile}
        {
          system.primaryUser = user;
          # ... rest of config
        }
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = {
            imports = [ ../../user/${user} ];
          };
        }
      ];
    };
  
  # Optional: additional utilities
  darwinUtils = {
    # Helper functions specific to darwin
  };
}
```

**Usage in flake.nix**:

```nix
let
  darwinLib = import ./system/darwin/lib/darwin.nix {
    inherit inputs lib;
  };
in
{
  darwinConfigurations = {
    cdrokar-home-macmini-m4 = darwinLib.mkDarwinConfig {
      user = "cdrokar";
      profile = "home-macmini-m4";
    };
    # ... more configs
  };
}
```

**Rationale**:

- Attrset export allows multiple functions (mkDarwinConfig + utilities)
- Passing `inputs` gives access to nixpkgs, nix-darwin, home-manager
- Relative paths work from lib file location (`./profiles/${profile}`)
- Pattern matches nixpkgs/flake-utils library structure

**Input Passing**:

- Flake inputs must be passed explicitly: `{ inherit inputs; }`
- Can also pass `lib` for utility functions
- `specialArgs` makes inputs available to imported modules

**Alternatives Considered**:

- ❌ Single function export: Rejected (limits extensibility)
- ❌ Nested imports: Rejected (complicates path resolution)
- ✅ Attrset with functions: Standard Nix flake pattern

______________________________________________________________________

## R3: Dynamic Configuration Generation

### Decision: Use `lib.genAttrs` with user×profile combinations

**Pattern**:

```nix
let
  # Auto-discovered lists
  users = [ "cdrokar" "cdrolet" "cdrixus" ];
  darwinProfiles = [ "home-macmini-m4" "work" ];
  
  # Generate all valid combinations
  darwinConfigs = lib.flatten (
    map (user:
      map (profile: {
        name = "${user}-${profile}";
        value = darwinLib.mkDarwinConfig { inherit user profile; };
      }) darwinProfiles
    ) users
  );
  
  # Convert list to attrset
  darwinConfigsAttr = builtins.listToAttrs darwinConfigs;
in
{
  darwinConfigurations = darwinConfigsAttr;
}
```

**Simpler Pattern** (if specific combinations needed):

```nix
let
  # Only generate specific combinations
  darwinConfigs = [
    { user = "cdrokar"; profile = "home-macmini-m4"; }
    { user = "cdrokar"; profile = "work"; }
    { user = "cdrolet"; profile = "work"; }
    { user = "cdrixus"; profile = "home-macmini-m4"; }
  ];
in
{
  darwinConfigurations = builtins.listToAttrs (
    map (cfg:
      {
        name = "${cfg.user}-${cfg.profile}";
        value = darwinLib.mkDarwinConfig cfg;
      }
    ) darwinConfigs
  );
}
```

**Rationale**:

- `lib.genAttrs` / `builtins.listToAttrs` are standard for dynamic attrsets
- Cartesian product (user×profile) can be full or filtered
- Name format `user-profile` matches existing conventions
- Easy to add logic (e.g., only certain users get certain profiles)

**Performance**:

- O(users × profiles) - acceptable for small numbers (\<100 total)
- Nix lazy evaluation: configs only built when requested
- Flake metadata generation is fast

**Alternatives Considered**:

- ❌ Manual config definitions: Rejected (defeats auto-discovery)
- ❌ Nested attrsets: Rejected (complicates CLI usage)
- ✅ Flat attrset with user-profile names: Standard, user-friendly

______________________________________________________________________

## R4: Current mkDarwinConfig Analysis

### Existing Implementation (flake.nix lines 71-97)

```nix
mkDarwinConfig = {
  user,
  profile,
  system ? "aarch64-darwin",
}:
  nix-darwin.lib.darwinSystem {
    inherit system;
    specialArgs = {inherit inputs;};
    modules = [
      # System profile (includes system settings + apps)
      ./system/darwin/profiles/${profile}

      # Set primary user for nix-darwin multi-user support
      {
        # Primary user for system.defaults that affect user preferences
        system.primaryUser = user;
      }

      # Home Manager integration
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${user} = {
          imports = [
            # User configuration (includes user-specific apps)
            ./user/${user}
          ];
        };
      }
    ];
  };
```

### What Must Be Preserved

**Critical Behaviors**:

1. Accept `{ user, profile, system? }` parameters
1. Call `nix-darwin.lib.darwinSystem` with proper args
1. Import profile from `./system/darwin/profiles/${profile}`
1. Set `system.primaryUser = user` (multi-user support)
1. Integrate Home Manager with `useGlobalPkgs` and `useUserPackages`
1. Import user config from `./user/${user}`
1. Pass flake inputs via `specialArgs`

**Path Resolution**:

- Current: relative to flake.nix root
- In lib file: must adjust to be relative to darwin.nix location
- Solution: Use `../../` to go up from `system/darwin/lib/` to root

**Migration Strategy**:

```nix
# system/darwin/lib/darwin.nix
{ inputs, ... }:
{
  mkDarwinConfig = { user, profile, system ? "aarch64-darwin" }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        # Path adjusted: ../profiles/${profile} from lib/darwin.nix
        ../profiles/${profile}
        
        { system.primaryUser = user; }
        
        inputs.home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.${user} = {
            # Path adjusted: ../../../user/${user} from lib/darwin.nix
            imports = [ ../../../user/${user} ];
          };
        }
      ];
    };
}
```

**Testing Equivalence**:

- Compare derivation outputs before/after
- Build all 4 configs and verify success
- Check flake show output matches

______________________________________________________________________

## Additional Research Findings

### Justfile Integration

Current justfile likely uses hardcoded lists or flake outputs. After refactor:

```bash
# justfile can access auto-discovered lists
list-users:
  nix eval .#validUsers --json | jq -r '.[]'

list-profiles platform:
  nix eval .#validProfiles.{{platform}} --json | jq -r '.[]'
```

If justfile currently hardcodes, it should be updated to use flake outputs.

### Platform-Specific Discovery

**Pattern for multi-platform profiles**:

```nix
let
  discoverProfiles = platform:
    discoverUsers ./system/${platform}/profiles;
    
  darwinProfiles = discoverProfiles "darwin";
  nixosProfiles = discoverProfiles "nixos";
in
{
  validProfiles = {
    darwin = darwinProfiles;
    linux = nixosProfiles;  # Note: "linux" alias for nixos
  };
}
```

______________________________________________________________________

## Technology Stack Summary

**Core Technologies**:

- Nix 2.19+ (flakes, builtins.readDir)
- nix-darwin 25.11+ (darwinSystem API)
- home-manager (homeManagerConfiguration API)

**Patterns**:

- Directory scanning: `builtins.readDir + lib.filterAttrs`
- Dynamic attrsets: `builtins.listToAttrs + map`
- Lib modules: Attrset exports with function bindings

**No New Dependencies**: All functionality built on existing Nix/nixpkgs features

______________________________________________________________________

## Decisions Summary

| Question | Decision | Rationale |
|----------|----------|-----------|
| How to discover users/profiles? | `builtins.readDir` with filtering | Pure, fast, standard Nix pattern |
| How to structure lib modules? | Attrset export with functions | Matches nixpkgs/flake-utils patterns |
| How to generate configs dynamically? | `builtins.listToAttrs + map` | Standard for dynamic attrsets |
| How to preserve mkDarwinConfig behavior? | Direct port with path adjustments | Maintain exact same functionality |
| How to handle platform differences? | Platform-specific lib files | Isolate concerns, follow directory structure |

______________________________________________________________________

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing configs | Port logic exactly, test all 4 configs |
| Path resolution errors | Test relative paths carefully, use ../ |
| Discovery picks up invalid dirs | Require default.nix, validate imports |
| Performance degradation | Benchmark with 10+ users, rely on Nix caching |
| Flake evaluation errors | Clear error messages, fail-fast acceptable |

______________________________________________________________________

## Next Steps

Proceed to Phase 1 design with these decisions:

1. Use `builtins.readDir` for auto-discovery
1. Create lib files with attrset exports
1. Port mkDarwinConfig exactly (with path fixes)
1. Generate configs dynamically with listToAttrs
1. Update justfile to use flake outputs
