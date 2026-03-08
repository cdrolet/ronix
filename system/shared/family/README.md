# Families

**Purpose**: Families are composable configuration variants that hosts opt into.

**Architecture Version**: 2.1.0 (Host/Family Architecture)

______________________________________________________________________

## What Are Families?

Families are **reusable configuration building blocks** that provide apps and settings for a specific concern. Hosts compose families to describe their capabilities.

**Examples**:

- `wayland`: Common Wayland utilities (shared across NixOS, Kali, Ubuntu, etc.)
- `gnome`: GNOME desktop environment (apps, dconf settings, extensions)
- `niri`: Niri compositor (tiling Wayland compositor)
- `server`: Server-specific configurations for headless systems

Families can represent any variation point: platform base, desktop environment, role, toolset, etc.

**Not For**: Deployment contexts (work, home, gaming) - hosts handle that

______________________________________________________________________

## Directory Structure

```
platform/shared/family/
  wayland/                    # Wayland family
    app/
      default.nix           # Auto-installed when family is referenced
      htop.nix              # Common Wayland apps
      tmux.nix
    settings/
      default.nix           # Auto-installed when family is referenced
  gnome/                    # GNOME family
    app/
      default.nix
      nautilus.nix          # GNOME-specific apps
    settings/
      default.nix           # GNOME settings
```

______________________________________________________________________

## Family Structure

Each family directory contains:

### Required

- `{family}/` - Family name directory (e.g., `wayland/`, `gnome/`)

### Optional

- `{family}/app/` - Applications specific to this family
- `{family}/app/default.nix` - Auto-installed when host references family
- `{family}/settings/` - Settings specific to this family
- `{family}/settings/default.nix` - Auto-installed when host references family

______________________________________________________________________

## Using Families

### In Host Configurations

Hosts reference families using the `family` array:

```nix
# platform/nixos/host/workstation/default.nix
{ ... }:
{
  name = "workstation";
  family = ["wayland", "gnome"];  # Compose multiple families
  applications = ["*"];
  settings = ["default"];
}
```

### Family Composition

Multiple families can be composed in order:

- Discovery searches in array order: `platform → family[0] → family[1] → ... → shared`
- First match wins (no merging)

______________________________________________________________________

## Auto-Installation

When a host references families, their `default.nix` files are **automatically installed**:

**Auto-installed files**:

- `platform/shared/family/{family}/app/default.nix`
- `platform/shared/family/{family}/settings/default.nix`

**Example**: Host with `family = ["wayland", "gnome"]` automatically gets:

1. `family/wayland/app/default.nix`
1. `family/wayland/settings/default.nix`
1. `family/gnome/app/default.nix`
1. `family/gnome/settings/default.nix`

______________________________________________________________________

## Hierarchical Discovery

Apps and settings are discovered using hierarchical search:

**Search Order** (first match wins):

1. `platform/{platform}/app/` or `platform/{platform}/settings/`
1. `platform/shared/family/{family[0]}/app/` or `settings/`
1. `platform/shared/family/{family[1]}/app/` or `settings/`
1. ... (for each family in array order)
1. `platform/shared/app/` or `platform/shared/settings/`

**Example**: Host with `family = ["wayland"]` requesting `htop`:

1. Check `platform/nixos/app/monitor/htop.nix` (not found)
1. Check `platform/shared/family/wayland/app/htop.nix` (found! ✓)
1. Use wayland family version

______________________________________________________________________

## Creating a Family

### Step 1: Create Directory Structure

```bash
mkdir -p platform/shared/family/{family-name}/{app,settings}
```

### Step 2: Create default.nix Files

**app/default.nix** (optional but recommended):

```nix
# Common apps for {family-name} family
{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Common packages for this family
    curl
    wget
    vim
  ];
}
```

**settings/default.nix** (optional):

```nix
# Common settings for {family-name} family
{ config, pkgs, lib, ... }:

{
  # Family-specific settings
  xdg.enable = true;
}
```

### Step 3: Add Family-Specific Apps

```nix
# platform/shared/family/{family-name}/app/some-app.nix
{ config, pkgs, lib, ... }:

{
  programs.some-app = {
    enable = true;
    # Configuration...
  };
}
```

### Step 4: Reference from Hosts

```nix
# platform/{platform}/host/{host-name}/default.nix
{ ... }:
{
  name = "host-name";
  family = ["family-name"];  # Reference your family
  applications = ["*"];
  settings = ["default"];
}
```

______________________________________________________________________

## Validation

Families are validated at evaluation time:

**Checks**:

- ✅ Family directories must exist in `platform/shared/family/`
- ✅ Referenced families must be valid directory names

**Validation Trigger**: `nix flake check` or build

______________________________________________________________________

## Examples

### Example 1: Wayland Family

**Use Case**: Common Wayland utilities shared across nixos, kali, ubuntu

```nix
# platform/shared/family/wayland/app/default.nix
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [ curl wget vim git ];
}
```

**Referenced by**:

```nix
# platform/nixos/host/server/default.nix
{ ... }:
{
  name = "server";
  family = ["wayland"];  # Gets common Wayland apps
  applications = ["*"];
  settings = ["default"];
}
```

### Example 2: GNOME Family

**Use Case**: GNOME desktop apps/settings for Wayland distributions with GNOME

```nix
# platform/shared/family/gnome/app/default.nix
{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [ gnome-tweaks nautilus ];
}
```

**Referenced by**:

```nix
# platform/nixos/host/desktop/default.nix
{ ... }:
{
  name = "desktop";
  family = ["wayland", "gnome"];  # Gets both families
  applications = ["*"];
  settings = ["default"];
}
```

### Example 3: Multi-Family Composition

**Use Case**: Combining multiple families for complex setups

```nix
# platform/kali/host/pentest-workstation/default.nix
{ ... }:
{
  name = "pentest-workstation";
  family = ["wayland", "gnome", "security"];  # Three families!
  applications = ["*"];
  settings = ["default"];
}
```

**Discovery order**: `platform/kali → family/wayland → family/gnome → family/security → platform/shared`

______________________________________________________________________

## Best Practices

### When to Use Families

✅ **Good Use Cases**:

- Platform base (wayland, server)
- Desktop environments (gnome, niri, kde)
- Common toolsets (developer, security, media)
- Any reusable variation point that multiple hosts can share

❌ **Not For**:

- Deployment contexts (work, home, gaming) - use hosts
- Platform-specific configs that apply to ALL hosts of that platform - use `platform/{platform}/settings/`

### Naming Conventions

- **Lowercase**: `wayland`, `gnome`, `server`
- **Descriptive**: Names should indicate functionality family
- **No platform names**: Don't use `nixos-family` (families transcend platforms)

### Keep Families Focused

- Each family should have a clear purpose
- Prefer multiple small families over one large family
- Use composition: `family = ["wayland", "gnome"]` over monolithic `wayland-gnome`

### Document Your Families

Add a README.md to each family explaining:

- Purpose of the family
- What platforms use it
- What apps/settings it provides

______________________________________________________________________

## Troubleshooting

### Family Not Found Error

```
error: Family 'xyz' not found at platform/shared/family/xyz
```

**Solution**: Create the family directory or fix typo in host config

### Apps Not Loading from Family

**Check**:

1. Is family referenced in host's `family` array?
1. Does `family/{name}/app/default.nix` exist?
1. Is app file named correctly in family directory?

### Settings Not Applied

**Check**:

1. Does `family/{name}/settings/default.nix` exist?
1. Are settings using proper Home Manager options?
1. Check for conflicts with platform-specific settings (platform wins)

______________________________________________________________________

## Migration from Old Architecture

**Old**: No family concept - everything in profiles
**New**: Families for cross-platform, hosts for machines

**Migration Steps**:

1. Identify cross-platform configurations in old profiles
1. Move to appropriate family (wayland, gnome, etc.)
1. Update hosts to reference families
1. Remove duplicate configs from platform directories

______________________________________________________________________

## Related Documentation

- [Host Schema](../../darwin/host/README.md) - Pure data host configurations
- [CLAUDE.md](../../../CLAUDE.md) - Architecture overview
- [Constitution](../../../.specify/memory/constitution.md) - Governance principles
