# Contract: Family App Discovery Without default.nix

**ID**: 001\
**Feature**: 028-gnome-family-system-integration\
**Status**: Required

## Behavior

Family app directories MUST NOT have a `default.nix` file and MUST be discovered hierarchically like system apps.

## Contract Specification

### GIVEN

A host configuration with:

```nix
{
  name = "nixos-workstation";
  family = ["gnome"];
}
```

A user configuration with:

```nix
{
  user.applications = ["gnome-tweaks"];
}
```

An app exists at:

```
system/shared/family/gnome/app/utility/gnome-tweaks.nix
```

### WHEN

Platform lib resolves user applications with hierarchical discovery

### THEN

1. **No default.nix exists**:

   ```bash
   ! test -f system/shared/family/gnome/app/default.nix
   ! test -f system/shared/family/linux/app/default.nix
   ```

1. **App is discovered hierarchically**:

   - Search order: system → families → shared
   - Found at: `system/shared/family/gnome/app/utility/gnome-tweaks.nix`

1. **App is imported in home-manager**:

   ```nix
   home-manager.users.${user}.imports = [
     .../system/shared/family/gnome/app/utility/gnome-tweaks.nix
   ];
   ```

1. **App is NOT auto-installed**:

   - Only installed because user explicitly selected it
   - If user removes from `applications`, app not installed

## Validation Tests

### Test 1: No default.nix in Family Apps

```bash
# Must fail (file should not exist)
test -f system/shared/family/gnome/app/default.nix && echo "FAIL" || echo "PASS"
test -f system/shared/family/linux/app/default.nix && echo "FAIL" || echo "PASS"
```

**Expected**: Both tests PASS (files don't exist)

### Test 2: App Discovered When Family in Host

```nix
# Evaluate app resolution
nix eval --json .#darwinConfigurations.user-host.config.home-manager.users.user.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

**Expected**: gnome-tweaks found if:

- Host has `family = ["gnome"]`
- User has `applications = ["gnome-tweaks"]` or `["*"]`

### Test 3: App NOT Discovered When Family NOT in Host

```nix
# Host without gnome family
{
  name = "nixos-server";
  family = [];  # No gnome
  applications = ["*"];
}

# User tries to use gnome app
{
  user.applications = ["gnome-tweaks"];
}
```

**Expected**: App resolution fails or returns empty (app not available)

### Test 4: Wildcard Includes Family Apps

```nix
# Host with gnome family
{
  family = ["gnome"];
}

# User with wildcard
{
  user.applications = ["*"];
}
```

**Expected**: Discovered apps include gnome-tweaks, dconf-editor (all gnome family apps)

## Error Conditions

### Error 1: default.nix Exists in Family App Directory

**Condition**: `system/shared/family/gnome/app/default.nix` exists

**Expected Behavior**:

- Validation fails during build
- Error message: "Family app directories must not have default.nix"
- Alternative: Silently ignore (hierarchical discovery takes precedence)

### Error 2: App Not Found

**Condition**: User requests `applications = ["nonexistent-app"]`

**Expected Behavior**:

- App not found in hierarchical search
- Filtered out from final imports
- Optional: Warning logged (app not found)

## Implementation Notes

### Platform Lib Responsibility

Platform lib (`darwin.nix`, `nixos.nix`) must:

1. Call `discovery.resolveApplications` with `families` parameter
1. Pass `families` from host configuration
1. Hierarchical search includes family paths

### Discovery Function Contract

```nix
resolveApplications = {
  apps,        # ["gnome-tweaks"]
  callerPath,  # user/{username}/
  basePath,    # repo root
  system,      # "darwin" | "x86_64-linux"
  families     # ["gnome"] from host.family
}: [
  # Returns list of absolute paths
  .../system/shared/family/gnome/app/utility/gnome-tweaks.nix
]
```

**Search Order**:

1. `system/{system}/app/**/*`
1. `system/shared/family/{family}/app/**/*` (for each family)
1. `system/shared/app/**/*`

## Acceptance Criteria

- [ ] No `default.nix` in `family/gnome/app/`
- [ ] No `default.nix` in `family/linux/app/`
- [ ] Family apps discovered hierarchically
- [ ] Apps loaded ONLY when user selects them
- [ ] Wildcard includes family apps if family in host
- [ ] Apps NOT available if family not in host

## Related Contracts

- 002: Family Settings Independence
- 003: Wildcard App Expansion
