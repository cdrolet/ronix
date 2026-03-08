# Phase 0: Research - Niri Family Technology Stack

**Feature**: 041-niri-family\
**Date**: 2026-01-29\
**Purpose**: Technology decisions and best practices for Niri compositor family configuration

## Research Questions

This research resolves all technology choices for implementing the Niri family desktop environment on NixOS.

## 1. Niri Package Availability

**Decision**: Use `pkgs.niri` from nixpkgs unstable

**Rationale**:

- Niri version 25.11 is available and actively maintained in nixpkgs unstable
- Binary cache available at `niri.cachix.org` for fast builds
- NixOS module available: `programs.niri.enable`
- Stable enough for day-to-day use according to upstream

**Alternatives Considered**:

- **sodiboo/niri-flake**: Provides Nix-native declarative configuration (`programs.niri.settings`)
  - Pros: Build-time validation, automatic schema sync, better Nix integration
  - Cons: Additional flake dependency
  - **Recommendation**: Consider for future enhancement (Phase 2 or separate feature)

**Implementation**:

- System-level: `programs.niri.enable = true;` in `settings/system/compositor.nix`
- Future: Migrate to niri-flake's `programs.niri.settings` for declarative keybindings

## 2. Display Manager Selection

**Decision**: greetd + tuigreet

**Rationale**:

- Minimal, agnostic, and designed specifically for Wayland
- Available in nixpkgs with `services.greetd.enable`
- Lightweight TUI greeter (tuigreet) written in Rust
- Does not require separate compositor
- Well-documented NixOS patterns

**Alternatives Considered**:

| Display Manager | Status | Why Rejected |
|----------------|--------|--------------|
| greetd + ReGreet | ✅ Works | GUI greeter - overkill for keyboard-focused Niri |
| SDDM | ⚠️ Experimental | Wayland support experimental, still requires X.org |
| GDM | ❌ Not suitable | GNOME-specific, conflicts with Niri family concept |
| Ly | ⚠️ Works | "Not recommended" per community feedback |

**Implementation**:

```nix
# settings/system/display-manager.nix
services.greetd = {
  enable = true;
  settings = {
    default_session.command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd niri-session";
  };
};
```

## 3. Niri Configuration Approach

**Decision**: Use traditional KDL config file managed via Home Manager

**Rationale**:

- KDL (KDL Document Language) is Niri's native format
- Live-reloading: changes apply immediately without restart
- Human-readable, indentation-friendly
- Can be managed declaratively via `xdg.configFile` in Home Manager
- Default config auto-generated if missing (safe fallback)

**Configuration Path**: `~/.config/niri/config.kdl`

**Alternatives Considered**:

- **niri-flake declarative**: `programs.niri.settings` (Nix attrset)
  - Pros: Build-time validation, type-safe, schema sync
  - Cons: Additional flake dependency, overkill for initial family setup
  - **Defer to**: Future enhancement (041-B or separate feature)

**Implementation Pattern**:

```nix
# settings/user/keyboard.nix
xdg.configFile."niri/config.kdl".text = ''
  binds {
    Mod+T { spawn "ghostty"; }
    Mod+Q { close-window; }
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
  }
  
  input {
    keyboard {
      xkb {
        options "caps:ctrl_modifier"
      }
    }
  }
'';
```

## 4. Wallpaper Management

**Decision**: swaybg + systemd user service

**Rationale**:

- Niri has no built-in wallpaper support (compositor focuses on window management)
- swaybg is the standard Wayland wallpaper tool (Sway project)
- Lightweight, single-purpose, well-maintained
- Works with layer-shell protocol

**Integration with Feature 033** (existing wallpaper config):

**Single Wallpaper**:

```nix
# settings/user/wallpaper.nix
systemd.user.services.niri-wallpaper = lib.mkIf hasWallpaper {
  Unit.Description = "Niri wallpaper daemon";
  Service = {
    ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${wallpaperPath} -m fill";
    Restart = "on-failure";
  };
  Install.WantedBy = ["graphical-session.target"];
};
```

**Per-Monitor Wallpapers**:

```nix
# Spawn multiple swaybg instances
systemd.user.services."niri-wallpaper-0" = {
  Service.ExecStart = "${pkgs.swaybg}/bin/swaybg -o DP-1 -i ${path0} -m fill";
};
systemd.user.services."niri-wallpaper-1" = {
  Service.ExecStart = "${pkgs.swaybg}/bin/swaybg -o HDMI-A-1 -i ${path1} -m fill";
};
```

**Alternatives Considered**:

- **hyprpaper**: More features, IPC controls (Hyprland-specific, unnecessary complexity)
- **waypaper**: GUI frontend (conflicts with keyboard-driven Niri philosophy)
- **nitrogen**: X11 tool (not Wayland-native)

## 5. Font Integration

**Decision**: Reuse existing `fonts.fontconfig.defaultFonts` (no changes needed)

**Rationale**:

- Wayland delegates font rendering to client applications
- Applications use fontconfig to discover and render fonts
- Home Manager's `fonts.fontconfig` already works correctly
- No compositor-specific configuration needed
- fc-cache runs automatically via Home Manager

**Implementation**: ✅ **No action required** - Feature 030 font configuration works as-is

**Verification**:

```nix
# Existing user config works unchanged
fonts.fontconfig = {
  enable = true;
  defaultFonts = {
    monospace = ["Berkeley Mono" "Fira Code"];
    sansSerif = ["Inter"];
    serif = ["Crimson Pro"];
  };
};
```

## 6. Dark Mode and Theming

**Decision**: Reuse GNOME family's GTK dark mode settings

**Rationale**:

- Dark mode is application-level, not compositor-level
- GTK applications use `GTK_THEME` environment variable and GTK settings
- dconf `org.gnome.desktop.interface.color-scheme` works for Wayland portals
- Niri doesn't manage themes (compositor is theme-agnostic)

**Implementation**: Share GTK dark mode module between GNOME and Niri families

**Options**:

1. **Shared module** (recommended): Create `system/shared/settings/user/gtk-dark-mode.nix`
1. **Copy GNOME module**: Duplicate `gnome/settings/user/ui.nix` into `niri/settings/user/theme.nix`

**Configuration Pattern**:

```nix
# settings/user/theme.nix (or shared module)
gtk = {
  enable = true;
  gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
};

home.sessionVariables.GTK_THEME = "Adwaita:dark";

dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
```

## 7. Keyboard Shortcuts Configuration

**Decision**: KDL config file with sane defaults, user-customizable

**Rationale**:

- Niri requires explicit keybinding definitions (no default bindings)
- KDL format is human-readable and live-reloadable
- Can provide sensible defaults while allowing user overrides
- Build-time validation deferred to future niri-flake migration

**Key Features**:

- **Mod key**: Super/Windows key (standard for tiling WMs)
- **Default bindings**: Common tiling operations (focus, move, resize, close)
- **Live reload**: Edit and save config, changes apply immediately
- **Discovery tool**: Use `wev` to find XKB key names

**Implementation**:

```nix
# settings/user/keyboard.nix
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
    
    // Workspaces
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    
    // Applications (user should customize)
    Mod+Return { spawn "${terminal}"; }  // Terminal from user config
    Mod+Space { spawn "${launcher}"; }   // Launcher app
  }
'';
```

**Future Enhancement**: Migrate to niri-flake's `programs.niri.settings.binds` for build-time validation

## 8. Panel/Bar for Dock Functionality

**Decision**: Waybar with custom integration for `user.docked`

**Rationale**:

- Waybar is the most mature and widely-used Wayland bar
- GTK-based (matches GNOME family patterns)
- JSON configuration (can be declaratively managed)
- Excellent Niri integration (active community examples)
- Supports custom modules for app launchers

**Integration with `user.docked`**:

- Favorite apps → Waybar custom launcher modules
- Separators (`|`, `||`) → Waybar spacing/gaps
- Folders → Waybar custom scripts (optional, lower priority)
- `<trash>` → Omit (less relevant in tiling WM)

**Implementation Pattern**:

```nix
# app/utility/waybar.nix (Niri-specific app)
programs.waybar = {
  enable = true;
  settings.mainBar = {
    layer = "top";  # Required for Niri visibility
    position = "top";
    modules-left = ["niri/workspaces" "niri/window"];
    modules-center = ["custom/favorites"];  # user.docked apps
    modules-right = ["tray" "clock"];
  };
};
```

**Alternatives Considered**:

| Panel | Type | Why Rejected |
|-------|------|--------------|
| Ironbar | GTK/Rust | Less mature, smaller community |
| Eww | Widget framework | Overkill complexity for simple bar |
| i3bar-river | Minimalist | Too basic, lacks features |

**Decision**: Waybar for Phase 1, consider alternatives as separate app modules users can opt into

## Technology Summary

| Component | Choice | Package | Rationale |
|-----------|--------|---------|-----------|
| **Compositor** | Niri | `pkgs.niri` | Native nixpkgs, stable, active development |
| **Display Manager** | greetd + tuigreet | `pkgs.greetd.greetd`, `pkgs.greetd.tuigreet` | Wayland-native, lightweight, minimal |
| **Configuration** | KDL file | Managed via `xdg.configFile` | Native format, live-reload, human-readable |
| **Wallpaper** | swaybg | `pkgs.swaybg` | Standard Wayland tool, layer-shell support |
| **Fonts** | fontconfig | Existing Feature 030 config | No changes needed, works as-is |
| **Dark Mode** | GTK settings | Shared with GNOME family | Application-level, compositor-agnostic |
| **Keyboard** | KDL config | Niri native keybindings | Explicit bindings, live-reload |
| **Panel/Bar** | Waybar | `pkgs.waybar` | Mature, well-integrated, customizable |

## Future Enhancements (Out of Scope for Phase 1)

1. **niri-flake integration**: Migrate to declarative `programs.niri.settings` for build-time validation
1. **Multi-monitor configuration**: Advanced output management beyond basic mirroring
1. **Additional panels**: Ironbar, Eww as alternative app modules
1. **Notification daemon**: mako or dunst (separate app module)
1. **Launcher app**: fuzzel, rofi, tofi (separate app module)
1. **Session management**: swaylock, swayidle (separate app modules)

## Dependencies

- **Linux family**: Compose with existing `system/shared/family/linux/` for XDG directories, keyboard layout
- **Existing features**: Integrates with Feature 030 (fonts), Feature 033 (wallpaper), Feature 036 (standalone home-manager), Feature 039 (context-segregated settings)
- **Discovery system**: Uses `system/shared/lib/discovery.nix` for auto-loading modules

## References

- [Niri GitHub Repository](https://github.com/YaLTeR/niri)
- [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake)
- [NixOS Wiki: Niri](https://wiki.nixos.org/wiki/Niri)
- [NixOS Wiki: Greetd](https://nixos.wiki/wiki/Greetd)
- [Arch Wiki: Niri](https://wiki.archlinux.org/title/Niri)
- [Niri Configuration: Key Bindings](https://github.com/YaLTeR/niri/wiki/Configuration:-Key-Bindings)
- [awesome-niri: Curated list](https://github.com/Vortriz/awesome-niri)
- [swaybg documentation](https://github.com/swaywm/swaybg)
- [Waybar documentation](https://github.com/Alexays/Waybar)
