# Contract: Wildcard App Expansion

**ID**: 003\
**Feature**: 028-gnome-family-system-integration\
**Status**: Required

## Behavior

When a user declares `applications = ["*"]`, the wildcard MUST expand to include ALL available apps from system, families (if in host), and shared directories.

## Contract Specification

### GIVEN

A host configuration with families:

```nix
{
  name = "nixos-workstation";
  family = ["linux" "gnome"];
}
```

A user configuration with wildcard:

```nix
{
  user.applications = ["*"];
}
```

Apps exist at:

```
system/nixos/app/cli/something.nix
system/shared/family/linux/app/cli/caligula.nix
system/shared/family/gnome/app/utility/gnome-tweaks.nix
system/shared/family/gnome/app/utility/dconf-editor.nix
system/shared/app/dev/git.nix
system/shared/app/shell/zsh.nix
```

### WHEN

Platform lib expands wildcard `"*"`

### THEN

1. **Wildcard expands to all discoverable apps**:

   ```nix
   expanded = [
     "something"        # from system/nixos/app/
     "caligula"         # from family/linux/app/
     "gnome-tweaks"     # from family/gnome/app/
     "dconf-editor"     # from family/gnome/app/
     "git"              # from shared/app/
     "zsh"              # from shared/app/
     # ... all other apps
   ];
   ```

1. **Family apps included ONLY if family in host**:

   - Host has `family = ["linux" "gnome"]`
   - ✅ Include: linux/app/*, gnome/app/*
   - ❌ Exclude: Other families not in host (e.g., kde/app/\*)

1. **All expanded apps imported**:

   ```nix
   home-manager.users.${user}.imports = [
     # All resolved app paths
     .../system/nixos/app/cli/something.nix
     .../system/shared/family/linux/app/cli/caligula.nix
     .../system/shared/family/gnome/app/utility/gnome-tweaks.nix
     .../system/shared/family/gnome/app/utility/dconf-editor.nix
     .../system/shared/app/dev/git.nix
     .../system/shared/app/shell/zsh.nix
     # ...
   ];
   ```

## Validation Tests

### Test 1: Wildcard Includes Platform Apps

```nix
# User with wildcard on NixOS
{
  user.applications = ["*"];
}

# Evaluate packages
nix eval .#nixosConfigurations.host.config.home-manager.users.user.home.packages \
  | jq 'length'
```

**Expected**: Large number (all platform apps included)

### Test 2: Wildcard Includes Family Apps When Family in Host

```nix
# Host with gnome family
{
  family = ["gnome"];
}

# User with wildcard
{
  user.applications = ["*"];
}

# Check for gnome-tweaks
nix eval .#nixosConfigurations.host.config.home-manager.users.user.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

**Expected**: gnome-tweaks found (family app included)

### Test 3: Wildcard Excludes Family Apps When Family NOT in Host

```nix
# Host WITHOUT gnome family
{
  family = [];
}

# User with wildcard
{
  user.applications = ["*"];
}

# Check for gnome-tweaks
nix eval .#nixosConfigurations.host.config.home-manager.users.user.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

**Expected**: gnome-tweaks NOT found (family not in host)

### Test 4: Wildcard Respects Hierarchical Search Order

```nix
# App exists in multiple locations:
# - system/darwin/app/dev/git.nix
# - system/shared/app/dev/git.nix

# Wildcard expansion
applications = ["*"]
```

**Expected**: Platform-specific version takes precedence (darwin/app/dev/git.nix)

## Error Conditions

### Error 1: Wildcard with No Apps

**Condition**: Empty repository, no apps exist

**Expected Behavior**:

- Wildcard expands to empty list `[]`
- No error, builds successfully
- User has no apps installed

### Error 2: Circular Dependencies

**Condition**: App A imports App B, App B imports App A (unlikely but possible)

**Expected Behavior**:

- Nix module system detects infinite recursion
- Error during evaluation
- User must fix module imports

## Implementation Notes

### Discovery Function for Wildcard

```nix
discoverApplicationNames = searchPaths: let
  # Find all .nix files in all search paths
  discoverInPath = path:
    if builtins.pathExists path
    then discovery.discoverModules path
    else [];
  
  # Map to app names (remove .nix, extract basename)
  toAppName = filepath: let
    basename = baseNameOf filepath;
  in
    lib.removeSuffix ".nix" basename;
in
  lib.unique (
    lib.flatten (
      map (path: map toAppName (discoverInPath path)) searchPaths
    )
  );

# Usage in platform lib:
allAvailableApps = discovery.discoverApplicationNames [
  "${repoRoot}/system/${system}/app"
  # Include families if host has them
] ++ (lib.optionals (hostFamily != [])
      (map (f: "${repoRoot}/system/shared/family/${f}/app") hostFamily)
    ) ++ [
  "${repoRoot}/system/shared/app"
];

resolvedUserApps =
  if elem "*" userData.user.applications
  then allAvailableApps
  else userData.user.applications;
```

### Platform Lib Wildcard Expansion

**Darwin Example**:

```nix
# system/darwin/lib/darwin.nix
resolvedUserApps =
  if builtins.elem "*" userData.user.applications
  then let
    # Discover all available apps
    allApps = discovery.discoverApplicationNames {
      searchPaths = [
        ../app  # darwin apps
      ] ++ (map (f: ../../shared/family/${f}/app) hostFamily)
        ++ [
        ../../shared/app  # shared apps
      ];
    };
  in allApps
  else userData.user.applications;
```

**NixOS Example**:

```nix
# system/nixos/lib/nixos.nix
resolvedUserApps =
  if builtins.elem "*" userData.user.applications
  then let
    allApps = discovery.discoverApplicationNames {
      searchPaths = [
        ../app  # nixos apps
      ] ++ (map (f: ../../shared/family/${f}/app) hostFamily)
        ++ [
        ../../shared/app  # shared apps
      ];
    };
  in allApps
  else userData.user.applications;
```

## Acceptance Criteria

- [ ] Wildcard `"*"` expands to all discoverable apps
- [ ] Includes platform-specific apps (`system/{platform}/app`)
- [ ] Includes family apps IF family in host.family
- [ ] Includes shared apps (`system/shared/app`)
- [ ] Excludes family apps if family NOT in host
- [ ] Respects hierarchical search order (first match wins)
- [ ] No duplicates in expanded list

## Performance Considerations

### Discovery Caching

```nix
# Cache discovered apps per platform
# Avoid re-scanning filesystem multiple times
cachedAllApps = lib.mkOnce (
  discovery.discoverApplicationNames searchPaths
);

# Use cached result for all users
```

### Lazy Evaluation

```nix
# Don't expand wildcard if no user uses it
# Only evaluate when actually referenced
allApps = lib.mkIf (anyUserUsesWildcard) (
  discovery.discoverApplicationNames searchPaths
);
```

## Design Rationale

**Why Include Family Apps in Wildcard?**

1. **User Expectation**: `"*"` means "give me everything available"
1. **Family Context**: If host has GNOME family, GNOME apps ARE available
1. **Consistency**: Wildcard behaves like explicit listing of all apps

**Why Exclude Families Not in Host?**

1. **Availability**: Apps from families not in host aren't available
1. **System Integration**: GNOME apps need GNOME desktop (from family settings)
1. **Performance**: Don't discover apps that can't be used

**Why Hierarchical Search?**

1. **Specificity**: Platform-specific overrides generic
1. **Customization**: Host can override shared apps
1. **Predictability**: First match wins (no merging confusion)

## Related Contracts

- 001: Family App Discovery
- 002: Family Settings Independence
- 005: Hierarchical App Resolution
