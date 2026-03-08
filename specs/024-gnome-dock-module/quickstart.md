# Quickstart: GNOME Dock Module

**Feature**: 024-gnome-dock-module

## Overview

This module enables the `user.docked` configuration to work on GNOME desktop environments. The same dock configuration that works on Darwin now works on GNOME.

## Basic Usage

The `docked` field in user configuration works the same way:

```nix
# user/username/default.nix
{...}: {
  user = {
    name = "username";
    applications = ["*"];
    
    docked = [
      "firefox"
      "nautilus"
      "terminal"
    ];
  };
}
```

On GNOME, this sets the Shell favorites (the apps shown in the dock/dash).

## GNOME-Specific Behavior

### Supported Items

| Type | Darwin | GNOME |
|------|--------|-------|
| Applications | Yes | Yes |
| Folders | Yes | No (ignored) |
| Separators | Yes | No (ignored) |
| `<trash>` | No-op | Yes (creates .desktop) |

### Example: Cross-Platform Config

```nix
docked = [
  # Apps - work on both platforms
  "firefox"
  "terminal"
  
  # Separator - works on Darwin, ignored on GNOME
  "|"
  
  # More apps
  "nautilus"  # GNOME file manager
  "zed"       # Editor
  
  # Folder - works on Darwin, ignored on GNOME
  "/Downloads"
  
  # Trash - no-op on Darwin, works on GNOME
  "<trash>"
];
```

**Result on GNOME**: Firefox, Terminal, Nautilus, Zed, and Trash appear as favorites.

## Application Names

Use simple application names - the module finds the `.desktop` file:

| You Write | GNOME Finds |
|-----------|-------------|
| `"firefox"` | `firefox.desktop` or `org.mozilla.firefox.desktop` |
| `"nautilus"` | `org.gnome.Nautilus.desktop` |
| `"terminal"` | `org.gnome.Terminal.desktop` |
| `"code"` | `code.desktop` |

## Trash Support

When you include `"<trash>"` in your docked array:

1. The module creates `~/.local/share/applications/trash.desktop`
1. Adds `trash.desktop` to GNOME favorites
1. Clicking it opens Nautilus with the trash view

```nix
docked = [
  "firefox"
  "<trash>"  # Trash icon appears in dock
];
```

## Testing

After modifying your configuration:

```bash
# Build without applying
just build username host

# Apply changes (on a NixOS/GNOME system)
just install username host
```

The GNOME dock will update immediately (or after logging out/in).

## Troubleshooting

### App Not Appearing

1. Check if the app has a `.desktop` file installed
1. Look in `/run/current-system/sw/share/applications/`
1. Try the exact .desktop filename without extension

### Trash Not Appearing

1. Verify `"<trash>"` is in your docked array
1. Check `~/.local/share/applications/trash.desktop` exists after activation
1. Ensure Nautilus is installed

### Separators/Folders Ignored

This is expected behavior. GNOME favorites only supports applications. Use separators and folders for Darwin compatibility, but they won't appear on GNOME.

## Verification Commands

```bash
# Check current GNOME favorites
gsettings get org.gnome.shell favorite-apps

# Check if trash.desktop exists
cat ~/.local/share/applications/trash.desktop

# List available .desktop files
ls /run/current-system/sw/share/applications/
```
