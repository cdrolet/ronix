# GNOME Family Applications

## Overview

This directory contains optional GNOME applications that users can install individually. Apps are user-selected (not auto-installed) and discovered hierarchically when the host has `family = ["gnome"]`.

## Directory Structure

```
gnome/app/
└── utility/
    ├── gnome-tweaks.nix    # GNOME customization tool
    └── dconf-editor.nix    # Low-level configuration editor
```

## How Apps Work

### User Selection Required

Apps in this directory are **NOT** automatically installed. Users must explicitly select them:

```nix
# user/{username}/default.nix
{
  user = {
    applications = [
      "gnome-tweaks"    # Select specific app
      "dconf-editor"
      # OR use wildcard:
      # "*"  # Includes all available apps (if family in host)
    ];
  };
}
```

### Hierarchical Discovery

Apps are discovered via hierarchical search (no default.nix needed):

1. Search order: `system/{platform}/app` → `family/{name}/app` → `shared/app`
1. First match wins
1. Available only if host has `family = ["gnome"]`

### App Module Pattern

Each app module follows this structure:

```nix
# gnome/app/utility/example-app.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install package
  home.packages = [ pkgs.example-app ];
  
  # Optional: Configure the app
  programs.example-app = {
    enable = lib.mkDefault true;
    # Additional config...
  };
}
```

## GNOME Shell Extensions

Apps that need GNOME Shell extensions should declare them in their own module. **Do NOT create a centralized systray.nix or extensions.nix file.**

### Extension Pattern

Each app declares its own extensions:

```nix
# Example: App with GNOME Shell extension
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Install the app
  home.packages = [ pkgs.my-app ];
  
  # Declare GNOME Shell extensions needed by this app
  home.packages = with pkgs.gnomeExtensions; [
    appindicator  # System tray support for this app
    # Add other extensions this app needs
  ];
  
  # Enable extensions via dconf
  dconf.settings = {
    "org/gnome/shell" = {
      enabled-extensions = lib.mkDefault [
        "appindicator@rgcjonas.gmail.com"
      ];
    };
  };
}
```

### Why Per-App Extensions?

**Good reasons:**

- Clear dependency relationship (app → extension)
- Extensions only installed when app is selected
- Easy to remove app + extensions together
- No centralized configuration to maintain

**Anti-pattern:**

```nix
# ❌ DON'T create gnome/settings/systray.nix
# ❌ DON'T centralize extensions for all apps
# This creates hidden dependencies and makes it unclear
# which extensions are needed by which apps
```

## Adding New Apps

To add a new GNOME app:

1. **Create app module:**

   ```bash
   $EDITOR system/shared/family/gnome/app/utility/my-app.nix
   ```

1. **Follow the pattern:**

   ```nix
   # Header comment with purpose
   # Dependencies listed
   # Usage instructions
   {
     config,
     lib,
     pkgs,
     ...
   }: {
     home.packages = [ pkgs.my-app ];
     # Configuration...
   }
   ```

1. **Keep it small:**

   - Modules must be \<200 lines (constitutional requirement)
   - Use `lib.mkDefault` for all options (user-overridable)
   - Include header documentation

1. **No manual imports needed:**

   - Apps are discovered automatically
   - Just create the .nix file and it's available

## Testing App Discovery

Verify your app is discoverable:

```bash
# Check if app appears in discovery
nix eval .#darwinConfigurations.user-host.config.home-manager.users.user.home.packages \
  | jq 'map(select(.name | contains("my-app")))'

# Should show your app if:
# - Host has family = ["gnome"]
# - User has applications = ["my-app"] or ["*"]
```

## Constitutional Requirements

All app modules must follow:

1. **Size limit:** \<200 lines per file
1. **Overridability:** Use `lib.mkDefault` for all options
1. **Documentation:** Header comments explaining purpose, dependencies, usage
1. **Independence:** Apps should not depend on other apps in this directory
1. **Platform-agnostic:** Use cross-platform home-manager options when possible

## References

- GNOME Shell Extensions: https://extensions.gnome.org/
- Home Manager Options: https://nix-community.github.io/home-manager/options.html
- dconf Settings: https://help.gnome.org/admin/system-admin-guide/stable/dconf.html
