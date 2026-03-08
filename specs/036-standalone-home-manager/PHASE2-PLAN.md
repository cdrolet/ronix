# Feature 036 - Phase 2 Migration Plan

**Date**: 2026-01-01\
**Status**: 🔄 **IN PROGRESS**\
**Goal**: Migrate all users from nix-darwin module integration to standalone home-manager

## Homebrew Strategy Decision

**Selected**: **Option B - Keep homebrew in darwin system, reference from home-manager**

### How It Works

1. **System Level (nix-darwin)**: Continues to extract and install homebrew casks/brews

   - `darwin.nix` extracts `homebrew.casks` from ALL app modules
   - Installs via `homebrew.casks = [...]` at system level
   - Works exactly as it does now

1. **User Level (home-manager standalone)**: Imports same app modules, gets configuration only

   - App modules declare both `homebrew.casks` AND user config
   - Home-manager ignores `homebrew.*` attributes (they don't exist in HM schema)
   - Only user-level config is applied

### Example App Module Pattern

```nix
# system/darwin/app/wm/aerospace.nix
{ config, pkgs, lib, ... }:

{
  # System-level installation (darwin extracts this)
  homebrew.casks = ["nikitabobko/tap/aerospace"];
  homebrew.taps = ["nikitabobko/tap"];
  
  # User-level configuration (home-manager uses this)
  xdg.configFile."aerospace/aerospace.toml".text = ''
    # Aerospace config
  '';
}
```

**Result**:

- ✅ Darwin system installs aerospace via homebrew
- ✅ Home-manager standalone configures aerospace settings
- ✅ No changes needed to existing app modules
- ✅ Clean separation of concerns

### Why This Works

- Homebrew IS a system concern (requires admin/root, modifies /Applications)
- User config IS a home-manager concern (in ~/, per-user)
- Existing architecture already designed this way
- No app module changes required

## Migration Steps

### Step 1: Update Darwin System Integration

**Current**: darwin.nix creates darwinSystem with home-manager module integration\
**Target**: darwin.nix creates darwinSystem WITHOUT home-manager (system only)

**Changes**:

- Remove `home-manager.darwinModules.home-manager` from imports
- Remove `home-manager.users.${user}` configuration
- Keep homebrew extraction logic (it's system-level)
- Keep all darwin settings modules

**Result**: `just build user host` builds darwin system only (no home-manager)

### Step 2: Update Justfile Workflow

**Current**: `just install user host` → `darwin-rebuild switch`\
**Target**: `just install user host` → run BOTH commands

**New workflow**:

```bash
# just install cdrolet home-macmini-m4
darwin-rebuild switch --flake .#cdrolet-home-macmini-m4  # System
home-manager switch --flake .#cdrolet@home-macmini-m4    # User
```

**Justfile changes**:

```make
# Install configuration (system + user)
install user host:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Detect system from host
    SYSTEM=$(just _detect-system {{host}})
    
    # Build and activate system
    if [ "$SYSTEM" = "darwin" ]; then
        darwin-rebuild switch --flake .#{{user}}-{{host}}
    elif [ "$SYSTEM" = "nixos" ]; then
        sudo nixos-rebuild switch --flake .#{{user}}-{{host}}
    fi
    
    # Build and activate user config
    home-manager switch --flake .#{{user}}@{{host}}
```

### Step 3: Test With Minimal User

Use `test-lib-hm` user to verify:

1. Darwin system builds and activates
1. Home-manager builds and activates
1. Both can run independently
1. No conflicts or errors

**Validation**:

```bash
# Build system
nix build .#darwinConfigurations.test-lib-hm-home-macmini-m4.system

# Build user
nix build .#homeConfigurations."test-lib-hm@home-macmini-m4".activationPackage

# Activate system (dry-run)
darwin-rebuild build --flake .#test-lib-hm-home-macmini-m4

# Activate user (dry-run) 
home-manager build --flake .#test-lib-hm@home-macmini-m4
```

### Step 4: Migrate One Production User

**Target**: cdrolet (simple config, no secrets issues)

**Process**:

1. Verify cdrolet has no dependency on module integration features
1. Test build: `just build cdrolet home-macmini-m4`
1. Test both outputs exist
1. Update docs with new workflow
1. Test activation on actual hardware (if available)

### Step 5: Migrate Remaining Users

**Targets**: cdrokar, cdronix

**Process**: Same as Step 4 for each user

**Validation**: All users can build both system and home configs

### Step 6: Remove Old Integration Code

**Cleanup**:

- Remove home-manager module integration from darwin.nix
- Remove any lib.hm workarounds (home-manager-lib.nix)
- Update documentation
- Remove commented-out code

## Success Criteria

- [ ] All users build without lib.hm errors
- [ ] Darwin system builds (homebrew still works)
- [ ] Home-manager standalone builds (lib.hm available)
- [ ] Justfile hides complexity (one command installs both)
- [ ] Activation scripts execute successfully
- [ ] Wallpaper, fonts, dock, git-repos all work
- [ ] No regressions in existing functionality

## Rollback Plan

If migration fails:

1. Git has all changes tracked
1. Can revert to module integration mode
1. Phase 1 already proved standalone works
1. Low risk - both modes coexist during migration

## Timeline

- **Step 1**: Update darwin.nix - 1 hour
- **Step 2**: Update justfile - 30 min
- **Step 3**: Test minimal user - 30 min
- **Step 4**: Migrate cdrolet - 1 hour
- **Step 5**: Migrate others - 30 min
- **Step 6**: Cleanup - 30 min

**Total**: ~4 hours

## Current Status

- [x] Homebrew strategy decided
- [ ] Darwin.nix updated
- [ ] Justfile updated
- [ ] Test user validated
- [ ] Production users migrated
- [ ] Cleanup complete
