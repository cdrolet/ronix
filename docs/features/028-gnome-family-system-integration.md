# Feature 028: GNOME Family System Integration

Cross-platform family architecture with system/user level separation for GNOME desktop environments.

## Overview

This feature reorganizes the GNOME family to properly separate system-level desktop installation from user-level configuration:

- **System-level**: GNOME Shell, GDM, Wayland, core apps (NixOS only)
- **User-level**: dconf settings, GTK themes, optional tools (all platforms)
- **Hierarchical Discovery**: Apps discovered without default.nix files
- **Platform-Agnostic**: Generic NixOS options work across configurations

## Key Changes

### Before (Feature 025)

- Family apps had `default.nix` with manual imports
- GNOME settings mixed system and user concerns
- No clear desktop environment installation
- Nautilus as separate user app

### After (Feature 028)

- Family apps discovered hierarchically (no `default.nix`)
- System-level `desktop/` modules install GNOME
- User-level modules configure preferences
- Nautilus included with `services.gnome.core-apps`

## Directory Structure

```
system/shared/family/gnome/
  app/                          # User-level apps (hierarchical discovery)
    utility/
      gedit.nix                # Individual apps (no default.nix!)
    README.md                  # Family app documentation
    
  settings/                    # System-level settings (NixOS only)
    default.nix                # Auto-discovery
    desktop/
      default.nix              # Auto-discovery for desktop modules
      gnome-core.nix           # GNOME Shell, GDM, core-apps
      gnome-optional.nix       # Optional components (disabled)
      gnome-exclude.nix        # Exclude unwanted packages
    ui.nix                     # User interface (dconf)
    keyboard.nix               # Window shortcuts
    power.nix                  # Screen timeout, suspend
    dock.nix                   # Dock favorites
    wayland.nix                # Wayland display server
    shortcuts.nix              # Global keyboard shortcuts
```

## Usage

### Enable GNOME Desktop

```nix
# system/nixos/host/my-workstation/default.nix
{ ... }:
{
  name = "my-workstation";
  family = ["linux", "gnome"];  # Auto-installs GNOME desktop
  applications = ["firefox", "gedit"];
  settings = ["default"];
}
```

When you declare `family = ["gnome"]`:

1. **System level**: GNOME desktop automatically installed

   - GNOME Shell + GDM display manager
   - Core apps (nautilus, calculator, etc.)
   - Wayland enabled with Electron support
   - GNOME keyring

1. **User level**: Apps discovered hierarchically

   - User-selected apps like `firefox`, `gedit`
   - Searched in: `nixos/app/` → `gnome/app/` → `linux/app/` → `shared/app/`

## What You Get

### System-Level (Automatic)

**Desktop Environment** (`desktop/gnome-core.nix`):

- GNOME Shell (desktop environment)
- GDM (login manager)
- GNOME core apps (nautilus, calculator, text-editor, etc.)
- GNOME keyring for secrets management

**Wayland** (`wayland.nix`):

- GDM Wayland enabled
- `NIXOS_OZONE_WL=1` for Electron apps

**Exclusions** (`desktop/gnome-exclude.nix`):

- Removes: gnome-tour, gnome-user-docs, epiphany (use Firefox/Brave)

**Optional Components Disabled** (`desktop/gnome-optional.nix`):

- Dev tools: Disabled by default
- Games: Disabled by default

### User-Level (Via dconf)

**UI Settings** (`ui.nix`):

- Dark mode enabled
- Font configuration
- Animation preferences

**Keyboard Shortcuts** (`keyboard.nix`):

- Super+Q: Close window
- Super+W: Switch windows
- Super+Tab: Switch apps

**Power Management** (`power.nix`):

- Screen timeout settings
- Suspend configuration

**Dock** (`dock.nix`):

- Favorites from `user.docked` array

**Global Shortcuts** (`shortcuts.nix`):

- Ctrl+Alt+Space: Toggle activities overview

## Hierarchical App Discovery

Family apps are discovered without `default.nix` files:

```nix
# User selects apps
user.applications = ["firefox", "gedit"];

# Discovery searches in order:
# 1. system/nixos/app/
# 2. system/shared/family/gnome/app/
# 3. system/shared/family/linux/app/
# 4. system/shared/app/
```

**Benefits**:

- Users opt-in to apps (no automatic imports)
- Apps can exist in multiple families
- First match wins (specific overrides general)
- No maintenance of import lists

## Adding Apps to GNOME Family

### Regular Apps

```nix
# system/shared/family/gnome/app/utility/gedit.nix
{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.gnome-text-editor ];
}
```

### Apps with GNOME Shell Extensions

For apps requiring system tray or other GNOME Shell features:

```nix
# system/shared/family/gnome/app/communication/discord.nix
{ config, pkgs, lib, ... }:
{
  home.packages = [ pkgs.discord ];
  
  # Per-app GNOME Shell extensions
  home.packages = with pkgs.gnomeExtensions; [
    appindicator  # System tray for this app
  ];
  
  # Enable extensions via dconf
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = lib.mkDefault [
        "appindicator@rgcjonas.gmail.com"
      ];
    };
  };
}
```

**Pattern**: Apps declare their own extensions (no centralized `systray.nix`).

See `system/shared/family/gnome/app/README.md` for full documentation.

## Platform-Agnostic Design

Family modules use generic NixOS options:

```nix
# ✅ Good: Generic dconf (works across NixOS configs)
dconf.settings = {
  "org/gnome/desktop/interface" = {
    color-scheme = lib.mkDefault "prefer-dark";
  };
};

# ❌ Bad: Direct GNOME API calls (platform lock-in)
services.gnome.gnome-settings-daemon.plugins.color = {
  night-light-enabled = true;
};
```

This allows families to work across different NixOS configurations without platform-specific dependencies.

## Overriding Settings

All settings use `lib.mkDefault` for easy overriding:

```nix
# In a host configuration
{ config, lib, ... }:
{
  # Override family default (dark mode)
  dconf.settings."org/gnome/desktop/interface".color-scheme = lib.mkForce "prefer-light";
  
  # Enable optional components
  services.gnome.games.enable = lib.mkForce true;
}
```

## System vs User Level

**Why the separation?**

| Level | Scope | Examples | Platform |
|-------|-------|----------|----------|
| System | Desktop environment installation | GNOME Shell, GDM, Wayland | NixOS only |
| User | Personal preferences, themes | dconf settings, GTK themes | All platforms |

**NixOS Architecture**:

- System-level settings imported BEFORE home-manager
- Allows families to install desktop environments
- User-level settings applied via home-manager after system is ready

**Darwin Limitation**:

- nix-darwin has no system-level family settings
- All family configuration happens at user level
- Darwin hosts typically use `family = []`

## Migration Notes

### Removed Files

- `system/shared/family/gnome/app/default.nix` (hierarchical discovery)
- `system/shared/family/linux/app/default.nix` (hierarchical discovery)
- `system/shared/family/gnome/app/utility/nautilus.nix` (now in core-apps)

### Breaking Changes

- Apps no longer auto-imported from families
- Users must explicitly select apps in `user.applications`
- Hosts declaring `family = ["gnome"]` now get full desktop environment

### Migration Path

1. Review `user.applications` - ensure desired apps are listed
1. Test with `nix flake check`
1. Build configuration: `just build <user> <host>`
1. Deploy on NixOS host with `family = ["gnome"]`

## Related Features

- Feature 021: Host/family architecture
- Feature 025: NixOS settings modules
- Feature 017: Platform-agnostic discovery

## Testing

```bash
# Validate configuration
nix flake check

# Build NixOS configuration
just build <user> <nixos-host>

# Test on NixOS host
just install <user> <nixos-host>
```

**Expected Behavior**:

- GNOME desktop environment installed
- GDM login screen at boot
- Wayland session available
- User apps discovered hierarchically
- dconf settings applied at login
