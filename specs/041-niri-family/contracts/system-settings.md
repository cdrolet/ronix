# System-Level Settings Contracts

**Feature**: 041-niri-family\
**Context**: NixOS system rebuild (Stage 1)\
**Location**: `system/shared/family/niri/settings/system/`

## Overview

System-level settings run during NixOS system rebuild and configure system-wide state that requires root privileges. These modules do NOT have access to home-manager options.

## Module Interface Contract

### Required Module Structure

```nix
{
  config,
  lib,
  pkgs,
  ...  # Do NOT include 'options' parameter
}: {
  # Configuration here
  # Uses system-level options only: system.*, environment.*, services.*, programs.*
  # NO access to: home.*, programs.* (home-manager)
}
```

### Context Requirements

- ✅ **NO context validation needed** - System-level modules always run in NixOS context
- ✅ **NO `options ? home` check** - Would always be false
- ❌ **CANNOT use home-manager options** - `home.packages`, `home.activation`, `xdg.configFile`, `dconf.settings`

### Common Patterns

**Enable Services**:

```nix
services.myservice = {
  enable = lib.mkDefault true;
  # service configuration
};
```

**Install System Packages**:

```nix
environment.systemPackages = [
  pkgs.mypackage
];
```

**Set Environment Variables**:

```nix
environment.sessionVariables = {
  MY_VAR = lib.mkDefault "value";
};
```

## Module Contracts

### `compositor.nix`

**Purpose**: Install and enable Niri compositor

**Inputs**: None (unconditional installation)

**Outputs**:

- `programs.niri.enable = true` - Enables Niri compositor
- `environment.sessionVariables.NIXOS_OZONE_WL = "1"` - Electron apps use Wayland

**Dependencies**: nixpkgs `pkgs.niri` package

**Validation**:

- Module runs in NixOS context only
- No user-specific configuration
- Can be overridden with `lib.mkForce false` if needed

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.niri.enable = lib.mkDefault true;
  
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };
}
```

______________________________________________________________________

### `display-manager.nix`

**Purpose**: Configure greetd + tuigreet for Wayland login

**Inputs**: None (standard greetd configuration)

**Outputs**:

- `services.greetd.enable = true` - Enables greetd display manager
- `services.greetd.settings.default_session.command` - Launches tuigreet with Niri session

**Dependencies**:

- nixpkgs `pkgs.greetd.greetd` package
- nixpkgs `pkgs.greetd.tuigreet` package

**Validation**:

- Module runs in NixOS context only
- Uses `lib.mkDefault` for all options (user-overridable)
- greetd automatically enabled when Niri family declared

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.greetd = {
    enable = lib.mkDefault true;
    settings = {
      default_session = {
        command = lib.mkDefault "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd niri-session";
      };
    };
  };
}
```

______________________________________________________________________

### `session.nix`

**Purpose**: Set up Niri as a Wayland graphical session

**Inputs**: None (standard Wayland environment)

**Outputs**:

- `services.xserver.enable = false` - No X11 (Wayland-only)
- `environment.sessionVariables.XDG_SESSION_TYPE = "wayland"` - Session type
- `environment.sessionVariables.XDG_CURRENT_DESKTOP = "niri"` - Desktop identifier

**Dependencies**: None (environment variables only)

**Validation**:

- Module runs in NixOS context only
- Uses `lib.mkDefault` for all options
- X11 disabled by default (can be re-enabled if needed)

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver.enable = lib.mkDefault false;
  
  environment.sessionVariables = {
    XDG_SESSION_TYPE = lib.mkDefault "wayland";
    XDG_CURRENT_DESKTOP = lib.mkDefault "niri";
  };
}
```

______________________________________________________________________

### `default.nix`

**Purpose**: Auto-discovery entry point for all system-level modules

**Inputs**: None (discovery system)

**Outputs**: Imports all `.nix` files in directory (except itself)

**Dependencies**: `system/shared/lib/discovery.nix`

**Validation**:

- Recursively discovers all modules
- No manual imports required
- Follows Feature 039 pattern (GNOME family reference)

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

## Integration Points

### With Linux Family

Niri family composes with Linux family:

```nix
# Host configuration
{
  family = ["linux", "niri"];  # Linux MUST come first
}
```

**Linux family provides**:

- `settings/system/keyboard.nix` - XKB layout (Super ↔ Ctrl swap)
- Shared Linux utilities

**Niri family adds**:

- Compositor installation
- Display manager configuration
- Wayland session setup

### With Discovery System

System-level settings auto-imported when host declares `family = ["niri"]`:

1. Host config parsed by `system/nixos/lib/nixos.nix`
1. Family validated via `discovery.validateFamilyExists`
1. `niri/settings/system/default.nix` imported automatically
1. All system modules discovered and loaded

**No manual imports required** - Family integration is fully automatic.

### With Platform Libraries

NixOS platform library (`system/nixos/lib/nixos.nix`) handles:

- Family validation
- Auto-installation of family defaults
- Module composition

**No changes needed to platform libraries** - Discovery system handles everything.

## Error Handling

### Invalid Family Declaration

```nix
# ERROR: Conflicting desktop families
{
  family = ["gnome", "niri"];  # Both declare desktop environments
}
```

**Expected behavior**: Validation error at evaluation time with clear message.

### Missing Packages

```nix
# ERROR: Niri not available in nixpkgs
programs.niri.enable = true;
```

**Expected behavior**: Build fails with package not found error.

### Context Errors

System-level modules should NEVER access home-manager options:

```nix
# ❌ WRONG: This will fail
{
  home.packages = [ pkgs.niri ];  # home option doesn't exist in system context
}

# ✅ CORRECT: Use system options
{
  environment.systemPackages = [ pkgs.niri ];
}
```

## Testing Strategy

### Unit Testing (Build Verification)

```bash
# Test system-level module evaluation
nix build ".#nixosConfigurations.test-niri-host.config.system.build.toplevel"
```

### Integration Testing (NixOS VM)

```bash
# Build and run NixOS VM with Niri family
nixos-rebuild build-vm --flake ".#test-niri-host"
./result/bin/run-*-vm
```

### Expected Outcomes

1. ✅ System builds without errors
1. ✅ Niri compositor installed
1. ✅ greetd display manager enabled
1. ✅ Wayland environment variables set
1. ✅ Login screen appears (tuigreet)
1. ✅ Niri session option available

## Migration Path

### From GNOME to Niri

```nix
# Before
{
  family = ["linux", "gnome"];
}

# After
{
  family = ["linux", "niri"];  # Single line change
}
```

**System rebuild installs**:

- Niri compositor (replaces GNOME Shell)
- greetd (replaces GDM)
- Wayland environment (same as GNOME)

**User rebuild installs**:

- Niri keybindings
- swaybg wallpaper daemon (replaces GNOME background)
- Waybar panel (replaces GNOME panel)

## Compliance Checklist

System-level modules MUST:

- [x] Be \<200 lines (constitutional requirement)
- [x] Use `lib.mkDefault` for all options (user-overridable)
- [x] NOT access home-manager options (`home.*`, `programs.*` with hm)
- [x] NOT use context validation (`options ? home` not needed)
- [x] Be auto-discoverable via `default.nix`
- [x] Have clear purpose and single responsibility
- [x] Document all dependencies
