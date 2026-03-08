# Contract: Justfile Installation API

**Feature**: 010-repo-restructure\
**Date**: 2025-10-31\
**Purpose**: Define the command-line interface for system installation

## Overview

The justfile provides a user-friendly command interface for installing system configurations. It validates inputs, provides clear error messages, and invokes the appropriate platform-specific build commands.

## Commands

### `just install <user> <profile>`

Install or rebuild system configuration for a specific user and profile combination.

**Parameters**:

- `user` (required): Username from `validUsers` list

  - Allowed values: "cdrokar", "cdrolet", "cdrixus"
  - Corresponds to directory in `user/{username}/`

- `profile` (required): Profile name from `validProfiles.{platform}` list

  - Darwin profiles: "home", "work"
  - Linux profiles: "gnome-desktop-1", "kde-desktop-1", "server-1"
  - Corresponds to directory in `system/{platform}/profiles/{profile}/`

**Behavior**:

1. Validate `user` against `nix eval .#validUsers`

   - If invalid: Print error with valid options, exit 1

1. Detect platform via `uname -s | tr '[:upper:]' '[:lower:]'`

   - darwin → check `validProfiles.darwin`
   - linux → check `validProfiles.linux`

1. Validate `profile` against platform-specific list

   - If invalid: Print error with valid options for current platform, exit 1

1. Invoke platform-specific rebuild command:

   - Darwin: `darwin-rebuild switch --flake .#{user}-{profile}`
   - Linux (NixOS): `nixos-rebuild switch --flake .#{user}-{profile}`
   - Linux (non-NixOS): `home-manager switch --flake .#{user}-{profile}`

**Examples**:

```bash
# Install cdrokar's home profile on macOS
just install cdrokar home

# Install cdrolet's work profile on macOS
just install cdrolet work

# Install cdrixus's GNOME desktop profile on NixOS
just install cdrixus gnome-desktop-1
```

**Success Output**:

```
✓ User 'cdrokar' is valid
✓ Profile 'home' is valid for darwin
Building configuration: cdrokar-home
[darwin-rebuild output...]
```

**Error Output** (invalid user):

```
Error: Invalid user 'invalid'
Valid users: cdrokar, cdrolet, cdrixus
```

**Error Output** (invalid profile):

```
Error: Invalid profile 'invalid' for platform 'darwin'
Valid profiles for darwin: home, work
```

**Exit Codes**:

- 0: Success
- 1: Invalid parameter (user or profile)
- > 1: Build failure (from darwin-rebuild/nixos-rebuild)

### `just list-users`

List all valid users defined in the repository.

**Parameters**: None

**Behavior**:

1. Query `nix eval .#validUsers --json`
1. Parse JSON and print one user per line

**Example Output**:

```
Available users:
  cdrokar
  cdrolet
  cdrixus
```

**Exit Codes**:

- 0: Success
- 1: Flake evaluation error

### `just list-profiles [platform]`

List all valid profiles for the current or specified platform.

**Parameters**:

- `platform` (optional): Override platform detection
  - Allowed values: "darwin", "linux"
  - Default: Auto-detected via `uname -s`

**Behavior**:

1. Determine platform (parameter or auto-detect)
1. Query `nix eval .#validProfiles.{platform} --json`
1. Parse JSON and print one profile per line

**Example Output** (darwin):

```
Available profiles for darwin:
  home
  work
```

**Example Output** (linux):

```
Available profiles for linux:
  gnome-desktop-1
  kde-desktop-1
  server-1
```

**Exit Codes**:

- 0: Success
- 1: Invalid platform or flake evaluation error

### `just check`

Validate flake syntax and build configurations without installing.

**Parameters**: None

**Behavior**:

1. Run `nix flake check`
1. Optionally run `nix flake show` to display outputs

**Example Output**:

```
Running flake checks...
✓ All checks passed

Available configurations:
  darwinConfigurations:
    ├─ cdrokar-home
    ├─ cdrokar-work
    └─ cdrolet-work
  nixosConfigurations:
    ├─ cdrokar-gnome-desktop-1
    └─ cdrixus-kde-desktop-1
```

**Exit Codes**:

- 0: All checks passed
- 1: Flake check failed

### `just update`

Update flake inputs and regenerate flake.lock.

**Parameters**: None

**Behavior**:

1. Run `nix flake update`
1. Display summary of updated inputs

**Example Output**:

```
Updating flake inputs...
Updated inputs:
  nixpkgs: a1b2c3d → e4f5g6h
  darwin: 1234567 → 8901234
  home-manager: abc123d → def456g
```

**Exit Codes**:

- 0: Success
- 1: Update failed

## Implementation

### Justfile Template

```justfile
# nix-config justfile
# Command runner for system installation and management

# Default recipe: show available commands
default:
    @just --list

# Install system configuration for user and profile
install user profile:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Validate user
    valid_users=$(nix eval .#validUsers --json | jq -r '.[]')
    if ! echo "$valid_users" | grep -q "^{{user}}$"; then
        echo "Error: Invalid user '{{user}}'"
        echo "Valid users: $(echo $valid_users | tr '\n' ', ' | sed 's/,$//')"
        exit 1
    fi
    echo "✓ User '{{user}}' is valid"
    
    # Detect platform
    platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # Validate profile for platform
    valid_profiles=$(nix eval .#validProfiles.${platform} --json | jq -r '.[]')
    if ! echo "$valid_profiles" | grep -q "^{{profile}}$"; then
        echo "Error: Invalid profile '{{profile}}' for platform '$platform'"
        echo "Valid profiles for $platform: $(echo $valid_profiles | tr '\n' ', ' | sed 's/,$//')"
        exit 1
    fi
    echo "✓ Profile '{{profile}}' is valid for $platform"
    
    # Build configuration name
    config="{{user}}-{{profile}}"
    echo "Building configuration: $config"
    
    # Platform-specific rebuild
    if [[ "$platform" == "darwin" ]]; then
        darwin-rebuild switch --flake .#$config
    elif [[ -f /etc/NIXOS ]]; then
        sudo nixos-rebuild switch --flake .#$config
    else
        # Non-NixOS Linux (e.g., Kali)
        home-manager switch --flake .#$config
    fi

# List all valid users
list-users:
    #!/usr/bin/env bash
    echo "Available users:"
    nix eval .#validUsers --json | jq -r '.[]' | sed 's/^/  /'

# List valid profiles for current or specified platform
list-profiles platform="":
    #!/usr/bin/env bash
    if [ -z "{{platform}}" ]; then
        plat=$(uname -s | tr '[:upper:]' '[:lower:]')
    else
        plat="{{platform}}"
    fi
    echo "Available profiles for $plat:"
    nix eval .#validProfiles.$plat --json | jq -r '.[]' | sed 's/^/  /'

# Validate flake and show configurations
check:
    @echo "Running flake checks..."
    nix flake check
    @echo "✓ All checks passed"
    @echo ""
    @echo "Available configurations:"
    nix flake show

# Update flake inputs
update:
    @echo "Updating flake inputs..."
    nix flake update
    @echo "Updated inputs:"
    @git diff flake.lock | grep -A1 "locked" || echo "No changes"

# Format Nix files with alejandra
format:
    alejandra .

# Build without installing (for testing)
build user profile:
    #!/usr/bin/env bash
    platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    config="{{user}}-{{profile}}"
    if [[ "$platform" == "darwin" ]]; then
        darwin-rebuild build --flake .#$config
    else
        nixos-rebuild build --flake .#$config
    fi
```

## Validation Requirements

### Input Validation

1. **User Parameter**:

   - Must match regex: `^[a-z][a-z0-9]*$`
   - Must exist in `nix eval .#validUsers`
   - Must have corresponding directory: `user/{user}/`

1. **Profile Parameter**:

   - Must match regex: `^[a-z][a-z0-9-]*[a-z0-9]$`
   - Must exist in `nix eval .#validProfiles.{platform}`
   - Must have corresponding directory: `system/{platform}/profiles/{profile}/`

1. **Platform Detection**:

   - `uname -s` output normalized to lowercase
   - Supported: "darwin", "linux"
   - Others: Error with unsupported platform message

### Error Handling

1. **Missing flake.nix**: Suggest running from repository root
1. **Nix not installed**: Suggest installation instructions
1. **Permission denied**: Suggest sudo for NixOS rebuild
1. **Build failure**: Show build log path, suggest `just check`

## Evolution and Versioning

This contract represents the initial (v1.0) justfile API. Future additions may include:

**Potential v1.1 additions**:

- `just rollback` - Revert to previous generation
- `just diff` - Show changes between current and pending
- `just gc` - Garbage collect old generations

**Potential v2.0 changes** (breaking):

- Support for multiple hosts per user
- Remote deployment via SSH
- Multi-user batch installation

Any breaking changes require:

1. Major version bump (v1.x → v2.0)
1. Deprecation notice (minimum 1 release)
1. Migration guide in docs/
