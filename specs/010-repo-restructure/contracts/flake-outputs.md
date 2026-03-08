# Contract: Flake Output Schema

**Feature**: 010-repo-restructure\
**Date**: 2025-10-31\
**Purpose**: Define the structure of flake.nix outputs for the new directory layout

## Overview

The flake.nix exports structured outputs that define all valid configurations, provide validation data for tooling (justfile), and follow Nix flakes best practices.

## Output Schema

### Root Structure

```nix
{
  inputs = { /* ... */ };
  
  outputs = { self, nixpkgs, darwin, home-manager, agenix }: {
    # Validation data (for justfile and other tooling)
    validUsers = [ /* ... */ ];
    validProfiles = { /* ... */ };
    
    # macOS configurations (nix-darwin)
    darwinConfigurations = { /* ... */ };
    
    # NixOS configurations
    nixosConfigurations = { /* ... */ };
    
    # Home Manager standalone (for Kali, etc.)
    homeConfigurations = { /* ... */ };
    
    # Development shells (optional, for contributors)
    devShells = { /* ... */ };
  };
}
```

## Validation Outputs

### `validUsers`

List of all user names that have configurations in `user/` directory.

**Type**: `list of string`

**Purpose**: Enable justfile and other tools to validate user parameter

**Example**:

```nix
validUsers = [ "cdrokar" "cdrolet" "cdrixus" ];
```

**Requirements**:

- Each user must have `user/{username}/default.nix`
- Names must match directory names exactly
- Must be kept in sync manually (no auto-generation in v1)

### `validProfiles`

Nested attribute set mapping platform to list of valid profile names.

**Type**: `{ platform :: list of string }`

**Purpose**: Enable platform-specific profile validation

**Example**:

```nix
validProfiles = {
  darwin = [ "home" "work" ];
  linux = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ];
};
```

**Requirements**:

- Each profile must have `system/{platform}/profiles/{profile}/default.nix`
- Profile names must match directory names exactly
- Platform key must be "darwin" or "linux" (lowercase)

## Configuration Outputs

### `darwinConfigurations`

macOS system configurations using nix-darwin.

**Type**: `{ config-name :: darwin-configuration }`

**Naming Convention**: `{user}-{profile}`

**Purpose**: Define deployable macOS systems

**Example**:

```nix
darwinConfigurations = {
  cdrokar-home = darwin.lib.darwinSystem {
    system = "aarch64-darwin";  # or x86_64-darwin
    modules = [
      # System profile (apps + settings for this profile)
      ./system/darwin/profiles/home/default.nix
      
      # Home Manager integration
      home-manager.darwinModules.home-manager
      {
        home-manager.users.cdrokar = import ./user/cdrokar/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      
      # Agenix integration
      agenix.darwinModules.default
    ];
  };
  
  cdrolet-work = darwin.lib.darwinSystem {
    system = "aarch64-darwin";
    modules = [
      ./system/darwin/profiles/work/default.nix
      home-manager.darwinModules.home-manager
      {
        home-manager.users.cdrolet = import ./user/cdrolet/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      agenix.darwinModules.default
    ];
  };
};
```

**Requirements**:

- Name must match `{user}-{profile}` format
- User must exist in `validUsers`
- Profile must exist in `validProfiles.darwin`
- System must be "aarch64-darwin" or "x86_64-darwin"
- Must import user config from `user/{user}/default.nix`
- Must import profile config from `system/darwin/profiles/{profile}/default.nix`

### `nixosConfigurations`

NixOS system configurations.

**Type**: `{ config-name :: nixos-configuration }`

**Naming Convention**: `{user}-{profile}`

**Purpose**: Define deployable NixOS systems

**Example**:

```nix
nixosConfigurations = {
  cdrokar-gnome-desktop-1 = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      # System profile
      ./system/nixos/profiles/gnome-desktop-1/default.nix
      
      # Home Manager integration
      home-manager.nixosModules.home-manager
      {
        home-manager.users.cdrokar = import ./user/cdrokar/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      
      # Agenix integration
      agenix.nixosModules.default
    ];
  };
  
  cdrixus-server-1 = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./system/nixos/profiles/server-1/default.nix
      home-manager.nixosModules.home-manager
      {
        home-manager.users.cdrixus = import ./user/cdrixus/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      agenix.nixosModules.default
    ];
  };
};
```

**Requirements**:

- Name must match `{user}-{profile}` format
- User must exist in `validUsers`
- Profile must exist in `validProfiles.linux`
- System must be "x86_64-linux" or "aarch64-linux"
- Must import user config from `user/{user}/default.nix`
- Must import profile config from `system/nixos/profiles/{profile}/default.nix`

### `homeConfigurations`

Home Manager standalone configurations (for non-NixOS Linux like Kali).

**Type**: `{ config-name :: home-manager-configuration }`

**Naming Convention**: `{user}-{profile}`

**Purpose**: Define user environments for non-NixOS systems

**Example**:

```nix
homeConfigurations = {
  cdrixus-kali = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    modules = [
      ./user/cdrixus/default.nix
      # Kali-specific settings from shared/profiles/linux/
      ./system/shared/profiles/linux/app/pentest.nix
    ];
  };
};
```

**Requirements**:

- Used for Kali Linux and other non-NixOS distributions
- Only manages user environment (no system-level config)
- Must import user config from `user/{user}/default.nix`
- Can import linux family profiles from `system/shared/profiles/linux/`

## Helper Functions (Internal)

### `mkDarwinConfig`

Helper function to reduce boilerplate in darwinConfigurations.

**Signature**:

```nix
mkDarwinConfig :: string -> string -> darwin-configuration
mkDarwinConfig user profile
```

**Implementation**:

```nix
let
  mkDarwinConfig = user: profile: darwin.lib.darwinSystem {
    system = "aarch64-darwin";  # or make configurable
    modules = [
      ./system/darwin/profiles/${profile}/default.nix
      home-manager.darwinModules.home-manager
      {
        home-manager.users.${user} = import ./user/${user}/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      agenix.darwinModules.default
    ];
  };
in
{
  darwinConfigurations = {
    cdrokar-home = mkDarwinConfig "cdrokar" "home";
    cdrokar-work = mkDarwinConfig "cdrokar" "work";
    cdrolet-work = mkDarwinConfig "cdrolet" "work";
  };
}
```

### `mkNixosConfig`

Helper function to reduce boilerplate in nixosConfigurations.

**Signature**:

```nix
mkNixosConfig :: string -> string -> nixos-configuration
mkNixosConfig user profile
```

**Implementation**:

```nix
let
  mkNixosConfig = user: profile: nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";  # or make configurable
    modules = [
      ./system/nixos/profiles/${profile}/default.nix
      home-manager.nixosModules.home-manager
      {
        home-manager.users.${user} = import ./user/${user}/default.nix;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
      }
      agenix.nixosModules.default
    ];
  };
in
{
  nixosConfigurations = {
    cdrokar-gnome-desktop-1 = mkNixosConfig "cdrokar" "gnome-desktop-1";
    cdrixus-server-1 = mkNixosConfig "cdrixus" "server-1";
  };
}
```

## Development Outputs (Optional)

### `devShells`

Development shells for contributors working on the configuration.

**Type**: `{ system :: { shell-name :: derivation } }`

**Purpose**: Provide consistent development environment

**Example**:

```nix
devShells = {
  x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
    packages = with nixpkgs.legacyPackages.x86_64-linux; [
      alejandra  # Nix formatter
      nil        # Nix LSP
      just       # Command runner
      agenix     # Secret management
    ];
  };
  
  aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
    packages = with nixpkgs.legacyPackages.aarch64-darwin; [
      alejandra
      nil
      just
      agenix
    ];
  };
};
```

## Complete Example

```nix
{
  description = "Multi-user, multi-platform Nix configuration";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, darwin, home-manager, agenix }:
    let
      # Helper functions
      mkDarwinConfig = user: profile: darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./system/darwin/profiles/${profile}/default.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.users.${user} = import ./user/${user}/default.nix;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
          agenix.darwinModules.default
        ];
      };
      
      mkNixosConfig = user: profile: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/nixos/profiles/${profile}/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.users.${user} = import ./user/${user}/default.nix;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
          agenix.nixosModules.default
        ];
      };
    in
    {
      # Validation data
      validUsers = [ "cdrokar" "cdrolet" "cdrixus" ];
      validProfiles = {
        darwin = [ "home" "work" ];
        linux = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ];
      };
      
      # macOS configurations
      darwinConfigurations = {
        cdrokar-home = mkDarwinConfig "cdrokar" "home";
        cdrokar-work = mkDarwinConfig "cdrokar" "work";
        cdrolet-work = mkDarwinConfig "cdrolet" "work";
      };
      
      # NixOS configurations
      nixosConfigurations = {
        cdrokar-gnome-desktop-1 = mkNixosConfig "cdrokar" "gnome-desktop-1";
        cdrixus-kde-desktop-1 = mkNixosConfig "cdrixus" "kde-desktop-1";
        cdrixus-server-1 = mkNixosConfig "cdrixus" "server-1";
      };
      
      # Home Manager standalone (for Kali)
      homeConfigurations = {
        cdrixus-kali = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            ./user/cdrixus/default.nix
            ./system/shared/profiles/linux/app/pentest.nix
          ];
        };
      };
    };
}
```

## Validation Rules

1. **Consistency**: All users in `validUsers` must have at least one configuration
1. **Completeness**: All profiles in `validProfiles` must be used in at least one configuration
1. **Naming**: Configuration names must follow `{user}-{profile}` format
1. **Platform**: darwin configs only in `darwinConfigurations`, nixos only in `nixosConfigurations`
1. **Synchronization**: `validUsers` and `validProfiles` must be manually kept in sync with directory structure

## Evolution

**v1.0** (current): Manual list maintenance
**v1.1** (future): Auto-generate validUsers/validProfiles from directory scanning
**v2.0** (future): Support for multi-host configurations (e.g., `{user}-{host}-{profile}`)
