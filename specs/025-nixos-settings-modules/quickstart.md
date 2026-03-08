# Quickstart: NixOS Settings Modules

**Feature**: 025-nixos-settings-modules

## Overview

This feature creates NixOS system settings modules that mirror the Darwin settings structure, providing sensible defaults for security, locale, keyboard, network, and system configuration.

## Directory Structure

```
system/
├── nixos/
│   └── settings/
│       ├── default.nix      # Auto-discovers all settings
│       ├── security.nix     # Firewall, sudo
│       ├── locale.nix       # Timezone, locale
│       ├── keyboard.nix     # Repeat rate
│       ├── network.nix      # NetworkManager
│       └── system.nix       # Boot, Nix settings
│
└── shared/
    └── family/
        └── gnome/
            └── settings/
                ├── default.nix  # Auto-discovers GNOME settings
                ├── ui.nix       # Dark mode, fonts
                ├── keyboard.nix # Shortcuts
                └── power.nix    # Screen timeout
```

## Usage

### For NixOS Hosts

Settings are automatically applied when a host uses the NixOS platform. User-specific locale settings are read from your user configuration:

```nix
# user/username/default.nix
{ ... }:
{
  user = {
    name = "username";
    timezone = "America/Toronto";
    locale = "en_CA.UTF-8";
    languages = [ "en-CA" "fr-CA" ];
    keyboardLayout = [ "us" ];
  };
}
```

### For GNOME Hosts

GNOME settings are automatically applied when a host includes `gnome` in its family:

```nix
# system/nixos/host/my-desktop/default.nix
{ ... }:
{
  name = "my-desktop";
  family = [ "gnome" ];  # Enables GNOME family settings
  applications = [ "*" ];
  settings = [ "default" ];
}
```

## Adding New Settings

Thanks to auto-discovery, adding new settings is simple:

1. Create a new `.nix` file in the appropriate directory
1. That's it - no import updates needed!

Example:

```bash
# Create a new NixOS setting
touch system/nixos/settings/bluetooth.nix

# Create a new GNOME setting
touch system/shared/family/gnome/settings/notifications.nix
```

## Overriding Defaults

All settings use `lib.mkDefault`, allowing easy overrides in host configuration:

```nix
# In your host config
{
  # Override firewall default
  networking.firewall.allowPing = true;  # Default is false
  
  # Override keyboard repeat
  services.xserver.autoRepeatDelay = 300;  # Default is 200
}
```

## Cross-Platform Consistency

Settings are designed to match Darwin behavior where applicable:

| Setting | Darwin | NixOS |
|---------|--------|-------|
| Keyboard repeat delay | InitialKeyRepeat = 10 | autoRepeatDelay = 200 |
| Keyboard repeat rate | KeyRepeat = 2 | autoRepeatInterval = 25 |
| Firewall enabled | Yes (socketfilterfw) | Yes (iptables/nftables) |
| Timezone | From user.timezone | From user.timezone |
| Locale | From user.locale | From user.locale |

## Verification

After building your NixOS configuration:

```bash
# Check firewall status
sudo iptables -L

# Check timezone
timedatectl

# Check locale
localectl status

# Check GNOME settings (if GNOME)
gsettings get org.gnome.desktop.interface color-scheme
```
