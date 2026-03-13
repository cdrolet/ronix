# ronix

declarative framework for system configuration using Nix flakes.

## Overview

This repository contains a complete declarative configuration for macOS (via nix-darwin) using a user/system split architecture. It manages system settings, user environments, applications, and dotfiles using a single source of truth with excellent modularity and multi-user support.

## Features

- 🍎 **macOS Support**: Full system configuration via nix-darwin
- 🐧 **NixOS Ready**: Platform-agnostic design supports NixOS
- 👥 **Multi-User**: Independent user configurations (cdrokar, cdrolet, cdrixus)
- 🏠 **Host-Based**: Pure data host configurations for each machine
- 🌐 **Cross-Platform Families**: Share configs across platforms (linux, gnome, server)
- 📦 **App-Centric**: One file per app, independently importable
- 🔐 **Secrets Management**: Per-user age encryption with agenix
- 🚀 **Binary Cache**: Automatic Cachix integration for faster builds
- 🔄 **Rollback Capability**: Easy rollback to previous configurations
- 🏗️ **Constitutional Governance**: v2.1.0 with user/host/family architecture
- ⚡ **Platform-Agnostic**: Only loads configs for platforms you use

## Architecture

### Platform-Agnostic Design

The flake uses a **platform-agnostic orchestration layer**:

- Each platform (darwin, nixos) is completely self-contained
- Platform libs export ALL outputs for that platform
- flake.nix only loads platforms that exist
- No darwin code loaded if you only use NixOS (and vice versa)
- Perfect separation of concerns

### User/Host/Family Architecture

The configuration uses a **user/host/family architecture** where:

- **Users** (`user/`) select which apps they want (pure data)
- **Hosts** (`system/{name}/host/`) define machine-specific settings (pure data)
- **Families** (`system/shared/family/`) provide cross-platform shared configs
- **Platforms** (`system/{darwin,nixos}/`) are self-contained
- **Hierarchical Discovery**: Apps/settings resolved via platform → families → shared

```
user/           # User configurations (pure data)
  cdrokar/      # Personal user
  cdrolet/      # Work user
  cdrixus/      # Security-focused user
  shared/lib/   # User helper libraries

system/         # System configurations
  darwin/       # macOS-specific (self-contained platform)
    host/       # Host configurations (pure data, formerly profiles)
      home-macmini-m4/
      work/
    app/        # Darwin apps (aerospace, borders)
    settings/   # System defaults (dock, finder, keyboard, etc.)
    lib/        # Platform libraries (darwin.nix exports all darwin outputs)
  nixos/        # NixOS-specific (self-contained platform)
    host/       # NixOS host configurations
    app/        # NixOS apps
    settings/   # NixOS settings
    lib/        # Platform libraries (nixos.nix exports all nixos outputs)
  shared/       # Cross-platform
    family/     # Cross-platform families (linux, gnome, server)
      linux/    # Shared by nixos, kali, ubuntu
      gnome/    # GNOME desktop configs
    app/        # Shared apps (git, zsh, helix, etc.)
      dev/      # Development tools
      shell/    # Shell tools
      editor/   # Editors
      browser/  # Browsers
    settings/   # Shared system settings
    lib/        # Shared helper libraries (including discovery system)

secrets/        # Encrypted secrets (agenix)
  users/        # User-specific secrets
  system/       # System-specific secrets
```

## Quick Start

### Installation

Use the `just` command interface:

```bash
# Install for a specific user and host
just install <user> <host>

# Examples:
just install cdrokar home-macmini-m4  # Personal home setup
just install cdrolet work             # Work setup
just install cdrixus home-macmini-m4  # Security-focused setup

# List available users and hosts
just list-users
just list-hosts  # (formerly list-profiles)
```

### Common Operations

```bash
# Update all packages
just update

# Check configuration
just check

# Build without applying
just build <user> <host>

# Build and push to Cachix (if configured)
just build-and-push <user> <host>

# Apply configuration changes
just install <user> <host>

# See all available commands
just --list
```

### Cachix Binary Cache

All users automatically benefit from faster builds using Cachix:

```bash
# Automatic - no configuration needed!
just build <user> <host>  # Downloads from cache automatically
```

**For developers** who want to push builds to the cache:

```bash
# 1. Get token from https://app.cachix.org/personal-auth-tokens
# 2. Store token
just secrets-set <user> cachix.authToken "your-token"

# 3. Add to user config (user/<user>/default.nix):
#    cachix = { authToken = "<secret>"; };

# 4. Build and push
just build-and-push <user> <host>
```

See [Cachix User Guide](./specs/034-cachix-integration/USER-GUIDE.md) for complete documentation.

## Available Configurations

### Users

- **cdrokar**: Personal development user (full app suite)
- **cdrolet**: Work-focused user (professional tools)
- **cdrixus**: Security testing user (pentest tools)

### Profiles

#### Darwin Profiles

- **home-macmini-m4**: Home Mac Mini M4 setup (unrestricted)
- **work**: Professional work environment (restricted)

## Adding New Content

### Adding a New App

1. Create app module: `system/shared/app/<category>/<app>.nix`
1. Import in user config: `user/<username>/default.nix`

Example app module structure:

```nix
{ config, pkgs, lib, ... }:

{
  # Package installation
  home.packages = [ pkgs.myapp ];
  
  # Configuration
  programs.myapp = {
    enable = true;
    settings = { ... };
  };
  
  # Shell aliases (namespaced)
  home.shellAliases = {
    myapp-start = "myapp run";
  };
}
```

### Adding a New User

1. Create directory: `user/<username>/`
1. Create `user/<username>/default.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../shared/lib/home-manager.nix
    ../../system/shared/app/dev/git.nix
    # ... other apps
  ];

  user.name = "username";
  user.email = "user@example.com";
  user.fullName = "Full Name";
}
```

3. That's it! The user is **automatically discovered** - no flake.nix edits needed.
1. Verify with: `just list-users`

### Adding a New Profile

1. Create directory: `system/darwin/profiles/<profile-name>/`
1. Create `system/darwin/profiles/<profile-name>/default.nix` with:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../../../shared/lib/host.nix  # Host configuration module
    ../../settings/default.nix    # Darwin system settings
  ];

  # Host identification (standardized via host module)
  host = {
    name = "hostname";           # Hostname identifier (e.g., "home-macmini")
    display = "Display Name";    # Human-readable name (e.g., "Home Mac Mini")
    platform = "aarch64-darwin"; # Target platform (or "x86_64-darwin")
  };
  
  # Profile-specific overrides
  # system.defaults.dock.autohide = lib.mkForce true;
}
```

3. That's it! The profile is **automatically discovered** - no flake.nix edits needed.
1. Verify with: `just list-profiles darwin`

**Note**: `system.stateVersion` is centralized in `system/darwin/lib/darwin.nix` (currently set to 5). Profiles can override if needed, but this is rarely necessary.

### Adding a New System Setting

Settings use **auto-discovery** - just create the file, no manual imports needed!

1. Create setting module: `system/darwin/settings/<topic>.nix`
   - Or in subdirectory: `system/darwin/settings/<category>/<topic>.nix`
1. That's it! The setting is **automatically imported** via `system/darwin/settings/default.nix`

**How it works**:

- `settings/default.nix` recursively scans for all `.nix` files (excluding itself)
- New files are automatically discovered and imported
- To disable a setting: move it outside the directory or rename without `.nix` extension
- Pattern can be reused in other `default.nix` files (e.g., app directories)

**Example setting module structure**:

```nix
{ config, lib, pkgs, ... }:

{
  # Declarative preferences via nix-darwin
  system.defaults.NSGlobalDomain = {
    AppleShowScrollBars = "Always";
  };
  
  # Imperative setup via activation scripts (when needed)
  system.activationScripts.mySetup = {
    text = ''
      echo "Running custom setup..."
      # ... idempotent operations
    '';
  };
}
```

### How Configurations Are Generated

**Automatic Cartesian Product**: The system automatically generates ALL valid user-profile combinations.

- 3 users × 2 darwin profiles = 6 configurations automatically created
- Add a new user → all profiles instantly available for that user
- Add a new profile → all users instantly get that profile
- No manual configuration list maintenance required

**Example**: With users `[cdrokar, cdrolet, cdrixus]` and profiles `[home-macmini-m4, work]`, you automatically get:

```
cdrokar-home-macmini-m4
cdrokar-work
cdrolet-home-macmini-m4
cdrolet-work
cdrixus-home-macmini-m4
cdrixus-work
```

**Performance**: Generating combinations is instant (\<0.1s for dozens of configs). Only the configuration you install is actually built.

**Optional Filtering**: If certain user-profile combinations don't make sense, you can add validation rules in `system/darwin/lib/darwin.nix` (see comments in the file).

## Documentation

- [Constitution](.specify/memory/constitution.md) v2.0.0 - Governance and architectural standards
- [Feature 010 Spec](specs/010-repo-restructure/spec.md) - User/system split architecture
- [Implementation Plan](specs/010-repo-restructure/plan.md) - Technical details
- [Task Breakdown](specs/010-repo-restructure/tasks.md) - Implementation tasks

## Constitutional Governance

This configuration is governed by Constitutional Framework v2.0.0, which establishes:

- ✅ User/System Split Architecture
- ✅ App-Centric Organization (\<200 lines per module)
- ✅ Hierarchical Configuration (specific overrides general)
- ✅ Platform Abstraction
- ✅ Multi-User Isolation
- ✅ Secrets Management via agenix

See [Constitution](.specify/memory/constitution.md) for complete governance details.

## Migration Status

**Current Version**: 2.0.0 (User/System Split Architecture)

**Completed Phases**:

- ✅ Phase 0: Constitution update and planning
- ✅ Phase 1: Foundation with 3 reference apps (git, zsh, starship)
- ✅ Phase 2: Core apps migration (9 apps total)
- ✅ Phase 3: Platform-specific settings & apps
- ✅ Phase 4: Multiple users (cdrokar, cdrolet, cdrixus)
- ✅ Phase 5: Old structure cleanup

**Future Work**:

- NixOS configurations with new structure
- Home Manager standalone configs
- Nix-on-Droid configurations
- Secrets migration to agenix

## Contributing

This is a personal configuration repository, but feel free to use it as a reference or template for your own setup.

## License

MIT

## Acknowledgments

- [nix-darwin](https://github.com/LnL7/nix-darwin) - macOS system management
- [Home Manager](https://github.com/nix-community/home-manager) - User environment management
- [agenix](https://github.com/ryantm/agenix) - Age-based secrets management
- Nix community for inspiration and patterns
