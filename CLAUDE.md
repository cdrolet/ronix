# ronix Development Guidelines

Project guidelines for working with this Nix configuration repository.

## Repo Identity

- **Framework repo**: `ronix` (`~/project/ronix`) — user/host agnostic, public library
- **Private config repo**: `usst` (`~/project/usst`, symlinked from `~/.config/nix-private`) — user/host data only
- **GitHub**: `github:cdrolet/ronix` (framework), private repo for usst

## Terminology

See `docs/terminology.md` for complete definitions. Quick reference:

- **system** = OS name (darwin, nixos) - matches `system/darwin/`, `system/nixos/`
- **architecture** = CPU arch (aarch64, x86_64) - declared in host config
- **platform** = Nix platform string (aarch64-darwin, x86_64-linux) - generated from architecture + system

## Architecture Notes

### Standalone Home-Manager Mode (Feature 036)

**Status**: ✅ **ACTIVE** - Now using standalone home-manager\
**Change**: Migrated from nix-darwin module integration to standalone home-manager

**Benefits**:

- ✅ Full lib.hm availability (dag, gvariant, types utilities)
- ✅ Better multi-user isolation
- ✅ Faster user config iteration
- ✅ Independent system and user configurations

**Implementation**:

- System configs: `darwinConfigurations.{user}-{host}` (nix-darwin only, no home-manager)
- User configs: `homeConfigurations."{user}@{host}"` (standalone home-manager)
- Justfile commands handle both transparently

**For users**:

- Commands unchanged (`just install user host`, `just build user host`)
- Internally runs both system and user activation
- User configs (`user/*/default.nix`) unchanged - still pure data

**See**: `specs/036-standalone-home-manager/spec.md` for full details

______________________________________________________________________

## Architecture

This repository uses a **User/Host/Family Architecture** (v2.1.0):

- **Users** (`user/`) select which apps they want (pure data configurations)
- **Hosts** (`system/{name}/host/`) define machine-specific settings (pure data)
- **Families** (`system/shared/family/`) provide cross-platform shared configs (wayland, gnome, server)
- **System** provides platform-specific apps and settings

## Directory Structure

```
user/           # User configurations
  <username>/   # Per-user config (pure data)
    default.nix     # User configuration
    public.age      # User's public key (committed)
    secrets.age     # Encrypted secrets (committed)
  shared/
    lib/            # User helper libraries
    template/       # User templates (Feature 031)
      common.nix    # Basic user template
      developer.nix # Developer template

system/         # System configurations
  darwin/       # macOS-specific
    host/       # Host configurations (pure data, formerly profiles)
    app/        # Darwin apps
    settings/   # System defaults (Feature 039: segregated by context)
      system/   # System-level settings (darwin-rebuild context)
      user/     # User-level settings (home-manager context)
    lib/        # Helper libraries
  nixos/        # NixOS-specific (future)
    host/       # NixOS host configurations
    app/        # NixOS apps
    settings/   # NixOS settings (Feature 039: segregated by context)
      system/   # System-level settings (nixos-rebuild context)
      user/     # User-level settings (home-manager context)
  shared/       # Cross-platform
    family/     # Cross-platform families (wayland, gnome, server)
    hardware/   # Shared hardware profiles (Feature 045)
      vm/       # VM profiles (qemu-guest, spice, apple-virtualization)
      gpu/      # GPU profiles (base-gpu, amd-gpu, virtio-gpu)
      partition/ # Disko partition layouts (standard-partitions, luks-encrypted-partition)
      monitor/  # Display profiles (hidpi-4k-27)
    app/        # Shared apps (by category)
    settings/   # Shared settings (Feature 039: segregated by context)
      system/   # System-level settings (system build context)
      user/     # User-level settings (home-manager context)
    lib/        # Shared helpers (including discovery system)

~/.config/agenix/key.txt  # Per-user private key (NOT committed, distribute securely)
```

## Active Technologies
- Nix (flakes, 2.19+), just 1.x\ + nix-darwin, home-manager, treefmt-nix, disko, stylix\ (048-inverted-flake-architecture)
- N/A (declarative `.nix` files)\ (048-inverted-flake-architecture)

- Nix (flakes, 2.19+) + disko (nix-community/disko), nixpkgs, NixOS modules (046-disko-disk-management)

- Declarative disk configuration (disko.devices) (046-disko-disk-management)

- Nix 2.19+ with flakes enabled + NixOS modules, Home Manager (standalone mode), agenix (secrets), provider-specific tools (git, aws-cli/s3cmd, proton-drive-cli) (038-multi-provider-repositories)

- Files (systemd service definition, home-manager activation scripts, desktop file cache)\\ (040-single-reboot-installation)

- nixpkgs (Niri compositor package)(041-niri-family)

- Declarative Nix configuration files (`.nix` expressions)\\ (041-niri-family)

- nix-darwin

- Age-encrypted JSON files (`user/{username}/secrets.age`) (027-user-colocated-secrets,029-nested-secrets-support)

- GNOME Shell, GDM, dconf, Wayland (028-gnome-family-system-integration)

- Nix (flakes, 2.19+)\\ + Home Manager (standalone), nix-darwin, NixOS modules\\ (044-keyboard-config-restructure)

- N/A (declarative configuration files)\\ (044-keyboard-config-restructure)

- Nix (flakes, NixOS modules)\\ + NixOS module system, home-manager (standalone), host-schema.nix\\ (045-shared-hardware-profiles)

- Filesystem (`.nix` expression files)\\ (045-shared-hardware-profiles)

- Bash (justfile recipes), jq (029-nested-secrets-support)

- User font directories (~/.local/share/fonts/, ~/Library/Fonts/) (030-user-font-config)

- Per-user age keypairs (`user/{name}/public.age` + `~/.config/agenix/key.txt`) (031-per-user-secrets)

- User creation templates (`user/shared/template/`) (031-per-user-secrets)

- Bash (for activation scripts), git (from user applications), agenix (for SSH credentials) (032-user-git-repos)

- Local filesystem (cloned repositories), age-encrypted secrets (user/{username}/secrets.age) (032-user-git-repos)

- File system (wallpaper image files), user configuration (Nix expressions) (033-user-wallpaper-config)

- Cachix (optional binary)(034-cachix-integration)

- Dual configuration outputs: `darwinConfigurations.{user}-{host}` (system), `homeConfigurations."{user}@{host}"` (user) (036-standalone-home-manager)

- File system (Nix expressions in .nix files, directory scanning) (011-modularize-flake-libs)

- Just (command runner)

## Commands

```bash
# User Management (Feature 031)
just user-create                               # Create new user interactively

# Installation
just install <user> <host>                     # System auto-detected from host
just build <user> <host>                       # Build without applying (system auto-detected)
just build-and-push <user> <host>              # Build and push to Cachix (Feature 034)
just diff <user> <host>                        # Show diff (system auto-detected)

# List available users/hosts
just list-users
just list-hosts
just list-combinations                         # Show all valid user-host combinations

# Update dependencies
just update
just update-input <input>

# Check configuration
just check

# Format Nix files
just fmt
just fmt-check                                 # Check formatting without modifying

# Secrets Management (Feature 031 - Per-User Keys)
just secrets-init-user <user>                  # Initialize per-user keypair
just secrets-set <user> <field> <value>        # Set a secret value (supports nested paths)
just secrets-edit <user>                       # Edit user secrets (interactive)
just secrets-list                              # List all user secrets status
just secrets-show-pubkey <user>                # Show user's public key
just secrets-rotate-user <user>                # Rotate user's encryption key

# Cleanup
just clean                                     # Clean old generations and garbage collect
```

## NixOS Installation Flow (Feature 040)

NixOS installations from ISO require **2 reboots** to reach a functional desktop:

**Installation Process**:

1. Boot from ISO
1. Run `bash install-remote.sh <user> <host> init-disk`
1. Disko auto-detects disk, partitions/formats/mounts using host's storage profile
1. **Reboot #1**: System reboots after nixos-install
1. **First boot**: Automatic home-manager setup runs (2-5 minutes)
   - Service blocks GDM until setup completes
   - Clones repository, builds configuration, installs apps
   - Desktop file cache refreshed automatically
1. **Login #1**: All configured apps visible immediately

**What happens during first boot**:

- `nix-config-first-boot.service` runs before graphical session
- Systemd ordering (`before = ["graphical.target"]`) blocks GDM
- Progress messages show: "[1/4] Cloning..." → "[2/4] Building..." → "[3/4] Installing..." → "[4/4] Complete!"
- Login screen appears only after setup finishes

**Result**: Apps visible on first login, no 3rd reboot needed.

## Code Style

### Nix Code

- Use `lib.mkDefault` for overridable settings
- Use `lib.mkForce` when enforcement is required
- Keep modules under 200 lines (constitutional requirement)
- One app per file (app-centric organization)
- Namespace shell aliases to avoid conflicts

### Module Structure

```nix
{ config, pkgs, lib, ... }:

{
  # Package installation
  home.packages = [ pkgs.app ];
  
  # Program configuration
  programs.app = {
    enable = true;
    settings = { ... };
  };
  
  # Shell aliases (namespaced)
  home.shellAliases = {
    app-cmd = "app command";
  };
}
```

### Homebrew Integration (Darwin Apps)

Darwin apps can declare homebrew casks/brews directly in the app module. The darwin system configuration automatically extracts and installs them:

```nix
{ config, pkgs, lib, ... }:

{
  # System-level installation (collected by darwin.nix)
  # home-manager ignores these, darwin system config installs them
  homebrew.casks = ["my-app"];
  
  # Optional: homebrew formulae
  homebrew.brews = ["my-cli-tool"];
  
  # Optional: custom taps
  homebrew.taps = ["vendor/tap"];
  
  # User-level configuration (home-manager)
  xdg.configFile."my-app/config.json".text = ''
    {...}
  '';
}
```

**How it works:**

1. Apps declare `homebrew.casks` in their module
1. `darwin.nix` extracts all homebrew declarations from user apps
1. System-level homebrew installs the casks
1. Home-manager handles user configuration only

**Benefits:**

- Apps are self-contained (installation + configuration)
- No need for separate settings files
- Works for aerospace, cursor, and other darwin apps

### Desktop Metadata (Optional)

Applications can declare desktop integration metadata for file associations and autostart:

```nix
{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.app ];
  
  programs.app = {
    enable = true;
    
    # Desktop metadata (optional)
    desktop = {
      # Platform-specific installation paths
      paths = {
        darwin = "/Applications/App.app";
        nixos = "${pkgs.app}/bin/app";
      };
      
      # File associations (optional)
      associations = [ ".json" ".xml" ".yaml" ];
      
      # Autostart at login (optional, default: false)
      autostart = false;
    };
  };
}
```

**Desktop Metadata Rules**:

- Entirely optional - apps without it continue to work normally
- If `associations` or `autostart` are specified, `paths` for active platform is required
- File extensions must start with "." (e.g., ".json", not "json")
- Platform paths are platform-specific (darwin uses `/Applications/`, nixos uses Nix store paths)
- Validation occurs at evaluation time (`nix flake check`)
- See `docs/features/019-app-desktop-metadata.md` for full documentation

### Import Conventions

- Users import apps using the discovery system (pure data arrays)
- Hosts import settings using the discovery system (pure data arrays)
- Families provide cross-platform shared configurations
- Apps should be independently importable
- Avoid circular dependencies

### Host/Family Architecture (Feature 021, 028)

**Hosts** are pure data machine configurations:

```nix
# system/darwin/host/home-macmini-m4/default.nix
{ ... }:
{
  name = "home-macmini-m4";
  family = [];  # Darwin typically doesn't share cross-platform
  applications = ["*"];  # All apps
  settings = ["default"];  # All platform settings
}
```

**Families** are cross-platform shared configurations:

- **Purpose**: Share configs across platforms (e.g., "wayland" for Wayland desktops, "gnome" for GNOME)
- **NOT for**: Deployment contexts (work, home, gaming) - hosts are specific enough
- **Location**: `system/shared/family/{name}/`
- **Composition**: Hosts can use multiple families: `family = ["wayland", "gnome"]`

**Cross-Platform Family Architecture** (Feature 028):

Families enable true cross-platform sharing while respecting platform differences:

**System vs User Level Separation**:

- **System-level** (`settings/`): Desktop environment installation, display managers, system services
  - NixOS: Imported at system level (before home-manager)
  - Darwin: No system-level family settings (nix-darwin limitations)
- **User-level** (`app/`): User applications, dconf settings, GTK themes
  - Both platforms: Imported via home-manager with hierarchical discovery

**Family Integration Pattern**:

```nix
# NixOS host with GNOME family
{
  name = "nixos-workstation";
  family = ["wayland", "gnome"];  # System-level settings auto-installed
  applications = ["git" "firefox"];
  settings = ["default"];
}
```

When a host declares `family = ["gnome"]`:

1. **System level**: `gnome/settings/default.nix` auto-imported (GNOME desktop, GDM, Wayland)
1. **User level**: Apps hierarchically discovered (system → gnome → linux → shared)

**Family Structure**:

```
system/shared/family/gnome/
  app/                    # User-level apps (hierarchical discovery)
    utility/
      gedit.nix          # Individual apps (no default.nix)
    README.md            # Family app documentation
  settings/              # System-level settings (NixOS only)
    default.nix          # Auto-discovery for all .nix modules
    desktop/
      gnome-core.nix     # GNOME Shell, GDM, core-apps
      gnome-optional.nix # Optional components (dev tools, games)
      gnome-exclude.nix  # Exclude unwanted packages
    ui.nix               # User interface settings
    wayland.nix          # Wayland configuration
    shortcuts.nix        # Global keyboard shortcuts
```

**Hierarchical Discovery**:

- Apps/settings search order: system → family1 → family2 → ... → shared
- First match wins (no merging)
- Example: `system/nixos/app/` → `system/shared/family/gnome/app/` → `system/shared/family/wayland/app/` → `system/shared/app/`
- Family apps: No `default.nix` required - discovered when user selects them

**Platform-Agnostic Design**:

Family modules use generic NixOS options (not GNOME-specific APIs):

```nix
# gnome/settings/ui.nix uses dconf, not org.gnome.desktop directly
dconf.settings = {
  "org/gnome/desktop/interface" = {
    color-scheme = lib.mkDefault "prefer-dark";
  };
};
```

This allows families to work across different NixOS configurations without platform lock-in.

### Discovery System

The repository uses an automatic discovery system for finding and loading modules.

**User Configs** (Feature 020 - Pure Data Pattern):
Users simply declare applications in their `user.applications` array. Platform libraries automatically handle discovery and imports:

```nix
{ ... }:
{
  user = {
    name = "username";
    applications = [ "git" "zsh" "helix" "aerospace" ];
  };
}
```

**Host Configs** (Feature 021 - Pure Data Hosts):
Hosts declare name, families, applications, and settings. Platform libraries handle all discovery:

```nix
{ ... }:
{
  name = "nixos-workstation";
  family = ["wayland", "gnome"];  # Compose families
  hardware = ["qemu-guest" "spice" "standard-partitions"];  # Shared hardware profiles
  applications = ["git" "firefox"];
  settings = ["default"];
}
```

**How It Works**:

1. Platform libs (darwin.nix, etc.) load user/host configs as pure data
1. Extract fields before module evaluation
1. Auto-install family defaults (if family array non-empty)
1. Call hierarchical discovery for apps/settings (system → families → shared)
1. Combine pure data + generated imports in home-manager configuration

**Available Discovery Functions** (for system lib developers):

- `discoverUsers`: Auto-discover users from `user/` directory
- `discoverHosts`: Discover hosts for a system
- `discoverModules`: Recursively find .nix files in a directory
- `discoverApplicationNames`: Find app names in app directories
- `discoverApplications`: Discover all apps for a caller context
- `resolveApplications`: Resolve app names to paths with hierarchical search
- `discoverWithHierarchy`: Hierarchical search (system → families → shared)
- `resolveHardwareProfiles`: Resolve hardware profile names to paths (fuzzy or full path)
- `validateFamilyExists`: Validate family directories exist
- `validateNoWildcardInSettings`: Ensure settings don't use wildcards
- `autoInstallFamilyDefaults`: Get family default.nix paths

## Constitutional Requirements

Per Constitution v2.0.0 (updated for Feature 021):

1. **Module Size**: \<200 lines per module
1. **App-Centric**: One file per app
1. **Hierarchical Config**: Specific overrides general (system → families → shared)
1. **Multi-User Isolation**: Users can't interfere with each other
1. **Platform Abstraction**: Platform-specific code in platform directories
1. **Documentation**: Each module has header explaining purpose
1. **Pure Data Pattern**: Users and hosts are pure data (no imports)

## Adding Content

### New App

1. Create `system/{platform}/app/<category>/<app>.nix`
1. Add app name to user or host config applications list
1. Keep under 200 lines
1. Include header documentation
1. Apps are automatically discovered - no manual imports needed!

### Dock Configuration (Feature 023)

Users can define their dock layout using the `docked` field:

```nix
{ ... }:
{
  user = {
    name = "username";
    applications = ["*"];
    
    # Dock items in display order
    docked = [
      # Applications (resolved to platform paths)
      "zen"
      "brave"
      "mail"
      
      # Separator
      "|"
      
      # More apps
      "zed"
      "ghostty"
      
      # Thick separator (darwin only)
      "||"
      
      # Folders (resolved to $HOME/<name>)
      "/Downloads"
    ];
  };
}
```

**Syntax**:

- Application names: `"zen"`, `"mail"` (resolved to platform paths)
- Folders: `"/Downloads"` (tries `$HOME/Downloads`, then `/Downloads`)
- Standard separator: `"|"`
- Thick separator: `"||"` (darwin only, falls back to standard)
- System items: `"<trash>"` (no-op on darwin, creates .desktop on GNOME)

**Behavior**:

- Missing apps/folders are silently skipped
- Empty array clears dock
- If not specified, dock is unchanged
- Darwin: Uses dockutil
- GNOME: Uses gsettings favorite-apps

### Font Configuration (Feature 030)

Users configure fonts using font family names. Packages are auto-installed from nixpkgs.

```nix
{ ... }:
{
  user = {
    name = "username";
    applications = ["*"];
    
    fonts = {
      defaults = {
        # Each category has families (list) + size (int, default 11)
        monospace = {
          families = ["Berkeley Mono" "Fira Code"];  # Fallback order
          size = 12;
        };
        sansSerif = {
          families = ["Inter"];
          size = 10;
        };
        serif = {
          families = ["Crimson Pro"];
          # size = 11;  # Default if not specified
        };
      };
      
      # Optional: explicit packages for non-standard naming
      # packages = ["hack-font"];  # When "Hack" -> pkgs.hack fails
      
      # Private font repositories (requires sshKeys.fonts)
      repositories = [
        "git@github.com:myorg/private-fonts.git"
      ];
    };
    
    # Deploy key for private repos (optional)
    sshKeys = {
      fonts = "<secret>";
    };
  };
}
```

**How Auto-Translation Works**:
Font family names are translated to nixpkgs package names:

1. `"Fira Code"` → `fira-code` (lowercase + dash)
1. Try fallback suffixes: `fira-code-font`, `fira-code-fonts`
1. Try underscore variants: `fira_code`, `fira_code_fonts`
1. If not found, assume private font from repositories

**Private Repositories**:

- Cloned to `~/.local/share/fonts/private/` (both platforms)
- Darwin: Font files symlinked to `~/Library/Fonts/`
- Linux: `fc-cache` run after cloning
- Requires `sshKeys.fonts` deploy key
- Silently skipped if deploy key not configured

**Apps Using fonts.defaults**:
Apps reference the user's font config with no fallback:

```nix
# In an app module
let
  monoConfig = (config.user.fonts or {}).defaults.monospace or {};
  monoFamilies = monoConfig.families or [];
  monoSize = monoConfig.size or 11;
  hasFont = monoFamilies != [];
in {
  xdg.configFile."myapp/config".text = ''
    ${lib.optionalString hasFont "font-family = ${builtins.head monoFamilies}"}
    font-size = ${toString monoSize}
  '';
}
```

**Platform Behavior**:

- **Linux**: Home Manager `fonts.fontconfig.defaultFonts` (works on NixOS AND non-NixOS)
- **GNOME**: dconf for UI fonts (`monospace-font-name`, `document-font-name`, `font-name`)
- **Darwin**: No centralized font setting (apps reference `fonts.defaults` directly)
- **No fallbacks**: If user didn't configure fonts, system/app defaults are used

### Wallpaper Configuration (Feature 033)

Users can declaratively set their desktop wallpaper by specifying a file path. Supports both single wallpaper (all monitors) and per-monitor configurations. Works on macOS (Darwin) and GNOME desktop environments.

**Single Wallpaper** (same image on all monitors):

```nix
{ ... }:
{
  user = {
    name = "username";
    applications = ["*"];
    
    # Simple wallpaper configuration
    wallpaper = "~/Pictures/wallpaper.jpg";
  };
}
```

**Per-Monitor Wallpapers** (different image per display):

```nix
{ ... }:
{
  user = {
    name = "username";
    applications = ["*"];
    
    # Multi-monitor configuration
    wallpapers = [
      { monitor = 0; path = "~/Pictures/left-monitor.jpg"; }
      { monitor = 1; path = "~/Pictures/right-monitor.jpg"; }
      { monitor = 2; path = "~/Pictures/center-monitor.png"; }
    ];
    
    # Optional: fallback for unspecified monitors
    wallpaper = "~/Pictures/default.jpg";
  };
}
```

**Monitor Numbering**:

- Monitors are 0-indexed (first monitor = 0, second = 1, etc.)
- **macOS**: Check monitor order in System Settings → Displays (left to right)
- **GNOME**: Check with `xrandr --listmonitors` (list order = monitor index)
- If `wallpapers` and `wallpaper` both set, per-monitor takes precedence
- Unspecified monitors use `wallpaper` value (if set) or system default

**Supported Path Formats**:

- **Home-relative** (recommended): `"~/Pictures/wallpaper.jpg"` - portable across machines
- **Absolute**: `"/Users/username/Pictures/wallpaper.jpg"` (macOS) or `"/home/username/Pictures/wallpaper.png"` (Linux)
- **Paths with spaces**: Automatically handled - `"~/Pictures/My Wallpapers/image 1.jpg"`

**Supported Image Formats**:

- JPEG (`.jpg`, `.jpeg`) - Most common, good compression
- PNG (`.png`) - Lossless, supports transparency
- HEIC (`.heic`) - High efficiency (macOS)
- WebP (`.webp`) - Modern format, excellent compression

**Platform-Specific Behavior**:

- **macOS (Darwin)**:

  - **Single wallpaper**: Uses osascript (AppleScript), requires one-time TCC permission for "System Events"
  - **Per-monitor**: Uses desktoppr (Homebrew), automatically installed when `wallpapers` configured
  - Wallpaper persists across reboots

- **GNOME Desktop**:

  - **Single wallpaper**: Uses dconf.settings, applies immediately
  - **Per-monitor**: Uses nitrogen with systemd service, runs on login
  - Sets wallpaper for both light and dark modes (single wallpaper only)
  - Changes take effect immediately (no logout required)

**Validation & Error Handling**:

- Build-time warning if wallpaper file doesn't exist (build still succeeds)
- Runtime validation skips wallpaper setting if file missing (logs warning to stderr)
- Invalid file paths don't prevent system activation
- Missing dependencies (desktoppr, nitrogen) logged with installation instructions
- System default wallpaper remains if configuration invalid

**Example Configurations**:

```nix
# Single wallpaper
user.wallpaper = "~/Pictures/mountain-view.jpg";

# With spaces in filename
user.wallpaper = "~/Pictures/Northern Lights 2024.png";

# Absolute path
user.wallpaper = "/mnt/shared/wallpapers/corporate-bg.jpg";

# Dual monitor setup
user.wallpapers = [
  { monitor = 0; path = "~/left.jpg"; }
  { monitor = 1; path = "~/right.jpg"; }
];

# Triple monitor with fallback
user = {
  wallpaper = "~/Pictures/default.jpg";  # Fallback
  wallpapers = [
    { monitor = 0; path = "~/workspace-left.png"; }
    { monitor = 1; path = "~/workspace-center.png"; }
    # Monitor 2 will use default.jpg
  ];
};
```

**Troubleshooting**:

- **"Wallpaper file not found" warning**: Check file exists at specified path with `ls <path>`
- **macOS single wallpaper not changing**: First run requires TCC permission approval (popup: "Terminal wants to control System Events")
- **macOS per-monitor not working**: Ensure desktoppr installed: `brew install scriptingosx/tap/desktoppr`
- **GNOME single wallpaper not changing**: Verify dconf value: `gsettings get org.gnome.desktop.background picture-uri`
- **GNOME per-monitor not working**: Check systemd service: `systemctl --user status nitrogen-wallpaper`
- **Wrong monitor gets wallpaper**: Verify monitor indices with `xrandr --listmonitors` (GNOME) or System Settings (macOS)
- **Wallpaper resets after rebuild**: Ensure file path is correct and file exists

**Limitations**:

- Lock screen wallpaper uses same image (GNOME has separate setting: `org/gnome/desktop/screensaver/picture-uri`)
- Dynamic wallpapers (time-of-day changing) require special HEIC format (macOS only)
- Per-monitor dark mode wallpapers not supported (nitrogen limitation)

### New User

**Recommended Approach** (Feature 031 - Interactive Creation):

```bash
# Create user interactively with template
just user-create

# This will prompt for:
#   - Username (alphanumeric, underscore, hyphen only)
#   - Email (validated format)
#   - Full name (optional, defaults to username)
#   - Template selection:
#       1. common - Basic applications (firefox, git, zsh, ghostty, obsidian, bitwarden)
#       2. developer - Development toolset (adds zed, helix, cursor, tmux, docker, etc.)

# Initialize encryption keypair
just secrets-init-user <username>

# Add secrets
just secrets-set <username> email "user@example.com"
```

**Manual Approach** (if you prefer to write the file yourself):

1. Create `user/<username>/default.nix` with pure data configuration:

```nix
{ ... }:

{
  user = {
    name = "<username>";
    email = "<email>";
    fullName = "<full name>";  # Optional, omit if same as username
    
    # Simply list the applications you want
    applications = [
      "git"
      "zsh"
      "helix"
      # Add more apps here
    ];
    
    # Optional: Dock configuration
    docked = [
      "firefox"
      "mail"
      "|"
      "ghostty"
    ];
  };
}
```

2. Initialize encryption keypair:

```bash
just secrets-init-user <username>
```

3. Platform libraries automatically handle all imports - no helper functions needed!

**Wildcard Pattern** (imports all available apps):

```nix
{ ... }:

{
  user = {
    name = "<username>";
    email = "<email>";
    applications = [ "*" ];  # Import ALL available apps
  };
}
```

**Exclusion Patterns** (Feature 043 — exclude apps from wildcards):

```nix
{ ... }:

{
  user = {
    name = "<username>";
    email = "<email>";
    applications = [
      "*"           # Start with all apps
      "!docker"     # Exclude specific app
      "!ai/*"       # Exclude entire category
    ];
  };
}
```

**Exclusion Rules**:

- `"!appname"` — excludes a specific app from wildcard results
- `"!category/*"` — excludes all apps in a category
- Explicit includes override exclusions: `["*", "!docker", "docker"]` installs docker
- Exclusions only subtract from wildcard results: `["!docker"]` alone installs nothing
- Non-matching exclusions are silently ignored
- Processing order: expand wildcards → subtract exclusions → add explicit includes

### New Host

1. Create `system/<platform>/host/<hostname>/default.nix` with pure data configuration (Feature 021):

**Darwin Host** (no cross-platform families):

```nix
{ ... }:

{
  name = "home-macmini-m4";
  family = [];  # Darwin typically doesn't share cross-platform
  applications = ["*"];  # All apps
  settings = ["default"];  # All platform settings
}
```

**Linux Host** (with cross-platform families):

```nix
{ ... }:

{
  name = "nixos-workstation";
  family = ["wayland", "gnome"];  # Compose families
  hardware = ["qemu-guest" "standard-partitions"];  # Shared hardware profiles (Feature 045)
  applications = ["git" "firefox" "helix"];
  settings = ["default"];
}
```

2. Hosts are auto-discovered - no need to edit flake.nix!
1. No imports, just pure data.

### New Family

1. Create `system/shared/family/<family-name>/` directory with `app/` and `settings/` subdirectories

1. **Add apps** (user-level, hierarchical discovery):

   - Create app files: `app/<category>/<app>.nix`
   - **Do NOT create `app/default.nix`** - apps discovered hierarchically when user selects them
   - Add `app/README.md` to document family-specific app patterns

1. **Add settings** (Feature 039: segregated by context):

   **System-level settings** (`settings/system/default.nix`):

   ```nix
   { config, lib, pkgs, ... }:
   let
     discovery = import ../../../../lib/discovery.nix {inherit lib;};
   in {
     imports = map (file: ./${file}) (discovery.discoverModules ./.);
   }
   ```

   - Add individual modules: `settings/system/<name>.nix`
   - Auto-imported during system build when host declares `family = ["<family-name>"]`
   - Use system options: `services.*`, `environment.*`, etc.

   **User-level settings** (`settings/user/default.nix`):

   ```nix
   { config, lib, pkgs, ... }:
   let
     discovery = import ../../../../lib/discovery.nix {inherit lib;};
   in {
     imports = map (file: ./${file}) (discovery.discoverModules ./.);
   }
   ```

   - Add individual modules: `settings/user/<name>.nix`
   - Auto-imported during home-manager activation
   - Use user options: `home.*`, `programs.*`, `dconf.*`, etc.

1. **Platform considerations**:

   - System-level settings work on NixOS only (imported before home-manager)
   - User-level settings work on all platforms (imported via home-manager)
   - Use generic NixOS options (dconf, systemd) for platform-agnostic design

1. Families are for cross-platform sharing (linux, gnome, server), NOT deployment contexts

### Settings Organization (Feature 039)

**Settings Categorization** - System vs User Level:

Settings are segregated into `system/` and `user/` subdirectories based on their build context:

**System-level settings** (`settings/system/`):

- Imported during system build (darwin-rebuild, nixos-rebuild)
- Configure system-wide state: services, boot, networking, security
- Use system-level options: `system.*`, `environment.*`, `services.*`, `homebrew.*` (darwin)
- **Examples**: firewall rules, system timezone, boot loader, network configuration
- **No access to**: `home.*`, `programs.*` (home-manager options)

**User-level settings** (`settings/user/`):

- Imported during home-manager activation (standalone or integrated)
- Configure user-specific state: dotfiles, themes, user services
- Use user-level options: `home.*`, `programs.*`, `dconf.*`, `xdg.*`
- **Examples**: shell config, GTK themes, dconf settings, user activation scripts
- **No access to**: `system.*`, `environment.*` (system options)

**How to categorize new settings**:

1. Does it use `system.*`, `environment.*`, or `services.*`? → `settings/system/`
1. Does it use `home.*`, `programs.*`, or `lib.hm.*`? → `settings/user/`
1. Does it need system rebuild to apply? → `settings/system/`
1. Does it run during home-manager activation? → `settings/user/`

**Benefits**:

- No manual context guards (`options ? home`) needed
- Clear separation prevents build context errors
- Automatic discovery based on subdirectory
- Self-documenting: directory structure indicates build context

### Settings Modules (Feature 025, 028, 039)

Settings are organized by platform and family with auto-discovery.

**Context-segregated structure**: All settings directories now have `system/` and `user/` subdirectories.

**NixOS Settings** (`system/nixos/settings/`):

System-level (`system/nixos/settings/system/`):

- `security.nix` - Firewall, sudo, polkit
- `locale.nix` - Timezone, locale from user config
- `keyboard.nix` - Key repeat rate, layout, Mac-style modifier remapping
- `network.nix` - NetworkManager, DNS
- `system.nix` - Boot loader, Nix settings, GC
- `user.nix` - User account creation
- `virtualization.nix` - QEMU guest agent, SPICE VD agent (VM integration)

User-level (`system/nixos/settings/user/`): (none currently - user settings in shared/)

**Darwin Settings** (`system/darwin/settings/`):

System-level (`system/darwin/settings/system/`):

- `dock.nix` - Dock configuration
- `system.nix` - System preferences
- `finder.nix` - Finder settings
- `firewall.nix` - Application firewall
- `network.nix` - Network configuration
- `locale.nix` - Language and timezone
- `keyboard.nix` - Key repeat rate
- And more...

User-level (`system/darwin/settings/user/`):

- `fonts.nix` - Private font repository syncing
- `wallpaper.nix` - Desktop wallpaper configuration

**Wayland Family Settings** (`system/shared/family/wayland/settings/`):

User-level (`system/shared/family/wayland/settings/user/`):

- `fonts.nix` - Font installation and fc-cache
- `home-directory.nix` - Create standard directories
- `virtualization.nix` - SPICE VD agent user session (clipboard, display)

**GNOME Family Settings** (`system/shared/family/gnome/settings/`):

System-level (`system/shared/family/gnome/settings/system/`):

- `desktop/gnome-core.nix` - GNOME Shell, GDM, core packages
- `desktop/gnome-optional.nix` - Optional packages (disabled by default)
- `desktop/gnome-exclude.nix` - Exclude unwanted packages
- `wayland.nix` - Wayland display server configuration

User-level (`system/shared/family/gnome/settings/user/`):

- `ui.nix` - Dark mode, fonts, animations (dconf)
- `keyboard.nix` - Window shortcuts (Super+Q to close)
- `power.nix` - Screen timeout, suspend settings
- `dock.nix` - Dock favorites from user.docked
- `shortcuts.nix` - Global keyboard shortcuts
- `fonts.nix` - GNOME font settings (dconf)
- `wallpaper.nix` - Desktop wallpaper
- `keyring.nix` - GNOME Keyring SSH agent

**Shared Settings** (`system/shared/settings/`):

System-level (`system/shared/settings/system/`):

- `cachix.nix` - Cachix binary cache (read-only token)

User-level (`system/shared/settings/user/`):

- `password.nix` - User password from secrets
- `fonts.nix` - Font package installation
- `git-repos.nix` - Git repository syncing
- `s3-repos.nix` - S3 repository syncing
- `proton-drive-repos.nix` - Proton Drive syncing

All settings use auto-discovery via `default.nix` in each subdirectory - just add a `.nix` file and it's automatically imported based on context.

### Secrets Management (Feature 031 - Per-User Keys)

Secrets are encrypted using age with per-user encryption keys and stored alongside user configurations.

**Architecture**:

- **Per-User Key Model**: Each user has their own encryption keypair (security isolation)
- **Colocated Secrets**: `user/{name}/secrets.age` beside `user/{name}/default.nix`
- **No Central Registry**: No `secrets.nix` to maintain - just add secrets per user
- **JSON Format**: Secrets stored as encrypted JSON with nested path support (Feature 029)

**File Layout**:

```
user/
  cdrokar/
    default.nix                # Config with "<secret>" placeholders
    public.age                 # User's public key (commit this)
    secrets.age                # Encrypted JSON secrets (commit this)
    
~/.config/agenix/key.txt       # User's private key (distribute securely, NEVER commit)
```

**Quick Start**:

```bash
# 1. Create a new user (interactive)
just user-create
# Prompts for: username, email, full name (optional), template (common/developer)

# 2. Initialize user's keypair
just secrets-init-user username

# 3. Add secrets (flat or nested paths)
just secrets-set username email "me@example.com"
just secrets-set username sshKeys.personal "$(cat ~/.ssh/id_ed25519)"
just secrets-set username tokens.github "ghp_xxx"

# 4. List all secrets (shows nested paths)
just secrets-list
# Output: 
#   username:
#     Public key: user/username/public.age ✓
#     Secrets: user/username/secrets.age ✓
#     Fields:
#       - email: [encrypted]
#       - sshKeys.personal: [encrypted]
#       - tokens.github: [encrypted]

# 5. Reference in config (user/username/default.nix)
user = {
  name = "username";
  email = "<secret>";           # Flat path
  sshKeys = {
    personal = "<secret>";      # Nested path (Feature 029)
    work = "<secret>";
  };
  tokens.github = "<secret>";   # Nested paths work
  timezone = "America/Toronto"; # Plain text (no secret needed)
};
```

**Nested Secrets JSON Structure** (Feature 029):

```json
{
  "email": "me@example.com",
  "sshKeys": {
    "personal": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
    "work": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  },
  "tokens": {
    "github": "ghp_xxx"
  }
}
```

**Per-User Key Benefits**:

- Each user has independent encryption keypair
- Individual key rotation without affecting other users
- Better security isolation (users can't decrypt each other's secrets)
- Revoke access by removing user's public key
- Bitwarden CLI integration for secure key backup

**Key Distribution**:

```bash
# Option 1 - Bitwarden CLI (recommended)
bw login
export BW_SESSION=$(bw unlock --raw)
bw get template item | jq '
  .type = 2 |
  .secureNote.type = 0 |
  .name = "username - nix-config age key" |
  .notes = "'$(cat ~/.config/agenix/key.txt)'" |
  .fields = [{name: "username", value: "username", type: 0}]
' | bw encode | bw create item

# Option 2 - Manual distribution
scp ~/.config/agenix/key.txt other-machine:~/.config/agenix/

# Option 3 - Environment variable (CI/CD)
export AGENIX_KEY=$(cat ~/.config/agenix/key.txt)
```

**Key Rotation**:

```bash
# Rotate a user's key (re-encrypts all secrets with new key)
just secrets-rotate-user username
```

**App-Level Secret Resolution**:

Apps are responsible for resolving their own secrets at activation time. The `secrets-module.nix` only sets up agenix infrastructure. Use the simplified `secrets` helper library:

```nix
# In an app .nix file (e.g., system/shared/app/dev/git.nix)
{ config, pkgs, lib, ... }:
let
  secrets = import ../../../../user/shared/lib/secrets.nix { inherit lib pkgs; };
in {
  # Use config.user fields directly - no placeholder handling needed
  programs.myapp.email = config.user.email;
  
  # Resolve secrets at activation time - mkActivationScript handles everything
  home.activation.applyMyAppSecrets = secrets.mkActivationScript {
    inherit config pkgs lib;
    name = "myapp";
    fields = {
      # fieldName must match: config.user.fieldName AND JSON key in secrets.age
      email = ''${pkgs.myapp}/bin/myapp config set email "$EMAIL"'';
    };
  };
}
```

**How it works**:

1. Set `user.email = "<secret>"` in user config
1. App uses `config.user.email` directly (contains `"<secret>"`)
1. `mkActivationScript` automatically detects the `"<secret>"` placeholder
1. At activation: reads from `secrets.age`, runs your shell command with `$EMAIL` set

**Key benefits**:

- ✅ **No boilerplate** - no need to check `isSecret`, get `secretsPath`, or handle conditionals
- ✅ **Auto-detection** - automatically finds which fields are secrets
- ✅ **Convention over configuration** - field names match across user config, secrets.age, and shell variables
- ✅ **KISS principle** - minimal knowledge required to add secret support to an app

### New Platform

**Current Architecture** (Optimal for Nix Flakes):

Adding a new platform requires editing `flake.nix` to declare platform-specific inputs and import the platform library. This is the recommended approach based on research from feature 016-platform-delegation.

1. **Add platform inputs to `flake.nix`**:

   ```nix
   inputs = {
     # ... existing inputs
     new-platform-input = {
       url = "github:...";
       inputs.nixpkgs.follows = "nixpkgs";
     };
   };
   ```

1. **Add platform import to `flake.nix` outputs**:

   ```nix
   newPlatformOutputs =
     if builtins.pathExists ./system/new-platform/lib/new-platform.nix
     then (import ./system/new-platform/lib/new-platform.nix {
       inherit inputs lib nixpkgs validUsers discoverHosts;
     }).outputs
     else {};
   ```

1. **Merge platform outputs**:

   ```nix
   {
     newPlatformConfigurations = newPlatformOutputs.newPlatformConfigurations or {};
     formatter = (formatter or {}) // (newPlatformOutputs.formatter or {});
   }
   ```

1. **Create platform library** at `system/new-platform/lib/new-platform.nix` following the pattern in `system/darwin/lib/darwin.nix`

**Why This Architecture?**

Research (feature 016) investigated delegating platform-specific flake logic to platform libraries to achieve "single file to add platform". Key findings:

- ✅ Dynamic discovery: Technically viable
- ❌ **Input delegation: Not possible** - Nix flakes require centralized input declaration
- ✅ Output composition: Already working
- Current architecture is optimal given Nix flake constraints

See `specs/016-platform-delegation/research.md` for detailed analysis.

## Testing

```bash
# Check syntax
nix flake check

# Build configuration
just build <user> <host>

# Test specific configuration
nix build ".#darwinConfigurations.<user>-<host>.system"
```

## Migration Status

- ✅ Phase 0-5 Complete (User/System Split)
- ✅ Constitution v2.0.0 Ratified
- ✅ Feature 020: Pure data user configs (applications array)
- ✅ Feature 021: Host/family architecture
- ✅ Feature 023: User dock configuration
- ✅ Feature 024: GNOME dock module
- ✅ Feature 025: NixOS settings modules
- ✅ Feature 027: User colocated secrets
- ✅ Feature 028: GNOME family system integration (cross-platform family architecture)
- ✅ Feature 029: Nested secrets support
- ✅ Feature 030: User font configuration
- ✅ Feature 031: Per-user secrets with interactive user creation
- ✅ Feature 036: Standalone home-manager mode (Phase 2 complete)

## Recent Changes
- 048-inverted-flake-architecture: Added Nix (flakes, 2.19+), just 1.x\ + nix-darwin, home-manager, treefmt-nix, disko, stylix\

- 046-disko-disk-management: Added Nix (flakes, 2.19+) + disko (nix-community/disko), nixpkgs, NixOS modules

- 045-shared-hardware-profiles: Added Nix (flakes, NixOS modules)\\ + NixOS module system, home-manager (standalone), host-schema.nix\\


  - Migrated all darwin configurations
  - Created 3 users (cdrokar, cdrolet, cdrixus)
  - Created 2 hosts (home-macmini-m4, work) - formerly profiles
  - Cross-platform family system for shared configs

## Resources

- [Constitution](.specify/memory/constitution.md) - Governance
- [Feature 010 Spec](specs/010-repo-restructure/spec.md) - Architecture details
- [README.md](README.md) - User documentation
