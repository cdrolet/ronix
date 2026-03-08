# Research: Repository Restructure - User/System Split

**Feature**: 010-repo-restructure\
**Date**: 2025-10-31\
**Purpose**: Resolve technical unknowns and establish best practices for implementation

## Research Questions

This document addresses the following unknowns from the Technical Context:

1. How to implement justfile validation against flake.nix outputs?
1. What's the best pattern for Home Manager bootstrap module (`user/shared/lib/home.nix`)?
1. How to implement cross-platform file association helper (`mkFileAssociation`)?
1. What's the migration strategy for sops-nix to agenix?
1. How to structure flake.nix outputs for the new directory layout?
1. Best practices for Nix module dependency declaration to prevent circular deps?
1. Shell alias conflict detection during build?

## 1. Justfile Validation Against Flake Outputs

### Decision

Implement justfile validation by reading flake.nix outputs using `nix eval` and validating user/profile parameters against those outputs before invoking build commands.

### Rationale

- **Fail fast**: Catch invalid parameters before starting expensive build process
- **Single source of truth**: Flake outputs define valid configurations, justfile queries them
- **No duplication**: Avoid hardcoding valid users/profiles in two places (flake + justfile)
- **User-friendly errors**: Provide clear error messages listing available options

### Implementation Pattern

```justfile
# Validate and install system configuration
install user profile:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Get valid users from flake
    valid_users=$(nix eval .#validUsers --json | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
    if ! echo "$valid_users" | grep -q "{{user}}"; then
        echo "Error: Invalid user '{{user}}'. Valid users: $valid_users"
        exit 1
    fi
    
    # Get valid profiles for platform
    platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    valid_profiles=$(nix eval .#validProfiles.${platform} --json | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')
    if ! echo "$valid_profiles" | grep -q "{{profile}}"; then
        echo "Error: Invalid profile '{{profile}}'. Valid profiles for $platform: $valid_profiles"
        exit 1
    fi
    
    # Platform-specific build command
    if [[ "$platform" == "darwin" ]]; then
        darwin-rebuild switch --flake .#{{user}}-{{profile}}
    elif [[ "$platform" == "linux" ]]; then
        nixos-rebuild switch --flake .#{{user}}-{{profile}}
    fi
```

### Flake Output Schema

```nix
# flake.nix outputs section
{
  # Validation data (not actual configurations)
  validUsers = [ "cdrokar" "cdrolet" "cdrixus" ];
  
  validProfiles = {
    darwin = [ "home" "work" ];
    linux = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ];
  };
  
  # Actual configurations
  darwinConfigurations = {
    cdrokar-home = /* ... */;
    cdrokar-work = /* ... */;
    cdrolet-work = /* ... */;
  };
  
  nixosConfigurations = {
    cdrokar-gnome-desktop-1 = /* ... */;
    /* ... */
  };
}
```

### Alternatives Considered

- **Directory scanning**: Rejected because it's fragile (depends on file system structure, misses flake output logic)
- **Hardcoded lists**: Rejected because it duplicates information from flake.nix
- **No validation**: Rejected because it leads to cryptic Nix errors deep in build process

## 2. Home Manager Bootstrap Module Pattern

### Decision

Create `user/shared/lib/home.nix` as a standard Home Manager module that provides options for user configuration and sets up Home Manager defaults declaratively.

### Rationale

- **Consistent initialization**: All users get same Home Manager setup
- **DRY principle**: User-specific values (name, email) defined once in user config
- **Type safety**: Use lib.mkOption with proper types
- **Platform detection**: Handle macOS vs Linux home directory differences

### Implementation Pattern

```nix
# user/shared/lib/home.nix
{ config, lib, pkgs, ... }:

{
  options.user = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "User's login name";
      example = "cdrokar";
    };
    
    email = lib.mkOption {
      type = lib.types.str;
      description = "User's email address";
      example = "cdrokar@example.com";
    };
    
    fullName = lib.mkOption {
      type = lib.types.str;
      description = "User's full name";
      example = "Charles Drokar";
    };
  };
  
  config = {
    # Home Manager state version (update cautiously)
    home.stateVersion = "24.05";
    
    # Basic user info
    home.username = config.user.name;
    home.homeDirectory = 
      if pkgs.stdenv.isDarwin 
      then "/Users/${config.user.name}"
      else "/home/${config.user.name}";
    
    # Enable home-manager self-management
    programs.home-manager.enable = true;
    
    # Common programs everyone gets
    programs.git = {
      userName = config.user.fullName;
      userEmail = config.user.email;
    };
  };
}
```

### Usage in User Config

```nix
# user/cdrokar/default.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ../shared/lib/home.nix
    ../../system/shared/app/dev/git.nix
    # ... other apps
  ];
  
  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
    fullName = "Charles Drokar";
  };
  
  # User-specific overrides
  programs.git.signing.key = "ABC123DEF456";
}
```

### Alternatives Considered

- **Inline in each user config**: Rejected due to duplication
- **Function that returns config**: Rejected because it's less idiomatic than modules
- **No abstraction**: Rejected because it leads to inconsistent Home Manager setups

## 3. Cross-Platform File Association Helper

### Decision

Implement `mkFileAssociation` helper in `system/shared/lib/file-associations.nix` that detects platform and generates appropriate activation script commands.

### Rationale

- **Platform abstraction**: Hide duti vs xdg-mime differences from app modules
- **Consistent interface**: App modules use same function regardless of platform
- **Idempotency**: Generates idempotent activation scripts
- **Error handling**: Validates inputs before generating commands

### Implementation Pattern

```nix
# system/shared/lib/file-associations.nix
{ pkgs, lib, ... }:

{
  # Associate file extension with application
  mkFileAssociation = { extension, appId, mimeType ? null }:
    let
      # Validate extension starts with dot
      ext = if lib.hasPrefix "." extension 
            then extension 
            else ".${extension}";
    in
    if pkgs.stdenv.isDarwin then
      # macOS: use duti
      ''
        # Check if duti is available
        if ! command -v ${pkgs.duti}/bin/duti &> /dev/null; then
          echo "Warning: duti not found, skipping file association for ${ext}"
        else
          ${pkgs.duti}/bin/duti -s ${lib.escapeShellArg appId} ${lib.escapeShellArg ext} all 2>/dev/null || true
        fi
      ''
    else
      # Linux: use xdg-mime
      let
        # Infer MIME type if not provided
        mime = if mimeType != null 
               then mimeType
               else "application/x-${lib.removePrefix "." ext}";
      in
      ''
        # Check if xdg-mime is available
        if ! command -v ${pkgs.xdg-utils}/bin/xdg-mime &> /dev/null; then
          echo "Warning: xdg-mime not found, skipping file association for ${ext}"
        else
          ${pkgs.xdg-utils}/bin/xdg-mime default ${lib.escapeShellArg appId}.desktop ${lib.escapeShellArg mime} 2>/dev/null || true
        fi
      '';
  
  # Associate multiple extensions with same app
  mkMultipleFileAssociations = { extensions, appId, mimeTypes ? {} }:
    lib.concatMapStringsSep "\n" 
      (ext: mkFileAssociation { 
        extension = ext; 
        inherit appId; 
        mimeType = mimeTypes.${ext} or null; 
      }) 
      extensions;
}
```

### Usage in App Module

```nix
# system/shared/app/dev/git.nix
{ config, lib, pkgs, ... }:

let
  fileAssoc = import ../../lib/file-associations.nix { inherit pkgs lib; };
in
{
  home.packages = [ pkgs.git ];
  
  programs.git = {
    enable = true;
    # ... git config
  };
  
  # Set file associations
  home.activation.gitFileAssociations = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${fileAssoc.mkFileAssociation {
      extension = ".git";
      appId = if pkgs.stdenv.isDarwin 
              then "com.github.GitUp.GitUp"
              else "git-cola";
      mimeType = "inode/directory";
    }}
  '';
}
```

### Alternatives Considered

- **Platform-specific modules**: Rejected because it duplicates app definitions
- **Inline platform checks**: Rejected because it clutters app modules
- **No abstraction**: Rejected because it leads to inconsistent file association code

## 4. Migration from sops-nix to agenix

### Decision

Use parallel approach: set up agenix infrastructure, migrate secrets incrementally, remove sops-nix last.

### Rationale

- **Risk reduction**: Both systems work during migration
- **Testing**: Validate agenix setup before removing sops-nix
- **Rollback**: Can revert to sops-nix if issues found
- **Incremental**: Migrate one secret at a time, verify each

### Migration Steps

1. **Install agenix** (Phase 4, Week 7)

   ```nix
   # flake.nix inputs
   inputs.agenix.url = "github:ryantm/agenix";
   inputs.agenix.inputs.nixpkgs.follows = "nixpkgs";
   ```

1. **Generate age keys** (per user + per system)

   ```bash
   # User key
   age-keygen -o ~/.age-key.txt

   # System key (darwin)
   sudo age-keygen -o /var/lib/age-key.txt
   ```

1. **Create secrets.nix** (centralized)

   ```nix
   # secrets/secrets.nix
   let
     cdrokar = "age1...public-key...";
     cdrolet = "age1...public-key...";
     darwinSystem = "age1...public-key...";
   in
   {
     "users/cdrokar/ssh-key.age".publicKeys = [ cdrokar ];
     "system/darwin/work-vpn.age".publicKeys = [ darwinSystem cdrokar cdrolet ];
   }
   ```

1. **Encrypt secrets**

   ```bash
   # Decrypt from sops
   sops -d secrets/work-vpn.yaml > /tmp/work-vpn.txt

   # Encrypt with agenix
   agenix -e secrets/system/darwin/work-vpn.age
   # (paste content from /tmp/work-vpn.txt)

   # Clean up
   rm /tmp/work-vpn.txt
   ```

1. **Update references**

   ```nix
   # OLD (sops-nix)
   sops.secrets.work-vpn = {
     sopsFile = ./secrets/work.yaml;
     path = "/run/secrets/work-vpn";
   };

   # NEW (agenix)
   age.secrets.work-vpn = {
     file = ../../secrets/system/darwin/work-vpn.age;
     path = "/run/agenix/work-vpn";
   };
   ```

1. **Test and validate**

   - Build configuration
   - Verify secret decryption
   - Test applications using secrets
   - Compare with sops-nix behavior

1. **Remove sops-nix** (after all secrets migrated)

   - Remove sops-nix from flake inputs
   - Delete old `secrets/` sops files
   - Update documentation

### Key Differences: sops-nix vs agenix

| Feature | sops-nix | agenix |
|---------|----------|--------|
| Encryption | age, GPG, AWS KMS | age only |
| Config | YAML with sops | Individual .age files |
| Key management | .sops.yaml | secrets.nix |
| File format | YAML (partial encryption) | Binary (full encryption) |
| Complexity | Higher (more options) | Lower (focused) |

### Why agenix?

- **Simpler**: Fewer moving parts, easier to understand
- **Nix-native**: Designed specifically for Nix/NixOS
- **Age-based**: Modern encryption, simple key management
- **File-per-secret**: Better granularity, clearer structure
- **Community preference**: Growing adoption in Nix community

## 5. Flake.nix Output Structure

### Decision

Structure flake outputs to support user+profile combinations with clear naming convention: `{user}-{profile}`.

### Rationale

- **Clarity**: Name immediately shows who + what
- **Flexibility**: Easy to add new users or profiles
- **Validation**: Can enumerate all valid combinations
- **Standard**: Follows nix-darwin and NixOS conventions

### Implementation Pattern

```nix
# flake.nix
{
  description = "Multi-user, multi-platform Nix configuration";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    home-manager.url = "github:nix-community/home-manager";
    agenix.url = "github:ryantm/agenix";
  };
  
  outputs = { self, nixpkgs, darwin, home-manager, agenix, ... }: 
    let
      # Validation lists
      users = [ "cdrokar" "cdrolet" "cdrixus" ];
      darwinProfiles = [ "home" "work" ];
      nixosProfiles = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ];
      
      # Helper to create user+profile config
      mkDarwinConfig = user: profile: darwin.lib.darwinSystem {
        system = "aarch64-darwin";  # or x86_64-darwin
        modules = [
          ./system/darwin/profiles/${profile}/default.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.users.${user} = import ./user/${user}/default.nix;
          }
        ];
      };
      
      mkNixosConfig = user: profile: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./system/nixos/profiles/${profile}/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.users.${user} = import ./user/${user}/default.nix;
          }
        ];
      };
    in
    {
      # Validation outputs
      validUsers = users;
      validProfiles = {
        darwin = darwinProfiles;
        linux = nixosProfiles;
      };
      
      # Darwin configurations
      darwinConfigurations = {
        cdrokar-home = mkDarwinConfig "cdrokar" "home";
        cdrokar-work = mkDarwinConfig "cdrokar" "work";
        cdrolet-work = mkDarwinConfig "cdrolet" "work";
      };
      
      # NixOS configurations
      nixosConfigurations = {
        cdrokar-gnome-desktop-1 = mkNixosConfig "cdrokar" "gnome-desktop-1";
        cdrixus-kde-desktop-1 = mkNixosConfig "cdrixus" "kde-desktop-1";
      };
    };
}
```

### Alternatives Considered

- **Flat output names**: Rejected because it's unclear (what's "main"? what's "work"?)
- **Nested structure**: Rejected because nix-darwin/nixos-rebuild don't support it well
- **Auto-generation**: Rejected for initial implementation (can add later for DRY)

## 6. Preventing Circular Dependencies in Modules

### Decision

Use explicit `imports` declarations at module top + build-time validation. For complex dependencies, split into base + enhanced modules.

### Rationale

- **Visibility**: Dependencies declared at top of file, easy to audit
- **Fail fast**: Nix infinite recursion errors catch circular deps at build time
- **Flexibility**: Base/enhanced split allows optional features without cycles
- **Documentation**: Explicit imports serve as documentation

### Pattern for Dependencies

```nix
# system/shared/app/dev/git.nix
{ config, lib, pkgs, ... }:

{
  # DEPENDENCIES: Declare at top
  imports = [
    ../tools/delta.nix  # Git uses delta for diffs
  ];
  
  home.packages = [ pkgs.git ];
  programs.git = {
    enable = true;
    delta.enable = true;  # From delta.nix
  };
}
```

### Pattern for Breaking Cycles (base + enhanced)

```nix
# system/shared/app/shell/zsh-base.nix
{ config, lib, pkgs, ... }:

{
  # NO IMPORTS - this is the base
  
  programs.zsh = {
    enable = true;
    # Basic config only
  };
}

# system/shared/app/shell/zsh-enhanced.nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./zsh-base.nix
    ../tools/fzf.nix       # Enhanced features
    ../tools/starship.nix
  ];
  
  # Additional zsh configuration using fzf and starship
}
```

### Build-Time Detection

Nix automatically detects circular dependencies:

```
error: infinite recursion encountered
  at /path/to/app-a.nix:3:5:
    imports = [ ./app-b.nix ];
  at /path/to/app-b.nix:3:5:
    imports = [ ./app-a.nix ];
```

### Prevention Checklist

- [ ] Keep dependency graph acyclic (A → B → C, not A → B → A)
- [ ] Use base/enhanced split for complex cases
- [ ] Document why each import is needed
- [ ] Test each module in isolation (import alone should work)
- [ ] Review imports during code review

## 7. Shell Alias Conflict Detection

### Decision

Implement namespacing convention (app-prefixed aliases) + optional build-time validation script.

### Rationale

- **Prevention**: Namespacing makes conflicts rare
- **Clarity**: `gst` (git status) is more obvious than `st`
- **Detection**: Build script can check for duplicates if needed
- **User control**: User can override in their config if desired

### Namespacing Convention

```nix
# system/shared/app/dev/git.nix
programs.zsh.shellAliases = {
  # Git prefix
  g = "git";
  gst = "git status";
  gco = "git checkout";
  gcm = "git commit -m";
  # NOT: st, co, cm (too generic)
};

# system/shared/app/tools/ripgrep.nix
programs.zsh.shellAliases = {
  # Ripgrep prefix
  rg = "ripgrep";
  rgi = "ripgrep --ignore-case";
  rgf = "ripgrep --files-with-matches";
  # NOT: g, grep (conflicts with git)
};
```

### Build-Time Validation (Optional)

```nix
# system/shared/lib/validate-aliases.nix
{ config, lib, ... }:

let
  # Collect all aliases from all modules
  allAliases = config.programs.zsh.shellAliases or {};
  
  # Find duplicates
  aliasList = lib.attrNames allAliases;
  duplicates = lib.filter (a: (lib.count (x: x == a) aliasList) > 1) aliasList;
in
{
  # Assertion: no duplicate aliases
  assertions = [{
    assertion = duplicates == [];
    message = ''
      Duplicate shell aliases found: ${lib.concatStringsSep ", " duplicates}
      This likely means multiple apps are defining the same alias.
      Use namespaced aliases (e.g., 'gst' instead of 'st').
    '';
  }];
}
```

### Alternatives Considered

- **No namespacing**: Rejected because it leads to frequent conflicts
- **Automatic prefixing**: Rejected because it makes aliases less intuitive
- **Runtime detection**: Rejected because it's too late (user already built system)

## Summary of Decisions

| Question | Decision | Key Benefit |
|----------|----------|-------------|
| Justfile validation | Query flake outputs via `nix eval` | Fail fast with clear errors |
| Home Manager bootstrap | Standard module in `user/shared/lib/home.nix` | DRY + type safety |
| File associations | Helper function with platform detection | Consistent cross-platform interface |
| sops-nix → agenix | Parallel migration, incremental switchover | Low risk, testable |
| Flake outputs | `{user}-{profile}` naming convention | Clear, flexible, standard |
| Circular deps | Explicit imports + base/enhanced split | Visible dependencies, fail fast |
| Alias conflicts | Namespacing convention + optional validation | Prevention + detection |

All decisions prioritize:

- **Simplicity**: Easy to understand and maintain
- **Safety**: Catch errors early in build process
- **Flexibility**: Support current needs, allow future growth
- **Standards**: Follow Nix community conventions where applicable
