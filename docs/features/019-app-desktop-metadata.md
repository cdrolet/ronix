# Application Desktop Metadata

**Feature**: Enable declarative desktop integration for applications\
**Version**: 1.0.0\
**Status**: Implemented

## Overview

Desktop metadata allows you to declare desktop integration preferences directly in application configuration files:

- **File Associations**: Which file types should open with your application
- **Autostart**: Whether the application should launch at login
- **Platform Paths**: Where the application is installed on each platform

## When to Use

Add desktop metadata when you want:

- Files to open automatically with a specific application
- An application to start when you log in
- Desktop integration for GUI applications

Don't add desktop metadata for:

- CLI-only tools
- Applications that don't need desktop integration

## Quick Example

```nix
# platform/shared/app/editor/zed.nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.zed-editor ];
  
  programs.zed-editor = {
    enable = true;
    
    desktop = {
      paths = {
        darwin = "/Applications/Zed.app";
        nixos = "${pkgs.zed-editor}/bin/zed";
      };
      associations = [ ".json" ".xml" ".yaml" ".nix" ];
      autostart = false;
    };
  };
}
```

## Adding Desktop Metadata

### Step 1: Add Desktop Block

In your application's `.nix` file, add a `desktop` attribute:

```nix
programs.myapp = {
  enable = true;
  
  desktop = {
    # Configuration goes here
  };
};
```

### Step 2: Define Platform Paths

Specify where the application is installed on each platform:

```nix
desktop = {
  paths = {
    darwin = "/Applications/MyApp.app";
    nixos = "${pkgs.myapp}/bin/myapp";
  };
};
```

**Path conventions**:

- **macOS (darwin)**: `/Applications/App.app` for GUI apps
- **NixOS**: `${pkgs.app}/bin/app` for Nix store paths

### Step 3: Add File Associations (Optional)

Declare file types that should open with this application:

```nix
desktop = {
  paths = { /* ... */ };
  associations = [ ".txt" ".md" ".json" ];
};
```

Rules:

- Extensions must start with "." (period)
- Use lowercase for consistency
- Common file types only (no wildcards)

### Step 4: Enable Autostart (Optional)

Make the application start at login:

```nix
desktop = {
  paths = { /* ... */ };
  autostart = true;
};
```

Default is `false` if omitted.

## Common Patterns

### Text Editor with File Associations

```nix
desktop = {
  paths = {
    darwin = "/Applications/VSCode.app";
    nixos = "${pkgs.vscode}/bin/code";
  };
  associations = [ ".txt" ".md" ".json" ".yaml" ".nix" ];
  autostart = false;
};
```

### Password Manager (Autostart Only)

```nix
desktop = {
  paths = {
    darwin = "/Applications/Bitwarden.app";
    nixos = "${pkgs.bitwarden}/bin/bitwarden";
  };
  autostart = true;
};
```

### Media Player (Specific File Types)

```nix
desktop = {
  paths = {
    darwin = "/Applications/VLC.app";
    nixos = "${pkgs.vlc}/bin/vlc";
  };
  associations = [ ".mp4" ".mkv" ".avi" ".mp3" ".flac" ];
  autostart = false;
};
```

### Platform-Specific Application

```nix
desktop = {
  paths = {
    darwin = "/Applications/AeroSpace.app";
    # No nixos path - darwin-only app
  };
  autostart = true;
};
```

## Validation

The system automatically validates desktop metadata:

✅ **Valid**: Paths with associations\
✅ **Valid**: Paths with autostart\
✅ **Valid**: Complete integration (both)\
❌ **Invalid**: Associations without platform path\
❌ **Invalid**: Autostart without platform path\
❌ **Invalid**: Extensions without "." prefix

## Error Messages

When validation fails, you'll see clear error messages:

```
Application 'zed-editor' requires desktop.paths.darwin for file associations or autostart on this platform
```

**Fix**: Add the missing path for your platform

```
Application 'myapp' has invalid file extensions (must start with '.')
```

**Fix**: Add "." prefix (e.g., "json" → ".json")

## Platform-Specific Behavior

### macOS (Darwin)

- **File Associations**: Registered with Launch Services
- **Autostart**: Creates LaunchAgent in `~/Library/LaunchAgents/`
- **Path Format**: `/Applications/App.app`

### NixOS

- **File Associations**: Updates XDG mimeapps.list
- **Autostart**: Creates systemd user service
- **Path Format**: `${pkgs.app}/bin/app`

## Testing

### Test File Associations

1. Activate configuration: `just install <user> <profile>`
1. Double-click a file with the declared extension
1. Verify it opens with your application

### Test Autostart

1. Activate configuration: `just install <user> <profile>`
1. Log out and log back in
1. Verify application launches automatically

**macOS**: Check `launchctl list | grep myapp`\
**NixOS**: Check `systemctl --user status myapp.service`

## Troubleshooting

### File Associations Not Working

**macOS**: Rebuild Launch Services database

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user
```

**NixOS**: Check mimeapps.list

```bash
cat ~/.config/mimeapps.list
xdg-mime query default application/json
```

### Autostart Not Working

**macOS**: Check LaunchAgent status

```bash
launchctl list | grep myapp
cat ~/Library/LaunchAgents/org.nix.myapp.plist
```

**NixOS**: Check systemd service

```bash
systemctl --user status myapp.service
journalctl --user -u myapp.service
```

## Limitations

- **macOS Spotlight**: May not index symlinked apps from Nix store (prefer Homebrew casks for GUI apps)
- **File Association Conflicts**: System applies platform-specific precedence rules
- **Autostart Timing**: Applications start after login, not during boot
- **Path Changes**: Version updates may change paths (manual update required)

## Examples in Repository

See these applications for real-world examples:

- `platform/shared/app/editor/zed.nix` - Text editor with file associations
- `platform/darwin/app/aerospace.nix` - Window manager with autostart

## Related Documentation

- [Specification](../../specs/019-app-desktop-metadata/spec.md) - Full feature specification
- [Quickstart Guide](../../specs/019-app-desktop-metadata/quickstart.md) - Detailed implementation guide
- [CLAUDE.md](../../CLAUDE.md) - Development guidelines
