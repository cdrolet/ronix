# Quick Start: GNOME Desktop on NixOS

**Feature**: GNOME Family System Integration\
**Audience**: End users configuring GNOME desktop on their NixOS systems

## Overview

This guide shows you how to set up a NixOS system with GNOME desktop using the family system. The GNOME family provides a complete desktop environment with modern features like Wayland, customizable shortcuts, and optional utility tools.

______________________________________________________________________

## Prerequisites

- NixOS system with nix-config repository
- Nix flakes enabled
- Basic understanding of Nix configuration files

______________________________________________________________________

## Quick Setup (5 Minutes)

### Step 1: Configure Your Host

Edit your host configuration to use the GNOME family:

```bash
# Edit your host config
$EDITOR system/nixos/host/my-workstation/default.nix
```

Add GNOME to the family list:

```nix
{
  name = "my-workstation";
  family = ["linux" "gnome"];  # Both Linux and GNOME families
  applications = ["*"];          # Optional: system apps
  settings = ["default"];
}
```

**Key Points**:

- `family = ["linux" "gnome"]` - Installs both Linux base utilities and GNOME desktop
- Order matters: later families can override earlier ones
- You can use just `["gnome"]` if you don't want Linux-specific settings

### Step 2: Configure Your User Apps

Edit your user configuration to select GNOME tools:

```bash
# Edit your user config
$EDITOR user/your-username/default.nix
```

Add GNOME apps to your applications:

```nix
{
  user = {
    name = "your-username";
    email = "you@example.com";
    fullName = "Your Name";
    
    applications = [
      # Your existing apps
      "git"
      "zsh"
      "helix"
      
      # Optional GNOME tools
      "gnome-tweaks"    # GNOME customization tool
      "dconf-editor"    # Low-level settings editor
      
      # Or use wildcard to get everything
      # "*"
    ];
  };
}
```

**Key Points**:

- GNOME apps available ONLY if host has `family = ["gnome"]`
- Wildcard `"*"` includes all available apps (shared + platform + family apps)
- Apps are user-specific (each user chooses their own tools)

### Step 3: Build and Apply

Build your configuration:

```bash
# Build without applying
just build your-username my-workstation

# Or build and apply
just install your-username my-workstation
```

Reboot to start GNOME:

```bash
sudo reboot
```

**Expected Result**:

- GDM login screen appears
- GNOME desktop environment loads
- Wayland session active
- Optional tools (gnome-tweaks, dconf-editor) available if you selected them

______________________________________________________________________

## What You Get

### System-Level (Automatic)

When you add `family = ["gnome"]` to your host, you automatically get:

✅ **GNOME Desktop**:

- GNOME Shell (core desktop environment)
- GNOME Control Center (system settings)
- Core GNOME apps (Nautilus file manager, calculator, etc.)

✅ **Display Server**:

- GDM (GNOME Display Manager)
- Wayland support enabled
- Proper graphics stack configuration

✅ **Desktop Features**:

- Application launcher (Ctrl+Alt+Space)
- Window management shortcuts
- Dark mode UI theme
- Power management
- Dock configuration (from user.docked)

### User-Level (Optional)

Apps you can add to `user.applications`:

- `gnome-tweaks` - Customize GNOME appearance and behavior
- `dconf-editor` - Edit low-level GNOME settings
- More GNOME apps as they're added to the family

______________________________________________________________________

## Customization Examples

### Example 1: Minimal GNOME

Just GNOME desktop, no Linux family settings:

```nix
# system/nixos/host/minimal-gnome/default.nix
{
  name = "minimal-gnome";
  family = ["gnome"];  # Only GNOME, no Linux family
  applications = [];
  settings = ["default"];
}
```

### Example 2: Full GNOME with All Apps

GNOME + Linux + all available apps:

```nix
# system/nixos/host/full-gnome/default.nix
{
  name = "full-gnome";
  family = ["linux" "gnome"];
  applications = [];
  settings = ["default"];
}

# user/your-username/default.nix
{
  user = {
    # ...
    applications = ["*"];  # Get everything
  };
}
```

### Example 3: GNOME for Multiple Users

Different apps per user, same GNOME desktop:

```nix
# Host (shared by all users)
{
  name = "shared-workstation";
  family = ["linux" "gnome"];  # All users get GNOME
  applications = [];
  settings = ["default"];
}

# User 1 - Developer
{
  user = {
    name = "developer";
    applications = [
      "git" "zed" "helix"
      "gnome-tweaks"  # Customization tools
    ];
  };
}

# User 2 - Regular user
{
  user = {
    name = "regular";
    applications = [
      "firefox" "libreoffice"
      # No gnome-tweaks - doesn't need it
    ];
  };
}
```

______________________________________________________________________

## Keyboard Shortcuts

GNOME family includes these default shortcuts:

### Application Launcher

- **Ctrl+Alt+Space** - Open application launcher (Activities Overview)

### Window Management

- **Super+Q** - Close window
- **Super+H** - Minimize window
- **Super+↑** - Maximize window
- **Super+↓** - Restore window

### System

- **Super** - Toggle Activities Overview
- **Alt+F2** - Run command

**Customization**: Edit `system/shared/family/gnome/settings/shortcuts.nix` to change shortcuts

______________________________________________________________________

## Dock Configuration

Configure your dock in your user config:

```nix
{
  user = {
    name = "username";
    # ...
    
    docked = [
      # Applications
      "firefox"
      "thunderbird"
      "nautilus"
      
      # Separator
      "|"
      
      # More apps
      "gnome-terminal"
      "gnome-tweaks"
      
      # Folders (tries $HOME first)
      "/Downloads"
      "/Documents"
    ];
  };
}
```

**Dock Features**:

- Application names resolved to GNOME .desktop files
- Folders resolved to `$HOME/<name>` or absolute path
- `"|"` creates separator
- Missing apps/folders silently skipped

______________________________________________________________________

## Wayland vs X11

### Default: Wayland

GNOME family enables Wayland by default for:

- Better performance
- Modern graphics features
- Improved security

### Check Your Session

```bash
echo $XDG_SESSION_TYPE
# Output: wayland
```

### Fallback to X11

If needed, select "GNOME on Xorg" at GDM login screen.

______________________________________________________________________

## Troubleshooting

### GNOME Desktop Not Loading

**Check**: Host has GNOME family

```bash
# View your host config
cat system/nixos/host/your-host/default.nix | grep family
```

**Expected**: `family = ["gnome"]` or `family = ["linux" "gnome"]`

### GNOME Apps Not Available

**Problem**: Apps like `gnome-tweaks` not found

**Solution**: Host must have `family = ["gnome"]` for GNOME apps to be discoverable

```nix
# Host config MUST include gnome
{
  family = ["gnome"];  # Makes GNOME apps available
}

# Then user can select them
{
  user.applications = ["gnome-tweaks"];
}
```

### Wildcard Includes Too Many Apps

**Problem**: `applications = ["*"]` installs hundreds of apps

**Solution**: Be explicit about what you want

```nix
{
  applications = [
    # List only what you need
    "git"
    "zsh"
    "gnome-tweaks"
  ];
}
```

### GDM Not Starting

**Check**: System configuration

```bash
# Check if GNOME enabled
nixos-option services.xserver.desktopManager.gnome.enable
# Should output: true

# Check if GDM enabled
nixos-option services.xserver.displayManager.gdm.enable
# Should output: true
```

**Fix**: Rebuild and reboot

```bash
just install your-username your-host
sudo reboot
```

______________________________________________________________________

## Advanced Configuration

### Exclude GNOME Apps

Don't want certain GNOME apps?

Edit `system/shared/family/gnome/settings/desktop/gnome-exclude.nix`:

```nix
{
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour        # Remove getting started tour
    gnome-user-docs   # Remove help docs
    epiphany          # Remove GNOME Web browser
  ];
}
```

### Enable GNOME Games

Want GNOME games?

Edit `system/shared/family/gnome/settings/desktop/gnome-optional.nix`:

```nix
{
  services.gnome.games.enable = lib.mkForce true;
}
```

### Custom Shortcuts

Add your own shortcuts in `system/shared/family/gnome/settings/shortcuts.nix`:

```nix
{
  dconf.settings = {
    "org/gnome/shell/keybindings" = {
      toggle-overview = ["<Ctrl><Alt>space"];  # Existing
      
      # Add custom shortcuts
      show-screenshot-ui = ["<Shift><Super>s"];
    };
    
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Super>q"];  # Existing
      
      # Add more window shortcuts
      toggle-fullscreen = ["F11"];
    };
  };
}
```

______________________________________________________________________

## Next Steps

### Learn More

- **Architecture**: Read `specs/028-gnome-family-system-integration/spec.md`
- **Data Model**: See `specs/028-gnome-family-system-integration/data-model.md`
- **Constitution**: Review `.specify/memory/constitution.md`

### Extend GNOME Family

Want to add more GNOME apps or settings?

1. Create a new module in `system/shared/family/gnome/settings/` or `app/`
1. Keep modules \<200 lines (constitutional requirement)
1. Use auto-discovery (no need to import manually)
1. Submit PR with your additions

### Other Families

Explore other families:

- `linux` - Linux-specific utilities and settings (Mac-style keyboard remapping)
- More families coming soon (KDE, XFCE, etc.)

______________________________________________________________________

## Getting Help

### Check Configuration

```bash
# View final system configuration
nix eval .#nixosConfigurations.your-host.config.services.xserver

# View user packages
nix eval .#nixosConfigurations.your-host.config.home-manager.users.you.home.packages
```

### Common Commands

```bash
# List available hosts
just list-hosts

# List available users
just list-users

# Check configuration
just check

# Format Nix files
just fmt

# Update dependencies
just update
```

### Community

- File issues: GitHub repository
- Documentation: `docs/` directory
- Specifications: `specs/` directory

______________________________________________________________________

## Summary

**To use GNOME desktop**:

1. Add `family = ["linux" "gnome"]` to your host
1. Optionally add GNOME apps to `user.applications`
1. Run `just install user host`
1. Reboot

**You get**:

- Full GNOME desktop environment (system-wide)
- Wayland support
- Keyboard shortcuts (Ctrl+Alt+Space for launcher)
- Optional GNOME tools (per user)

**Remember**:

- Settings are system-level (all users get GNOME desktop)
- Apps are user-level (each user chooses their tools)
- Wildcard `"*"` includes family apps if family in host
