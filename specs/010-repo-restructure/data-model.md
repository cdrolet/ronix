# Data Model: Repository Restructure - User/System Split

**Feature**: 010-repo-restructure\
**Date**: 2025-10-31\
**Purpose**: Define entities, relationships, and state for the new directory structure

## Overview

This feature reorganizes the Nix configuration repository. The "data model" consists of configuration entities (not database records) represented as Nix modules with explicit relationships through imports and references.

## Core Entities

### 1. User

Represents a user persona with independent application selections and personal settings.

**Location**: `user/{username}/default.nix`

**Attributes**:

- `username` (string, required): Login name (e.g., "cdrokar")
- `email` (string, required): Email address for git, etc.
- `fullName` (string, required): Display name
- `appImports` (list of module paths): Applications selected by this user
- `personalSettings` (attribute set): User-specific overrides

**Relationships**:

- Has many: App Module (via imports)
- References: User Shared Lib (home.nix bootstrap)
- Deployed to: System Profile (many-to-many)

**Validation Rules**:

- Username must match directory name
- Must import `user/shared/lib/home.nix`
- Email must be valid format
- Cannot import platform-incompatible apps (validated at build)

**Example**:

```nix
# user/cdrokar/default.nix
{
  imports = [
    ../shared/lib/home.nix
    ../../system/shared/app/dev/git.nix
    ../../system/darwin/app/aerospace.nix
  ];
  
  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
    fullName = "Charles Drokar";
  };
}
```

### 2. System Profile

Represents a deployable system configuration combining apps and settings for a specific platform and context.

**Location**: `system/{platform}/profiles/{context}/default.nix` OR `system/shared/profiles/{family}/`

**Attributes**:

- `profileType` (enum: base|complete|mixin, required): Profile classification via `_profileType` metadata
- `platform` (enum: shared|darwin|nixos|kali): Target platform
- `context` (string, optional): Use case (home, work, gnome-desktop-1, etc.)
- `imports` (list of module paths): Apps, settings, libs, and other profiles
- `settings` (attribute set): Profile-specific configuration overrides

**Relationships**:

- Has many: App Module (via imports)
- Has many: Settings Module (via imports)
- References: Helper Libraries (via imports)
- Can import: Other profiles (mixin composition)
- Used by: User (many-to-many via flake configurations)

**Validation Rules**:

- Must declare `_profileType` metadata
- Base profiles: settings only, no apps
- Complete profiles: explicit app list required
- Mixin profiles: subset of apps for composition
- Platform compatibility enforced via flake.nix

**Example**:

```nix
# system/darwin/profiles/home/default.nix
{
  _profileType = "complete";
  
  imports = [
    ../../settings/default.nix
    ../../../shared/app/shell/zsh.nix
    ../../../shared/app/editor/helix.nix
    ../../app/aerospace.nix
  ];
  
  # Profile-specific overrides
  system.defaults.dock.autohide = true;
}
```

### 3. App Module

Represents a self-contained application configuration bundling package, config, aliases, and file associations.

**Location**:

- `system/shared/app/{category}/{app}.nix` (cross-platform)
- `system/shared/profiles/{family}/app/{category}/{app}.nix` (platform family)
- `system/{platform}/app/{category}/{app}.nix` (platform-specific)

**Attributes**:

- `appName` (string, implicit from filename): Application identifier
- `category` (string, implicit from directory): Functional grouping (dev, editor, shell, etc.)
- `package` (derivation): Nix package to install
- `configuration` (attribute set): Application settings
- `shellAliases` (attribute set): Command aliases (namespaced)
- `fileAssociations` (list): File extension mappings
- `dependencies` (list of module paths): Other apps required

**Relationships**:

- Depends on: Other App Modules (explicit via imports)
- Uses: Helper Libraries (for file associations, etc.)
- Used by: User, System Profile, other App Modules
- References: Secrets (for sensitive config)

**Validation Rules**:

- Must be \<200 lines (refactor if larger)
- Dependencies must be explicit via `imports` at top
- No circular dependencies (enforced by Nix)
- Shell aliases must be namespaced
- File associations must use `mkFileAssociation` helper

**Example**:

```nix
# system/shared/app/dev/git.nix
{ config, lib, pkgs, ... }:

let
  fileAssoc = import ../../lib/file-associations.nix { inherit pkgs lib; };
in
{
  imports = [
    ../tools/delta.nix  # Git uses delta for diffs
  ];
  
  home.packages = [ pkgs.git ];
  
  programs.git = {
    enable = true;
    userName = config.user.fullName;
    userEmail = config.user.email;
    delta.enable = true;
  };
  
  programs.zsh.shellAliases = {
    g = "git";
    gst = "git status";
    gco = "git checkout";
  };
  
  home.activation.gitFileAssociations = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${fileAssoc.mkFileAssociation {
      extension = ".git";
      appId = if pkgs.stdenv.isDarwin 
              then "com.github.GitUp.GitUp"
              else "git-cola";
    }}
  '';
}
```

### 4. Helper Library

Provides reusable functions for activation scripts, file associations, and platform abstractions.

**Location**:

- `system/shared/lib/` (cross-platform helpers)
- `system/{platform}/lib/` (platform-specific helpers)
- `user/shared/lib/` (user environment helpers)

**Attributes**:

- `functions` (attribute set): Exported helper functions
- `platform` (enum: shared|darwin|linux|nixos): Scope of helpers
- `dependencies` (list): Other libs imported (unidirectional)

**Relationships**:

- Used by: App Modules, System Profiles, Activation Scripts
- Depends on: Other Helper Libraries (platform → shared)

**Validation Rules**:

- Shared libs must have zero platform-specific code
- Platform libs can import shared libs only
- Must document all exported functions
- Functions must be idempotent

**Example**:

```nix
# system/shared/lib/file-associations.nix
{ pkgs, lib, ... }:

{
  mkFileAssociation = { extension, appId, mimeType ? null }:
    if pkgs.stdenv.isDarwin then
      # macOS implementation
      ''${pkgs.duti}/bin/duti -s ${lib.escapeShellArg appId} ${lib.escapeShellArg extension} all''
    else
      # Linux implementation
      let mime = mimeType or "application/x-${lib.removePrefix "." extension}";
      in ''${pkgs.xdg-utils}/bin/xdg-mime default ${lib.escapeShellArg appId}.desktop ${lib.escapeShellArg mime}'';
}
```

### 5. Secret

Represents encrypted sensitive data (API tokens, SSH keys, passwords) managed by agenix.

**Location**: `secrets/{scope}/{resource}/`

- `secrets/users/{username}/` (user-specific)
- `secrets/system/{platform}/` (system-specific)
- `secrets/shared/` (cross-platform)

**Attributes**:

- `secretName` (string): Identifier
- `encryptedFile` (path): `.age` file
- `authorizedKeys` (list of age public keys): Who can decrypt
- `owner` (string): Unix user who accesses secret
- `targetPath` (path): Where secret is decrypted to

**Relationships**:

- Owned by: User or System
- Used by: App Module (via age.secrets references)
- Defined in: `secrets/secrets.nix` (single source of truth)

**Validation Rules**:

- Must be encrypted with agenix
- Never commit plaintext secrets
- Must declare authorized age keys
- Owner must match expected user

**Example**:

```nix
# secrets/secrets.nix
let
  cdrokar = "age1...public-key...";
  darwinSystem = "age1...system-key...";
in
{
  "users/cdrokar/ssh-key.age".publicKeys = [ cdrokar ];
  "system/darwin/work-vpn.age".publicKeys = [ darwinSystem cdrokar ];
}
```

```nix
# Usage in app module
age.secrets.protonvpn-credentials = {
  file = ../../../secrets/users/cdrokar/protonvpn-credentials.age;
  owner = "cdrokar";
};

programs.protonvpn.credentialsFile = config.age.secrets.protonvpn-credentials.path;
```

## Entity Relationships

### Hierarchy Diagram

```
User (cdrokar, cdrolet, cdrixus)
  ├─ imports: user/shared/lib/home.nix (Home Manager bootstrap)
  ├─ imports: App Modules (specific selections)
  │   └─ App Module
  │       ├─ imports: Other App Modules (dependencies)
  │       ├─ uses: Helper Libraries
  │       └─ references: Secrets
  └─ deployed via: Flake Configuration
      └─ combines: User + System Profile

System Profile (darwin/home, darwin/work, nixos-gnome-desktop-1)
  ├─ imports: Settings Modules
  ├─ imports: App Modules (profile's app bundle)
  │   └─ [see App Module above]
  ├─ imports: Other Profiles (mixin composition)
  └─ uses: Helper Libraries

Helper Library
  ├─ location: system/shared/lib/ (cross-platform)
  ├─ location: system/{platform}/lib/ (platform-specific)
  └─ dependency: shared ← linux ← platform (unidirectional)

Secret
  ├─ encrypted with: age keys
  ├─ defined in: secrets/secrets.nix
  └─ used by: App Modules
```

### Composition Flow

```
Installation Request: just install cdrokar darwin-home
  ↓
Flake Output: cdrokar-darwin-home
  ↓
Combines:
  ├─ User Config: user/cdrokar/default.nix
  │   ├─ Bootstrap: user/shared/lib/home.nix
  │   └─ Apps: [git, helix, aerospace, ...]
  │
  └─ System Profile: system/darwin/profiles/home/default.nix
      ├─ Settings: system/darwin/settings/default.nix
      ├─ Apps: [zsh, helix, ...]
      └─ Libs: system/darwin/lib/mac.nix
  ↓
Build Result: Complete system configuration
```

### Profile Inheritance Precedence

```
Platform + Context Profile (darwin/profiles/work/)
  ↓ overrides
Platform-Level Config (darwin/{app,settings,lib}/)
  ↓ overrides
Cross-Platform Family Profile (shared/profiles/linux-gnome/)
  ↓ overrides
Universal Shared Config (shared/{app,settings,lib}/)
  ↓ overrides
Default Values
```

## State Transitions

### 1. App Module Lifecycle

```
[Created] → [Validated] → [Imported] → [Built] → [Activated]
   ↓           ↓             ↓           ↓          ↓
- File      - Syntax     - In user   - Derivation - Activation
  created     valid        or profile   built       scripts run
- Deps      - No cycles    config     - Package   - File assocs
  declared  - <200 lines              installed    set
```

### 2. User Configuration Lifecycle

```
[Defined] → [Validated] → [Combined] → [Built] → [Deployed]
   ↓           ↓             ↓           ↓          ↓
- user/     - Required    - With      - Home     - User
  {name}/     fields        profile     Manager    login
  default.    present       via flake   derivation
  nix       - Valid apps              - Symlinks
            - No platform              created
              conflicts
```

### 3. Secret Lifecycle

```
[Created] → [Encrypted] → [Mapped] → [Referenced] → [Decrypted]
   ↓           ↓            ↓            ↓             ↓
- Plaintext - agenix     - In         - In app     - At build/
  temp file   -e           secrets.     module       deploy
- Generated   command      nix          age.secrets  time
  or manual - .age file  - Age keys   - File path  - To /run/
            - Committed    authorized               agenix/
```

## Validation Rules Summary

### Cross-Entity Constraints

1. **Platform Compatibility**

   - Darwin apps cannot be imported by NixOS users/profiles
   - NixOS apps cannot be imported by darwin users/profiles
   - Shared apps work on all platforms
   - Family profiles (linux/) work on any Linux (NixOS, Kali)

1. **Dependency Acyclicity**

   - No circular imports: A → B → A is forbidden
   - Build fails with infinite recursion error
   - Use base/enhanced split if needed

1. **Naming Consistency**

   - Flake output: `{user}-{profile}`
   - User directory matches username
   - App filename matches app name
   - Profile directory matches context

1. **File Size Limits**

   - App modules: \<200 lines
   - Profile configs: \<200 lines per file
   - Use topic-based split if exceeded

1. **Shell Alias Uniqueness**

   - No duplicate aliases across imported modules
   - Use namespaced prefixes (gst not st)
   - Optional build-time validation available

1. **Secret Security**

   - Never commit plaintext
   - Always encrypted with age
   - Authorized keys declared in secrets.nix
   - Owner matches expected user

## Data Flow Example

### End-to-End: User Installing System

1. **User executes**: `just install cdrokar darwin-home`

1. **Justfile validates**:

   - Query: `nix eval .#validUsers` → includes "cdrokar" ✓
   - Query: `nix eval .#validProfiles.darwin` → includes "home" ✓
   - Platform: `uname -s` → "darwin" ✓

1. **Flake builds**: `darwinConfigurations.cdrokar-home`

   - Loads: `user/cdrokar/default.nix`
     - Imports: `user/shared/lib/home.nix` (bootstrap)
     - Imports: `system/shared/app/dev/git.nix`
       - Imports: `system/shared/app/tools/delta.nix`
       - Uses: `system/shared/lib/file-associations.nix`
     - Imports: `system/darwin/app/aerospace.nix`
       - Uses: `system/darwin/lib/mac.nix`
   - Loads: `system/darwin/profiles/home/default.nix`
     - Imports: `system/darwin/settings/default.nix`
     - Imports: `system/shared/app/shell/zsh.nix`

1. **Nix evaluates**: Merges all attribute sets

   - home.packages = [ git delta aerospace ... ]
   - programs.git = { enable = true; ... }
   - programs.zsh.shellAliases = { g = "git"; ... }
   - system.defaults.dock = { ... }

1. **Nix builds**: Creates derivations

   - Downloads packages
   - Generates config files
   - Creates activation scripts

1. **darwin-rebuild activates**:

   - Installs packages
   - Writes configs to ~/.config/
   - Runs activation scripts (file associations, dock config)
   - Switches system profile

1. **User logs in**: Environment ready

   - Shell aliases available
   - Applications installed
   - File associations set
   - Settings applied

## Migration Impact on Data Model

### Phase Transitions

**Phase 1** (Foundation):

- NEW: `user/cdrokar/default.nix` (1 user)
- NEW: `system/darwin/profiles/home/default.nix` (1 profile)
- NEW: 3 app modules (git, zsh, starship)
- NEW: `system/shared/lib/file-associations.nix`
- NEW: `user/shared/lib/home.nix`
- OLD: Existing structure intact

**Phase 2-3** (Apps + Platform):

- NEW: ~40 app modules migrated
- NEW: All platform profiles
- NEW: Platform-specific settings
- OLD: Existing structure intact but unused

**Phase 4** (Users + Secrets):

- NEW: All 3 users (cdrokar, cdrolet, cdrixus)
- NEW: `secrets/` directory with agenix
- NEW: `secrets/secrets.nix` (single source of truth)
- MIGRATION: sops-nix → agenix

**Phase 5** (Cleanup):

- REMOVED: `modules/`, `home/`, `profiles/`, `overlays/`
- REMOVED: Old `secrets/` with sops-nix
- FINAL: Only new structure remains
