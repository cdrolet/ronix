# User-Level Settings Contracts

**Feature**: 041-niri-family\
**Context**: Home Manager activation (Stage 2, standalone mode)\
**Location**: `system/shared/family/niri/settings/user/`

## Overview

User-level settings run during home-manager activation and configure user-specific state in the home directory. These modules have access to home-manager options and user configuration fields.

## Module Interface Contract

### Required Module Structure

```nix
{
  config,
  lib,
  pkgs,
  options,  # REQUIRED for context validation
  ...
}: {
  config = lib.optionalAttrs (options ? home) {
    # Home Manager configuration here
    # Can access: home.*, programs.*, xdg.*, dconf.*, systemd.user.*
    # Can read: config.user.* fields
  };
}
```

### Context Requirements

- ✅ **MUST use `lib.optionalAttrs (options ? home)` pattern** - Prevents evaluation errors
- ✅ **MUST include `options` in module parameters** - Required for context check
- ❌ **CANNOT access `config._configContext`** - Causes infinite recursion
- ❌ **CANNOT use `lib.mkIf`** - Module system validates option existence even when false

### Common Patterns

**Install User Packages**:

```nix
config = lib.optionalAttrs (options ? home) {
  home.packages = [ pkgs.myapp ];
};
```

**Create Config Files**:

```nix
config = lib.optionalAttrs (options ? home) {
  xdg.configFile."myapp/config".text = ''
    setting = value
  '';
};
```

**Set dconf Settings**:

```nix
config = lib.optionalAttrs (options ? home) {
  dconf.settings."org/myapp" = {
    key = "value";
  };
};
```

**Create Systemd User Services**:

```nix
config = lib.optionalAttrs (options ? home) {
  systemd.user.services.myservice = {
    Unit.Description = "My service";
    Service.ExecStart = "${pkgs.myapp}/bin/myapp";
    Install.WantedBy = ["graphical-session.target"];
  };
};
```

## Module Contracts

### `keyboard.nix`

**Purpose**: Configure Niri window management keybindings

**Inputs**:

- `config.user.terminal` (optional) - Terminal command (default: `${pkgs.ghostty}/bin/ghostty`)
- `config.user.launcher` (optional) - Launcher command (default: `${pkgs.fuzzel}/bin/fuzzel`)
- `config.user.keyboardLayout` (optional) - XKB layout from linux family

**Outputs**:

- `xdg.configFile."niri/config.kdl"` - Niri configuration file with keybindings

**Dependencies**:

- Linux family `config.user.keyboardLayout` (optional)
- User-selected terminal and launcher apps

**Validation**:

- Uses `lib.optionalAttrs (options ? home)`
- Reads user config with fallbacks
- Module \<200 lines

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  terminal = config.user.terminal or "${pkgs.ghostty}/bin/ghostty";
  launcher = config.user.launcher or "${pkgs.fuzzel}/bin/fuzzel";
in {
  config = lib.optionalAttrs (options ? home) {
    xdg.configFile."niri/config.kdl".text = ''
      binds {
        Mod+Return { spawn "${terminal}"; }
        Mod+Space { spawn "${launcher}"; }
        Mod+Q { close-window; }
        Mod+Left { focus-column-left; }
        // ... more keybindings
      }
      
      layout {
        gaps 8
      }
    '';
  };
}
```

______________________________________________________________________

### `wallpaper.nix`

**Purpose**: Integrate user wallpaper config with swaybg daemon

**Inputs**:

- `config.user.wallpaper` (optional) - Wallpaper path (string)
- `config.user.wallpapers` (optional) - Per-monitor wallpapers (array, future)
- `config.home.homeDirectory` - Home directory for tilde expansion

**Outputs**:

- `home.packages = [ pkgs.swaybg ]` - Wallpaper tool
- `systemd.user.services.niri-wallpaper` - Wallpaper daemon service

**Dependencies**:

- Feature 033 (wallpaper config pattern)
- nixpkgs `pkgs.swaybg` package

**Validation**:

- Uses `lib.optionalAttrs (options ? home && hasWallpaper)`
- Path expansion with tilde support (`~/` → `$HOME/`)
- Graceful skip if no wallpaper configured

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  hasWallpaper = (config.user.wallpaper or null) != null;
  wallpaperPath = config.user.wallpaper or "";
  
  expandPath = path:
    if lib.hasPrefix "~/" path
    then "${config.home.homeDirectory}/${lib.removePrefix "~/" path}"
    else path;
in {
  config = lib.optionalAttrs (options ? home && hasWallpaper) {
    home.packages = [ pkgs.swaybg ];
    
    systemd.user.services.niri-wallpaper = {
      Unit = {
        Description = "Niri wallpaper daemon (swaybg)";
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${expandPath wallpaperPath} -m fill";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
```

______________________________________________________________________

### `theme.nix`

**Purpose**: GTK dark mode integration

**Inputs**:

- `config.user.darkMode` (optional) - Boolean (default: true for Niri)

**Outputs**:

- `gtk.enable = true` - Enable GTK configuration
- `gtk.gtk3.extraConfig.gtk-application-prefer-dark-theme = true` - GTK3 dark mode
- `gtk.gtk4.extraConfig.gtk-application-prefer-dark-theme = true` - GTK4 dark mode
- `home.sessionVariables.GTK_THEME = "Adwaita:dark"` - Environment variable
- `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"` - Wayland portal

**Dependencies**: None (standard GTK theming)

**Validation**:

- Uses `lib.optionalAttrs (options ? home && darkMode)`
- Defaults to dark mode for Niri (minimalist aesthetic)
- Can be shared with GNOME family (future refactor)

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  darkMode = config.user.darkMode or true;
in {
  config = lib.optionalAttrs (options ? home && darkMode) {
    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    };
    
    home.sessionVariables.GTK_THEME = "Adwaita:dark";
    
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
```

______________________________________________________________________

### `default.nix`

**Purpose**: Auto-discovery entry point for all user-level modules

**Inputs**: None (discovery system)

**Outputs**: Imports all `.nix` files in directory (except itself) when in home-manager context

**Dependencies**: `system/shared/lib/discovery.nix`

**Validation**:

- Uses `lib.optionalAttrs (options ? home)` for imports
- Recursively discovers all modules
- Context-aware (only imports in home-manager context)

**Example**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = lib.optionalAttrs (options ? home) (
    map (file: ./${file}) (discovery.discoverModules ./.)
  );
}
```

## Integration Points

### With User Configuration

User-level settings read from `config.user.*` fields:

```nix
# user/{username}/default.nix
{
  user = {
    name = "username";
    terminal = "${pkgs.ghostty}/bin/ghostty";     # Read by keyboard.nix
    launcher = "${pkgs.fuzzel}/bin/fuzzel";       # Read by keyboard.nix
    wallpaper = "~/Pictures/wallpaper.jpg";       # Read by wallpaper.nix
    darkMode = true;                              # Read by theme.nix
    keyboardLayout = "us";                        # Read by keyboard.nix (via linux family)
    fonts = { /* ... */ };                        # Read system-wide (Feature 030)
  };
}
```

### With Feature 033 (Wallpaper)

Wallpaper integration follows Feature 033 patterns:

- Single wallpaper: `config.user.wallpaper` (string)
- Per-monitor: `config.user.wallpapers` (array of {monitor, path}) - future enhancement
- Path expansion: `~/` → `$HOME/`
- File validation: Build-time warning if missing

### With Feature 030 (Fonts)

Font configuration works automatically:

- `config.user.fonts.defaults.monospace` - Monospace fonts
- `config.user.fonts.defaults.sansSerif` - Sans-serif fonts
- `config.user.fonts.defaults.serif` - Serif fonts

**No Niri-specific font configuration needed** - Applications read fontconfig automatically.

### With Linux Family

Keyboard layout from linux family:

```nix
# linux/settings/system/keyboard.nix sets XKB layout
# niri/settings/user/keyboard.nix reads config.user.keyboardLayout
```

### With Discovery System

User-level settings auto-imported when:

1. Host declares `family = ["niri"]`
1. Home-manager activation runs (Stage 2)
1. `niri/settings/user/default.nix` imported
1. All user modules discovered and loaded (within `options ? home` guard)

## Error Handling

### Missing User Configuration

```nix
# Graceful fallback to defaults
let
  terminal = config.user.terminal or "${pkgs.ghostty}/bin/ghostty";
in {
  # Use terminal variable (never fails)
}
```

### Context Errors

User-level modules MUST use context validation:

```nix
# ❌ WRONG: Will fail in system context
{
  home.packages = [ pkgs.myapp ];
}

# ✅ CORRECT: Context-guarded
{
  config = lib.optionalAttrs (options ? home) {
    home.packages = [ pkgs.myapp ];
  };
}
```

### Infinite Recursion Prevention

```nix
# ❌ WRONG: Accessing config in condition causes infinite recursion
config = lib.optionalAttrs (config._configContext == "home") { /* ... */ };

# ✅ CORRECT: Use options parameter
config = lib.optionalAttrs (options ? home) { /* ... */ };
```

## Testing Strategy

### Unit Testing (Home Manager Build)

```bash
# Test user-level module evaluation
nix build ".#homeConfigurations.\"user@host\".activationPackage"
```

### Integration Testing (Activation Dry-Run)

```bash
# Test home-manager activation
home-manager build --flake ".#user@host"
./result/activate  # Dry-run mode
```

### Expected Outcomes

1. ✅ Home Manager builds without errors
1. ✅ Niri config file generated (`~/.config/niri/config.kdl`)
1. ✅ swaybg service created (`systemctl --user list-units niri-wallpaper`)
1. ✅ GTK dark mode applied (`echo $GTK_THEME`)
1. ✅ Wallpaper displays on login
1. ✅ Keyboard shortcuts work

## Compliance Checklist

User-level modules MUST:

- [x] Be \<200 lines (constitutional requirement)
- [x] Use `lib.optionalAttrs (options ? home)` pattern (context validation)
- [x] Include `options` in module parameters
- [x] NOT access `config._configContext` (infinite recursion)
- [x] NOT use `lib.mkIf` for context checks (option validation still runs)
- [x] Be auto-discoverable via `default.nix`
- [x] Have clear purpose and single responsibility
- [x] Document all user config fields read
- [x] Provide sensible defaults for optional fields

## Anti-Patterns

### ❌ Using `lib.mkIf` for Context Check

```nix
# WRONG: Module system validates option existence even when condition is false
{
  home.packages = lib.mkIf (options ? home) [ pkgs.myapp ];
}
```

**Error**: `error: The option 'home.packages' does not exist`

### ❌ Accessing Config in Condition

```nix
# WRONG: Causes infinite recursion
config = lib.optionalAttrs (config._configContext == "home") {
  home.packages = [ pkgs.myapp ];
};
```

**Error**: `error: infinite recursion encountered`

### ❌ Missing Options Parameter

```nix
# WRONG: Cannot check context without options parameter
{
  config,
  lib,
  pkgs,
  # options missing!
  ...
}: {
  config = lib.optionalAttrs (options ? home) {  # ERROR: options undefined
    home.packages = [ pkgs.myapp ];
  };
}
```

**Error**: `error: undefined variable 'options'`

### ✅ Correct Pattern

```nix
{
  config,
  lib,
  pkgs,
  options,  # Include options parameter
  ...
}: {
  config = lib.optionalAttrs (options ? home) {  # Check capability, not config
    home.packages = [ pkgs.myapp ];
  };
}
```
