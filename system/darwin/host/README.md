# Darwin Host Configurations

Pure data configurations for darwin (macOS) hosts.

## Purpose

Hosts are **pure data** configurations (no imports) that define machine-specific settings. Each host represents a physical or virtual macOS machine.

## Structure

```nix
{ ... }:

{
  name = "host-identifier";
  family = [];                  # Darwin typically doesn't share cross-platform
  applications = ["*"];         # List of apps or ["*"] for all
  settings = ["default"];       # List of settings or ["default"] for all
}
```

## Fields

- **name** (required): Host identifier (e.g., "home-macmini-m4", "work")
- **family** (optional): Array of cross-platform family names
  - Darwin hosts typically use `[]` since macOS configs don't share cross-platform
  - Future: Could reference darwin-specific families if needed
- **applications** (optional): Applications to install
  - List specific apps: `["git", "helix", "zsh"]`
  - Or use wildcard: `["*"]` to import all available apps
- **settings** (optional): System settings to apply
  - List specific settings: `["dock", "keyboard"]`
  - Or use keyword: `["default"]` to import all darwin settings
  - **NOT allowed**: `["*"]` wildcard (validation error)

## Hierarchical Discovery

Apps and settings are resolved via hierarchical search:

1. **platform/darwin/app/** or **platform/darwin/settings/** (tier 1 - darwin-specific)
1. **platform/shared/family/{family}/app/** or **/settings/** (tier 2 - if families defined)
1. **platform/shared/app/** or **platform/shared/settings/** (tier 3 - shared fallback)

**First match wins** - no merging across tiers.

## Examples

### Minimal Host

```nix
{ ... }:

{
  name = "simple-macbook";
  family = [];
  settings = ["default"];
}
```

### Full-Featured Host

```nix
{ ... }:

{
  name = "home-macmini-m4";
  family = [];  # No cross-platform sharing for darwin
  applications = ["*"];  # All available apps
  settings = ["default"];  # All darwin settings
}
```

### Selective Host

```nix
{ ... }:

{
  name = "work-macbook";
  family = [];
  applications = [
    "git"
    "helix"
    "zsh"
    "aerospace"
  ];
  settings = [
    "dock"
    "keyboard"
    "displays"
  ];
}
```

## Migration from Profiles

Old profile structure (with imports):

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../settings/default.nix
    ../../../shared/lib/host.nix
  ];
  
  host = {
    name = "work-laptop";
    # ...
  };
}
```

New host structure (pure data):

```nix
{ ... }:

{
  name = "work-laptop";
  family = [];
  applications = ["*"];
  settings = ["default"];  # Replaces import of settings/default.nix
}
```

## Platform Library Integration

The darwin platform library (`platform/darwin/lib/darwin.nix`):

1. Loads host config as pure data (before module evaluation)
1. Extracts `name`, `family`, `applications`, `settings` fields
1. Validates: families exist, no "\*" in settings
1. Auto-installs family defaults (if families defined)
1. Resolves apps/settings via hierarchical discovery
1. Generates imports list and passes to home-manager

## Validation

- Run `nix flake check` to validate all host configurations
- Build specific host: `nix build ".#darwinConfigurations.cdrokar-home-macmini-m4.system"`
- All validation happens at evaluation time

## See Also

- **Discovery System**: `platform/shared/lib/discovery.nix`
- **Platform Library**: `platform/darwin/lib/darwin.nix`
- **Feature Spec**: `specs/021-host-family-refactor/spec.md`
- **Quickstart**: `specs/021-host-family-refactor/quickstart.md`
