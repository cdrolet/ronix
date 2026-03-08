# Implementation Tasks: Repository Restructure - User/System Split

**Feature**: 010-repo-restructure\
**Branch**: `010-repo-restructure`\
**Date**: 2025-10-31

## Implementation Order

This task list follows the migration strategy defined in [spec.md](./spec.md) with 5 phases over 6-8 weeks.

______________________________________________________________________

## Phase 0: Planning & Constitution (Week 1)

**Goal**: Get constitutional approval and prepare migration plan

### Task 0.1: Update Constitution with New Directory Structure

- [X] Read current constitution (`.specify/memory/constitution.md`)
- [X] Create amendment document for Section II (Modularity and Reusability)
- [X] Replace required directories with new structure:
  - FROM: `hosts/`, `modules/`, `home/`, `profiles/`, `overlays/`, `secrets/`
  - TO: `user/`, `system/`, `secrets/` (with hierarchical organization)
- [X] Document rationale (improved modularity, app-centric, multi-user)
- [X] Increment constitution version: 1.7.0 → 2.0.0 (MAJOR)
- [X] Update constitution last amended date
- [X] Commit: `feat(constitution): add user/system directory structure (v2.0.0)`

**Files**: `.specify/memory/constitution.md`\
**Dependencies**: None\
**Validation**: Constitution version is 2.0.0, new directory structure documented

### Task 0.2: Create Migration Checklist Document

- [X] Create `docs/migration/010-checklist.md`
- [X] List all app modules to migrate (~40-50 apps)
- [X] Group by category (shell, editor, browser, dev, etc.)
- [X] Add checkboxes for tracking progress
- [X] Document testing procedure for each migrated app
- [X] Commit: `docs: add migration checklist for repository restructure`

**Files**: `docs/migration/010-checklist.md`\
**Dependencies**: Task 0.1\
**Validation**: Checklist has all current apps listed

### Task 0.3: Create Helper Library Templates

- [X] Create `system/shared/lib/file-associations.nix` with `mkFileAssociation` function
  - Platform detection (darwin vs linux)
  - duti implementation for macOS
  - xdg-mime implementation for Linux
  - Idempotent, with error handling
- [X] Create `user/shared/lib/home.nix` Home Manager bootstrap module
  - Options: user.name, user.email, user.fullName
  - Config: home.stateVersion, home.username, home.homeDirectory
  - Platform-specific home directory (darwin vs linux)
- [X] Test both helpers in isolation
- [X] Commit: `feat(lib): add helper libraries for file associations and home manager`

**Files**: `system/shared/lib/file-associations.nix`, `user/shared/lib/home.nix`\
**Dependencies**: Task 0.1\
**Validation**: `nix-instantiate --eval` succeeds for both files

### Task 0.4: Constitutional Amendment Approval

- [X] Constitution amended to remove waiting period for personal projects (v2.0.1)
- [X] No waiting period required (solo developer)
- [X] Amendment rationale documented in commit message
- [X] Ready to proceed to Phase 1

**Files**: `.specify/memory/constitution.md` (v2.0.1)\
**Dependencies**: Task 0.1\
**Validation**: Constitution updated, no waiting period for personal projects

______________________________________________________________________

## Phase 1: Foundation & Tooling (Week 2)

**Goal**: Create proof of concept with 3 apps, 1 user, 1 profile

### Task 1.1: Create Directory Structure

- [X] Create `user/` directory with subdirectories:
  - `user/cdrokar/`
  - `user/shared/lib/` (already has home.nix from Task 0.3)
- [X] Create `system/` directory with hierarchical structure:
  - `system/shared/app/`, `system/shared/settings/`, `system/shared/lib/`
  - `system/shared/profiles/linux/`, `system/shared/profiles/linux-gnome/`
  - `system/darwin/app/`, `system/darwin/settings/`, `system/darwin/lib/`
  - `system/darwin/profiles/home/`, `system/darwin/profiles/work/`
  - `system/nixos/app/`, `system/nixos/settings/`, `system/nixos/lib/`
  - `system/nixos/profiles/gnome-desktop-1/`
- [X] Create `secrets/` directory:
  - `secrets/users/`, `secrets/system/`, `secrets/shared/`
  - `secrets/secrets.nix`
- [X] Add `.gitkeep` files to empty directories
- [X] Commit: `feat: create user/system/secrets directory structure`

**Files**: Multiple directories\
**Dependencies**: Task 0.4 (approval)\
**Validation**: All directories exist, `tree` output matches spec

### Task 1.2: Migrate Reference App - git

- [ ] Copy existing git configuration to `system/shared/app/dev/git.nix`
- [ ] Consolidate package, config, aliases in single file
- [ ] Add explicit dependency import (delta.nix if used)
- [ ] Add namespaced shell aliases (g, gst, gco, gcm)
- [ ] Add file associations using `mkFileAssociation` helper
- [ ] Ensure module is \<200 lines
- [ ] Test in isolation: `nix-instantiate --eval system/shared/app/dev/git.nix`
- [ ] Commit: `feat(app): migrate git to new app-centric structure`

**Files**: `system/shared/app/dev/git.nix`\
**Dependencies**: Task 1.1\
**Validation**: Module builds alone, all git config works

### Task 1.3: Migrate Reference App - zsh

- [ ] Copy existing zsh configuration to `system/shared/app/shell/zsh.nix`
- [ ] Consolidate package, config, plugins, aliases
- [ ] Add explicit dependency imports (fzf, starship if used)
- [ ] Ensure no circular dependencies
- [ ] Test in isolation
- [ ] Commit: `feat(app): migrate zsh to new structure`

**Files**: `system/shared/app/shell/zsh.nix`\
**Dependencies**: Task 1.1\
**Validation**: Module builds alone, zsh config loads

### Task 1.4: Migrate Reference App - starship

- [ ] Copy existing starship configuration to `system/shared/app/shell/starship.nix`
- [ ] Consolidate package and config
- [ ] Ensure independent (no dependencies on zsh)
- [ ] Test in isolation
- [ ] Commit: `feat(app): migrate starship to new structure`

**Files**: `system/shared/app/shell/starship.nix`\
**Dependencies**: Task 1.1\
**Validation**: Module builds alone, starship prompts work

### Task 1.5: Create User Config - cdrokar

- [ ] Create `user/cdrokar/default.nix`
- [ ] Import `user/shared/lib/home.nix`
- [ ] Import 3 reference apps (git, zsh, starship)
- [ ] Set user info (name, email, fullName)
- [ ] Add user-specific overrides if needed
- [ ] Test evaluation
- [ ] Commit: `feat(user): create cdrokar user configuration`

**Files**: `user/cdrokar/default.nix`\
**Dependencies**: Tasks 1.2, 1.3, 1.4\
**Validation**: `nix-instantiate --eval user/cdrokar/default.nix`

### Task 1.6: Create System Profile - darwin/home

- [ ] Create `system/darwin/profiles/home/default.nix`
- [ ] Add `_profileType = "complete"` metadata
- [ ] Import `system/darwin/settings/default.nix`
- [ ] Import 3 reference apps
- [ ] Add profile-specific settings overrides
- [ ] Test evaluation
- [ ] Commit: `feat(profile): create darwin home profile`

**Files**: `system/darwin/profiles/home/default.nix`\
**Dependencies**: Tasks 1.2, 1.3, 1.4\
**Validation**: Profile evaluates correctly

### Task 1.7: Update flake.nix with New Outputs

- [ ] Add `validUsers = [ "cdrokar" ]`
- [ ] Add `validProfiles = { darwin = [ "home" ]; linux = []; }`
- [ ] Create `mkDarwinConfig` helper function
- [ ] Add `darwinConfigurations.cdrokar-home` using helper
- [ ] Import Home Manager integration
- [ ] Test flake check: `nix flake check`
- [ ] Commit: `feat(flake): add new output structure for user/system split`

**Files**: `flake.nix`\
**Dependencies**: Tasks 1.5, 1.6\
**Validation**: `nix flake check` passes

### Task 1.8: Create Justfile Installation Interface

- [ ] Create `justfile` at repository root
- [ ] Implement `install <user> <profile>` command
  - Validate user against `nix eval .#validUsers`
  - Detect platform via `uname -s`
  - Validate profile against `nix eval .#validProfiles.{platform}`
  - Invoke `darwin-rebuild switch --flake .#{user}-{profile}`
- [ ] Implement `list-users` command
- [ ] Implement `list-profiles [platform]` command
- [ ] Implement `check` command
- [ ] Implement `update` command
- [ ] Test all commands
- [ ] Commit: `feat(just): add installation interface with validation`

**Files**: `justfile`\
**Dependencies**: Task 1.7\
**Validation**: All just commands work correctly

### Task 1.9: End-to-End Test

- [X] Run `just check` - should pass (flake check passes)
- [X] Run `just list-users` - should show "cdrokar" (validated via nix eval)
- [X] Run `just list-profiles` - should show "home" (on darwin) (validated via nix eval)
- [X] Run `just build cdrokar home` - should build successfully (✓ builds successfully)
- [ ] Run `just install cdrokar home` - should install successfully (not tested - requires actual system)
- [ ] Verify git, zsh, starship all work (deferred to actual installation)
- [ ] Verify shell aliases work (g, gst, etc.) (deferred to actual installation)
- [X] Create git tag: `phase-1-complete`
- [X] Commit: `chore: phase 1 complete - proof of concept working`

**Files**: None (testing)\
**Dependencies**: Task 1.8\
**Validation**: Full system works with new structure

______________________________________________________________________

## Phase 2: Core Apps Migration (Week 3-4)

**Goal**: Migrate all cross-platform apps to new structure

### Task 2.1: Migrate Shell Tools Category

- [ ] Migrate `ghostty` to `system/shared/app/shell/ghostty.nix`
- [ ] Migrate `kitty` to `system/shared/app/shell/kitty.nix`
- [ ] Migrate other terminal emulators
- [ ] Test each app independently
- [ ] Check alias namespacing (no conflicts)
- [ ] Update migration checklist
- [ ] Commit: `feat(app): migrate shell tools to new structure`

**Files**: `system/shared/app/shell/*.nix`\
**Dependencies**: Task 1.9\
**Validation**: All shell tools build and work independently

### Task 2.2: Migrate Editors Category

- [ ] Migrate `helix` to `system/shared/app/editor/helix.nix`
- [ ] Migrate `zed` to `system/shared/app/editor/zed.nix`
- [ ] Migrate `cursor` to `system/shared/app/editor/cursor.nix`
- [ ] Migrate other editors
- [ ] Test each editor independently
- [ ] Add file associations using helper
- [ ] Update migration checklist
- [ ] Commit: `feat(app): migrate editors to new structure`

**Files**: `system/shared/app/editor/*.nix`\
**Dependencies**: Task 2.1\
**Validation**: All editors build and work

### Task 2.3: Migrate Browsers Category

- [ ] Migrate `zen` to `system/shared/app/browser/zen.nix`
- [ ] Migrate `brave` to `system/shared/app/browser/brave.nix`
- [ ] Migrate other browsers
- [ ] Add file associations for web content
- [ ] Test each browser
- [ ] Update migration checklist
- [ ] Commit: `feat(app): migrate browsers to new structure`

**Files**: `system/shared/app/browser/*.nix`\
**Dependencies**: Task 2.2\
**Validation**: All browsers build and work

### Task 2.4: Migrate Development Tools Category

- [ ] Migrate `uv` to `system/shared/app/dev/uv.nix`
- [ ] Migrate `sdkman` to `system/shared/app/dev/sdkman.nix`
- [ ] Migrate language toolchains (python, node, rust, etc.)
- [ ] Add dependencies between dev tools where needed
- [ ] Test each tool independently
- [ ] Update migration checklist
- [ ] Commit: `feat(app): migrate development tools to new structure`

**Files**: `system/shared/app/dev/*.nix`\
**Dependencies**: Task 2.3\
**Validation**: All dev tools build and work

### Task 2.5: Create Linux Family Profiles

- [ ] Create `system/shared/profiles/linux/app/` directory
- [ ] Identify Linux-specific apps (systemd tools, etc.)
- [ ] Create mixin profile with Linux apps
- [ ] Create `system/shared/profiles/linux-gnome/app/` directory
- [ ] Identify GNOME-specific apps
- [ ] Create mixin profile with GNOME apps
- [ ] Test on NixOS (if available)
- [ ] Commit: `feat(profile): create linux family profiles`

**Files**: `system/shared/profiles/linux/`, `system/shared/profiles/linux-gnome/`\
**Dependencies**: Task 2.4\
**Validation**: Profiles evaluate correctly

### Task 2.6: Update cdrokar User with All Apps

- [ ] Import all migrated apps into `user/cdrokar/default.nix`
- [ ] Test build: `just build cdrokar home`
- [ ] Verify no circular dependencies
- [ ] Verify no alias conflicts
- [ ] Install and test: `just install cdrokar home`
- [ ] Verify all apps work as before migration
- [ ] Create git tag: `phase-2-complete`
- [ ] Commit: `feat: phase 2 complete - all core apps migrated`

**Files**: `user/cdrokar/default.nix`\
**Dependencies**: Task 2.5\
**Validation**: All apps work on cdrokar's system

______________________________________________________________________

## Phase 3: Platform-Specific Settings & Apps (Week 5-6)

**Goal**: Migrate platform-specific configurations

### Task 3.1: Migrate Darwin Settings

- [ ] Copy existing darwin settings to `system/darwin/settings/default.nix`
- [ ] Organize by topic (dock, finder, keyboard, etc.) following Topic-Based pattern
- [ ] Use `lib.mkDefault` for all settings (overridability)
- [ ] Keep each topic module \<200 lines
- [ ] Test: `nix-instantiate --eval system/darwin/settings/default.nix`
- [ ] Commit: `feat(darwin): migrate system settings to new structure`

**Files**: `system/darwin/settings/*.nix`\
**Dependencies**: Task 2.6\
**Validation**: All darwin settings apply correctly

### Task 3.2: Migrate Darwin Apps

- [ ] Migrate `aerospace` to `system/darwin/app/aerospace.nix`
- [ ] Migrate `borders` to `system/darwin/app/borders.nix`
- [ ] Migrate other macOS-specific apps
- [ ] Add platform checks where needed
- [ ] Test each app independently
- [ ] Update migration checklist
- [ ] Commit: `feat(darwin): migrate macOS-specific apps`

**Files**: `system/darwin/app/*.nix`\
**Dependencies**: Task 3.1\
**Validation**: All darwin apps work

### Task 3.3: Create Darwin Work Profile

- [ ] Create `system/darwin/profiles/work/default.nix`
- [ ] Add `_profileType = "complete"` metadata
- [ ] Import darwin settings
- [ ] Import work-appropriate apps (no games, restricted browser settings)
- [ ] Add work-specific overrides
- [ ] Test evaluation
- [ ] Commit: `feat(darwin): create work profile`

**Files**: `system/darwin/profiles/work/default.nix`\
**Dependencies**: Task 3.2\
**Validation**: Work profile evaluates correctly

### Task 3.4: Update Flake with Darwin Profiles

- [ ] Update `validProfiles.darwin = [ "home" "work" ]`
- [ ] Add `darwinConfigurations.cdrokar-work`
- [ ] Add `darwinConfigurations.cdrolet-work`
- [ ] Test flake check
- [ ] Commit: `feat(flake): add darwin work profile configurations`

**Files**: `flake.nix`\
**Dependencies**: Task 3.3\
**Validation**: `nix flake check` passes

### Task 3.5: Migrate NixOS Settings

- [ ] Copy existing NixOS settings to `system/nixos/settings/default.nix`
- [ ] Organize by topic (systemd, network, boot, etc.)
- [ ] Use `lib.mkDefault` for overridability
- [ ] Test: `nix-instantiate --eval system/nixos/settings/default.nix`
- [ ] Commit: `feat(nixos): migrate system settings to new structure`

**Files**: `system/nixos/settings/*.nix`\
**Dependencies**: Task 3.4\
**Validation**: NixOS settings evaluate correctly

### Task 3.6: Create NixOS Profiles

- [ ] Create `system/nixos/profiles/gnome-desktop-1/default.nix`
- [ ] Add `_profileType = "complete"` metadata
- [ ] Import NixOS settings
- [ ] Import linux family profile
- [ ] Import linux-gnome family profile
- [ ] Import desktop apps
- [ ] Create `system/nixos/profiles/server-1/default.nix` (minimal server)
- [ ] Test evaluation
- [ ] Commit: `feat(nixos): create GNOME desktop and server profiles`

**Files**: `system/nixos/profiles/*/default.nix`\
**Dependencies**: Task 3.5\
**Validation**: All NixOS profiles evaluate

### Task 3.7: Update Flake with NixOS Profiles

- [ ] Update `validProfiles.linux = [ "gnome-desktop-1" "kde-desktop-1" "server-1" ]`
- [ ] Create `mkNixosConfig` helper function
- [ ] Add `nixosConfigurations.cdrokar-gnome-desktop-1`
- [ ] Add other NixOS configurations
- [ ] Test flake check
- [ ] Create git tag: `phase-3-complete`
- [ ] Commit: `feat(flake): add NixOS profile configurations`

**Files**: `flake.nix`\
**Dependencies**: Task 3.6\
**Validation**: `nix flake check` passes

______________________________________________________________________

## Phase 4: Users & Secrets (Week 7)

**Goal**: Create all users and migrate secrets to agenix

### Task 4.1: Create Remaining Users

- [ ] Create `user/cdrolet/default.nix` (work profile focused)
- [ ] Create `user/cdrixus/default.nix` (pentest profile focused)
- [ ] Import appropriate apps for each user
- [ ] Set user info for each
- [ ] Test each user config independently
- [ ] Commit: `feat(user): create cdrolet and cdrixus user configurations`

**Files**: `user/cdrolet/default.nix`, `user/cdrixus/default.nix`\
**Dependencies**: Task 3.7\
**Validation**: All user configs evaluate

### Task 4.2: Add Agenix to Flake Inputs

- [ ] Add agenix to `flake.nix` inputs
  ```nix
  inputs.agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  ```
- [ ] Import agenix modules in configurations
- [ ] Test flake update and check
- [ ] Commit: `feat(secrets): add agenix to flake inputs`

**Files**: `flake.nix`, `flake.lock`\
**Dependencies**: Task 4.1\
**Validation**: Agenix available in configurations

### Task 4.3: Generate Age Keys

- [ ] Generate age key for cdrokar: `age-keygen -o ~/.age-key-cdrokar.txt`
- [ ] Generate age key for cdrolet: `age-keygen -o ~/.age-key-cdrolet.txt`
- [ ] Generate age key for cdrixus: `age-keygen -o ~/.age-key-cdrixus.txt`
- [ ] Generate system age key (darwin): `sudo age-keygen -o /var/lib/age-key.txt`
- [ ] Document public keys in secure location
- [ ] Commit: None (keys are not committed)

**Files**: Age key files (outside repo)\
**Dependencies**: Task 4.2\
**Validation**: All keys generated, public keys documented

### Task 4.4: Create Centralized secrets.nix

- [ ] Create `secrets/secrets.nix` with all age public keys
- [ ] Define mappings for user secrets:
  - `secrets/users/cdrokar/*.age`
  - `secrets/users/cdrolet/*.age`
  - `secrets/users/cdrixus/*.age`
- [ ] Define mappings for system secrets:
  - `secrets/system/darwin/*.age`
  - `secrets/system/nixos/*.age`
- [ ] Define mappings for shared secrets
- [ ] Test: `nix-instantiate --eval secrets/secrets.nix`
- [ ] Commit: `feat(secrets): create centralized secrets.nix with age keys`

**Files**: `secrets/secrets.nix`\
**Dependencies**: Task 4.3\
**Validation**: secrets.nix evaluates correctly

### Task 4.5: Migrate Secrets from sops-nix to agenix

- [ ] List all current sops-nix secrets
- [ ] For each secret:
  - Decrypt with sops: `sops -d old-secret.yaml > /tmp/secret.txt`
  - Encrypt with agenix: `agenix -e secrets/.../new-secret.age`
  - Update references in app modules
  - Test secret decryption
  - Delete temporary plaintext file
- [ ] Remove sops-nix from flake inputs
- [ ] Remove old sops secrets directory
- [ ] Commit: `feat(secrets): migrate all secrets from sops-nix to agenix`

**Files**: `secrets/`, app modules referencing secrets\
**Dependencies**: Task 4.4\
**Validation**: All secrets accessible via agenix

### Task 4.6: Test Multi-User Isolation

- [ ] Build cdrokar configuration
- [ ] Build cdrolet configuration
- [ ] Build cdrixus configuration
- [ ] Verify each user has independent app selections
- [ ] Verify each user's secrets are isolated
- [ ] Verify no cross-contamination
- [ ] Create git tag: `phase-4-complete`
- [ ] Commit: `test: verify multi-user isolation works correctly`

**Files**: None (testing)\
**Dependencies**: Task 4.5\
**Validation**: All users work independently

______________________________________________________________________

## Phase 5: Cleanup & Validation (Week 8)

**Goal**: Remove old structure and finalize migration

### Task 5.1: Remove Old Directory Structure

- [ ] Delete `modules/` directory
- [ ] Delete `home/` directory
- [ ] Delete `profiles/` directory
- [ ] Delete `overlays/` directory (migrate overlays to new location if needed)
- [ ] Delete old `secrets/` with sops-nix files
- [ ] Commit: `refactor: remove old directory structure`

**Files**: Multiple old directories (deleted)\
**Dependencies**: Task 4.6\
**Validation**: Only new structure remains

### Task 5.2: Update All Documentation

- [ ] Update `README.md` with new structure
- [ ] Create `docs/features/010-repo-restructure.md` summary
- [ ] Update any guides referencing old structure
- [ ] Update `.specify/` documentation if needed
- [ ] Ensure all examples use new paths
- [ ] Commit: `docs: update all documentation for new structure`

**Files**: `README.md`, `docs/features/*.md`, guides\
**Dependencies**: Task 5.1\
**Validation**: No references to old structure in docs

### Task 5.3: Update CLAUDE.md

- [ ] Ensure CLAUDE.md reflects new structure (already done via update script)
- [ ] Add commands for new workflow
- [ ] Document justfile usage
- [ ] Verify technologies list is current
- [ ] Commit: `docs: finalize CLAUDE.md for new structure`

**Files**: `CLAUDE.md`\
**Dependencies**: Task 5.2\
**Validation**: CLAUDE.md accurate and complete

### Task 5.4: Archive Old Specs

- [ ] Review specs 001-009
- [ ] Add migration notes to specs referencing old structure
- [ ] Update spec status to "archived" if applicable
- [ ] Ensure no broken references
- [ ] Commit: `docs: add migration notes to old specs`

**Files**: `specs/001-*/*.md` through `specs/009-*/*.md`\
**Dependencies**: Task 5.3\
**Validation**: All specs have migration context

### Task 5.5: Run Full System Tests

- [ ] Test all user/profile combinations:
  - `just install cdrokar home`
  - `just install cdrokar work`
  - `just install cdrolet work`
  - `just install cdrixus gnome-desktop-1` (if NixOS available)
- [ ] Verify all apps work
- [ ] Verify all settings apply
- [ ] Verify all secrets decrypt
- [ ] Verify shell aliases work
- [ ] Verify file associations work
- [ ] Document any issues found
- [ ] Commit: `test: validate all user/profile combinations`

**Files**: None (testing)\
**Dependencies**: Task 5.4\
**Validation**: All configurations work perfectly

### Task 5.6: Performance Benchmarking

- [ ] Measure first build time for typical profile (target: \<10 min)
- [ ] Measure incremental rebuild time (target: \<2 min)
- [ ] Measure justfile validation time (target: \<30 sec)
- [ ] Compare with old structure (if baseline available)
- [ ] Document results in `docs/performance/010-benchmarks.md`
- [ ] Commit: `docs: add performance benchmarks for new structure`

**Files**: `docs/performance/010-benchmarks.md`\
**Dependencies**: Task 5.5\
**Validation**: Performance meets targets

### Task 5.7: Success Criteria Validation

- [ ] **SC-001**: Single justfile command installs system ✓
- [ ] **SC-002**: Adding app requires one file ✓
- [ ] **SC-003**: Apps importable independently ✓
- [ ] **SC-004**: Multi-user isolation works ✓
- [ ] **SC-005**: Platform-specific apps can't be imported incorrectly ✓
- [ ] **SC-006**: Secrets never unencrypted in repo ✓
- [ ] **SC-007**: First build \<10 minutes ✓
- [ ] **SC-008**: Incremental rebuild \<2 minutes ✓
- [ ] **SC-009**: Documentation clear for new contributors ✓
- [ ] **SC-010**: Old and new structures can coexist (N/A - clean migration) ✓
- [ ] Commit: `test: validate all success criteria met`

**Files**: None (validation)\
**Dependencies**: Task 5.6\
**Validation**: All 10 success criteria pass

### Task 5.8: Create Migration Guide

- [ ] Create `docs/migration/010-complete-guide.md`
- [ ] Document lessons learned
- [ ] Document pitfalls and solutions
- [ ] Provide examples for future migrations
- [ ] Include before/after comparisons
- [ ] Commit: `docs: add complete migration guide`

**Files**: `docs/migration/010-complete-guide.md`\
**Dependencies**: Task 5.7\
**Validation**: Guide is comprehensive and helpful

### Task 5.9: Final Testing and Tag

- [ ] Run final `nix flake check` - must pass
- [ ] Run final `just check` - must pass
- [ ] Test rollback to phase-4-complete tag (validate rollback works)
- [ ] Create git tag: `phase-5-complete`
- [ ] Create git tag: `v2.0.0` (repository version matching constitution)
- [ ] Merge feature branch to main
- [ ] Commit: `chore: phase 5 complete - migration finalized`

**Files**: None (finalization)\
**Dependencies**: Task 5.8\
**Validation**: All tests pass, tags created, merged to main

______________________________________________________________________

## Task Metrics

**Total Tasks**: 45\
**Estimated Duration**: 6-8 weeks\
**Phases**: 5 (0 through 5)\
**Critical Path**: Linear (each phase depends on previous)

## Rollback Points

- **Phase 0**: No code changes, can abandon
- **Phase 1**: Git revert to pre-migration commit
- **Phase 2-3**: Git revert to `phase-1-complete` tag
- **Phase 4**: Git revert to `phase-3-complete` tag
- **Phase 5**: Git revert to `phase-4-complete` tag (last chance before cleanup)

## Success Indicators

- [ ] All 45 tasks completed
- [ ] All 10 success criteria validated
- [ ] No references to old structure remain
- [ ] All documentation updated
- [ ] Constitution version 2.0.0 ratified
- [ ] Tagged as v2.0.0
- [ ] Merged to main branch

## Notes

- Tasks marked with ⚠️ require special attention
- Tasks marked with 🔒 require secrets/age keys
- Each phase has a git tag for rollback safety
- Run `nix flake check` after every significant change
- Use migration checklist to track app migration progress
- Test each migrated app independently before integrating

______________________________________________________________________

**Generated**: 2025-10-31\
**Based on**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md)
