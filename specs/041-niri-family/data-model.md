# Phase 1: Data Model - Niri Family Structure

**Feature**: 041-niri-family\
**Date**: 2026-01-29\
**Purpose**: Define the organizational structure and module relationships for the Niri family

## Overview

The Niri family follows the established family pattern (Feature 028) with context-segregated settings (Feature 039). It provides a Wayland tiling compositor desktop environment as an alternative to GNOME.

## Directory Structure

```
system/shared/family/niri/
├── app/                          # Niri-specific applications (optional)
│   └── utility/
│       └── waybar.nix            # Panel/bar for dock functionality
│
├── settings/                     # Family settings (Feature 039)
│   ├── system/                   # System-level (NixOS context)
│   │   ├── default.nix           # Auto-discovery entry point
│   │   ├── compositor.nix        # Niri compositor installation
│   │   ├── display-manager.nix   # greetd + tuigreet configuration
│   │   └── session.nix           # Niri session setup
│   │
│   └── user/                     # User-level (home-manager context)
│       ├── default.nix           # Auto-discovery entry point
│       ├── keyboard.nix          # Window management keybindings
│       ├── wallpaper.nix         # Wallpaper integration (swaybg)
│       └── theme.nix             # GTK dark mode integration
│
└── lib/                          # Helper libraries (optional, empty initially)
```

## Module Descriptions

### System-Level Settings (`settings/system/`)

#### `default.nix`

**Purpose**: Auto-discovery entry point for system-level modules

**Content**:

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

**Dependencies**: `system/shared/lib/discovery.nix`

______________________________________________________________________

#### `compositor.nix`

**Purpose**: Install and enable Niri compositor

**Options Used**:

- `programs.niri.enable` - Enable Niri compositor
- `environment.systemPackages` - System-wide packages (if needed)

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.niri.enable = lib.mkDefault true;
  
  # Wayland environment variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";  # Electron apps use Wayland
  };
}
```

**Validation**:

- Module size: \<50 lines ✅
- Uses `lib.mkDefault` for overridability ✅
- No context guards needed (system-level only) ✅

______________________________________________________________________

#### `display-manager.nix`

**Purpose**: Configure greetd + tuigreet for Wayland login

**Options Used**:

- `services.greetd.enable` - Enable greetd display manager
- `services.greetd.settings` - Configure greetd sessions

**Configuration**:

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

**Validation**:

- Module size: \<50 lines ✅
- Uses `lib.mkDefault` for overridability ✅
- No context guards needed (system-level only) ✅

______________________________________________________________________

#### `session.nix`

**Purpose**: Set up Niri as a graphical session target

**Options Used**:

- `services.xserver.enable` (if needed for Wayland support)
- Custom session configuration

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Ensure Wayland support
  services.xserver.enable = lib.mkDefault false;  # Wayland-only, no X11
  
  # Session environment
  environment.sessionVariables = {
    XDG_SESSION_TYPE = lib.mkDefault "wayland";
    XDG_CURRENT_DESKTOP = lib.mkDefault "niri";
  };
}
```

**Validation**:

- Module size: \<50 lines ✅
- Uses `lib.mkDefault` for overridability ✅

______________________________________________________________________

### User-Level Settings (`settings/user/`)

#### `default.nix`

**Purpose**: Auto-discovery entry point for user-level modules

**Content**:

```nix
{
  config,
  lib,
  pkgs,
  options,  # Required for context validation
  ...
}: let
  discovery = import ../../../../lib/discovery.nix {inherit lib;};
in {
  imports = lib.optionalAttrs (options ? home) (
    map (file: ./${file}) (discovery.discoverModules ./.)
  );
}
```

**Dependencies**: `system/shared/lib/discovery.nix`

**Validation**:

- Uses `lib.optionalAttrs (options ? home)` pattern ✅
- Context validation prevents evaluation errors ✅

______________________________________________________________________

#### `keyboard.nix`

**Purpose**: Configure Niri window management keybindings

**Options Used**:

- `xdg.configFile."niri/config.kdl"` - Niri configuration file

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Read user preferences if available
  terminal = config.user.terminal or "${pkgs.ghostty}/bin/ghostty";
  launcher = config.user.launcher or "${pkgs.fuzzel}/bin/fuzzel";
in {
  config = lib.optionalAttrs (options ? home) {
    xdg.configFile."niri/config.kdl".text = ''
      binds {
        // Window management
        Mod+Q { close-window; }
        Mod+Left { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up { focus-window-up; }
        Mod+Down { focus-window-down; }
        
        // Move windows
        Mod+Shift+Left { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up { move-window-up; }
        Mod+Shift+Down { move-window-down; }
        
        // Resize
        Mod+R { switch-preset-column-width; }
        Mod+F { maximize-column; }
        Mod+C { center-column; }
        
        // Workspaces
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        
        // Applications
        Mod+Return { spawn "${terminal}"; }
        Mod+Space { spawn "${launcher}"; }
        
        // System
        Mod+Shift+E { quit; }
        Mod+Shift+P { power-off-monitors; }
      }
      
      input {
        keyboard {
          xkb {
            // Layout from linux family (if set)
            ${lib.optionalString (config.user ? keyboardLayout) ''
              layout "${config.user.keyboardLayout}"
            ''}
          }
        }
      }
      
      layout {
        gaps 8
        center-focused-column "never"
        preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
        }
      }
    '';
  };
}
```

**Validation**:

- Module size: \<200 lines ✅
- Uses `lib.optionalAttrs (options ? home)` ✅
- Reads user config fields safely with fallbacks ✅

______________________________________________________________________

#### `wallpaper.nix`

**Purpose**: Integrate user wallpaper config with swaybg

**Options Used**:

- `systemd.user.services` - Wallpaper daemon
- `home.packages` - Install swaybg

**User Config Integration**:

- `config.user.wallpaper` - Single wallpaper (all monitors)
- `config.user.wallpapers` - Per-monitor wallpapers (array of {monitor, path})

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Read user wallpaper config
  hasWallpaper = (config.user.wallpaper or null) != null;
  wallpaperPath = config.user.wallpaper or "";
  
  # Expand tilde paths
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

**Future Enhancement**: Support `config.user.wallpapers` array for per-monitor wallpapers

**Validation**:

- Module size: \<100 lines ✅
- Uses `lib.optionalAttrs (options ? home)` ✅
- Path expansion matches Feature 033 pattern ✅

______________________________________________________________________

#### `theme.nix`

**Purpose**: GTK dark mode integration

**Options Used**:

- `gtk.enable` - Enable GTK configuration
- `gtk.gtk3.extraConfig` - GTK3 dark mode
- `gtk.gtk4.extraConfig` - GTK4 dark mode
- `home.sessionVariables` - Environment variables
- `dconf.settings` - Wayland portal dark mode

**User Config Integration**:

- `config.user.darkMode` - Boolean (if defined in future), default: true for Niri

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Default to dark mode for Niri (keyboard-driven, minimalist aesthetic)
  darkMode = config.user.darkMode or true;
in {
  config = lib.optionalAttrs (options ? home && darkMode) {
    gtk = {
      enable = true;
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };
    
    home.sessionVariables = {
      GTK_THEME = "Adwaita:dark";
    };
    
    # Wayland portal dark mode preference
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };
}
```

**Validation**:

- Module size: \<100 lines ✅
- Uses `lib.optionalAttrs (options ? home)` ✅
- Can be shared with GNOME family (future refactor) ✅

______________________________________________________________________

### Applications (`app/utility/`)

#### `waybar.nix`

**Purpose**: Panel/bar for Niri with dock integration

**Options Used**:

- `programs.waybar.enable` - Enable Waybar
- `programs.waybar.settings` - Waybar configuration
- `programs.waybar.style` - CSS styling

**User Config Integration**:

- `config.user.docked` - Array of favorite apps

**Configuration**:

```nix
{
  config,
  lib,
  pkgs,
  options,
  ...
}: let
  # Read user docked apps
  dockedApps = config.user.docked or [];
  hasDocked = dockedApps != [];
  
  # Generate custom launcher modules for docked apps
  # (Simplified for Phase 1, full implementation in tasks)
in {
  config = lib.optionalAttrs (options ? home) {
    programs.waybar = {
      enable = lib.mkDefault true;
      
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          
          modules-left = ["niri/workspaces" "niri/window"];
          modules-center = lib.mkIf hasDocked ["custom/favorites"];
          modules-right = ["tray" "clock"];
          
          "niri/workspaces" = {
            format = "{icon}";
            format-icons = {
              "1" = "󰲠";
              "2" = "󰲢";
              "3" = "󰲤";
              "4" = "󰲦";
            };
          };
          
          "niri/window" = {
            format = "{title}";
            max-length = 50;
          };
          
          clock = {
            format = "{:%H:%M}";
            format-alt = "{:%Y-%m-%d}";
          };
          
          tray = {
            spacing = 10;
          };
        };
      };
      
      style = ''
        * {
          font-family: monospace;
          font-size: 12px;
        }
        
        window#waybar {
          background-color: rgba(30, 30, 46, 0.8);
          color: #cdd6f4;
        }
        
        #workspaces button {
          padding: 0 5px;
          background: transparent;
          color: #cdd6f4;
        }
        
        #workspaces button.active {
          background: rgba(205, 214, 244, 0.2);
        }
      '';
    };
  };
}
```

**Validation**:

- Module size: \<200 lines ✅
- Uses `lib.optionalAttrs (options ? home)` ✅
- Optional app (users can choose alternatives) ✅

______________________________________________________________________

## Entity Relationships

```
Host Config (family = ["linux", "niri"])
  │
  ├──> Linux Family (system/shared/family/linux/)
  │      ├─> settings/system/keyboard.nix (XKB layout)
  │      └─> settings/user/fonts.nix (fontconfig)
  │
  └──> Niri Family (system/shared/family/niri/)
         │
         ├─> System Settings (NixOS context)
         │      ├─> compositor.nix (Niri install)
         │      ├─> display-manager.nix (greetd)
         │      └─> session.nix (Wayland env)
         │
         ├─> User Settings (home-manager context)
         │      ├─> keyboard.nix (reads user.terminal, user.launcher)
         │      ├─> wallpaper.nix (reads user.wallpaper)
         │      └─> theme.nix (reads user.darkMode)
         │
         └─> Apps (optional)
                └─> waybar.nix (reads user.docked)
```

## Module Dependencies

### External Dependencies

- `system/shared/lib/discovery.nix` - Auto-discovery system
- `system/shared/family/linux/` - Linux family (keyboard layout, XDG dirs)
- Feature 030 (fonts) - `config.user.fonts.defaults`
- Feature 033 (wallpaper) - `config.user.wallpaper`, `config.user.wallpapers`
- Feature 036 (standalone home-manager) - User-level activation
- Feature 039 (context segregation) - system/ and user/ subdirectories

### Internal Dependencies

- `settings/system/default.nix` → All system modules
- `settings/user/default.nix` → All user modules
- No circular dependencies ✅

## Configuration Fields

### User Configuration Schema

```nix
# user/{username}/default.nix
{
  user = {
    name = "username";
    applications = ["waybar" "fuzzel" /* ... */];
    
    # Optional fields read by Niri family
    terminal = "<path-to-terminal>";     # Used in keyboard.nix
    launcher = "<path-to-launcher>";     # Used in keyboard.nix
    wallpaper = "~/path/to/image.jpg";   # Used in wallpaper.nix
    wallpapers = [                       # Future: per-monitor wallpapers
      { monitor = 0; path = "~/left.jpg"; }
      { monitor = 1; path = "~/right.jpg"; }
    ];
    darkMode = true;                     # Used in theme.nix (default: true)
    docked = ["firefox" "ghostty"];      # Used in waybar.nix
    keyboardLayout = "us";               # Used in keyboard.nix (from linux family)
    fonts = { /* ... */ };               # Used system-wide (Feature 030)
  };
}
```

### Host Configuration Schema

```nix
# system/nixos/host/example/default.nix
{
  name = "example-host";
  family = ["linux", "niri"];  # Compose Linux + Niri families
  applications = ["*"];
  settings = ["default"];
}
```

## Validation Rules

1. **Module Size**: All modules \<200 lines (constitutional requirement)
1. **Context Validation**: All user-level modules use `lib.optionalAttrs (options ? home)`
1. **Overridability**: All settings use `lib.mkDefault` (except explicit overrides)
1. **Dependencies**: No circular dependencies between modules
1. **Family Composition**: `linux` family MUST be declared before `niri` family in host config
1. **Discovery**: All modules auto-discovered via `default.nix` (no manual imports)

## State Transitions

1. **Build Time (Evaluation)**:

   - Host declares `family = ["linux", "niri"]`
   - Discovery system finds Niri family modules
   - System-level modules evaluated in NixOS context
   - User-level modules evaluated in home-manager context

1. **System Activation (Stage 1)**:

   - Niri compositor installed
   - greetd display manager configured
   - Wayland environment variables set

1. **User Activation (Stage 2)**:

   - Niri config file generated (`~/.config/niri/config.kdl`)
   - swaybg wallpaper daemon started (systemd user service)
   - GTK dark mode applied
   - Waybar launched (if user selected `waybar` app)

1. **Runtime (User Session)**:

   - User logs in via greetd/tuigreet
   - Niri compositor starts
   - Wallpaper displays immediately
   - Waybar shows workspaces and favorites
   - Keyboard shortcuts work instantly

## Success Metrics

- ✅ All modules \<200 lines
- ✅ Context validation prevents evaluation errors
- ✅ All settings user-overridable with `lib.mkDefault`
- ✅ No manual imports (auto-discovery works)
- ✅ Composes correctly with `linux` family
- ✅ User config integration works (wallpaper, fonts, keyboard)
