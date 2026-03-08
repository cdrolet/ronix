# Research: Desktop Integration for macOS and NixOS

**Date**: 2025-11-16\
**Purpose**: Document file associations, autostart mechanisms, and desktop path conventions for declarative configuration in Nix

______________________________________________________________________

## Executive Summary

This research documents the mechanisms and best practices for desktop integration across macOS (Darwin) and Linux (NixOS), focusing on declarative configuration through Nix, nix-darwin, and Home Manager.

**Key Findings**:

- ✅ **File Associations**: Both platforms supported with existing tools (duti/xdg-mime)
- ✅ **Autostart**: Well-supported through launchd (macOS) and systemd (Linux)
- ⚠️ **Path Conventions**: Platform-specific quirks and limitations exist
- ✅ **Home Manager Integration**: Mature modules available for both platforms
- ⚠️ **Edge Cases**: Several known limitations require workarounds

**Existing Implementation**:

- Repository already has `/platform/shared/lib/file-associations.nix` - a working cross-platform file association module
- Uses home-manager activation scripts with DAG ordering
- Supports both platform-agnostic and platform-specific app IDs

______________________________________________________________________

## 1. File Association Mechanisms

### 1.1 macOS (Darwin) File Associations

#### Technical Approach

**Launch Services Database**:

- Central system for managing file type associations
- Uses Uniform Type Identifiers (UTIs) for hierarchical file type classification
- Database maintained by Launch Services framework
- Location: Managed internally by macOS (not directly editable)

**UTI System**:

- UTIs form a hierarchical tree (e.g., `public.jpeg` → `public.image` → `public.data`)
- More flexible than file extensions alone
- Supports MIME types, file extensions, and OSTypes
- Example: `public.plain-text`, `com.adobe.pdf`, `public.jpeg`

**Command-Line Tools**:

1. **duti** (Recommended for automation):

   ```bash
   # Set default application for extension
   duti -s com.example.app .md all

   # Set default application for UTI
   duti -s com.example.app public.plain-text all

   # Set default for URL scheme
   duti -s com.google.Chrome http all
   ```

   **Status**: No longer actively developed (last major update 2012), but still widely used and functional

   **Pros**:

   - Simple, declarative syntax
   - Available in nixpkgs
   - Community standard for Nix configurations

   **Cons**:

   - Unmaintained (though stable)
   - Limited to basic use cases

1. **lsregister** (System tool):

   ```bash
   # Rebuild Launch Services database
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

   # Query handlers for file
   lsregister -dump | grep -i "bundle id"
   ```

   **Purpose**: Database maintenance and querying (not typically used for setting associations)

**File Association Persistence**:

- Settings stored in `~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist`
- Binary plist format (use `plutil` or `defaults` to read)
- Launch Services caches must be rebuilt after manual changes

#### Nix/Home Manager Integration

**Existing Implementation** (`/platform/shared/lib/file-associations.nix`):

```nix
# Usage in app modules
imports = [ ../../lib/file-associations.nix ];

fileAssociations.registrations = [
  {
    appId = "com.example.myapp";  # macOS bundle ID
    extensions = [ ".md" ".txt" ];
  }
];
```

**How it works**:

1. Declares file associations in app module
1. Automatically installs `duti` package
1. Creates home-manager activation script (runs after `writeBoundary`)
1. Executes `duti -s <bundleId> <extension> all` for each association
1. Errors suppressed with `|| true` (non-fatal if app not yet installed)

**DAG Ordering**:

```nix
home.activation.fileAssociations = lib.hm.dag.entryAfter ["writeBoundary"] ''
  ${pkgs.duti}/bin/duti -s ${appId} ${ext} all 2>/dev/null || true
'';
```

- `entryAfter ["writeBoundary"]`: Runs in "write" phase (modifies system state)
- `writeBoundary`: Separates verification phase from modification phase
- Activation scripts that modify state MUST be after `writeBoundary`

#### Limitations and Edge Cases

1. **Bundle ID Requirements**:

   - App must be installed and have valid `Info.plist`
   - Bundle ID must match exactly (case-sensitive)
   - Cannot set associations for apps not yet installed (must re-run after installation)

1. **System Integrity Protection (SIP)**:

   - Cannot override system apps in some cases
   - Certain file types protected by macOS (e.g., `.app` files)

1. **Spotlight Indexing**:

   - Spotlight does NOT index symlinks (only macOS aliases)
   - Nix store apps (`/nix/store/...`) not searchable in Spotlight
   - `/nix` directory has `nobrowse` flag set (prevents indexing)

   **Workaround**: Use homebrew casks for GUI apps that need Spotlight integration

1. **Application Path Issues**:

   - Nix-built `.app` bundles live in `/nix/store`
   - macOS expects apps in `/Applications` or `~/Applications`
   - Symlinks work for launching but not for Spotlight
   - File associations work even with nix store paths

1. **Reset by System Updates**:

   - Major macOS updates may reset Launch Services database
   - Solution: Re-run activation after updates (darwin-rebuild)

### 1.2 Linux (NixOS) File Associations

#### Technical Approach

**XDG MIME Applications Specification**:

- Standard defined by freedesktop.org
- Uses `mimeapps.list` file for associations
- Desktop entries (`.desktop` files) declare app capabilities
- MIME types follow standard format (e.g., `text/plain`, `image/jpeg`)

**File Locations**:

```
# User-specific (highest priority)
~/.config/mimeapps.list
~/.local/share/applications/mimeapps.list  # Deprecated but supported

# System-wide
/etc/xdg/mimeapps.list
/usr/share/applications/mimeapps.list
```

**mimeapps.list Format**:

```ini
[Default Applications]
text/html=firefox.desktop
image/png=gimp.desktop

[Added Associations]
text/plain=gedit.desktop;vim.desktop

[Removed Associations]
text/plain=nano.desktop
```

**Command-Line Tools**:

1. **xdg-mime** (Primary tool):

   ```bash
   # Set default application
   xdg-mime default firefox.desktop text/html

   # Query default application
   xdg-mime query default text/html

   # Query filetype
   xdg-mime query filetype document.pdf
   ```

1. **xdg-open** (Opens files with default app):

   ```bash
   xdg-open document.pdf
   ```

**Desktop Entry Files**:
Located in:

- `/usr/share/applications/` (system)
- `~/.local/share/applications/` (user)

Example `.desktop` file:

```desktop
[Desktop Entry]
Type=Application
Name=Firefox
Exec=firefox %u
MimeType=text/html;text/xml;application/xhtml+xml;
```

#### Nix/Home Manager Integration

**home-manager XDG Module**:

```nix
{
  xdg.mimeApps = {
    enable = true;
    
    # Set default applications
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "application/pdf" = "evince.desktop";
      "image/png" = "gimp.desktop";
    };
    
    # Additional associations
    associations.added = {
      "text/plain" = [ "gedit.desktop" "vim.desktop" ];
    };
    
    # Remove associations
    associations.removed = {
      "text/plain" = [ "nano.desktop" ];
    };
  };
}
```

**home-manager Desktop Entries**:

```nix
{
  xdg.desktopEntries = {
    firefox = {
      name = "Firefox";
      genericName = "Web Browser";
      exec = "firefox %U";
      terminal = false;
      categories = [ "Application" "Network" "WebBrowser" ];
      mimeType = [ "text/html" "text/xml" ];
    };
  };
}
```

**Existing Implementation** (`/platform/shared/lib/file-associations.nix`):

```nix
# Linux implementation (from existing code)
if pkgs.stdenv.isLinux then
  # Automatically installs xdg-utils
  home.packages = [ pkgs.xdg-utils ];
  
  # Activation script
  ${pkgs.xdg-utils}/bin/xdg-mime default ${appId}.desktop ${mimeType} 2>/dev/null || true
```

#### Limitations and Edge Cases

1. **Desktop Environment Conflicts**:

   - KDE/Plasma may override `mimeapps.list` with own database
   - GNOME has its own settings (though it respects XDG standard)
   - Some DEs write to file managed by home-manager (causes warnings)

   **Solution**: Set `xdg.mimeApps.enable = true` makes file read-only (prevents DE overwrites)

1. **Flatpak/Snap Conflicts**:

   - Flatpak inserts `/var/lib/flatpak/` into `XDG_DATA_DIRS` with higher priority
   - Snap apps use portals that may ignore system MIME associations
   - Desktop entries in flatpak locations searched first

   **Impact**: System-wide associations may be overridden by flatpak defaults

   **Solution**: Set associations in user's `~/.config/mimeapps.list` (highest priority)

1. **MIME Type Detection**:

   - MIME type must be correctly registered in shared-mime-info database
   - Custom file extensions need MIME type registration
   - Existing implementation auto-infers MIME types: `application/x-${ext}`

1. **Portal Compatibility**:

   - xdg-desktop-portal may use different MIME resolution
   - Sandboxed apps (flatpak) go through portal layer
   - Portal config: `/usr/share/xdg-desktop-portal/portals/`

1. **Home Manager File Ownership**:

   - `mimeapps.list` generated as read-only symlink to nix store
   - Desktop environments that write to file will fail (intentional)
   - Prevents drift from declarative config

### 1.3 Cross-Platform Best Practices

**Recommendation from Existing Implementation**:

Use the shared file-associations module pattern:

```nix
{
  fileAssociations.registrations = [
    {
      # Platform-specific app IDs
      appIds = {
        darwin = "com.example.MyApp";  # Bundle ID
        linux = "myapp";                # Desktop file name (without .desktop)
      };
      extensions = [ ".json" ".xml" ".yaml" ];
      
      # Optional: Linux MIME types (auto-inferred if not provided)
      mimeTypes = {
        ".json" = "application/json";
        ".xml" = "application/xml";
        ".yaml" = "application/yaml";
      };
    }
  ];
}
```

**Key Principles**:

1. Keep associations declarative (no imperative scripts)
1. Use activation scripts for actual registration (not just config files)
1. Make associations non-fatal (`|| true`) - apps may not be installed yet
1. Support both simple `appId` (same across platforms) and platform-specific `appIds`
1. Place activation scripts after `writeBoundary` (they modify system state)

______________________________________________________________________

## 2. Autostart Mechanisms

### 2.1 macOS (Darwin) Autostart

#### Technical Approach

**launchd System**:

- macOS native service management
- Replaces cron, init, and startup items
- Handles both system (daemons) and user (agents) services
- On-demand and scheduled execution support

**LaunchAgent Types**:

1. **System-wide LaunchAgents**: `/Library/LaunchAgents/` (run for all users)
1. **User LaunchAgents**: `~/Library/LaunchAgents/` (per-user)
1. **System LaunchDaemons**: `/Library/LaunchDaemons/` (system services, root)

**LaunchAgent plist Structure**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.example.myapp</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/MyApp.app/Contents/MacOS/MyApp</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

**Key plist Properties**:

| Property | Type | Description | Use Case |
|----------|------|-------------|----------|
| `Label` | String | Unique identifier (reverse DNS) | Required for all agents |
| `ProgramArguments` | Array | Command and arguments | Executable path + args |
| `RunAtLoad` | Boolean | Run when loaded (login) | Start at login |
| `KeepAlive` | Boolean/Dict | Restart if exits | Background services |
| `StartInterval` | Integer | Run every N seconds | Periodic tasks |
| `StartCalendarInterval` | Dict | Cron-like scheduling | Scheduled tasks |
| `ProcessType` | String | Resource allocation | Background/Interactive/Adaptive |
| `StandardOutPath` | String | stdout log location | Debugging |
| `StandardErrorPath` | String | stderr log location | Debugging |
| `EnvironmentVariables` | Dict | Environment vars | Config variables |

**KeepAlive Detailed Behavior**:

- **Boolean `true`**: Always restart if process exits
- **Boolean `false`**: Launch-on-demand only (default)
- **Dictionary**: Conditional restart based on:
  - `SuccessfulExit` (bool): Restart based on exit status
  - `NetworkState` (bool): Keep alive when network available
  - `PathState` (dict): Keep alive based on file existence

**RunAtLoad vs KeepAlive**:

- `RunAtLoad`: One-time launch when agent loads (at login)
- `KeepAlive`: Continuous running (restart if crashes)
- Both can be true: Launch at login AND restart if crashes
- Neither true: Launch on-demand only (via socket/message)

**ProcessType Values**:

- `Standard`: Default, no special treatment
- `Background`: Resource-limited (prevents disrupting user)
- `Interactive`: Same limits as GUI apps (none)
- `Adaptive`: Switches between Background/Interactive based on XPC activity

**launchctl Commands**:

```bash
# Load agent (start)
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.example.myapp.plist

# Unload agent (stop)
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.example.myapp.plist

# List loaded agents
launchctl list

# Check agent status
launchctl print gui/$UID/com.example.myapp
```

**Important 2025 Update**:

- Old commands (`launchctl load/unload`) deprecated
- Use `bootstrap`/`bootout` instead
- Domain specification required: `gui/$UID` for user agents

#### Nix/Home Manager Integration

**home-manager launchd Module**:

```nix
{
  launchd.agents.myapp = {
    enable = true;
    config = {
      ProgramArguments = [ "/Applications/MyApp.app/Contents/MacOS/MyApp" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/myapp.log";
      StandardErrorPath = "/tmp/myapp.err";
      EnvironmentVariables = {
        PATH = "/usr/local/bin:/usr/bin:/bin";
      };
    };
  };
}
```

**Automatic Label Generation**:

- home-manager auto-generates label: `org.nix-community.home.<agentName>`
- Example: `org.nix-community.home.myapp`
- Can be overridden in config with `Label` key

**Activation Process**:

1. home-manager generates plist file
1. Writes to `~/Library/LaunchAgents/org.nix-community.home.<name>.plist`
1. Sets file permissions to 444 (read-only)
1. Stops existing agent via `launchctl bootout`
1. Bootstraps new agent via `launchctl bootstrap`
1. Removes agents no longer defined

**Existing Repository Usage**:

```nix
# From /platform/darwin/app/aerospace.nix
launchd.agents.aerospace = {
  enable = true;
  config = {
    ProgramArguments = [ "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ];
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/tmp/aerospace.log";
    StandardErrorPath = "/tmp/aerospace.err";
  };
};
```

**nix-darwin vs home-manager**:

- **home-manager**: User-level agents (`~/Library/LaunchAgents/`)
- **nix-darwin**: Can create system-level agents/daemons
- Both support same plist schema
- home-manager runs as user, nix-darwin runs as root

**nix-darwin System Activation** (Post-2025):

- All activation now runs as **root**
- `system.activationScripts.{preUserActivation,extraUserActivation,postUserActivation}` removed
- Only `system.activationScripts.{preActivation,extraActivation,postActivation}` remain
- To run as user: Use `sudo -u $USERNAME command` in activation scripts
- `darwin-rebuild` must be run as root

#### Limitations and Edge Cases

1. **SSH Session Limitations**:

   - LaunchAgents can't be bootstrapped over SSH
   - Error: "Bootstrap failed: 125: Domain does not support specified action"
   - **Solution**: Use Screen Sharing or ARD for remote configuration
   - Background agents may load independently of GUI login (depending on config)

1. **File Ownership Requirements**:

   - Plist files MUST be owned by user running the agent
   - Cannot be symlinks from nix store (would be owned by root/nixbld)
   - **home-manager solution**: Copies files instead of symlinking (mode 444)

1. **Path Environment**:

   - LaunchAgents don't inherit shell PATH
   - Must explicitly set `EnvironmentVariables.PATH`
   - Nix store paths safe to use: `/nix/store/...` (stable until GC)

1. **Application Lifetime**:

   - Apps must not fork/daemonize if using KeepAlive
   - launchd loses track of forked processes
   - Use `KeepAlive = false` for apps that daemonize themselves

1. **Debugging Challenges**:

   - No console output by default
   - Must set `StandardOutPath` and `StandardErrorPath`
   - Check Console.app for system-wide launchd errors
   - Use `launchctl print` to inspect loaded config

1. **Activation Timing**:

   - home-manager activation may run before apps installed
   - LaunchAgent references `/Applications/...` (might not exist yet)
   - **Solution**: Agents fail gracefully, load on next login

1. **Homebrew App Paths**:

   - Cask apps install to `/Applications/` by default
   - Can customize with `homebrew.caskArgs.appdir`
   - Formula services use homebrew-specific paths

### 2.2 Linux (NixOS) Autostart

#### Technical Approach

**Three Autostart Methods**:

1. **systemd User Services** (Recommended):

   - Modern, robust service management
   - Proper dependency ordering
   - Resource limits and sandboxing
   - Log management via journald

1. **XDG Autostart**:

   - Desktop entry files in `~/.config/autostart/`
   - Desktop environment compatibility
   - Simple, no special permissions
   - Converted to systemd units by systemd-xdg-autostart-generator

1. **systemd + XDG Integration**:

   - systemd automatically converts XDG autostart entries
   - Targets: `xdg-desktop-autostart.target`
   - Can opt-out per-entry: `X-systemd-skip=true`

**systemd User Service Unit**:

```ini
[Unit]
Description=My Application
Documentation=man:myapp(1)
After=graphical-session.target

[Service]
ExecStart=/usr/bin/myapp
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

**systemd Unit Sections**:

- `[Unit]`: Metadata and dependencies
- `[Service]`: Execution configuration
- `[Install]`: Installation/activation requirements

**Common Service Properties**:

| Property | Description | Example |
|----------|-------------|---------|
| `ExecStart` | Command to execute | `/usr/bin/myapp --daemon` |
| `ExecStop` | Stop command (optional) | `/usr/bin/myapp --stop` |
| `Restart` | Restart policy | `always`, `on-failure`, `no` |
| `RestartSec` | Delay between restarts | `3` (seconds) |
| `Type` | Service type | `simple`, `forking`, `oneshot` |
| `Environment` | Environment variables | `"VAR=value"` |
| `WorkingDirectory` | Working directory | `/home/user/app` |
| `MemoryMax` | Memory limit | `2G` |

**systemd Commands**:

```bash
# Enable service (start at login)
systemctl --user enable myapp.service

# Start service now
systemctl --user start myapp.service

# Check status
systemctl --user status myapp.service

# View logs
journalctl --user -u myapp.service

# Reload systemd config
systemctl --user daemon-reload
```

**XDG Autostart Desktop Entry**:

```desktop
[Desktop Entry]
Type=Application
Name=My Application
Exec=/usr/bin/myapp
X-GNOME-Autostart-enabled=true
Hidden=false
```

Locations:

- User: `~/.config/autostart/`
- System: `/etc/xdg/autostart/`

**systemd-xdg-autostart-generator**:

- Automatically creates `.service` units from `.desktop` files
- Generated units start with `xdg-desktop-autostart.target`
- All generated units have `After=graphical-session.target`
- Desktop entry opt-out: Add `X-systemd-skip=true`

#### Nix/Home Manager Integration

**home-manager systemd.user.services**:

```nix
{
  systemd.user.services.myapp = {
    Unit = {
      Description = "My Application";
      After = [ "graphical-session.target" ];
    };
    
    Service = {
      ExecStart = "${pkgs.myapp}/bin/myapp";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = {
        PATH = "${pkgs.myapp}/bin";
      };
    };
    
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
```

**Real-World Examples**:

1. **Background Daemon**:

```nix
systemd.user.services.gopls = {
  Unit = {
    Description = "Run gopls as a daemon";
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
  Service = {
    ExecStart = "${pkgs.gopls}/bin/gopls -listen=unix;%t/gopls";
    ExecStopPost = "${pkgs.coreutils}/bin/rm -f %t/gopls";
    Restart = "always";
    RestartSec = 3;
    MemoryHigh = "1.5G";
    MemoryMax = "2G";
  };
};
```

2. **Script with Dependencies**:

```nix
systemd.user.services.backup = {
  Unit = {
    Description = "Backup service";
    After = [ "network-online.target" ];
  };
  Service = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "backup" ''
      #!/bin/bash
      ${pkgs.rsync}/bin/rsync -av /home /backup
    '';
  };
  Install = {
    WantedBy = [ "default.target" ];
  };
};
```

**home-manager XDG Autostart**:

```nix
{
  xdg.configFile."autostart/myapp.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=My Application
    Exec=${pkgs.myapp}/bin/myapp
    X-GNOME-Autostart-enabled=true
  '';
}
```

**Activation Process**:

1. home-manager generates systemd unit files
1. Writes to `~/.config/systemd/user/`
1. Runs `systemctl --user daemon-reload`
1. Enables services with `WantedBy` targets
1. Starts services (if not already running)

#### Limitations and Edge Cases

1. **XDG Autostart + systemd Conflicts**:

   - Don't create both systemd unit AND XDG autostart entry for same app
   - systemd-xdg-autostart-generator will create duplicate service
   - **Solution**: Use systemd units OR XDG autostart, not both
   - Add `X-systemd-skip=true` to desktop entry if needed

1. **Graphical Session Dependency**:

   - Services requiring GUI should use `After=graphical-session.target`
   - XDG-generated units automatically get this
   - Manual units need explicit declaration
   - `default.target` may start before GUI available

1. **Desktop Environment Integration**:

   - Some DEs (KDE, GNOME) have own autostart managers
   - May conflict with systemd user services
   - GNOME Tweaks, KDE System Settings override XDG autostart
   - **Solution**: Prefer systemd units for consistency

1. **Path Environment**:

   - systemd user services have minimal PATH
   - Must use absolute paths or set `Environment.PATH`
   - Nix store paths recommended: `${pkgs.app}/bin/app`

1. **Service Type Confusion**:

   - `Type=simple`: Default, process doesn't fork
   - `Type=forking`: Process forks (must set `PIDFile`)
   - `Type=oneshot`: Runs once, exits
   - Wrong type causes "Failed with result 'exit-code'"

1. **Resource Limits**:

   - User services subject to user slice limits
   - Check limits: `systemctl --user show user.slice`
   - Adjust with `MemoryMax`, `CPUQuota`, etc.

1. **Wayland Compositor Integration**:

   - Hyprland, Sway may need specific systemd integration
   - Some compositors conflict with systemd session management
   - Example: Hyprland has `systemd.enable` option (may need `false`)

### 2.3 Cross-Platform Best Practices

**Recommendation for this Repository**:

Create platform-specific autostart modules:

**macOS** (`platform/darwin/lib/autostart.nix`):

```nix
{ lib, ... }:

{
  # Helper to create standard LaunchAgent
  mkLaunchAgent = { name, program, args ? [], keepAlive ? true, runAtLoad ? true }:
    {
      launchd.agents.${name} = {
        enable = true;
        config = {
          ProgramArguments = [ program ] ++ args;
          RunAtLoad = runAtLoad;
          KeepAlive = keepAlive;
          StandardOutPath = "/tmp/${name}.log";
          StandardErrorPath = "/tmp/${name}.err";
        };
      };
    };
}
```

**Linux** (`platform/nixos/lib/autostart.nix`):

```nix
{ lib, pkgs, ... }:

{
  # Helper to create standard systemd user service
  mkAutostartService = { name, program, args ? [], description, restart ? "on-failure" }:
    {
      systemd.user.services.${name} = {
        Unit = {
          Description = description;
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${program} ${lib.concatStringsSep " " args}";
          Restart = restart;
          RestartSec = 3;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
}
```

**App Usage**:

```nix
{ config, pkgs, lib, userContext, ... }:

let
  autostartLib = if pkgs.stdenv.isDarwin
    then import ../../lib/autostart.nix { inherit lib; }
    else import ../../../nixos/lib/autostart.nix { inherit lib pkgs; };
in
{
  imports = [
    (autostartLib.mkLaunchAgent {  # or mkAutostartService on Linux
      name = "aerospace";
      program = "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
      keepAlive = true;
    })
  ];
}
```

______________________________________________________________________

## 3. Desktop Path Conventions

### 3.1 macOS Application Paths

#### Application Bundle Structure

**Standard .app Bundle**:

```
MyApp.app/
├── Contents/
│   ├── Info.plist          # Bundle metadata (bundle ID, version, etc.)
│   ├── MacOS/
│   │   └── MyApp           # Executable binary
│   ├── Resources/
│   │   ├── Icon.icns       # Application icon
│   │   └── ...             # Assets, nibs, etc.
│   ├── Frameworks/         # Embedded frameworks (optional)
│   └── PlugIns/           # Plugins (optional)
```

**Key Files**:

- `Info.plist`: Contains `CFBundleIdentifier` (bundle ID), version, icon, etc.
- `MacOS/<AppName>`: The actual executable
- Must have correct file permissions (executable bit set)

#### Standard Installation Paths

| Path | Purpose | Scope | Indexed by Spotlight |
|------|---------|-------|---------------------|
| `/Applications/` | System-wide apps | All users | ✅ Yes |
| `~/Applications/` | User-specific apps | Current user | ✅ Yes |
| `/System/Applications/` | macOS system apps | All users (SIP) | ✅ Yes |
| `/nix/store/...` | Nix-built apps | All users | ❌ No (nobrowse flag) |

**Spotlight Indexing Issue**:

- `/nix` directory has `nobrowse` extended attribute
- Prevents Spotlight from indexing nix store apps
- Symlinks not indexed (only macOS aliases work)
- **Impact**: Cmd+Space won't find nix-installed GUI apps

#### Homebrew Integration

**nix-darwin Homebrew Module**:

```nix
{
  homebrew = {
    enable = true;
    
    # Install cask (GUI app)
    casks = [ "firefox" "visual-studio-code" ];
    
    # Default cask installation directory
    caskArgs.appdir = "~/Applications";  # or "/Applications"
    
    # Install formula (CLI tool)
    brews = [ "git" "ripgrep" ];
  };
}
```

**Homebrew Paths**:

- **Apple Silicon** (`aarch64-darwin`): `/opt/homebrew/`
- **Intel** (`x86_64-darwin`): `/usr/local/`
- **Cask Apps**: Install to `~/Applications/` or `/Applications/` (configurable)
- **Formula Binaries**: Install to `<homebrew>/bin/`

**Why Use Homebrew for GUI Apps**:

1. Apps install to `/Applications/` (Spotlight works)
1. Automatic updates via `brew upgrade --cask`
1. Many GUI apps not in nixpkgs
1. Better macOS integration (updates, notarization)

**Existing Repository Usage**:

```nix
# From /platform/darwin/app/aerospace.nix
homebrew.casks = [ "nikitabobko/tap/aerospace" ];

# LaunchAgent points to homebrew-installed app
launchd.agents.aerospace.config.ProgramArguments = [
  "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
];
```

#### Nix Store App Integration

**Challenges**:

1. Apps built by Nix live in `/nix/store/<hash>-<name>-<version>/`
1. Paths not stable (hash changes on rebuild)
1. Spotlight doesn't index `/nix/` directory
1. Dock and LaunchServices work, but not searchable

**Workarounds**:

1. **Symlink to ~/Applications** (manual):

   ```bash
   ln -s /nix/store/.../MyApp.app ~/Applications/MyApp.app
   ```

   - Launching works
   - Dock works
   - Spotlight still doesn't index symlinks

1. **Create macOS Alias** (Spotlight compatible):

   ```applescript
   tell application "Finder"
     make new alias file at POSIX file "/Users/username/Applications" to POSIX file "/nix/store/.../MyApp.app"
   end tell
   ```

   - Requires AppleScript or Objective-C
   - Aliases ARE indexed by Spotlight
   - More complex to automate

1. **Use Homebrew for GUI Apps** (recommended):

   - Let nix-darwin manage homebrew
   - Homebrew installs to `/Applications/`
   - Works perfectly with Spotlight, Dock, LaunchServices

**Current Best Practice**:

- CLI tools: Nix packages (work great from PATH)
- GUI apps: Homebrew casks (Spotlight compatibility)
- Developer tools: Nix packages (reproducibility)

### 3.2 Linux Application Paths

#### Desktop Entry Locations

**Standard Paths**:

```
# User-specific (highest priority)
~/.local/share/applications/

# System-wide
/usr/share/applications/
/usr/local/share/applications/

# Flatpak
/var/lib/flatpak/exports/share/applications/
~/.local/share/flatpak/exports/share/applications/

# Snap
/var/lib/snapd/desktop/applications/
```

**Search Order**:

1. `~/.local/share/applications/` (user)
1. System paths from `$XDG_DATA_DIRS`
1. Default: `/usr/local/share/:/usr/share/`

**Flatpak Path Injection**:

- Flatpak adds `/var/lib/flatpak/exports/share` to `XDG_DATA_DIRS`
- Added BEFORE system paths (higher priority)
- Can cause desktop entries to be shadowed
- **Solution**: User desktop entries (~/.local/share) still take precedence

#### Binary Locations

**Standard Binary Paths**:

```
/usr/bin/              # System binaries
/usr/local/bin/        # Locally-installed binaries
~/.local/bin/          # User binaries
/nix/store/.../bin/    # Nix-built binaries
```

**Nix Profile Paths**:

```
~/.nix-profile/bin/           # User nix profile (symlinks to store)
/run/current-system/sw/bin/   # NixOS system profile
```

**Desktop Entry Exec Paths**:

- Can use absolute paths: `Exec=/usr/bin/firefox`
- Can use PATH lookup: `Exec=firefox` (searches PATH)
- Nix packages: Use `${pkgs.firefox}/bin/firefox` in home-manager

#### Icon Locations

**Icon Theme Directories**:

```
~/.local/share/icons/
/usr/share/icons/
/usr/share/pixmaps/
```

**Icon Specification**:

- In desktop entry: `Icon=firefox` (searches icon theme)
- Absolute path: `Icon=/usr/share/pixmaps/firefox.png`
- Nix packages: `Icon=${pkgs.firefox}/share/icons/...`

#### Autostart Locations

Already covered in section 2.2, but for reference:

```
~/.config/autostart/        # User XDG autostart
/etc/xdg/autostart/         # System XDG autostart
~/.config/systemd/user/     # systemd user units
```

### 3.3 Cross-Platform Path Management

**home-manager XDG Variables**:

```nix
{
  xdg = {
    enable = true;  # Enable XDG base directory management
    
    # Override defaults (usually not needed)
    configHome = "${config.home.homeDirectory}/.config";
    dataHome = "${config.home.homeDirectory}/.local/share";
    cacheHome = "${config.home.homeDirectory}/.cache";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };
}
```

**Platform Detection in Modules**:

```nix
{
  # Detect platform
  isLinux = pkgs.stdenv.isLinux;
  isDarwin = pkgs.stdenv.isDarwin;
  
  # Platform-specific config
  home.packages = []
    ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.gnome.nautilus ]
    ++ lib.optionals pkgs.stdenv.isDarwin [ ];
  
  # Platform-specific paths
  appPath = if pkgs.stdenv.isDarwin
    then "/Applications/MyApp.app"
    else "${pkgs.myapp}/bin/myapp";
}
```

**Best Practices**:

1. Use `pkgs.stdenv.isDarwin` / `isLinux` for platform detection
1. Use `${pkgs.app}` references (not hardcoded paths)
1. Use `lib.optionals` for platform-specific lists
1. Keep platform-specific code in platform directories
1. Share common logic in `/platform/shared/`

______________________________________________________________________

## 4. Recommendations for This Feature

### 4.1 Use Existing file-associations.nix Module

**Current Implementation**: `/platform/shared/lib/file-associations.nix`

**Strengths**:

- ✅ Well-designed declarative API
- ✅ Platform-agnostic with platform-specific app ID support
- ✅ Automatic tool installation (duti/xdg-utils)
- ✅ Proper DAG ordering (after writeBoundary)
- ✅ Non-fatal errors (|| true)
- ✅ Composable (multiple apps can register associations)

**Minor Enhancements Needed**:

1. Add documentation comments with usage examples
1. Consider adding URL scheme support (e.g., `http://`, `mailto:`)
1. Add validation for app IDs (bundle ID format on macOS)

**Example Enhancement**:

```nix
# Add URL scheme support
{
  options.fileAssociations = {
    urlSchemes = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          appId = /* ... */;
          schemes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "URL schemes (e.g., http, https, mailto)";
            example = [ "http" "https" ];
          };
        };
      });
      default = [];
    };
  };
}
```

### 4.2 Create Autostart Helper Libraries

**Recommendation**: Create platform-specific autostart modules for consistency.

**macOS** (`platform/darwin/lib/autostart.nix`):

```nix
{ lib, ... }:

{
  # Create standard LaunchAgent with sensible defaults
  mkLaunchAgent = {
    name,
    program,
    args ? [],
    keepAlive ? true,
    runAtLoad ? true,
    environmentVariables ? {},
    processType ? "Standard",
  }: {
    launchd.agents.${name} = {
      enable = true;
      config = {
        ProgramArguments = [ program ] ++ args;
        RunAtLoad = runAtLoad;
        KeepAlive = keepAlive;
        ProcessType = processType;
        StandardOutPath = "/tmp/${name}.log";
        StandardErrorPath = "/tmp/${name}.err";
      } // lib.optionalAttrs (environmentVariables != {}) {
        EnvironmentVariables = environmentVariables;
      };
    };
  };
  
  # Create LaunchAgent for Homebrew cask app
  mkCaskAgent = {
    name,
    appName,  # Name of .app bundle
    args ? [],
    keepAlive ? true,
  }: {
    launchd.agents.${name} = {
      enable = true;
      config = {
        ProgramArguments = [
          "/Applications/${appName}.app/Contents/MacOS/${appName}"
        ] ++ args;
        RunAtLoad = true;
        KeepAlive = keepAlive;
        StandardOutPath = "/tmp/${name}.log";
        StandardErrorPath = "/tmp/${name}.err";
      };
    };
  };
}
```

**Linux** (`platform/nixos/lib/autostart.nix`):

```nix
{ lib, pkgs, ... }:

{
  # Create systemd user service with sensible defaults
  mkAutostartService = {
    name,
    program,
    args ? [],
    description,
    after ? [ "graphical-session.target" ],
    wants ? [],
    restart ? "on-failure",
    restartSec ? 3,
    environment ? {},
    wantedBy ? [ "default.target" ],
  }: {
    systemd.user.services.${name} = {
      Unit = {
        Description = description;
        After = after;
        Wants = wants;
      };
      Service = {
        ExecStart = "${program} ${lib.concatStringsSep " " args}";
        Restart = restart;
        RestartSec = restartSec;
      } // lib.optionalAttrs (environment != {}) {
        Environment = lib.mapAttrsToList (k: v: "${k}=${v}") environment;
      };
      Install = {
        WantedBy = wantedBy;
      };
    };
  };
  
  # Create background daemon (always restart)
  mkDaemon = {
    name,
    program,
    args ? [],
    description,
    memoryMax ? null,
  }: {
    systemd.user.services.${name} = {
      Unit = {
        Description = description;
      };
      Service = {
        ExecStart = "${program} ${lib.concatStringsSep " " args}";
        Restart = "always";
        RestartSec = 3;
      } // lib.optionalAttrs (memoryMax != null) {
        MemoryMax = memoryMax;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
```

### 4.3 Document Platform Conventions

**Add to CLAUDE.md**:

````markdown
## Desktop Integration

### File Associations

Use the shared file-associations module:

```nix
imports = [ ../../lib/file-associations.nix ];

fileAssociations.registrations = [
  {
    appIds = {
      darwin = "com.microsoft.VSCode";
      linux = "code";
    };
    extensions = [ ".nix" ".md" ".json" ];
  }
];
````

### Autostart

**macOS**: Use home-manager launchd agents

```nix
launchd.agents.myapp = {
  enable = true;
  config = {
    ProgramArguments = [ "/Applications/MyApp.app/Contents/MacOS/MyApp" ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};
```

**Linux**: Use systemd user services

```nix
systemd.user.services.myapp = {
  Unit.Description = "My Application";
  Service.ExecStart = "${pkgs.myapp}/bin/myapp";
  Install.WantedBy = [ "default.target" ];
};
```

### Application Paths

**macOS**:

- GUI apps: Use Homebrew casks (Spotlight compatibility)
- CLI tools: Use Nix packages
- LaunchAgents: Point to `/Applications/` for casks

**Linux**:

- Use `${pkgs.app}/bin/app` for Nix-built binaries
- Desktop entries auto-created by home-manager

````

### 4.4 Address Known Limitations

**Document in Research or CLAUDE.md**:

1. **macOS Spotlight**: GUI apps should use Homebrew casks, not Nix packages
2. **SSH LaunchAgents**: Can't be loaded over SSH (use Screen Sharing)
3. **Flatpak Conflicts**: User mimeapps.list takes precedence (use home-manager)
4. **Desktop Environment Overrides**: Set `xdg.mimeApps.enable = true` (makes read-only)
5. **nix-darwin Activation**: All runs as root now (use `sudo -u` for user commands)

### 4.5 Future Enhancements

**Potential Features**:
1. **URL Scheme Handlers**: Extend file-associations.nix
2. **Dock/Taskbar Management**: macOS dock pinning, Linux favorites
3. **Application Aliases**: Create Spotlight-compatible aliases for Nix apps
4. **Default Browser/Email**: Special handling for system defaults
5. **MIME Type Registration**: Custom MIME types for new file formats

---

## 5. Technical Reference

### 5.1 Key Documentation Links

**macOS**:
- [launchd.plist man page](https://keith.github.io/xcode-man-pages/launchd.plist.5.html)
- [Creating Launch Daemons and Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
- [duti GitHub](https://github.com/moretension/duti)
- [UTI Documentation](https://developer.apple.com/documentation/uniformtypeidentifiers)

**Linux**:
- [XDG Desktop Entry Specification](https://specifications.freedesktop.org/desktop-entry-spec/latest/)
- [XDG MIME Applications Specification](https://specifications.freedesktop.org/mime-apps/latest-single/)
- [XDG Autostart Specification](https://specifications.freedesktop.org/autostart-spec/0.5/)
- [systemd.service man page](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

**Home Manager**:
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [launchd module source](https://github.com/nix-community/home-manager/blob/master/modules/launchd/default.nix)
- [XDG MIME module source](https://github.com/nix-community/home-manager/blob/master/modules/misc/xdg-mime-apps.nix)
- [systemd module source](https://github.com/nix-community/home-manager/blob/master/modules/systemd.nix)

**nix-darwin**:
- [nix-darwin Manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [Activation Scripts](https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/activation-scripts.nix)

### 5.2 Common Patterns

**Platform Detection**:
```nix
{
  config = lib.mkMerge [
    # Common config
    {
      home.packages = [ pkgs.git ];
    }
    
    # macOS-specific
    (lib.mkIf pkgs.stdenv.isDarwin {
      launchd.agents.myapp = { /* ... */ };
    })
    
    # Linux-specific
    (lib.mkIf pkgs.stdenv.isLinux {
      systemd.user.services.myapp = { /* ... */ };
    })
  ];
}
````

**Activation Scripts with DAG**:

```nix
{
  # Before writeBoundary: verification only
  home.activation.checkConfig = lib.hm.dag.entryBefore ["writeBoundary"] ''
    if [ ! -f ~/.config/myapp/config.yaml ]; then
      echo "Warning: Config file missing"
    fi
  '';
  
  # After writeBoundary: modify system state
  home.activation.setupMyApp = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p ~/.config/myapp
    run ln -sf ${config.xdg.configFile."myapp/config.yaml".source} ~/.config/myapp/config.yaml
  '';
}
```

**Conditional Imports**:

```nix
{
  imports = [
    ./common.nix
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    ./darwin.nix
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    ./linux.nix
  ];
}
```

### 5.3 Troubleshooting Guide

**macOS LaunchAgent Issues**:

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Bootstrap failed: 125" | SSH session | Use Screen Sharing, not SSH |
| Agent doesn't start | Wrong path | Check `ProgramArguments`, use absolute path |
| Agent exits immediately | App forks | Set `KeepAlive = false` for self-daemonizing apps |
| No logs | Missing log config | Add `StandardOutPath`/`StandardErrorPath` |
| "Permission denied" | Wrong ownership | home-manager should handle this (mode 444) |

**Commands**:

```bash
# Check if agent is loaded
launchctl list | grep org.nix-community.home

# View agent configuration
launchctl print gui/$UID/org.nix-community.home.myapp

# Check logs
tail -f /tmp/myapp.log /tmp/myapp.err

# Manually reload
launchctl bootout gui/$UID ~/Library/LaunchAgents/org.nix-community.home.myapp.plist
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/org.nix-community.home.myapp.plist
```

**Linux systemd Issues**:

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Unit not found" | Config not reloaded | `systemctl --user daemon-reload` |
| Service fails silently | Wrong `Type` | Check `journalctl --user -u myapp` |
| PATH issues | Minimal environment | Set explicit `Environment.PATH` |
| GUI app fails | Started before X11 | Add `After=graphical-session.target` |
| Resource limits | User slice limits | Add `MemoryMax`, `CPUQuota` |

**Commands**:

```bash
# Reload systemd config
systemctl --user daemon-reload

# Check service status
systemctl --user status myapp.service

# View recent logs
journalctl --user -u myapp.service -n 50

# Follow logs
journalctl --user -u myapp.service -f

# Restart service
systemctl --user restart myapp.service
```

**File Association Issues**:

| Symptom | Cause | Solution |
|---------|-------|----------|
| macOS: Association doesn't work | App not installed | Install app, re-run darwin-rebuild |
| macOS: Spotlight can't find app | Nix store app | Use Homebrew cask instead |
| Linux: Wrong app opens file | Flatpak conflict | Set in `~/.config/mimeapps.list` (user priority) |
| Linux: DE overrides setting | mimeapps.list writable | Set `xdg.mimeApps.enable = true` |

______________________________________________________________________

## 6. Conclusion

### 6.1 Summary

Desktop integration is well-supported on both macOS and Linux through declarative Nix configuration:

**File Associations**:

- ✅ Existing implementation in repository works well
- ✅ Cross-platform with platform-specific app ID support
- ⚠️ Minor enhancements needed (URL schemes, validation)

**Autostart**:

- ✅ home-manager supports both launchd and systemd
- ✅ Well-documented, mature modules
- 💡 Could benefit from helper libraries for consistency

**Path Conventions**:

- ⚠️ Platform-specific quirks require documentation
- 💡 Use Homebrew casks for macOS GUI apps (Spotlight)
- ✅ Linux integration straightforward with Nix packages

### 6.2 Action Items

1. **Immediate**:

   - Document file-associations.nix usage in CLAUDE.md
   - Add usage examples to file-associations.nix comments
   - Create autostart helper libraries (darwin, nixos)

1. **Short-term**:

   - Enhance file-associations.nix with URL scheme support
   - Add validation for bundle IDs and desktop file names
   - Document platform conventions in CLAUDE.md

1. **Long-term**:

   - Consider dock/taskbar management
   - Explore Spotlight alias creation for Nix apps
   - Investigate default application system settings

### 6.3 Risk Assessment

**Low Risk**:

- File associations (existing implementation proven)
- Autostart (mature home-manager modules)
- Documentation (no code changes)

**Medium Risk**:

- Helper libraries (new code, needs testing)
- URL scheme support (extends existing module)

**High Risk** (avoid for now):

- Spotlight alias automation (requires AppleScript/ObjC)
- Dock management (fragile, macOS-specific)

**Recommendation**: Focus on documentation and helper libraries first, defer risky features.
