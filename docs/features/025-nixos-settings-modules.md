# Feature 025: NixOS Settings Modules

NixOS and family settings modules inspired by Darwin's settings structure.

## Overview

This feature adds platform and family settings with auto-discovery:

- **NixOS Core**: Security, locale, keyboard, network, system settings
- **Linux Family**: Mac-style keyboard remapping (Super↔Ctrl swap)
- **GNOME Family**: UI, keyboard shortcuts, power management

## Directory Structure

```
system/
  nixos/
    settings/
      default.nix      # Auto-discovery
      security.nix     # Firewall, sudo, polkit
      locale.nix       # Timezone, locale from user config
      keyboard.nix     # Key repeat rate
      network.nix      # NetworkManager, DNS
      system.nix       # Boot, Nix settings, GC

  shared/
    family/
      linux/
        settings/
          default.nix    # Auto-discovery + XDG
          keyboard.nix   # Mac-style modifier remapping

      gnome/
        settings/
          default.nix    # Auto-discovery + GTK
          ui.nix         # Dark mode, fonts
          keyboard.nix   # Window shortcuts
          power.nix      # Screen timeout, suspend
          dock.nix       # Favorites from user.docked
```

## Usage

### NixOS Host with Linux + GNOME

```nix
# system/nixos/host/my-workstation/default.nix
{ ... }:
{
  name = "my-workstation";
  family = ["linux", "gnome"];  # Gets keyboard remapping + GNOME settings
  applications = ["*"];
  settings = ["default"];
}
```

### What You Get

**From `family = ["linux"]`**:

- Super/Ctrl keys swapped to match Mac keyboard layout
- XDG base directories enabled

**From `family = ["gnome"]`**:

- Dark mode enabled
- Mac-style shortcuts (Super+Q to close, Super+Tab to switch apps)
- Screen timeout and power settings
- Dock favorites from `user.docked`

**From NixOS settings**:

- Firewall enabled with stealth mode
- Sudo configured for wheel group
- Timezone and locale from user config
- Fast key repeat (matching Darwin)
- NetworkManager with fallback DNS
- Flakes enabled, weekly garbage collection

## Keyboard Remapping

The Linux family swaps Super and Ctrl keys to match Mac layout:

| Physical Key | Default Linux | With Remapping |
|--------------|--------------|----------------|
| Left Super (Win) | Super | Ctrl |
| Left Ctrl | Ctrl | Super |
| Right Super | Super | Ctrl |
| Right Ctrl | Ctrl | Super |

This means muscle memory from Mac (Cmd+C, Cmd+V) works on Linux (now Super+C which acts as Ctrl+C).

## User Config Integration

Settings read from user config where applicable:

```nix
# user/myuser/default.nix
{ ... }:
{
  user = {
    name = "myuser";
    timezone = "America/Toronto";     # Used by locale.nix
    locale = "en_CA.UTF-8";           # Used by locale.nix
    docked = ["firefox" "terminal"];  # Used by dock.nix
  };
}
```

## Adding New Settings

Just create a `.nix` file in the appropriate settings directory:

```nix
# system/nixos/settings/audio.nix
{ config, lib, pkgs, ... }:
{
  # PipeWire audio
  services.pipewire = {
    enable = lib.mkDefault true;
    alsa.enable = lib.mkDefault true;
    pulse.enable = lib.mkDefault true;
  };
}
```

The auto-discovery in `default.nix` will automatically import it.

## Related Features

- Feature 018: User locale configuration
- Feature 021: Host/family architecture
- Feature 023: User dock configuration
- Feature 024: GNOME dock module
