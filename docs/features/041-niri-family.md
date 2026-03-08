# Niri Family Desktop Environment

**Feature**: 041-niri-family\
**Status**: ✅ Implemented\
**Type**: NixOS Desktop Family

## Overview

The Niri family provides a **Wayland tiling compositor** desktop environment as an alternative to GNOME. Niri is a scrollable-tiling window manager that focuses on keyboard-driven workflows and minimalist aesthetics.

## Quick Start

### 1. Configure Your Host

Add the Niri family to your NixOS host configuration:

```nix
# system/nixos/host/my-workstation/default.nix
{
  name = "my-workstation";
  family = ["linux", "niri"];  # IMPORTANT: linux must come first
  applications = ["*"];
  settings = ["default"];
}
```

### 2. Optional: Customize User Preferences

```nix
# user/myusername/default.nix
{
  user = {
    name = "myusername";
    applications = [
      "ghostty"    # Terminal
      "fuzzel"     # Launcher
      "waybar"     # Panel/bar (optional)
      "firefox"
      # ... other apps
    ];
    
    # Optional: Default applications (with fallback chains)
    default = {
      terminal = ["ghostty" "foot"];  # Used in Mod+Return (first available)
      launcher = ["fuzzel" "tofi"];   # Used in Mod+Space (first available)
    };
    
    # Optional: Desktop appearance
    wallpaper = "~/Pictures/wallpaper.jpg";  # Desktop background
    darkMode = true;                         # Default for Niri
  };
}
```

### 3. Install

```bash
# Build and apply configuration
just install myusername my-workstation

# Or manually:
sudo nixos-rebuild switch --flake ".#myusername-my-workstation"
home-manager switch --flake ".#myusername@my-workstation"
```

### 4. Reboot and Login

1. Reboot your system
1. At the login screen (greetd), enter your username and password
1. Select "niri-session" from the session menu
1. Niri will start automatically

## Features

### ✅ What's Included

- **Niri Compositor**: Scrollable-tiling Wayland compositor
- **greetd + tuigreet**: Minimal, Wayland-native display manager
- **Keyboard Shortcuts**: Pre-configured keybindings for window management
- **Wallpaper Support**: Integration with `user.wallpaper` configuration
- **Dark Mode**: GTK dark theme enabled by default
- **Font Integration**: Works automatically with Feature 030 font configuration
- **Waybar Panel**: Optional panel/bar with workspace and window info

### 🎨 Appearance Integration

The Niri family integrates with your existing user configuration:

- **Wallpaper**: Set `user.wallpaper = "~/Pictures/image.jpg"` (uses swaybg)
- **Fonts**: Uses your `user.fonts.defaults` configuration automatically
- **Dark Mode**: Enabled by default, configurable via `user.darkMode`

### ⌨️ Default Keyboard Shortcuts

**Window Management**:

- `Mod+Q` - Close window
- `Mod+Left/Right/Up/Down` - Focus window
- `Mod+Shift+Left/Right/Up/Down` - Move window
- `Mod+H/J/K/L` - Vim-style window focus
- `Mod+F` - Maximize window
- `Mod+Shift+F` - Fullscreen window
- `Mod+R` - Cycle window widths
- `Mod+C` - Center window

**Workspaces**:

- `Mod+1` through `Mod+9` - Switch to workspace
- `Mod+Shift+1` through `Mod+Shift+9` - Move window to workspace

**Applications**:

- `Mod+Return` - Open terminal (uses `user.default.terminal` with fallback chain)
- `Mod+Space` or `Mod+D` - Open launcher (uses `user.default.launcher` with fallback chain)

**System**:

- `Mod+Shift+E` - Quit Niri
- `Mod+Shift+P` - Power off monitors

**Note**: `Mod` = Super key (Windows key)

## Configuration

### Default Applications

The Niri family uses a **fallback chain system** for default applications. You specify a list of preferences, and the system uses the first available one:

```nix
# user/myusername/default.nix
{
  user = {
    default = {
      terminal = ["ghostty" "foot" "kitty"];  # First available wins
      launcher = ["fuzzel" "tofi" "rofi-wayland"];
    };
  };
}
```

**How it works**:

1. Keyboard module tries each app in order
1. First app found in nixpkgs is used
1. If none exist, built-in fallback is used (foot for terminal, fuzzel for launcher)

**Supported formats**:

```nix
# App names (resolved to nixpkgs packages)
terminal = ["ghostty" "foot"];

# Full paths (used as-is)
terminal = ["${pkgs.ghostty}/bin/ghostty" "${pkgs.foot}/bin/foot"];

# Mixed (first available full path or app name)
terminal = ["/custom/path/to/terminal" "ghostty" "foot"];
```

**Resolution library**: `user/shared/lib/defaults.nix` provides the resolution logic:

- `getDefault {config, name, default}` - Generic resolver for any default type
- `resolveApp "app-name"` - Converts app name to full path
- `resolveDefault {apps, fallback}` - Generic fallback chain resolver

Example usage in modules:

```nix
terminal = defaults.getDefault {
  inherit config;
  name = "terminal";           # Looks at config.user.default.terminal
  default = "${pkgs.foot}/bin/foot";  # Used if not configured
};
```

## Architecture

### Directory Structure

```
system/shared/family/niri/
├── settings/
│   ├── system/              # System-level (NixOS context)
│   │   ├── default.nix      # Auto-discovery
│   │   ├── compositor.nix   # Niri compositor
│   │   ├── display-manager.nix  # greetd configuration
│   │   └── session.nix      # Wayland session setup
│   └── user/                # User-level (home-manager context)
│       ├── default.nix      # Auto-discovery
│       ├── keyboard.nix     # Keybindings
│       ├── wallpaper.nix    # Wallpaper integration
│       └── theme.nix        # Dark mode/GTK theme
└── app/utility/
    └── waybar.nix          # Optional panel/bar
```

### How It Works

1. **Declaration**: You declare `family = ["linux", "niri"]` in your host config
1. **Auto-Discovery**: The discovery system automatically finds and imports Niri modules
1. **System Build**: System-level modules install Niri, greetd, and configure Wayland
1. **User Build**: User-level modules configure keybindings, wallpaper, and theme
1. **First Boot**: Login via greetd, Niri starts automatically with your preferences

## Family Composition

The Niri family **composes with the Linux family**:

```nix
family = ["linux", "niri"];  # Both required for best experience
```

**What Linux family provides**:

- XDG base directories (`~/.config`, `~/.local/share`)
- Keyboard layout configuration (XKB)
- Font cache management

**What Niri family adds**:

- Niri compositor
- greetd display manager
- Wayland environment setup
- Keyboard shortcuts for tiling WM
- Wallpaper daemon (swaybg)
- GTK dark mode

## Customization

### Change Keyboard Shortcuts

Edit the Niri configuration file:

```nix
# system/shared/family/niri/settings/user/keyboard.nix
# Modify the binds section in the KDL config
```

Rebuild your home configuration:

```bash
home-manager switch --flake ".#username@hostname"
```

### Change Wallpaper

```nix
# user/username/default.nix
user.wallpaper = "~/Pictures/my-wallpaper.jpg";
```

Rebuild:

```bash
home-manager switch --flake ".#username@hostname"
```

### Add a Panel/Bar

The Waybar panel is optional. To enable it:

```nix
# user/username/default.nix
user.applications = ["waybar" /* ... */];
```

Alternative panels you can configure as apps:

- Ironbar (Rust-based)
- Eww (widget framework)
- i3bar-river (minimalist)

## Migration from GNOME

Switching from GNOME to Niri is a one-line change:

```nix
# Before
family = ["linux", "gnome"];

# After
family = ["linux", "niri"];
```

**What stays the same**:

- ✅ All your applications work
- ✅ Fonts configuration (fontconfig)
- ✅ GTK themes and appearance
- ✅ Wayland compatibility

**What changes**:

- Desktop environment: GNOME Shell → Niri
- Display manager: GDM → greetd
- Window management: Floating/tiling hybrid → Scrollable tiling
- Workflow: Mouse + keyboard → Primarily keyboard

## Troubleshooting

### Niri doesn't start after login

Check greetd logs:

```bash
journalctl -u greetd -f
```

Verify Niri is installed:

```bash
which niri-session
```

### Wallpaper not displaying

Check wallpaper service:

```bash
systemctl --user status niri-wallpaper
journalctl --user -u niri-wallpaper -f
```

Verify file exists:

```bash
ls -l ~/Pictures/wallpaper.jpg
```

### Keyboard shortcuts not working

Check Niri config:

```bash
cat ~/.config/niri/config.kdl
```

Validate syntax:

```bash
niri validate ~/.config/niri/config.kdl
```

### GTK apps not dark

Check environment:

```bash
echo $GTK_THEME  # Should be: Adwaita:dark
```

Check dconf:

```bash
gsettings get org.gnome.desktop.interface color-scheme
# Should be: 'prefer-dark'
```

## Technical Details

### Package Sources

- **Niri**: `pkgs.niri` from nixpkgs unstable
- **greetd**: `pkgs.greetd.greetd` and `pkgs.greetd.tuigreet`
- **swaybg**: `pkgs.swaybg` (wallpaper daemon)
- **Waybar**: `pkgs.waybar` (optional panel)

### Module Sizes

All modules comply with the constitutional 200-line limit:

| Module | Lines | Status |
|--------|-------|--------|
| waybar.nix | 143 | ✅ \<200 |
| keyboard.nix | 102 | ✅ \<200 |
| wallpaper.nix | 38 | ✅ \<200 |
| theme.nix | 35 | ✅ \<200 |
| All others | \<20 | ✅ \<200 |

### Context Validation

All user-level modules use the constitutional `lib.optionalAttrs (options ? home)` pattern to prevent evaluation errors.

## Resources

- [Niri Documentation](https://github.com/YaLTeR/niri/wiki)
- [NixOS Wiki: Niri](https://wiki.nixos.org/wiki/Niri)
- [Feature Specification](../../specs/041-niri-family/spec.md)
- [Implementation Plan](../../specs/041-niri-family/plan.md)

## Support

For issues or questions:

1. Check the [quickstart guide](../../specs/041-niri-family/quickstart.md)
1. Verify family declaration: `family = ["linux", "niri"]`
1. Run `nix flake check` for syntax validation
1. Check system logs: `journalctl -xe`
