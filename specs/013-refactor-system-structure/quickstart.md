# Quickstart: Refactor System Structure

**Feature**: 013-refactor-system-structure\
**Created**: 2025-01-27\
**Purpose**: Quick reference guide for implementing the system structure refactoring

______________________________________________________________________

## Overview

This quickstart provides step-by-step instructions for implementing the system structure refactoring. The refactoring standardizes profile configuration, centralizes state version management, consolidates discovery functions, and implements auto-discovery for settings/apps.

______________________________________________________________________

## Implementation Steps

### Step 1: Move Discovery Functions to Shared Library

**Location**: `system/shared/lib/discovery.nix` (NEW FILE)

**Action**: Extract discovery functions from `flake.nix` and create shared library.

**Functions to Move**:

- `discoverUsers`
- `discoverProfiles`
- `discoverAllProfilesPrefixed`
- `discoverModules` (NEW - implement recursive discovery)

**Implementation**:

```nix
# system/shared/lib/discovery.nix
{ lib }:

{
  discoverUsers = basePath: let
    entries = builtins.readDir basePath;
    dirs = lib.filterAttrs (name: type: type == "directory") entries;
    hasDefault = name: builtins.pathExists (basePath + "/${name}/default.nix");
  in
    builtins.attrNames (lib.filterAttrs (name: _: hasDefault name) dirs);

  discoverProfiles = platform: let
    basePath = ../../${platform}/profiles;
    entries = builtins.readDir basePath;
    dirs = lib.filterAttrs (name: type: type == "directory") entries;
    hasDefault = name: builtins.pathExists (basePath + "/${name}/default.nix");
  in
    builtins.attrNames (lib.filterAttrs (name: _: hasDefault name) dirs);

  discoverAllProfilesPrefixed = let
    allPlatforms = ["darwin" "nixos"];
    existingPlatforms = lib.filter (platform:
      builtins.pathExists ../../${platform}/profiles
    ) allPlatforms;
    platformProfiles = map (platform:
      let profiles = discoverProfiles platform;
      in map (profile: "${platform}-${profile}") profiles
    ) existingPlatforms;
  in
    lib.flatten platformProfiles;

  discoverModules = basePath: let
    entries = builtins.readDir basePath;
    files = lib.filterAttrs (name: type: 
      type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
    ) entries;
    dirs = lib.filterAttrs (name: type: type == "directory") entries;
    subdirFiles = lib.flatten (lib.mapAttrsToList (name: _:
      map (file: "${name}/${file}") (discoverModules (basePath + "/${name}"))
    ) dirs);
  in
    (lib.attrNames files) ++ subdirFiles;
}
```

**Update flake.nix**:

```nix
let
  discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
  validUsers = discovery.discoverUsers ./user;
  discoverProfiles = discovery.discoverProfiles;
  # ... rest of flake.nix
```

______________________________________________________________________

### Step 2: Create host.nix Module

**Location**: `system/shared/lib/host.nix` (NEW FILE)

**Action**: Create module that processes hostSpec and sets networking/platform config.

**Implementation**:

```nix
# system/shared/lib/host.nix
{ config, lib, ... }:

{
  options.hostSpec = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "Hostname identifier";
        };
        display = lib.mkOption {
          type = lib.types.str;
          description = "Human-readable display name";
        };
        platform = lib.mkOption {
          type = lib.types.str;
          description = "Target platform architecture";
        };
      };
    });
    default = null;
    description = "Host identification configuration";
  };

  config = lib.mkIf (config.hostSpec != null) {
    networking.hostName = config.hostSpec.name;
    networking.computerName = config.hostSpec.display;
    nixpkgs.hostPlatform = config.hostSpec.platform;
  };
}
```

**Usage in Profile**:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../shared/lib/host.nix
    ../../settings/default.nix
  ];

  hostSpec = {
    name = "home-macmini";
    display = "Home Mac Mini";
    platform = "aarch64-darwin";
  };
}
```

______________________________________________________________________

### Step 3: Centralize system.stateVersion in darwin.nix

**Location**: `system/darwin/lib/darwin.nix` (MODIFY)

**Action**: Add system.stateVersion = 5 to darwin.nix module list.

**Implementation**:

```nix
# system/darwin/lib/darwin.nix
modules = [
  # Central state version (lowest priority, profiles can override)
  {
    system.stateVersion = 5;
  }
  
  # System profile
  ../profiles/${profile}
  
  # ... rest of modules
];
```

**Remove from Profiles**: Remove `system.stateVersion = 5;` from individual profile files.

______________________________________________________________________

### Step 4: Implement Auto-Discovery in settings/default.nix

**Location**: `system/darwin/settings/default.nix` (MODIFY)

**Action**: Replace manual imports with auto-discovery.

**Before**:

```nix
imports = [
  ./dock.nix
  ./finder.nix
  ./trackpad.nix
  # ... manual list
];
```

**After**:

```nix
let
  discovery = lib.callPackage ../../shared/lib/discovery.nix {};
in
{
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

______________________________________________________________________

### Step 5: Refactor Profiles to Use hostSpec

**Location**: `system/darwin/profiles/{profile}/default.nix` (MODIFY BOTH PROFILES)

**Action**: Replace manual host config with hostSpec structure.

**Before** (home-macmini-m4):

```nix
networking.hostName = "home-macmini";
networking.computerName = "Home Mac Mini";
nixpkgs.hostPlatform = "aarch64-darwin";
system.stateVersion = 5;
```

**After**:

```nix
imports = [
  ../../shared/lib/host.nix
  ../../settings/default.nix
];

hostSpec = {
  name = "home-macmini";
  display = "Home Mac Mini";
  platform = "aarch64-darwin";
};

# system.stateVersion removed (now in darwin.nix)
```

**Repeat for work profile**: Update `system/darwin/profiles/work/default.nix` similarly.

______________________________________________________________________

### Step 6: Review Darwin Library Functions

**Location**: `system/darwin/lib/` (REVIEW)

**Action**: Review each function against nix-darwin capabilities.

**Functions to Review**:

- `dock.nix`: Check against `system.defaults.dock.*` options
- `power.nix`: Check against `system.defaults.EnergySaver.*` options
- `system-defaults.nix`: Check against `system.defaults.*` namespace
- `mac.nix`: Evaluate if re-export layer is necessary

**Decision Matrix**:

- If function provides value beyond nix-darwin: Keep
- If function is redundant: Remove and update usage
- If mac.nix only re-exports: Remove, import directly

**Document Findings**: Create notes about which functions are kept/removed and why.

______________________________________________________________________

### Step 7: Remove mac.nix (if unnecessary)

**Location**: `system/darwin/lib/mac.nix` (REMOVE IF UNNECESSARY)

**Action**: If mac.nix is determined to be unnecessary, remove it and update imports.

**Before Removal**: Check all usages of mac.nix and update to direct imports:

- `dock.nix` functions: Import `dock.nix` directly
- `power.nix` functions: Import `power.nix` directly
- `system-defaults.nix` functions: Import `system-defaults.nix` directly

**After Removal**: Update any files that imported mac.nix to import individual modules.

______________________________________________________________________

## Verification Steps

### 1. Build Verification

```bash
# Verify flake evaluation
nix flake check

# Verify Darwin configurations build
nix build .#darwinConfigurations.cdrokar-home-macmini-m4
nix build .#darwinConfigurations.cdrokar-work
```

### 2. Profile Verification

```bash
# Verify profiles use hostSpec correctly
grep -r "hostSpec" system/darwin/profiles/

# Verify stateVersion removed from profiles
grep -r "system.stateVersion" system/darwin/profiles/  # Should return empty or only comments
```

### 3. Discovery Verification

```bash
# Verify discovery functions work
nix eval .#validUsers
nix eval .#validProfiles.darwin

# Verify auto-discovery in settings
# (Should automatically include any new .nix files added to settings/)
```

### 4. Backward Compatibility

```bash
# Verify existing profiles still work
darwin-rebuild switch --flake .#cdrokar-home-macmini-m4
darwin-rebuild switch --flake .#cdrolet-work
```

______________________________________________________________________

## Testing Checklist

- [ ] `nix flake check` passes
- [ ] All Darwin configurations build successfully
- [ ] Existing profiles activate successfully
- [ ] hostSpec validation works (test with missing field)
- [ ] Auto-discovery includes all settings files
- [ ] Auto-discovery excludes defaults.nix (no circular deps)
- [ ] Discovery functions work in flake.nix
- [ ] State version centralization works
- [ ] Profile override of state version works (if needed)
- [ ] Darwin library cleanup completed (functions reviewed)

______________________________________________________________________

## Rollback Plan

If issues arise:

1. **Git Revert**: `git revert HEAD` (if committed)
1. **Manual Rollback**: Restore original files from git history
1. **Specific Rollback**: Revert individual changes:
   - Restore discovery functions to flake.nix
   - Restore manual imports in settings/default.nix
   - Restore hostSpec config to manual networking.\* config in profiles
   - Restore system.stateVersion to individual profiles

______________________________________________________________________

## Next Steps

After completing this refactoring:

1. Test thoroughly on actual systems
1. Update documentation (README.md, guides)
1. Consider applying auto-discovery to app defaults.nix files
1. Prepare for NixOS profile onboarding (hostSpec ready)

______________________________________________________________________

## Troubleshooting

### Issue: Discovery functions not found

**Solution**: Verify path in flake.nix import matches actual location.

### Issue: Circular dependency in auto-discovery

**Solution**: Verify `default.nix` is excluded from discovery (check `discoverModules` function).

### Issue: hostSpec validation not working

**Solution**: Verify host.nix module is imported in profile and module system is evaluating correctly.

### Issue: State version conflict

**Solution**: Verify module precedence (darwin.nix sets default, profile can override).

______________________________________________________________________

## References

- [Specification](./spec.md)
- [Data Model](./data-model.md)
- [Host Spec Contract](./contracts/host-spec.md)
- [Discovery API Contract](./contracts/discovery-api.md)
- [Research](./research.md)
