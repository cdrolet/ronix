# Quickstart: User Dock Configuration

**Feature**: 023-user-dock-config

## Overview

Define your dock layout in your user configuration using a simple, platform-agnostic syntax. The system automatically resolves app names to platform-specific paths.

## Basic Usage

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
      "mail"
      "|"
      "zed"
      "ghostty"
      "/Downloads"
    ];
  };
}
```

## Syntax Reference

| Type | Syntax | Example | Description |
|------|--------|---------|-------------|
| Application | plain name | `"firefox"` | Resolved to platform path |
| Folder | `/name` | `"/Downloads"` | User folder (or absolute path) |
| Separator | `\|` | `"\|"` | Standard spacer |
| Thick separator | `\|\|` | `"\|\|"` | Thick spacer (darwin only) |
| System item | `<name>` | `"<trash>"` | Platform-specific system element |

## Example Configurations

### Minimal Dock

```nix
docked = [ "firefox" "terminal" ];
```

### Developer Setup

```nix
docked = [
  # Browsers
  "zen"
  "brave"
  
  # Separator
  "|"
  
  # Development
  "zed"
  "ghostty"
  "obsidian"
  
  # Thick separator (darwin)
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

## Platform Behavior

### Darwin (macOS)

- Applications resolved from `/Applications`, `/System/Applications`
- Folders added to dock's right section
- `<trash>` is a no-op (macOS manages trash automatically)
- `||` creates a thick spacer

### GNOME (Linux)

- Applications resolved to `.desktop` files
- Folders are not supported in GNOME favorites (skipped)
- `<trash>` creates a trash.desktop file
- Separators are not supported (skipped)

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Missing app | Silently skipped |
| Missing folder | Silently skipped |
| Empty array `[]` | Clears dock |
| Field not specified | No dock changes |
| Consecutive separators | Collapsed to single |
| Leading/trailing separator | Removed |

## Testing

After modifying your configuration:

```bash
# Build without applying
just build cdrokar home-macmini-m4

# Apply changes
just install cdrokar home-macmini-m4
```

The dock will update immediately after activation.

## Troubleshooting

### App Not Appearing

1. Check app name matches the `.app` bundle name (without `.app`)
1. Verify app is installed in `/Applications` or `/System/Applications`
1. Check for typos (matching is case-insensitive)

### Folder Not Appearing

1. Verify folder exists at `$HOME/<name>` or as absolute path
1. Check folder name spelling

### Order Seems Wrong

1. Ensure no duplicate entries (only first occurrence kept)
1. Check for leading/trailing separators (removed automatically)
