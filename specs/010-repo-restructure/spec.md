# Feature Specification: Repository Restructure - User/System Split

**Feature Branch**: `010-repo-restructure`\
**Created**: 2025-10-29\
**Status**: Draft - Architectural Design\
**Input**: User description: "Repository restructure with user/system split and app-centric organization"

## User Scenarios & Testing

### User Story 1 - App-Centric Configuration (Priority: P1)

As a system administrator, I need to configure applications in self-contained modules that bundle package installation, configuration, shell aliases, and file associations together, so that enabling an application requires only a single import rather than scattered configuration across multiple files.

**Why this priority**: This is the foundational architectural change that drives all other restructuring. App-centric organization is the core value proposition that makes the new structure worthwhile.

**Independent Test**: Can be fully tested by configuring a single application (e.g., git.nix) with package, config, aliases, and file associations, importing it in a user profile, running the installation, and verifying all aspects are applied correctly.

**Acceptance Scenarios**:

1. **Given** a new application module `system/shared/app/dev/git.nix`, **When** I import it in a user profile and rebuild, **Then** git package is installed, .gitconfig is configured, shell aliases are available, and .git file associations are set
1. **Given** an existing scattered configuration (git in programs/, aliases in shell/), **When** I consolidate into `system/shared/app/dev/git.nix`, **Then** the same functionality works with a single import
1. **Given** multiple users with different app needs, **When** each user imports their specific app list, **Then** each user gets only their selected applications without conflicts

______________________________________________________________________

### User Story 2 - User/System Separation (Priority: P2)

As a multi-user system administrator, I need clear separation between user-specific configurations (in `user/`) and system-wide configurations (in `system/`), so that I can manage multiple user personas (cdrokar, cdrolet, cdrixus) independently while sharing common system configurations.

**Why this priority**: Enables multi-user management which is essential for the work/home/pentest persona separation. Builds on P1's app-centric foundation.

**Independent Test**: Can be tested by creating two user profiles (cdrokar and cdrolet) with different app selections, installing both on the same system, and verifying each user's environment is isolated and correct.

**Acceptance Scenarios**:

1. **Given** user `cdrokar` and `cdrolet` configurations, **When** I install the system with `just install cdrokar darwin-home`, **Then** only cdrokar's selected apps and settings are active
1. **Given** both users configured on same system, **When** I switch users, **Then** each user has their own independent application set and configurations
1. **Given** a shared app in `system/shared/app/`, **When** both users import it, **Then** each user gets their own instance without conflicts

______________________________________________________________________

### User Story 3 - Profile-Based System Installation (Priority: P3)

As a system administrator, I need to install systems using profile-based configurations (darwin/home, darwin/work, nixos/gnome-desktop-1, kali/pen-test-1) via a justfile command with two parameters (user, system profile), so that I can rapidly deploy consistent environments across different machines and use cases.

**Why this priority**: Provides the high-level installation interface. Depends on P1 and P2 being in place but adds deployment convenience.

**Independent Test**: Can be tested by running `just install cdrokar darwin-home`, verifying the correct profile's apps/settings are installed, then running `just install cdrolet darwin-work` on a different machine and verifying the work profile is applied.

**Acceptance Scenarios**:

1. **Given** a new macOS machine, **When** I run `just install cdrokar darwin-home`, **Then** the home profile with personal apps and unrestricted settings is deployed
1. **Given** a work laptop, **When** I run `just install cdrolet darwin-work`, **Then** the work profile with restricted settings and work-appropriate apps is deployed
1. **Given** a NixOS desktop, **When** I run `just install cdrokar nixos-gnome-desktop-1`, **Then** the GNOME desktop profile is installed

______________________________________________________________________

### User Story 4 - Agenix Secret Management (Priority: P4)

As a security-conscious administrator, I need to encrypt secrets using agenix with age keys, so that sensitive configuration (API tokens, passwords, SSH keys) can be version-controlled safely and deployed declaratively.

**Why this priority**: Security enhancement that can be added after basic structure works. Important but not blocking initial restructure.

**Independent Test**: Can be tested by creating an encrypted secret file with agenix, referencing it in a user configuration, deploying, and verifying the secret is decrypted correctly at runtime.

**Acceptance Scenarios**:

1. **Given** an API token for ProtonVPN, **When** I encrypt it with agenix and reference it in `user/cdrokar/secrets.nix`, **Then** the token is decrypted at build time and available to ProtonVPN configuration
1. **Given** SSH keys per user, **When** each user's configuration references their encrypted keys, **Then** each user gets their own keys deployed to their home directory
1. **Given** a work profile with company secrets, **When** I deploy the work profile, **Then** only authorized age keys can decrypt the work secrets

______________________________________________________________________

### Edge Cases

- What happens when a user imports the same app twice (via profile and direct import)?
- How does the system handle conflicting shell aliases from multiple apps?
- What happens when a system profile imports darwin-specific apps on a NixOS system?
- How are shared profiles (`system/shared/profiles/all/`) merged with platform-specific profiles?
- What happens when an app's configuration depends on another app being installed first?
- How does agenix handle key rotation when multiple users share some secrets?
- What happens when justfile is run with invalid user or profile names?
- How are user lib files (images, scripts) handled when the user home directory path changes?

## Requirements

### Functional Requirements

**Directory Structure**:

- **FR-001**: System MUST organize configuration into two top-level directories: `user/` for user-specific configs and `system/` for system-wide configs
- **FR-002**: System MUST support multiple users under `user/` (cdrokar, cdrolet, cdrixus) each with their own `default.nix`
- **FR-003**: System MUST support multiple platforms under `system/` (shared, darwin, nixos, kali) each with platform-specific configurations
- **FR-004**: System MUST organize configurations hierarchically:
  - `system/shared/{app,settings,lib}/` - Universal cross-platform (works on ANY platform)
  - `system/shared/profiles/{family}/{app,settings,lib}/` - Cross-platform families (e.g., `linux/`, `linux-gnome/`)
  - `system/{platform}/{app,settings,lib}/` - Platform-specific (e.g., `darwin/`, `nixos/`)
  - `system/{platform}/profiles/{context}/{app,settings,lib}/` - Platform + context specific (e.g., `darwin/profiles/work/`)

**App Module Structure**:

- **FR-005**: Each app module MUST contain package declaration, application configuration, shell aliases, and file associations in a single file
- **FR-006**: App modules MUST be importable independently without requiring other apps to be configured
- **FR-007**: App modules MUST declare their dependencies explicitly using `imports` at the top of the module file
- **FR-008**: App modules MUST NOT create circular dependencies (app A depends on app B which depends on app A)
- **FR-009**: App modules MUST use namespaced shell aliases to prevent conflicts (e.g., `gst` for git status, not generic `st`)
- **FR-010**: App modules MUST use helper library functions for cross-platform file associations (`mkFileAssociation` from `system/shared/lib/`)

**Profile System**:

- **FR-011**: System profiles MUST reside in one of two locations:
  - Platform-specific: `system/{platform}/profiles/{context}/` (e.g., `system/darwin/profiles/work/`)
  - Cross-platform families: `system/shared/profiles/{family}/` (e.g., `system/shared/profiles/linux/`, `system/shared/profiles/linux-gnome/`)
- **FR-012**: System profiles MUST be one of three types: Base (minimal settings only), Complete (full app bundle), or Mixin (additive app set)
- **FR-013**: System profiles MUST declare their profile type in metadata for validation
- **FR-014**: Complete profiles MUST import all required apps explicitly (no implicit "all apps" imports)
- **FR-015**: Profile configurations at each level MUST have `{app,settings,lib}/` subdirectories following the same structure
- **FR-016**: Shared family profiles (e.g., `linux/`, `linux-gnome/`) are reusable bundles for platform subsets, not universal configurations
- **FR-017**: Profile inheritance MUST follow explicit precedence: platform+context > platform > family > shared > base defaults

**User Configuration**:

- **FR-018**: User configurations (`user/{username}/default.nix`) MUST import apps from any level of the hierarchy (`system/shared/app/`, `system/shared/profiles/{family}/app/`, `system/{platform}/app/`, etc.)
- **FR-019**: User configurations MUST install user lib files (images, scripts) using `config.home.homeDirectory` instead of hardcoded paths
- **FR-020**: User configurations MUST bootstrap Home Manager by importing `user/shared/lib/home.nix` as a Home Manager module
- **FR-021**: `user/shared/lib/home.nix` MUST be a Home Manager module that accepts user config and initializes Home Manager state
- **FR-022**: Each user MUST be able to select apps independently without affecting other users
- **FR-023**: User configurations MAY import shared user profiles from `user/shared/profiles/` for common base setups

**Installation Interface**:

- **FR-024**: Justfile MUST provide an `install` command accepting two parameters: username and system profile
- **FR-025**: Justfile MUST validate username and profile against `flake.nix` outputs (not directory scanning)
- **FR-026**: Justfile MUST validate platform compatibility (darwin profiles only installable on darwin systems)
- **FR-027**: Justfile MUST provide clear error messages for invalid username/profile combinations
- **FR-028**: Installation MUST apply the selected system profile's apps and settings
- **FR-029**: Installation MUST configure the selected user's app selections and personal settings
- **FR-030**: `flake.nix` MUST export valid usernames and system profiles as flake outputs for validation

**Helper Libraries**:

- **FR-031**: Helper libraries (`system/shared/lib/`, `system/{platform}/lib/`) MUST contain activation script utilities and package installation functions
- **FR-032**: Helper libraries MUST follow the unidirectional dependency pattern: platform libs → shared libs
- **FR-033**: `system/shared/lib/` MUST provide `mkFileAssociation` function that auto-detects platform (duti on macOS, xdg-mime on Linux)

**Secrets Management**:

- **FR-034**: System MUST support agenix for secret encryption using age keys
- **FR-035**: Secrets MUST be stored in centralized `secrets/` directory at repository root
- **FR-036**: Secrets directory MUST be organized: `secrets/users/{username}/`, `secrets/system/{platform}/`, `secrets/shared/`
- **FR-037**: Each secrets subdirectory MUST have `secrets.nix` declaring age keys authorized to decrypt
- **FR-038**: Secrets MUST be encrypted in version control and decrypted at build/deploy time only
- **FR-039**: Each user MUST have their own age key for user-specific secrets
- **FR-040**: System-wide secrets MUST use platform-specific or shared age keys
- **FR-041**: `secrets/secrets.nix` MUST serve as single source of truth for all age key to secret mappings

### Key Entities

- **User**: Represents a user persona (cdrokar, cdrolet, cdrixus)

  - username (string)
  - default.nix path
  - lib/ directory with user-specific files
  - app selections (list of app imports)
  - Home Manager configuration

- **System Profile**: Represents a deployable system configuration

  - platform (shared, darwin, nixos, kali)
  - profile name (home, work, gnome-desktop-1, etc.)
  - app bundle (list of app imports)
  - settings bundle (list of setting imports)
  - parent profile references (optional)

- **App Module**: Represents a self-contained application configuration

  - category (shell, editor, browser, dev, etc.)
  - app name (git, zsh, helix, etc.)
  - package declaration
  - configuration (files, options)
  - shell aliases
  - file associations
  - dependencies (other apps)

- **Secret**: Encrypted sensitive data managed by agenix

  - secret name
  - encrypted file path
  - age keys authorized to decrypt
  - target users/systems

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can install a complete system with a single justfile command specifying user and profile
- **SC-002**: Adding a new application requires creating/editing only one file (`system/shared/app/{category}/{app}.nix`)
- **SC-003**: Each application module is independently importable - importing git.nix alone results in a working git setup
- **SC-004**: Multiple users can coexist on the same system with completely isolated application sets and configurations
- **SC-005**: Platform-specific apps (aerospace.nix in darwin/) cannot be accidentally imported on incompatible platforms (NixOS)
- **SC-006**: Secrets are never stored unencrypted in version control - all sensitive data uses agenix encryption
- **SC-007**: Installation time for a typical profile (20-30 apps) completes in under 10 minutes on first build
- **SC-008**: Profile changes (adding/removing 1 app) rebuild in under 2 minutes (cached dependencies)
- **SC-009**: Documentation clearly explains the user/system split for new contributors within 5 minutes of reading
- **SC-010**: Migration from old structure to new structure can be done incrementally - both structures can coexist during transition

## Design Patterns

### App Dependency Management

**Dependency Declaration Pattern**:

```nix
# system/shared/app/dev/git.nix
{ config, lib, pkgs, ... }:
{
  # Explicit dependency declaration at top
  imports = [
    ../tools/delta.nix  # Git needs delta for diff viewing
  ];
  
  # Rest of configuration
  home.packages = [ pkgs.git ];
  programs.git.enable = true;
  # ...
}
```

**Rules**:

1. Dependencies MUST be declared via `imports` at the module top
1. Circular dependencies are FORBIDDEN (build-time error)
1. Complex dependencies → split into base + optional modules:
   ```
   git-base.nix       # Core git without extras
   git-enhanced.nix   # Imports git-base.nix + delta.nix
   ```
1. Dependency order is handled by Nix module system automatically

### Profile Inheritance Model

**Profile Types**:

1. **Base Profile** - Minimal system settings only:

```nix
# system/darwin/profiles/base/default.nix
{
  _profileType = "base";  # Metadata for validation
  
  imports = [
    ../../settings/default.nix  # All darwin settings
  ];
  
  # No apps, just settings
}
```

2. **Complete Profile** - Full app bundle + settings:

```nix
# system/darwin/profiles/home/default.nix
{
  _profileType = "complete";
  
  imports = [
    ../../settings/default.nix
    ../../../shared/app/shell/zsh.nix
    ../../../shared/app/editor/helix.nix
    ../../app/aerospace.nix  # darwin-specific
    # ... explicit list of all apps
  ];
}
```

3. **Mixin Profile** - Additive app set (cross-platform family):

```nix
# system/shared/profiles/linux/app/dev-tools.nix
{
  _profileType = "mixin";
  
  imports = [
    ../../../../shared/app/dev/git.nix
    ../../../../shared/app/dev/python.nix
    ../../../shared/profiles/linux/app/gnome-terminal.nix  # Linux-specific
  ];
  
  # Can be imported by NixOS or Kali profiles
}
```

**Inheritance Precedence**:

```
Platform + context profiles (system/darwin/profiles/work/)
    ↓ (overrides)
Platform-level configs (system/darwin/{app,settings,lib}/)
    ↓ (overrides)
Cross-platform family profiles (system/shared/profiles/linux/)
    ↓ (overrides)
Universal shared configs (system/shared/{app,settings,lib}/)
    ↓ (overrides)
Default values
```

### Home Manager Integration Contract

**`user/shared/lib/home.nix` Interface**:

```nix
# This is a Home Manager module
{ config, lib, pkgs, ... }:
{
  # Accepts user-specific configuration
  options.user = {
    name = lib.mkOption { type = lib.types.str; };
    email = lib.mkOption { type = lib.types.str; };
    # ... other user options
  };
  
  config = {
    # Initialize Home Manager state
    home.stateVersion = "24.05";
    home.username = config.user.name;
    home.homeDirectory = 
      if pkgs.stdenv.isDarwin 
      then "/Users/${config.user.name}"
      else "/home/${config.user.name}";
    
    # Enable home-manager self-management
    programs.home-manager.enable = true;
  };
}
```

**Usage in user config**:

```nix
# user/cdrokar/default.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../shared/lib/home.nix  # Bootstrap Home Manager
    ../../system/shared/app/dev/git.nix
    ../../system/darwin/app/aerospace.nix
    # ... other apps from any hierarchy level
  ];
  
  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
  };
}
```

### Shell Alias Conflict Resolution

**Namespacing Convention**:

```nix
# system/shared/app/dev/git.nix
programs.zsh.shellAliases = {
  # Namespaced with app prefix
  g = "git";
  gst = "git status";
  gco = "git checkout";
  gcm = "git commit -m";
  # NOT just: st, co, cm (too generic)
};

# system/shared/app/tools/ripgrep.nix
programs.zsh.shellAliases = {
  rg = "ripgrep";
  rgi = "ripgrep --ignore-case";
  # NOT just: g (conflicts with git)
};
```

**Conflict Detection**:

- Nix will error if same alias defined twice by different modules
- User can override in their config with explicit precedence
- Build fails with clear message: "Alias 'g' defined in both git.nix and grep.nix"

### Platform-Specific File Associations

**Helper Library Pattern**:

```nix
# system/shared/lib/file-associations.nix
{ pkgs, lib, ... }:
{
  mkFileAssociation = { extension, appId, mimeType ? null }:
    if pkgs.stdenv.isDarwin then
      # macOS: use duti
      ''
        ${pkgs.duti}/bin/duti -s ${lib.escapeShellArg appId} ${lib.escapeShellArg extension} all
      ''
    else
      # Linux: use xdg-mime
      let
        mime = if mimeType != null then mimeType 
               else "application/x-${extension}";
      in ''
        ${pkgs.xdg-utils}/bin/xdg-mime default ${lib.escapeShellArg appId}.desktop ${lib.escapeShellArg mime}
      '';
}
```

**Usage in app module**:

```nix
# system/shared/app/dev/git.nix
{ config, lib, pkgs, ... }:
let
  fileAssocLib = import ../../lib/file-associations.nix { inherit pkgs lib; };
in {
  home.activation.setGitFileAssociations = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${fileAssocLib.mkFileAssociation { 
      extension = ".git"; 
      appId = "com.github.GitUp.GitUp"; 
    }}
  '';
}
```

## Assumptions

- **Project not in production**: This repository is not currently used in production, allowing clean migration without compatibility layer
- Home Manager is integrated and functional before this restructure is implemented
- Existing nix-darwin and NixOS configurations work and will be migrated, not rewritten from scratch
- Users understand Nix module system and imports
- The justfile command runner (just) is available on deployment systems
- Age keys for agenix are generated and distributed to authorized users before secret encryption
- Applications in `system/shared/app/` are truly cross-platform (work on ANY platform)
- Applications in `system/shared/profiles/{family}/app/` work across platform families (e.g., all Linux distros)
- Each app module is responsible for its own platform compatibility checks when needed
- User home directory paths are standard (`/Users/{username}` on macOS, `/home/{username}` on Linux)
- File associations use platform-appropriate mechanisms (duti on macOS, xdg-mime on Linux)
- The current `.specify/` workflow directory remains at repository root and is not affected by restructure

## Dependencies

- Home Manager integration (currently postponed in spec 010-startup-apps-migration)
- Nix flakes (already in use)
- Justfile command runner
- Agenix Nix library
- Age encryption tool
- Existing helper library patterns from specs 006-009 (dock, power, system-defaults libs)
- Constitution amendment to update directory structure standard (Section II: Modularity and Reusability)

## Out of Scope

- Automatic migration scripts (users manually migrate modules incrementally)
- Backward compatibility with old directory structure (clean break)
- GUI configuration tool for profile selection
- Dynamic profile switching (requires logout/rebuild)
- Cloud synchronization of secrets (agenix files managed via git only)
- Application version management per user (all users get same package versions)
- Per-app rollback capability (system-wide rollback only)
- Application dependency resolution (users manually specify dependencies)
- Cross-platform application abstraction layer (each app handles its own platforms)

## Migration Strategy

**Timeline**: 6-8 weeks (clean migration)\
**Approach**: Direct migration without compatibility layer (project not in production)\
**Rollback**: Git-based rollback available at any phase

### Phase 0: Planning & Constitution (Week 1)

- Update constitution with new directory structure (MAJOR amendment)
- Submit amendment for 1 week approval period per constitution process
- Document migration checklist for each app module type
- Create helper library templates (`mkFileAssociation`, `home.nix` bootstrap)
- **Rollback**: Simple git revert, no code changes yet
- **Output**: Approved constitution amendment, migration plan documented

### Phase 1: Foundation & Tooling (Week 2)

- Create new directory structure (`user/`, `system/`) with hierarchical organization
- Implement helper libraries:
  - `system/shared/lib/file-associations.nix` with `mkFileAssociation`
  - `user/shared/lib/home.nix` Home Manager bootstrap module
  - Shell alias conflict detection in build pipeline
- Implement justfile with validation against flake.nix outputs
- Update flake.nix to export new structure outputs
- Migrate 3 reference apps (git, zsh, starship) to new app-centric structure with explicit dependency declarations
- Create 1 user (cdrokar) and 1 profile (darwin/profiles/home/) as proof of concept
- Test end-to-end: `just install cdrokar darwin-home`
- **Rollback**: Git revert to pre-migration commit
- **Output**: Working proof of concept with 3 apps, 1 user, 1 profile

### Phase 2: Core Apps Migration (Week 3-4)

- Migrate remaining shell tools (ghostty, kitty, etc.) to `system/shared/app/` with explicit dependency imports
- Migrate editors (helix, zed, cursor, etc.)
- Migrate browsers (zen, brave)
- Migrate dev tools (uv, sdkman, language toolchains)
- For each app: validate no circular dependencies, check alias namespacing
- Create shared family profile bundles as Mixin profiles:
  - `system/shared/profiles/linux/` for Linux-specific apps
  - `system/shared/profiles/linux-gnome/` for GNOME desktop apps
- Test each migrated app independently (import alone should work)
- **Rollback**: Git revert to Phase 1 checkpoint
- **Output**: All cross-platform apps migrated to new structure

### Phase 3: Platform-Specific Settings & Apps (Week 5-6)

- Migrate darwin settings to `system/darwin/settings/`
- Migrate darwin apps (aerospace, borders) to `system/darwin/app/` with platform checks
- Create darwin context profiles in `system/darwin/profiles/{home,work}/` as Complete profiles with `_profileType` metadata
- Migrate NixOS settings to `system/nixos/settings/`
- Create NixOS profiles (gnome-desktop-1, kde-desktop-1, server-1) in `system/nixos/profiles/`
- Validate platform compatibility checks prevent darwin apps on NixOS
- Test profile inheritance precedence (platform+context > platform > family > shared > defaults)
- **Rollback**: Git revert to Phase 2 checkpoint
- **Output**: All platform-specific configurations migrated

### Phase 4: Users & Secrets (Week 7)

- Create remaining users (cdrolet, cdrixus) in `user/{username}/` with isolated app selections
- Implement agenix secret management infrastructure
- Create centralized `secrets/` directory structure:
  ```
  secrets/
  ├── users/{username}/
  ├── system/{platform}/
  ├── shared/
  └── secrets.nix  # Single source of truth
  ```
- Generate age keys per user
- Migrate existing sops-nix secrets to agenix with centralized structure
- Encrypt sensitive configurations
- Test multi-user isolation (each user's environment independent)
- **Rollback**: Git revert to Phase 3 checkpoint
- **Output**: All users configured, secrets migrated to agenix

### Phase 5: Cleanup & Validation (Week 8)

- Remove old directory structure (`modules/`, `home/`, `profiles/`, `overlays/`, old `secrets/`)
- Update CLAUDE.md with new structure guidelines
- Archive old specs that reference deprecated structure
- Run full system tests across all user/profile combinations
- Validate success criteria (SC-001 through SC-010)
- Performance benchmarking (installation time, rebuild time)
- Fix any edge cases discovered (duplicate imports, alias conflicts, missing dependencies)
- Update all documentation with new structure
- Create migration guide for future contributors
- Final end-to-end testing
- **Rollback**: Git revert to Phase 4 checkpoint (restore old structure from git history)
- **Output**: Clean repository with only new structure, all tests passing

### Rollback Strategy

**Simple git-based rollback** (no compatibility layer needed since not in production):

```bash
# Rollback to any previous phase
git log --oneline  # Find the commit before migration phase you want to revert
git revert <commit-hash>  # Or git reset --hard <commit-hash> if no work to preserve

# Emergency full rollback to pre-migration state
git revert <phase-0-commit>..<current-commit>
# Or
git reset --hard <pre-migration-commit>

# Rebuild system
darwin-rebuild switch --flake .
```

**Phase checkpoints**:

- Phase 0: Constitution updated, no code changes
- Phase 1: Proof of concept (3 apps, 1 user, 1 profile)
- Phase 2: All cross-platform apps migrated
- Phase 3: All platform-specific configs migrated
- Phase 4: All users and secrets migrated
- Phase 5: Old structure removed (point of no return unless restoring from git history)

## Secrets Architecture

**Centralized secrets structure** (addresses FR-035 through FR-041):

```
secrets/
├── users/
│   ├── cdrokar/
│   │   ├── ssh-key.age
│   │   ├── protonvpn-credentials.age
│   │   └── api-tokens.age
│   ├── cdrolet/
│   │   ├── ssh-key.age
│   │   └── work-vpn.age
│   └── cdrixus/
│       └── ssh-key.age
│
├── system/
│   ├── darwin/
│   │   ├── apple-developer-cert.age
│   │   └── work-mdm-profile.age
│   ├── nixos/
│   │   └── server-root-password.age
│   └── kali/
│       └── pentest-licenses.age
│
├── shared/
│   ├── backup-encryption-key.age
│   └── github-deploy-key.age
│
└── secrets.nix  # Single source of truth for age key mappings
```

**`secrets/secrets.nix` structure**:

```nix
# Single source of truth for all secret-to-key mappings
let
  # Age public keys
  cdrokar = "age1...";
  cdrolet = "age1...";
  cdrixus = "age1...";
  darwinSystem = "age1...";
  nixosSystem = "age1...";
in
{
  # User secrets
  "users/cdrokar/ssh-key.age".publicKeys = [ cdrokar ];
  "users/cdrokar/protonvpn-credentials.age".publicKeys = [ cdrokar ];
  "users/cdrolet/work-vpn.age".publicKeys = [ cdrolet darwinSystem ];  # User + system can decrypt
  
  # System secrets
  "system/darwin/apple-developer-cert.age".publicKeys = [ darwinSystem cdrokar cdrolet ];
  "system/nixos/server-root-password.age".publicKeys = [ nixosSystem cdrokar ];
  
  # Shared secrets
  "shared/backup-encryption-key.age".publicKeys = [ cdrokar cdrolet nixosSystem darwinSystem ];
  "shared/github-deploy-key.age".publicKeys = [ cdrokar cdrolet cdrixus ];
}
```

**Rationale for centralized structure**:

- **Single source of truth**: One `secrets.nix` file prevents key mapping inconsistencies
- **No secrets sprawl**: All encrypted files in one top-level `secrets/` directory
- **Clear ownership**: `users/{username}/` vs `system/{platform}/` vs `shared/` organization
- **Easier auditing**: All secrets visible in one directory tree
- **Simpler key rotation**: Update age keys in one place
- **Version control friendly**: Clear diff when secrets are added/removed

**Usage in app modules**:

```nix
# system/shared/app/proton/vpn.nix
{ config, pkgs, ... }:
{
  # Reference secret with absolute path from repo root
  age.secrets.protonvpn-credentials = {
    file = ../../../secrets/users/cdrokar/protonvpn-credentials.age;
    owner = "cdrokar";
  };
  
  # Use decrypted secret in configuration
  programs.protonvpn = {
    enable = true;
    credentialsFile = config.age.secrets.protonvpn-credentials.path;
  };
}
```

**Secret creation workflow**:

```bash
# 1. Create plaintext secret (never commit this!)
echo "username:password" > /tmp/protonvpn-creds.txt

# 2. Encrypt with agenix using user's age key
agenix -e secrets/users/cdrokar/protonvpn-credentials.age

# 3. Add mapping to secrets/secrets.nix
# "users/cdrokar/protonvpn-credentials.age".publicKeys = [ cdrokar ];

# 4. Delete plaintext
rm /tmp/protonvpn-creds.txt

# 5. Commit encrypted .age file and updated secrets.nix
git add secrets/users/cdrokar/protonvpn-credentials.age secrets/secrets.nix
git commit -m "feat(secrets): add ProtonVPN credentials for cdrokar"
```
