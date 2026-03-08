# Research: GNOME Dock Module

**Feature**: 024-gnome-dock-module
**Date**: 2025-12-19
**Status**: Complete
**Based on**: Feature 023 research (see `specs/023-user-dock-config/research.md`)

## Executive Summary

This feature implements the GNOME portion of dock configuration. Research was completed in Feature 023. Key findings for GNOME:

1. Use gsettings/dconf with `.desktop` file names for favorites
1. Trash requires creating a custom `.desktop` file
1. Separators and folders are not supported in GNOME favorites

______________________________________________________________________

## GNOME Favorites Configuration

### API

**Method**: dconf / gsettings

**Schema**: `org.gnome.shell`
**Key**: `favorite-apps`
**Type**: Array of strings (`.desktop` file names)

### Commands

```bash
# Read current favorites
gsettings get org.gnome.shell favorite-apps

# Set favorites
gsettings set org.gnome.shell favorite-apps \
  "['firefox.desktop', 'org.gnome.Nautilus.desktop']"

# Reset to default
gsettings reset org.gnome.shell favorite-apps
```

### Home Manager Integration

Use `dconf.settings` option for declarative configuration:

```nix
dconf.settings = {
  "org/gnome/shell" = {
    favorite-apps = [ "firefox.desktop" "org.gnome.Nautilus.desktop" ];
  };
};
```

______________________________________________________________________

## Desktop File Resolution

### Search Locations (Priority Order)

1. `~/.local/share/applications/` - User .desktop files
1. `/run/current-system/sw/share/applications/` - NixOS system apps
1. `/usr/share/applications/` - Traditional Linux system apps
1. `/var/lib/flatpak/exports/share/applications/` - Flatpak apps (optional)

### Naming Conventions

Desktop files follow various naming patterns:

| App | Common .desktop Names |
|-----|----------------------|
| Firefox | `firefox.desktop`, `org.mozilla.firefox.desktop` |
| Nautilus | `org.gnome.Nautilus.desktop`, `nautilus.desktop` |
| Terminal | `org.gnome.Terminal.desktop`, `gnome-terminal.desktop` |
| VS Code | `code.desktop`, `visual-studio-code.desktop` |

### Resolution Algorithm

```
For app name "firefox":
1. Try exact match: firefox.desktop
2. Try with org prefix: org.*.firefox.desktop
3. Try partial match: *firefox*.desktop
4. If not found, skip silently
```

______________________________________________________________________

## Trash Handling

### Problem

GNOME doesn't include a default `.desktop` file for the trash. To show trash in favorites, we must create one.

### Solution

Create `~/.local/share/applications/trash.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Trash
Comment=View deleted files
Icon=user-trash-full
Exec=nautilus trash://
Categories=Utility;
StartupNotify=true
```

### Implementation

Use Home Manager's `home.file` to create the file:

```nix
home.file.".local/share/applications/trash.desktop" = lib.mkIf hasTrash {
  text = ''
    [Desktop Entry]
    Type=Application
    Name=Trash
    Icon=user-trash-full
    Exec=nautilus trash://
  '';
};
```

______________________________________________________________________

## Unsupported Features

### Separators

GNOME favorites is a simple array of .desktop file names. No separator concept exists.

**Decision**: Silently ignore `|` and `||` entries.

### Folders

GNOME favorites only supports application launchers, not folder shortcuts.

**Decision**: Silently ignore entries starting with `/`.

### darwin-specific System Items

Items like `<launchpad>` are darwin-specific.

**Decision**: Silently ignore unknown system items. Only `<trash>` is handled on GNOME.

______________________________________________________________________

## Module Execution Timing

### Requirement

Desktop file resolution must happen during activation, not evaluation, because:

1. Applications may not be installed yet during evaluation
1. .desktop files are created by package installation

### Solution

Use Home Manager's activation hooks with proper ordering:

```nix
home.activation.configureDock = lib.hm.dag.entryAfter ["writeBoundary"] ''
  # dconf write happens here
'';
```

However, since we're using `dconf.settings`, Home Manager handles the timing automatically.

______________________________________________________________________

## Implementation Design

### Module Structure

```text
system/shared/family/gnome/
├── lib/
│   └── dock.nix       # resolveDesktopFile, mkFavoritesFromDocked
└── settings/
    └── dock.nix       # dconf.settings, trash.desktop creation
```

### Key Functions

```nix
# system/shared/family/gnome/lib/dock.nix

# Resolve app name to .desktop file name
# Returns null if not found
resolveDesktopFile = appName: ...;

# Filter docked list to only GNOME-supported items (apps + trash)
filterForGnome = dockedList: ...;

# Generate favorites list from docked config
mkFavoritesFromDocked = dockedList: ...;
```

______________________________________________________________________

## Sources

- [GNOME Favorites Documentation](https://help.gnome.org/admin//system-admin-guide/3.12/dconf-favorite-applications.html.en)
- [Red Hat GNOME Configuration](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/using_the_desktop_environment_in_rhel_8/customizing-default-favorite-applications_using-the-desktop-environment-in-rhel-8)
- [Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html)
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
- Feature 023 Research: `specs/023-user-dock-config/research.md`
