# Quickstart: Application Desktop Metadata

**Feature**: 019-app-desktop-metadata\
**Audience**: Configuration authors adding desktop integration to applications\
**Time**: 5-10 minutes to add metadata to an application

## What This Feature Provides

Desktop metadata enables you to declare:

- **File associations**: Which file types should open with your application
- **Autostart**: Whether the application should launch at login
- **Platform paths**: Where the application is installed on each platform

## When to Use Desktop Metadata

Add desktop metadata to an application when:

- ✅ You want files to open automatically with a specific application
- ✅ You need an application to start when you log in
- ✅ The application has a desktop/GUI component

Don't add desktop metadata when:

- ❌ The application is CLI-only
- ❌ You don't need file associations or autostart
- ❌ The application doesn't have a graphical interface

## Quick Example

Here's a complete example adding desktop metadata to the Zed editor:

```nix
# platform/shared/app/editor/zed.nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.zed-editor ];
  
  programs.zed-editor = {
    enable = true;
    
    # Desktop metadata (optional)
    desktop = {
      # Where the app is installed on each platform
      paths = {
        darwin = "/Applications/Zed.app";
        nixos = "${pkgs.zed-editor}/bin/zed";
      };
      
      # File types to open with this app
      associations = [ ".json" ".xml" ".yaml" ".nix" ];
      
      # Don't start automatically at login
      autostart = false;
    };
  };
}
```

## Step-by-Step Guide

### Step 1: Locate Your Application Config

Find the application's `.nix` file in the repository:

- Shared apps: `platform/shared/app/{category}/{app}.nix`
- Platform-specific: `platform/{platform}/app/{category}/{app}.nix`

### Step 2: Add Desktop Metadata Block

Add a `desktop` attribute to your application configuration:

```nix
{ config, pkgs, lib, ... }:

{
  # Existing configuration...
  programs.myapp = {
    enable = true;
    
    # Add this block
    desktop = {
      # Configuration goes here
    };
  };
}
```

### Step 3: Define Platform Paths

Add the installation paths for each platform you support:

```nix
desktop = {
  paths = {
    darwin = "/Applications/MyApp.app";  # macOS
    nixos = "${pkgs.myapp}/bin/myapp";   # NixOS
  };
};
```

**Path conventions**:

- **macOS (darwin)**: Use `/Applications/App.app` for GUI apps
- **NixOS**: Use `${pkgs.app}/bin/app` for Nix store paths

### Step 4: Add File Associations (Optional)

If you want files to open with this application, add extensions:

```nix
desktop = {
  paths = { /* ... */ };
  
  associations = [
    ".txt"    # Text files
    ".md"     # Markdown
    ".json"   # JSON
  ];
};
```

**Rules**:

- Extensions MUST start with "." (period)
- Use lowercase for consistency
- Only common file types (no wildcards)

### Step 5: Enable Autostart (Optional)

If the application should start at login:

```nix
desktop = {
  paths = { /* ... */ };
  autostart = true;  # Starts at login
};
```

**Default**: `false` if omitted

### Step 6: Validate Configuration

Build your configuration to validate:

```bash
just build <user> <profile>
```

Or check syntax:

```bash
nix flake check
```

## Common Patterns

### Pattern 1: Text Editor with File Associations

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

### Pattern 2: Password Manager (Autostart Only)

```nix
desktop = {
  paths = {
    darwin = "/Applications/Bitwarden.app";
    nixos = "${pkgs.bitwarden}/bin/bitwarden";
  };
  autostart = true;  # No file associations needed
};
```

### Pattern 3: Media Player (Specific File Types)

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

### Pattern 4: Platform-Specific Application

```nix
desktop = {
  paths = {
    darwin = "/Applications/AeroSpace.app";
    # No nixos path - darwin-only app
  };
  autostart = true;
};
```

### Pattern 5: No Desktop Integration (CLI Tool)

```nix
# No desktop metadata needed for CLI tools
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.ripgrep ];
  
  programs.ripgrep = {
    enable = true;
    # No desktop block - this is a CLI tool
  };
}
```

## Validation Rules

The system automatically validates desktop metadata:

### ✅ Valid Configurations

```nix
# Paths only (no features)
desktop = {
  paths = { darwin = "/Applications/App.app"; };
};

# Paths with associations
desktop = {
  paths = { darwin = "/Applications/App.app"; };
  associations = [ ".txt" ];
};

# Paths with autostart
desktop = {
  paths = { darwin = "/Applications/App.app"; };
  autostart = true;
};

# Complete integration
desktop = {
  paths = { darwin = "/Applications/App.app"; };
  associations = [ ".txt" ];
  autostart = true;
};
```

### ❌ Invalid Configurations

```nix
# ERROR: Associations without path for active platform
desktop = {
  paths = { nixos = "/bin/app"; };  # Missing darwin path
  associations = [ ".txt" ];
};
# Error on darwin: "requires desktop.paths.darwin"

# ERROR: Autostart without path
desktop = {
  autostart = true;
  # Missing paths entirely
};
# Error: "has autostart but no desktop.paths defined"

# ERROR: Invalid extension format
desktop = {
  paths = { darwin = "/Applications/App.app"; };
  associations = [ "txt" ];  # Missing "." prefix
};
# Error: "invalid file extensions (must start with '.')"

# ERROR: Empty path
desktop = {
  paths = { darwin = ""; };  # Empty string
  autostart = true;
};
# Error: "desktop.paths.darwin cannot be empty"
```

## Error Messages

When validation fails, you'll see clear error messages:

```
Application 'zed-editor' requires desktop.paths.darwin for file associations or autostart on this platform
```

**Fix**: Add the missing path for your platform

```
Application 'myapp' has invalid file extensions (must start with '.')
```

**Fix**: Add "." prefix to extensions (e.g., "json" → ".json")

## Platform Processing

Each platform processes desktop metadata differently:

### macOS (Darwin)

- **File Associations**: Registered with Launch Services using duti
- **Autostart**: Creates LaunchAgent plist in `~/Library/LaunchAgents/`
- **Path Format**: `/Applications/App.app` or Nix store paths

### NixOS

- **File Associations**: Updates XDG mimeapps.list via Home Manager
- **Autostart**: Creates systemd user service or XDG autostart entry
- **Path Format**: `${pkgs.app}/bin/app` or desktop file references

## Testing

### Test File Associations

1. Build and activate configuration:

   ```bash
   just install <user> <profile>
   ```

1. Test opening a file:

   - macOS: Double-click file in Finder
   - NixOS: Double-click file in file manager

1. Verify correct application opens

### Test Autostart

1. Build and activate configuration:

   ```bash
   just install <user> <profile>
   ```

1. Log out and log back in

1. Verify application starts automatically

1. Check autostart status:

   - macOS: Check `~/Library/LaunchAgents/` for plist files
   - NixOS: Check `systemctl --user list-units` for services

## Troubleshooting

### File Associations Not Working

**macOS**:

- Run `duti -x .ext` to see current handler
- Rebuild Launch Services database: `/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user`

**NixOS**:

- Check `~/.config/mimeapps.list`
- Verify MIME type exists: `xdg-mime query filetype file.ext`
- Check default: `xdg-mime query default application/json`

### Autostart Not Working

**macOS**:

- Check LaunchAgent loaded: `launchctl list | grep myapp`
- View plist: `cat ~/Library/LaunchAgents/org.nix.myapp.plist`
- Check logs: `log show --predicate 'process == "myapp"' --last 1h`

**NixOS**:

- Check service status: `systemctl --user status myapp.service`
- View logs: `journalctl --user -u myapp.service`
- Verify enabled: `systemctl --user is-enabled myapp.service`

### Path Not Found

**Error**: Application path doesn't exist after activation

**Solution**:

- Verify package is installed: `home.packages = [ pkgs.myapp ];`
- Check Nix store path: `which myapp` or `ls -l /Applications/`
- For macOS apps, ensure Homebrew cask is installed if needed

## Next Steps

After adding desktop metadata:

1. **Test thoroughly**: Verify file associations and autostart work as expected
1. **Document**: Add notes in the app config explaining why specific associations were chosen
1. **Share**: If useful, suggest similar metadata for related applications
1. **Iterate**: Refine file associations based on actual usage

## Reference

- **Spec**: [spec.md](spec.md) - Full feature specification
- **Data Model**: [data-model.md](data-model.md) - Detailed schema documentation
- **Schema**: [contracts/desktop-metadata-schema.nix](contracts/desktop-metadata-schema.nix) - Type definitions and validation
- **Research**: [research.md](research.md) - Platform mechanisms and best practices

## Examples from Repository

Look at these applications for real-world examples:

- `platform/shared/app/editor/zed.nix` - Text editor with file associations
- `platform/darwin/app/aerospace.nix` - Window manager with autostart
- `platform/shared/app/shell/zsh.nix` - CLI tool (no desktop metadata)
