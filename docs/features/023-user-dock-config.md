# User Dock Configuration

Define your dock layout directly in your user configuration using a simple, platform-agnostic syntax.

## Quick Start

Add the `docked` field to your user configuration:

```nix
# user/cdrokar/default.nix
{...}: {
  user = {
    name = "cdrokar";
    applications = ["*"];
    
    docked = [
      "zen"
      "brave"
      "|"
      "zed"
      "ghostty"
      "/Downloads"
    ];
  };
}
```

Run `just install <user> <host>` to apply.

## Syntax Reference

| Type | Syntax | Example | Description |
|------|--------|---------|-------------|
| Application | plain name | `"firefox"` | Resolved to platform path |
| Folder | `/name` | `"/Downloads"` | User folder or absolute path |
| Separator | `\|` | `"\|"` | Standard spacer |
| Thick separator | `\|\|` | `"\|\|"` | Thick spacer (darwin only) |
| System item | `<name>` | `"<trash>"` | Platform-specific system element |

## Application Names

Use simple application names without paths or extensions:

```nix
docked = [
  "zen"           # -> /Applications/Zen.app
  "brave"         # -> /Applications/Brave Browser.app
  "mail"          # -> /System/Applications/Mail.app
  "activity monitor"  # -> /System/Applications/Utilities/Activity Monitor.app
];
```

The system searches these locations (darwin):

1. `/Applications/`
1. `/System/Applications/`
1. `/System/Applications/Utilities/`
1. `~/Applications/`

## Folders

Prefix folder names with `/`:

```nix
docked = [
  "/Downloads"    # -> /Users/<username>/Downloads
  "/Documents"    # -> /Users/<username>/Documents
  "/Volumes/Backup"  # -> /Volumes/Backup (absolute path)
];
```

Resolution order:

1. Try `$HOME/<name>` first
1. Fall back to `/<name>` as absolute path
1. Skip if neither exists

## Separators

Group dock items visually:

```nix
docked = [
  # Browsers
  "zen"
  "brave"
  
  "|"  # Standard separator
  
  # Development
  "zed"
  "ghostty"
  
  "||"  # Thick separator (darwin only)
  
  # Folders
  "/Downloads"
];
```

## System Items

Special platform-specific items use angle brackets:

```nix
docked = [
  "firefox"
  "|"
  "<trash>"  # System trash/recycle bin
];
```

Platform behavior:

- **Darwin**: `<trash>` is a no-op (macOS manages trash automatically)
- **GNOME**: Creates a trash.desktop file and adds to favorites

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Missing app | Silently skipped |
| Missing folder | Silently skipped |
| Empty array `[]` | Clears dock |
| Not specified | Dock unchanged |
| Consecutive separators | Collapsed to single |
| Leading/trailing separator | Removed |

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Darwin (macOS) | Supported | Uses dockutil |
| GNOME | Supported | Uses dconf/gsettings |
| KDE | Future | Lower priority |
| Other | Ignored | Field has no effect |

### Platform Differences

| Feature | Darwin | GNOME |
|---------|--------|-------|
| Applications | Full support | Full support |
| Folders | Full support | Not supported (ignored) |
| Separators | Full support | Not supported (ignored) |
| `<trash>` | No-op | Creates trash.desktop |

GNOME favorites only supports application launchers. Folders and separators in your config are silently ignored on GNOME, allowing the same configuration to work on both platforms.

## Examples

### Minimal

```nix
docked = ["firefox" "terminal"];
```

### Developer Setup

```nix
docked = [
  # Browsers
  "zen"
  "brave"
  "firefox"
  
  "|"
  
  # Development
  "zed"
  "ghostty"
  "obsidian"
  
  "|"
  
  # Utilities
  "system settings"
  "activity monitor"
  
  "||"
  
  # Folders
  "/Downloads"
  "/Documents"
];
```

### With System Items

```nix
docked = [
  "firefox"
  "mail"
  "|"
  "/Downloads"
  "<trash>"
];
```

## Troubleshooting

### App Not Appearing

1. Check the app name matches the `.app` bundle name (without `.app`)
1. Verify the app is installed in a searched location
1. Check for typos (matching is case-insensitive)

### Folder Not Appearing

1. Verify the folder exists at `$HOME/<name>` or as absolute path
1. Check folder name spelling

### Order Seems Wrong

1. Check for duplicate entries (only first occurrence kept)
1. Verify no leading/trailing separators (removed automatically)
