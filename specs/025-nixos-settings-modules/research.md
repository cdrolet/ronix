# Research: NixOS Settings Modules

**Feature**: 025-nixos-settings-modules
**Date**: 2025-12-20
**Status**: Complete

## Executive Summary

This research documents NixOS equivalents for Darwin settings and best practices for GNOME configuration via dconf. The goal is cross-platform consistency while following NixOS conventions.

______________________________________________________________________

## NixOS Settings Equivalents

### Security Settings

**Darwin** (`security.nix`):

- Firewall via `socketfilterfw`
- Guest account disabled
- Screen saver password

**NixOS Equivalent**:

```nix
# Firewall
networking.firewall = {
  enable = true;
  allowPing = false;  # Stealth mode equivalent
};

# Sudo configuration
security.sudo = {
  enable = true;
  wheelNeedsPassword = true;
};

# Polkit for privilege escalation
security.polkit.enable = true;

# Screen lock (via desktop environment)
# Handled in GNOME settings for desktop systems
```

### Locale Settings

**Darwin** (`locale.nix`):

- `time.timeZone` from `user.timezone`
- `system.defaults.CustomUserPreferences` for locale

**NixOS Equivalent**:

```nix
# Timezone (same option, cross-platform)
time.timeZone = lib.mkIf hasTimezone (lib.mkDefault userConfig.timezone);

# System locale
i18n.defaultLocale = lib.mkIf hasLocale (lib.mkDefault userConfig.locale);

# Extra locale settings
i18n.extraLocaleSettings = lib.mkIf hasLocale {
  LC_TIME = userConfig.locale;
  LC_MONETARY = userConfig.locale;
  LC_MEASUREMENT = userConfig.locale;
};
```

### Keyboard Settings

**Darwin** (`keyboard.nix`):

- `KeyRepeat = 2` (fast repeat)
- `InitialKeyRepeat = 10` (delay before repeat)

**NixOS Equivalent**:

```nix
# X11 keyboard settings
services.xserver = {
  autoRepeatDelay = 200;    # InitialKeyRepeat equivalent (ms)
  autoRepeatInterval = 25;  # KeyRepeat equivalent (ms between repeats)
};

# Console keyboard
console.useXkbConfig = true;  # Apply X settings to console
```

**Conversion Notes**:

- Darwin KeyRepeat: Lower = faster (2 is very fast)
- NixOS autoRepeatInterval: Lower = faster (25ms between repeats)
- Darwin InitialKeyRepeat: Lower = shorter delay
- NixOS autoRepeatDelay: Lower = shorter delay (200ms is moderate)

### Network Settings

**Darwin** (`network.nix`):

- AirDrop over Ethernet
- Network browser settings

**NixOS Equivalent**:

```nix
# NetworkManager for desktop
networking.networkmanager.enable = true;

# DNS settings
networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

# Hostname (from host config)
networking.hostName = hostConfig.name;
```

### System Settings

**Darwin** (`system.nix`):

- Automatic text substitution (disabled)
- Show file extensions
- Disable open confirmation

**NixOS Equivalent**:

```nix
# Nix settings
nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  auto-optimise-store = true;
};

# Garbage collection
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

# Boot loader
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
```

______________________________________________________________________

## Linux Family: Mac-Style Keyboard Remapping

### Problem

Users switching between macOS and Linux want consistent keyboard behavior. On Mac, the Command key is the primary modifier for shortcuts (Cmd+C, Cmd+V). On Linux, this is typically Ctrl.

### Solution: XKB Options

Use `services.xserver.xkb.options` to remap modifier keys:

```nix
# system/shared/family/linux/settings/keyboard.nix
{
  services.xserver.xkb.options = lib.concatStringsSep "," [
    "ctrl:swap_lwin_lctl"    # Swap Left Win (Super) with Left Ctrl
    "ctrl:swap_rwin_rctl"    # Swap Right Win (Super) with Right Ctrl
  ];
}
```

### Key Mappings

| Physical Key | Mac Behavior | Linux Default | Linux with Remap |
|--------------|--------------|---------------|------------------|
| Left Super (Win) | Command | Super | Ctrl |
| Left Ctrl | Control | Ctrl | Super |
| Left Alt | Option | Alt | Alt (unchanged) |

### Alternative: Per-User via Home Manager

For user-specific remapping (if not all users want Mac layout):

```nix
# In home-manager config
home.keyboard.options = [ "ctrl:swap_lwin_lctl" ];
```

### Console Keyboard

To apply the same remapping to the Linux console (TTY):

```nix
console.useXkbConfig = true;  # Use X keyboard config for console
```

______________________________________________________________________

## GNOME Settings via dconf

### UI Settings

**dconf Path**: `org/gnome/desktop/interface`

```nix
dconf.settings = {
  "org/gnome/desktop/interface" = {
    # Dark mode
    color-scheme = "prefer-dark";
    gtk-theme = "Adwaita-dark";
    
    # Font rendering
    font-antialiasing = "rgba";
    font-hinting = "slight";
    
    # Animations
    enable-animations = true;
  };
};
```

### Keyboard Settings

**dconf Path**: `org/gnome/desktop/input-sources`

```nix
dconf.settings = {
  "org/gnome/desktop/input-sources" = {
    # Input sources from user config
    sources = [ 
      (lib.hm.gvariant.mkTuple [ "xkb" "us" ])
    ];
  };
  
  "org/gnome/desktop/wm/keybindings" = {
    # Common shortcuts
    close = [ "<Super>q" ];
    switch-applications = [ "<Super>Tab" ];
  };
};
```

### Power Settings

**dconf Path**: `org/gnome/settings-daemon/plugins/power`

```nix
dconf.settings = {
  "org/gnome/settings-daemon/plugins/power" = {
    # Screen timeout (seconds, 0 = never)
    sleep-inactive-ac-timeout = 1800;  # 30 minutes
    sleep-inactive-ac-type = "suspend";
    
    # Display off timeout
    idle-dim = true;
  };
  
  "org/gnome/desktop/session" = {
    idle-delay = lib.hm.gvariant.mkUint32 300;  # 5 minutes to dim
  };
};
```

______________________________________________________________________

## Auto-Discovery Pattern

The Darwin settings use this pattern in `default.nix`:

```nix
{ config, lib, pkgs, ... }:
let
  discovery = import ../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

This pattern:

1. Imports the discovery library
1. Calls `discoverModules` on current directory
1. Maps each discovered file to an import

**For NixOS**: Use the exact same pattern in `system/nixos/settings/default.nix`

**For GNOME**: Update `system/shared/family/gnome/settings/default.nix` to use auto-discovery instead of manual imports.

______________________________________________________________________

## User Config Access Pattern

Both Darwin and NixOS modules access user configuration via:

```nix
# Get primary user
primaryUser = config.system.primaryUser or null;

# Access user config
userConfig =
  if primaryUser != null && config.home-manager.users ? ${primaryUser}
  then config.home-manager.users.${primaryUser}.config.user or {}
  else {};

# Check if field is set
hasTimezone = userConfig ? timezone && userConfig.timezone != null;
```

This pattern is used in Darwin's `locale.nix` and should be replicated in NixOS.

______________________________________________________________________

## Sources

- [NixOS Manual - Firewall](https://nixos.org/manual/nixos/stable/#sec-firewall)
- [NixOS Manual - Locale](https://nixos.org/manual/nixos/stable/#sec-i18n)
- [Home Manager - dconf](https://nix-community.github.io/home-manager/options.xhtml#opt-dconf.settings)
- [GNOME dconf Keys Reference](https://help.gnome.org/admin/system-admin-guide/stable/dconf-keyfiles.html.en)
- Darwin settings in `system/darwin/settings/`
