# Contract: Family Settings Independence

**ID**: 002\
**Feature**: 028-gnome-family-system-integration\
**Status**: Required

## Behavior

Each family's `settings/default.nix` MUST use auto-discovery ONLY and MUST NOT import other families' settings.

## Contract Specification

### GIVEN

A host configuration with multiple families:

```nix
{
  name = "nixos-workstation";
  family = ["linux" "gnome"];
}
```

Family settings exist at:

```
system/shared/family/linux/settings/
  ├── default.nix
  └── keyboard.nix

system/shared/family/gnome/settings/
  ├── default.nix
  ├── desktop/
  ├── wayland.nix
  └── ...
```

### WHEN

Platform lib imports family settings at system level

### THEN

1. **Each family's default.nix is independent**:

   ```nix
   # system/shared/family/gnome/settings/default.nix
   # Uses auto-discovery pattern ONLY
   imports = map (file: ./${file}) (discoverModules ./.);

   # DOES NOT import:
   # ../../linux/settings/default.nix  # ❌ NO cross-family imports
   ```

1. **Both families' settings are imported**:

   ```nix
   nixpkgs.lib.nixosSystem {
     modules = [
       .../system/shared/family/linux/settings/default.nix
       .../system/shared/family/gnome/settings/default.nix
       # Both imported because both in hostFamily
     ];
   }
   ```

1. **Settings are system-level**:

   - Imported at root modules level (not in home-manager)
   - Available system-wide (all users)

1. **Order matters for conflicts**:

   - Later families override earlier families
   - `family = ["linux" "gnome"]` → gnome settings override linux

## Validation Tests

### Test 1: No Cross-Family Imports in settings/default.nix

```bash
# Check gnome/settings/default.nix
grep -q "linux/settings" system/shared/family/gnome/settings/default.nix \
  && echo "FAIL: Cross-family import found" \
  || echo "PASS: No cross-family imports"

# Check linux/settings/default.nix  
grep -q "gnome/settings" system/shared/family/linux/settings/default.nix \
  && echo "FAIL: Cross-family import found" \
  || echo "PASS: No cross-family imports"
```

**Expected**: Both tests PASS (no cross-imports)

### Test 2: Auto-Discovery Pattern Only

```nix
# Valid pattern in family/{name}/settings/default.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

**Expected**: Only calls `discoverModules` on current directory (`./.`)

### Test 3: Both Families' Settings Imported When Both in Host

```nix
# Evaluate system configuration
nix eval .#nixosConfigurations.nixos-workstation.config.services.xserver \
  | jq '.desktopManager.gnome.enable'  # From gnome family

nix eval .#nixosConfigurations.nixos-workstation.config.home-manager.users.user.xkb \
  | jq '.layout'  # From linux family (if configured)
```

**Expected**: Both family settings present in final configuration

### Test 4: Only Declared Families' Settings Imported

```nix
# Host with only gnome (no linux)
{
  name = "gnome-only-host";
  family = ["gnome"];
}
```

**Expected**:

- GNOME settings imported
- Linux settings NOT imported (not in family list)

## Error Conditions

### Error 1: Cross-Family Import Detected

**Condition**: `gnome/settings/default.nix` imports `../../linux/settings/default.nix`

**Expected Behavior**:

- Static analysis detects cross-import
- Warning or error during validation
- Builds succeed but violates contract

**Resolution**: Remove cross-import, rely on host declaring both families

### Error 2: Family Not in Host

**Condition**: User expects Linux settings but host only has `family = ["gnome"]`

**Expected Behavior**:

- Linux settings NOT imported
- No error (expected behavior)
- User must add `"linux"` to host.family

## Implementation Notes

### Platform Lib Responsibility

Platform lib must call `autoInstallFamilyDefaults` for settings:

```nix
familyDefaults = families: basePath: let
  collectDefaults = family: let
    familyPath = basePath + "/system/shared/family/${family}";
    settingsDefault = familyPath + "/settings/default.nix";
  in
    lib.optional (builtins.pathExists settingsDefault) settingsDefault;
in
  lib.flatten (map collectDefaults families);

# Usage in nixos.nix:
familySettingsDefaults = 
  if hostFamily != []
  then discovery.autoInstallFamilyDefaults hostFamily repoRoot
  else [];

nixpkgs.lib.nixosSystem {
  modules = [
    # Import all family settings defaults
  ] ++ familySettingsDefaults ++ [
    # ... rest of config
  ];
}
```

### Family default.nix Pattern

**Template** for `family/{name}/settings/default.nix`:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../lib/discovery.nix {inherit lib;};
in {
  # Auto-discovery ONLY (no cross-imports)
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

**DO**:

- ✅ Use `discoverModules ./.` on current directory
- ✅ Keep pattern consistent across all families
- ✅ Let host declare multiple families for composition

**DON'T**:

- ❌ Import other families' default.nix
- ❌ Hardcode module paths (use auto-discovery)
- ❌ Add conditional logic based on other families

## Acceptance Criteria

- [ ] `gnome/settings/default.nix` has no cross-family imports
- [ ] `linux/settings/default.nix` has no cross-family imports
- [ ] Each family uses auto-discovery pattern only
- [ ] Both families' settings imported when both in host.family
- [ ] Only declared families' settings imported (not all families)
- [ ] Settings imported at system level (not home-manager)

## Design Rationale

**Why Independent Settings?**

1. **Explicit Composition**: Host explicitly declares which families to combine

   ```nix
   family = ["linux" "gnome"];  # Clear intent
   ```

1. **Flexibility**: Hosts can use gnome without linux (e.g., on BSD)

   ```nix
   family = ["gnome"];  # Just GNOME, no Linux-specific settings
   ```

1. **No Hidden Dependencies**: All family dependencies visible in host config

1. **Simpler Maintenance**: No coupling between family modules

**Why Auto-Discovery?**

1. **Consistency**: Same pattern as system settings
1. **No Manual Imports**: Add .nix file, automatically imported
1. **Constitutional**: Modular, under 200 lines per file

## Related Contracts

- 001: Family App Discovery
- 003: Wildcard App Expansion
- 004: System vs User Level Separation
