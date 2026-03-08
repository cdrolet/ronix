# Research: GNOME Family System Integration

**Feature**: 028-gnome-family-system-integration\
**Date**: 2025-12-25\
**Phase**: 0 (Research)

## Research Questions

This document resolves the technical questions identified in plan.md:

1. Which specific GNOME packages to include in `settings/desktop/`?
1. How to configure system vs user-level with family integration?
1. Correct dconf schema path for Ctrl+Alt+Space launcher binding?
1. GDM Wayland configuration options in NixOS?

______________________________________________________________________

## Q1: GNOME Desktop Packages

### What `services.xserver.desktopManager.gnome.enable` Provides

**Core Shell Packages** (always installed):

- `gnome-shell` - Core desktop shell
- `gnome-control-center` - Settings application
- `gnome-backgrounds`, `gnome-bluetooth`, `gnome-color-manager`
- `adwaita-icon-theme`, `glib`, `gtk3`, `gnome-menus`
- `xdg-user-dirs`, `xdg-user-dirs-gtk`
- `gnome-tour`, `gnome-user-docs`

**Core Apps** (when `services.gnome.core-apps.enable = true`, default):

- **File Manager**: `nautilus`
- **Utilities**: `baobab`, `gnome-calculator`, `gnome-calendar`, `gnome-characters`, `gnome-clocks`, `gnome-console`, `gnome-contacts`, `gnome-font-viewer`, `gnome-logs`, `gnome-maps`, `gnome-music`, `gnome-system-monitor`, `gnome-weather`
- **Media**: `decibels`, `loupe`, `papers`, `showtime`, `snapshot`
- **Apps**: `epiphany`, `gnome-text-editor`, `gnome-connections`, `simple-scan`, `yelp`

**Core Developer Tools** (optional, `services.gnome.core-developer-tools.enable`):

- `dconf-editor`, `devhelp`, `d-spy`, `gnome-builder`, `sysprof`

**Games** (optional, `services.gnome.games.enable`):

- 19+ games like `gnome-chess`, `gnome-mines`, `gnome-sudoku`, etc.

### Recommended Module Organization

Create these modules in `system/shared/family/gnome/settings/desktop/`:

**1. `gnome-core.nix`** - Enable GNOME desktop environment:

```nix
{ config, lib, pkgs, ... }:
{
  services.xserver.desktopManager.gnome.enable = lib.mkDefault true;
  services.gnome.core-apps.enable = lib.mkDefault true;
}
```

**2. `gnome-optional.nix`** - Optional components:

```nix
{ config, lib, pkgs, ... }:
{
  services.gnome.core-developer-tools.enable = lib.mkDefault false;
  services.gnome.games.enable = lib.mkDefault false;
}
```

**3. `gnome-exclude.nix`** - Remove unwanted packages:

```nix
{ config, lib, pkgs, ... }:
{
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-user-docs
    epiphany  # Remove if using different browser
  ];
}
```

### Key Finding

**`nautilus` is automatically included** with `services.gnome.core-apps.enable = true`.

The current `system/shared/family/gnome/app/utility/nautilus.nix` should be:

- **Deleted** (redundant - nautilus installed by system)
- OR **Moved** to `settings/desktop/nautilus.nix` with system-level configuration only

Since nautilus is a core desktop component installed system-wide, it shouldn't be in user-level `app/utility/`.

______________________________________________________________________

## Q2: System vs User-Level Configuration with Family Integration

### Cross-Platform Family Architecture Clarification

**IMPORTANT**: The `gnome` and `linux` families in `system/shared/family/` are designed to work on **any Linux distribution**, not just NixOS:

- Works on: NixOS, Kali, Ubuntu, Arch, Fedora, etc.
- Platform-agnostic: Family modules use generic configuration
- Platform-specific: Platform libs (`nixos.nix`, `kali.nix`, etc.) translate to platform options
- When a host declares `family = ["gnome"]`, family **settings** become part of the system
- Family **apps** are discovered hierarchically but user-selected (not auto-installed)

### Family App Discovery WITHOUT default.nix

**Critical Requirement**: Family `app/` directories should behave like `system/{platform}/app/`:

- **NO `default.nix`** in `family/{name}/app/` directories
- Apps discovered hierarchically: system → families → shared
- Apps loaded **ONLY when user declares them** in `user.applications`
- Wildcard `applications = ["*"]` includes family apps if family in host
- Family apps become **eligible for user selection**, not automatically installed

### Family Settings Are Independent

**Important**: Each family's settings are auto-discovered independently:

- `gnome/settings/default.nix` does **NOT** import `linux/settings/default.nix`
- `linux/settings/default.nix` does **NOT** import other families
- To get both Linux + GNOME settings, host must declare: `family = ["linux", "gnome"]`
- Each family settings/ uses auto-discovery pattern (no cross-imports)

### Current Darwin Pattern (Working Example)

From `system/darwin/lib/darwin.nix` (lines 85-92):

```nix
# Auto-install family defaults
familyDefaults =
  if hostFamily != []
  then discovery.autoInstallFamilyDefaults hostFamily repoRoot
  else [];
```

The `autoInstallFamilyDefaults` function returns **both** `app/default.nix` and `settings/default.nix`:

```nix
autoInstallFamilyDefaults = families: basePath: let
  collectDefaults = family: let
    familyPath = familyBasePath + "/${family}";
    appDefault = familyPath + "/app/default.nix";
    settingsDefault = familyPath + "/settings/default.nix";
  in
    (lib.optional (builtins.pathExists appDefault) appDefault)
    ++ (lib.optional (builtins.pathExists settingsDefault) settingsDefault);
in
  lib.flatten (map collectDefaults families);
```

### Problem: NixOS Currently Missing Family Integration

Looking at `system/nixos/lib/nixos.nix`:

- ❌ No `hostData` loading
- ❌ No `hostFamily` extraction
- ❌ No `autoInstallFamilyDefaults` call
- TODO comment on line 47: "Implement nixos host loading like darwin"

### Solution: How Any Linux Platform Should Handle Families

**Architecture Principle** (System vs home-manager separation):

**System-Level** (family/gnome/settings/):

- Desktop environment installation
  - NixOS: `services.xserver.desktopManager.gnome.enable`
  - Other distros: Platform lib translates to appropriate mechanism
- Display manager configuration
  - NixOS: `services.xserver.displayManager.gdm`
  - Other distros: Platform-specific implementation
- System-wide services
- Configuration in `/etc` (NixOS) or distro-appropriate location
- Available to all users

**User-Level** (family/gnome/app/):

- User preferences (`dconf.settings`)
- GTK themes (`gtk.enable`, `gtk.theme`)
- Optional tools (`gnome-tweaks`, `dconf-editor`)
- Configuration in `~/.config`
- Per-user isolation
- **Cross-platform**: Works the same on all Linux distros via home-manager

### Required NixOS Implementation

Add to `system/nixos/lib/nixos.nix`:

```nix
mkNixosConfig = { user, host, system ? "x86_64-linux" }: let
  # Import discovery for family support
  discovery = import ../../shared/lib/discovery.nix { inherit lib; };
  repoRoot = ../../..;
  
  # Load host configuration as pure data
  hostDataPath = ../host/${host};
  hostData = import hostDataPath {};
  
  # Extract host fields
  hostName = hostData.name;
  hostFamily = hostData.family or [];
  
  # Validate families exist
  _ = assert (hostFamily != [] -> discovery.validateFamilyExists hostFamily repoRoot); null;
  
  # Auto-install family defaults (both app and settings)
  familyDefaults =
    if hostFamily != []
    then discovery.autoInstallFamilyDefaults hostFamily repoRoot
    else [];
in
  nixpkgs.lib.nixosSystem {
    modules = [
      # SYSTEM-LEVEL: Import family defaults here
      # Includes both settings/ (NixOS options) and app/ (home-manager options)
    ] ++ familyDefaults ++ [
      
      # Home Manager integration
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.users.${user} = {
          imports = [
            # USER-LEVEL: User config
            ../../../user/${user}
          ];
        };
      }
    ];
  };
```

**Critical Architectural Difference:**

| Platform | Where familyDefaults Imported | Reason |
|----------|------------------------------|---------|
| **Darwin** | Inside `home-manager.users.${user}` | macOS has no system-level settings (nix-darwin is user-level) |
| **NixOS** | At system modules root level | NixOS has true system-level configuration (`services.*` options) |

Since `familyDefaults` includes **both** `settings/default.nix` and `app/default.nix`:

- Settings modules use NixOS options (`services.xserver.*`) - work at system level
- App modules use home-manager options (`dconf.settings`, `gtk.*`) - work at system level too (delegated to home-manager)

**Single import at system level works for both!**

______________________________________________________________________

## Q3: Ctrl+Alt+Space Launcher Binding

### Correct dconf Schema Path

**Schema:** `org.gnome.shell.keybindings`\
**Key:** `toggle-overview`\
**Value:** `["<Ctrl><Alt>space"]`

Full dconf path: `/org/gnome/shell/keybindings/toggle-overview`

### Implementation in `gnome/settings/shortcuts.nix`:

```nix
{ config, lib, pkgs, ... }:
{
  # Global keyboard shortcuts for GNOME Shell
  dconf.settings = {
    "org/gnome/shell/keybindings" = {
      # Ctrl+Alt+Space to open Activities Overview (application launcher)
      toggle-overview = lib.mkDefault ["<Ctrl><Alt>space"];
    };
  };
}
```

### Key Distinction

- `org.gnome.desktop.wm.keybindings` - **Window manager** shortcuts (close, minimize, maximize, switch windows)
- `org.gnome.shell.keybindings` - **GNOME Shell** shortcuts (overview, screenshots, notifications)

The launcher/Activities Overview is a **Shell feature**, not a WM feature, hence `org.gnome.shell.keybindings`.

**Common Confusion**: The overview *looks* like a window manager feature, but it's actually part of GNOME Shell's user interface layer.

______________________________________________________________________

## Q4: GDM Wayland Configuration

### NixOS Options for GDM Wayland

**Basic Configuration:**

```nix
{ config, lib, pkgs, ... }:
{
  services.xserver = {
    enable = lib.mkDefault true;  # Still required for GDM (misnamed)
    displayManager.gdm = {
      enable = lib.mkDefault true;
      wayland = lib.mkDefault true;  # Enable Wayland session
    };
    desktopManager.gnome.enable = lib.mkDefault true;
  };
}
```

**Important Notes:**

1. `services.xserver.enable = true` is **still required** even for Wayland

   - GDM (GNOME Display Manager) needs it
   - The option is misnamed for historical reasons
   - NixOS doesn't have a separate `services.wayland` top-level

1. `wayland = true` is often the **default** in newer GNOME versions

1. Most Wayland environment variables are **set automatically**

**Optional Environment Variables:**

Usually not needed, but can help with specific apps:

```nix
environment.sessionVariables = {
  # Enable Wayland for Electron apps (Chrome, VSCode, etc.)
  NIXOS_OZONE_WL = lib.mkDefault "1";
  
  # Force Wayland for Qt apps (usually auto-detected)
  # QT_QPA_PLATFORM = "wayland";
};
```

**Session Verification:**

Users can verify Wayland session with:

```bash
echo $XDG_SESSION_TYPE  # Should output "wayland"
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type
```

### Recommended `wayland.nix` Module:

```nix
# GNOME Family: Wayland Configuration
# Purpose: Configure Wayland display server for GNOME desktop
# Dependencies: Requires services.xserver.desktopManager.gnome.enable
{ config, lib, pkgs, ... }:
{
  # GDM display manager with Wayland support
  services.xserver = {
    enable = lib.mkDefault true;  # Required for GDM (despite name)
    displayManager.gdm = {
      enable = lib.mkDefault true;
      wayland = lib.mkDefault true;
    };
  };
  
  # Optional: Enable Wayland support for Electron-based apps
  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";
}
```

**Alternative: Minimal Configuration**

If `gnome-core.nix` already enables GDM, `wayland.nix` can be even simpler:

```nix
{ config, lib, pkgs, ... }:
{
  # Enable Wayland session in GDM (assumes GDM already enabled)
  services.xserver.displayManager.gdm.wayland = lib.mkDefault true;
  
  # Wayland support for Electron apps
  environment.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";
}
```

______________________________________________________________________

## Summary & Decisions

### 0. Cross-Platform Family Architecture

**Families are platform-agnostic and cross-distro:**

- `system/shared/family/linux/` - Works on NixOS, Kali, Ubuntu, Arch, etc.
- `system/shared/family/gnome/` - Works on any Linux distro with GNOME
- Family modules use generic configuration (no platform-specific code)
- Platform libs translate to platform-specific options

**Family app/ has NO default.nix:**

- `family/{name}/app/` directories behave like `system/{platform}/app/`
- Apps discovered hierarchically (system → families → shared)
- Apps loaded ONLY when user declares them in `user.applications`
- Wildcard includes family apps if family in host
- Family apps are **eligible for selection**, not auto-installed

**Family settings are independent:**

- Each `family/{name}/settings/default.nix` uses auto-discovery only
- NO cross-family imports (gnome does NOT import linux)
- To get multiple families: host must declare `family = ["linux", "gnome"]`

**Action:** Delete `gnome/app/default.nix` and `linux/app/default.nix` if they exist

### 1. GNOME Packages Decision

**Use modular approach in `settings/desktop/`:**

- `gnome-core.nix` - Enable desktop environment and core apps
- `gnome-optional.nix` - Control optional components (dev tools, games)
- `gnome-exclude.nix` - Remove unwanted packages
- Keep modules platform-agnostic (NixOS-specific options used by platform lib)

**Action:** Delete `app/utility/nautilus.nix` (redundant with core-apps)

### 2. Family Integration Decision

**Any Linux platform needs family support:**

- Import `familyDefaults` at **system modules level** (not in home-manager)
- Reason: Linux systems have true system-level configuration
- Family settings use system options, family apps use user options
- Single import works for both because module system delegates appropriately
- NixOS first, other distros follow same pattern

**Action:** Implement family integration in `system/nixos/lib/nixos.nix` (reference implementation)

### 3. Launcher Binding Decision

**Use `org.gnome.shell.keybindings.toggle-overview`:**

- Schema: `org.gnome.shell.keybindings`
- Key: `toggle-overview`
- Value: `["<Ctrl><Alt>space"]`

**Action:** Create `shortcuts.nix` with shell keybindings

### 4. Wayland Configuration Decision

**Simple GDM Wayland configuration:**

- Enable `services.xserver.displayManager.gdm.wayland = true`
- Set `NIXOS_OZONE_WL=1` for Electron apps
- Keep `services.xserver.enable = true` (required despite name)

**Action:** Create `wayland.nix` with GDM Wayland configuration

______________________________________________________________________

## Sources

- [GNOME Desktop Manager Module - nixpkgs](https://github.com/NixOS/nixpkgs/blob/release-25.11/nixos/modules/services/desktop-managers/gnome.nix)
- [NixOS GNOME Wiki](https://wiki.nixos.org/wiki/GNOME)
- [System vs Home Manager Separation - NixOS Discourse](https://discourse.nixos.org/t/some-confusions-about-the-separation-of-home-manager-and-system-level/30041)
- [GNOME Shell Keybindings - GNOME Discourse](https://discourse.gnome.org/t/difference-between-org-gnome-desktop-wm-vs-shell-keybindings/16889)
- [Toggle Overview Keybinding - Ubuntu ADSys](https://documentation.ubuntu.com/adsys/stable/reference/policies/User%20Policies/Ubuntu/Desktop/Keyboard%20shortcuts/toggle-overview/)
- [Enable Wayland on GNOME - NixOS Discourse](https://discourse.nixos.org/t/enable-wayland-on-gnome-kde/39412)
- [Wayland - NixOS Wiki](https://nixos.wiki/wiki/Wayland)
- Existing codebase: `system/darwin/lib/darwin.nix`, `system/shared/lib/discovery.nix`
