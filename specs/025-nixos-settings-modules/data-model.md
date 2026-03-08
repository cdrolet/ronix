# Data Model: NixOS Settings Modules

**Feature**: 025-nixos-settings-modules
**Date**: 2025-12-20

## Entities

### Settings Module

A Nix module file containing related system configuration options.

| Field | Type | Description |
|-------|------|-------------|
| path | String | File path (e.g., `system/nixos/settings/security.nix`) |
| topic | String | Configuration topic (security, locale, keyboard, etc.) |
| platform | String | Target platform (nixos, gnome, shared) |

### User Config Fields

Fields read from user configuration for locale settings.

| Field | Type | Description |
|-------|------|-------------|
| timezone | String | IANA timezone (e.g., "America/Toronto") |
| locale | String | POSIX locale (e.g., "en_CA.UTF-8") |
| languages | [String] | Language preferences (e.g., ["en-CA", "fr-CA"]) |
| keyboardLayout | [String] | Keyboard layouts (e.g., ["us", "canadian-french"]) |

### dconf Setting

A GNOME configuration stored in the dconf database.

| Field | Type | Description |
|-------|------|-------------|
| path | String | dconf path (e.g., "org/gnome/desktop/interface") |
| key | String | Setting key (e.g., "color-scheme") |
| value | Any | Setting value (string, int, bool, array) |

## Module Mapping

### NixOS Core Settings

| Module | NixOS Options Used |
|--------|-------------------|
| security.nix | `networking.firewall.*`, `security.sudo.*`, `security.polkit.*` |
| locale.nix | `time.timeZone`, `i18n.defaultLocale`, `i18n.extraLocaleSettings` |
| keyboard.nix | `services.xserver.autoRepeat*`, `console.useXkbConfig` |
| network.nix | `networking.networkmanager.*`, `networking.nameservers` |
| system.nix | `nix.settings.*`, `nix.gc.*`, `boot.loader.*` |

### GNOME Family Settings

| Module | dconf Paths Used |
|--------|-----------------|
| ui.nix | `org/gnome/desktop/interface` |
| keyboard.nix | `org/gnome/desktop/input-sources`, `org/gnome/desktop/wm/keybindings` |
| power.nix | `org/gnome/settings-daemon/plugins/power`, `org/gnome/desktop/session` |

## State Transitions

### Auto-Discovery Flow

```
Settings Directory
    ↓ discoverModules
List of .nix files (excluding default.nix)
    ↓ map to imports
NixOS module imports
    ↓ evaluate
Applied system configuration
```

### User Config Flow

```
user/{username}/default.nix
    ↓ defines user.* options
Home Manager user config
    ↓ accessed via config.home-manager.users.${primaryUser}
Settings modules read user.timezone, user.locale, etc.
    ↓ apply with lib.mkDefault
System/GNOME settings configured
```

## Nix Type Definitions

### Settings Module Structure

```nix
# system/nixos/settings/{topic}.nix
{ config, lib, pkgs, ... }:
let
  # Access user config
  primaryUser = config.system.primaryUser or null;
  userConfig = if primaryUser != null
    then config.home-manager.users.${primaryUser}.config.user or {}
    else {};
    
  # Check field availability
  hasField = field: userConfig ? ${field} && userConfig.${field} != null;
in {
  # NixOS options
  option.path = lib.mkIf (hasField "fieldName") (
    lib.mkDefault userConfig.fieldName
  );
}
```

### GNOME Settings Module Structure

```nix
# system/shared/family/gnome/settings/{topic}.nix
{ config, lib, pkgs, ... }:
{
  dconf.settings = {
    "org/gnome/path" = {
      setting-key = lib.mkDefault value;
    };
  };
}
```
