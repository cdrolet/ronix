# Data Model: GNOME Dock Module

**Feature**: 024-gnome-dock-module
**Date**: 2025-12-19

## Entities

### DesktopFile

A freedesktop `.desktop` file representing an application launcher.

| Field | Type | Description |
|-------|------|-------------|
| filename | String | The .desktop filename (e.g., `firefox.desktop`) |
| path | String | Full path to the .desktop file |
| name | String | Display name from the file |
| exec | String | Command to execute |

### GnomeFavorites

The dconf setting for GNOME Shell favorites.

| Field | Type | Description |
|-------|------|-------------|
| path | String | `org/gnome/shell/favorite-apps` |
| value | [String] | Array of .desktop filenames |

### TrashDesktop

A custom .desktop file for trash access.

| Field | Type | Description |
|-------|------|-------------|
| path | String | `~/.local/share/applications/trash.desktop` |
| name | String | "Trash" |
| icon | String | "user-trash-full" |
| exec | String | "nautilus trash://" |

## Validation Rules

### V1: Desktop File Resolution

1. App name provided (e.g., "firefox")
1. Search XDG directories in order
1. Match by exact name, org prefix, or partial
1. Return first match or null

### V2: Docked Entry Filtering for GNOME

| Entry Type | GNOME Support | Action |
|------------|---------------|--------|
| app | Supported | Resolve to .desktop |
| folder | Not supported | Skip silently |
| separator | Not supported | Skip silently |
| system:trash | Supported | Create trash.desktop |
| system:other | Not supported | Skip silently |

### V3: Favorites Array Generation

```
Input: docked = ["firefox" "|" "nautilus" "/Downloads" "<trash>"]

Filter → ["firefox" "nautilus" "<trash>"]
Resolve → ["firefox.desktop" "org.gnome.Nautilus.desktop" "trash.desktop"]
Output → dconf favorite-apps setting
```

## State Transitions

### Activation Flow

```
User Config (docked array)
    ↓ parse (shared lib)
List<DockEntry>
    ↓ filter (GNOME-supported only)
List<DockEntry> (apps + trash)
    ↓ resolve (.desktop lookup)
List<String> (.desktop filenames)
    ↓ deduplicate
List<String> (unique .desktop files)
    ↓ generate
dconf.settings + optional trash.desktop file
```

## Nix Type Definitions

### GNOME Dock Library Functions

```nix
# system/shared/family/gnome/lib/dock.nix

# Resolve app name to .desktop filename
# Type: String -> String?
resolveDesktopFile = appName: ...;

# Check if entry is GNOME-supported
# Type: { type, value, raw } -> Bool
isGnomeSupported = entry:
  entry.type == "app" ||
  (entry.type == "system" && entry.value == "trash");

# Filter and resolve docked list for GNOME
# Type: [String] -> [String]
mkFavoritesFromDocked = dockedList: ...;

# Check if trash is in docked list
# Type: [{ type, value, raw }] -> Bool
hasTrash = entries:
  lib.any (e: e.type == "system" && e.value == "trash") entries;
```

### GNOME Dock Settings Module

```nix
# system/shared/family/gnome/settings/dock.nix

# Input from user config
userDocked = config.home-manager.users.${userName}.user.docked or [];

# Output: dconf settings
dconf.settings = lib.mkIf hasDockConfig {
  "org/gnome/shell" = {
    favorite-apps = favorites;  # List of .desktop filenames
  };
};

# Output: trash.desktop file (if needed)
home.file.".local/share/applications/trash.desktop" = lib.mkIf hasTrash {
  text = trashDesktopContent;
};
```
