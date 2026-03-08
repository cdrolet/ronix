# Implementation Tasks: GNOME Family System Integration

**Feature**: 028-gnome-family-system-integration\
**Branch**: `028-gnome-family-system-integration`\
**Generated**: 2025-12-25

## Overview

This document provides an ordered task list for implementing GNOME family system integration. Tasks are organized by user story to enable independent implementation and testing of each feature increment.

**Implementation Strategy**: Incremental delivery - each user story phase produces a complete, independently testable feature.

______________________________________________________________________

## Task Summary

- **Total Tasks**: 29
- **Completed**: 26/29 (90%)
- **Remaining**: 3 (T008, T009, T029 - all require NixOS host for testing)
- **Parallelizable**: 15 tasks marked with [P]
- **User Stories**: 6 (US0-US5)
- **Estimated Phases**: 9

### Tasks Per User Story

- Setup (Phase 1): 2 tasks ✅
- Foundational (Phase 2): 3 tasks ✅
- US0 (Phase 3): 4 tasks (2/4 - testing deferred)
- US1 (Phase 4): 5 tasks ✅
- US2 (Phase 5): 3 tasks ✅
- US3 (Phase 6): 3 tasks ✅
- US4 (Phase 7): 3 tasks ✅
- US5 (Phase 8): 1 task ✅
- Polish (Phase 9): 4 tasks ✅, 1 deferred (T029)

______________________________________________________________________

## Phase 1: Setup & Preparation

**Goal**: Prepare project structure and validate existing state

**Tasks**:

- [X] T001 Verify current family app directory structure (check for existing default.nix files)
- [X] T002 Verify current GNOME family settings structure in system/shared/family/gnome/settings/

**Completion Criteria**:

- Current state documented
- Existing default.nix files identified
- GNOME family structure mapped

______________________________________________________________________

## Phase 2: Foundational Changes

**Goal**: Make breaking architectural changes that all user stories depend on

**Tasks**:

- [X] T003 Update system/nixos/lib/nixos.nix to add family integration support (load hostFamily from host config)
- [X] T004 Update system/nixos/lib/nixos.nix to import familyDefaults at system modules level
- [X] T005 Verify discovery.autoInstallFamilyDefaults function exists and handles settings/ correctly

**Completion Criteria**:

- NixOS platform lib loads family data from host configs
- Family settings imported at system level (not home-manager)
- Build succeeds with `nix flake check`

**Dependencies**: BLOCKING - Must complete before any user story

______________________________________________________________________

## Phase 3: User Story 0 - Family App Discovery

**Story**: Family app directories have NO default.nix and use hierarchical discovery

**Goal**: Remove default.nix from family app directories so apps are discovered hierarchically (user-selected, not auto-installed)

**Independent Test Criteria**:

- [ ] No default.nix files exist in family/\*/app/ directories
- [ ] Family apps still discoverable via hierarchical search
- [ ] Wildcard `applications = ["*"]` includes family apps when family in host
- [ ] Apps NOT auto-installed (only when user selects them)

**Tasks**:

- [X] T006 [P] [US0] Delete system/shared/family/gnome/app/default.nix (if exists)
- [X] T007 [P] [US0] Delete system/shared/family/linux/app/default.nix (if exists)
- [ ] T008 [US0] Test hierarchical app discovery with family apps (verify gnome-tweaks found when family=["gnome"])
- [ ] T009 [US0] Test wildcard expansion includes family apps when family in host

**Validation**:

```bash
# Verify no default.nix in family app dirs
! test -f system/shared/family/gnome/app/default.nix
! test -f system/shared/family/linux/app/default.nix

# Test app discovery
nix eval .#nixosConfigurations.test-host.config.home-manager.users.testuser.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

**Dependencies**: Phase 2 (Foundational)

______________________________________________________________________

## Phase 4: User Story 1 - GNOME Desktop in settings/desktop/

**Story**: GNOME desktop environment configured in gnome/settings/desktop/ for system-wide installation

**Goal**: Create modular GNOME desktop settings that install the full desktop environment at system level

**Independent Test Criteria**:

- [ ] `gnome/settings/desktop/` directory exists with auto-discovery
- [ ] `gnome-core.nix`, `gnome-optional.nix`, `gnome-exclude.nix` modules created
- [ ] All modules \<200 lines (constitutional requirement)
- [ ] `nautilus.nix` removed from `app/utility/` (redundant)
- [ ] GNOME desktop packages available when host has `family = ["gnome"]`

**Tasks**:

- [X] T010 [P] [US1] Create system/shared/family/gnome/settings/desktop/ directory
- [X] T011 [P] [US1] Create system/shared/family/gnome/settings/desktop/default.nix with auto-discovery pattern
- [X] T012 [P] [US1] Create system/shared/family/gnome/settings/desktop/gnome-core.nix (enable GNOME desktop + core-apps)
- [X] T013 [P] [US1] Create system/shared/family/gnome/settings/desktop/gnome-optional.nix (control dev tools, games)
- [X] T014 [P] [US1] Create system/shared/family/gnome/settings/desktop/gnome-exclude.nix (remove unwanted packages)
- [X] T015 [US1] Delete system/shared/family/gnome/app/utility/nautilus.nix (redundant with core-apps)

**Validation**:

```bash
# Verify modules created
test -f system/shared/family/gnome/settings/desktop/default.nix
test -f system/shared/family/gnome/settings/desktop/gnome-core.nix
test -f system/shared/family/gnome/settings/desktop/gnome-optional.nix
test -f system/shared/family/gnome/settings/desktop/gnome-exclude.nix

# Verify nautilus removed
! test -f system/shared/family/gnome/app/utility/nautilus.nix

# Test GNOME desktop enabled
nix eval .#nixosConfigurations.test-host.config.services.xserver.desktopManager.gnome.enable
# Expected: true
```

**Dependencies**: Phase 2 (Foundational)

______________________________________________________________________

## Phase 5: User Story 2 - System-Level GNOME Configuration

**Story**: GNOME desktop uses system-level options (not user-level) for proper integration

**Goal**: Ensure GNOME family settings use NixOS system options and are platform-agnostic

**Independent Test Criteria**:

- [ ] Family modules use `services.xserver.*` (NixOS options)
- [ ] No platform-specific code in family modules (no `if NixOS then...`)
- [ ] GDM (GNOME Display Manager) configured at system level
- [ ] Auto-discovered by `gnome/settings/default.nix`

**Tasks**:

- [X] T016 [US2] Verify gnome-core.nix uses services.xserver.desktopManager.gnome.enable
- [X] T017 [US2] Verify gnome-core.nix configures GDM at system level
- [X] T018 [US2] Ensure all desktop modules use lib.mkDefault for user-overridability

**Validation**:

```bash
# Verify system-level options used
grep "services.xserver.desktopManager.gnome.enable" \
  system/shared/family/gnome/settings/desktop/gnome-core.nix

# Verify no platform-specific code in family
! grep -r "stdenv.isLinux\|stdenv.isDarwin" \
  system/shared/family/gnome/settings/desktop/

# Test GDM enabled
nix eval .#nixosConfigurations.test-host.config.services.xserver.displayManager.gdm.enable
# Expected: true
```

**Dependencies**: Phase 4 (US1)

______________________________________________________________________

## Phase 6: User Story 3 - Wayland Configuration

**Story**: Wayland configured as the display server for modern graphics and performance

**Goal**: Enable Wayland session with GDM and proper environment variables

**Independent Test Criteria**:

- [ ] `wayland.nix` module created in `gnome/settings/`
- [ ] GDM Wayland enabled (`services.xserver.displayManager.gdm.wayland = true`)
- [ ] `NIXOS_OZONE_WL=1` set for Electron apps
- [ ] Platform-agnostic (uses generic NixOS options)

**Tasks**:

- [X] T019 [P] [US3] Create system/shared/family/gnome/settings/wayland.nix module
- [X] T020 [US3] Configure GDM Wayland in wayland.nix (services.xserver.displayManager.gdm.wayland)
- [X] T021 [US3] Set NIXOS_OZONE_WL environment variable for Electron app support

**Validation**:

```bash
# Verify module created
test -f system/shared/family/gnome/settings/wayland.nix

# Test Wayland enabled
nix eval .#nixosConfigurations.test-host.config.services.xserver.displayManager.gdm.wayland
# Expected: true

# Test environment variable
nix eval .#nixosConfigurations.test-host.config.environment.sessionVariables.NIXOS_OZONE_WL
# Expected: "1"
```

**Dependencies**: Phase 4 (US1), Phase 5 (US2)

______________________________________________________________________

## Phase 7: User Story 4 - Global Shortcuts

**Story**: Ctrl+Alt+Space configured as global shortcut for application launcher

**Goal**: Set up GNOME Shell keybindings for quick application access

**Independent Test Criteria**:

- [ ] `shortcuts.nix` module created in `gnome/settings/`
- [ ] Ctrl+Alt+Space bound to `toggle-overview` via dconf
- [ ] Uses correct dconf schema (`org.gnome.shell.keybindings`)
- [ ] User-level configuration (dconf settings in home-manager)

**Tasks**:

- [X] T022 [P] [US4] Create system/shared/family/gnome/settings/shortcuts.nix module
- [X] T023 [US4] Configure Ctrl+Alt+Space → toggle-overview in dconf.settings
- [X] T024 [US4] Add module header documentation with keybinding reference

**Validation**:

```bash
# Verify module created
test -f system/shared/family/gnome/settings/shortcuts.nix

# Test keybinding configured
nix eval .#nixosConfigurations.test-host.config.home-manager.users.testuser.dconf.settings \
  | jq '."org/gnome/shell/keybindings"."toggle-overview"'
# Expected: ["<Ctrl><Alt>space"]
```

**Dependencies**: Phase 2 (Foundational)

______________________________________________________________________

## Phase 8: User Story 5 - System Tray Integration

**Story**: System tray properly configured with per-app GNOME Shell extensions

**Goal**: Ensure applications can declare their own GNOME Shell extensions (no centralized systray.nix)

**Independent Test Criteria**:

- [ ] No centralized systray.nix file
- [ ] Apps declare GNOME Shell extensions in their own modules
- [ ] Extension pattern documented for app authors

**Tasks**:

- [ ] T025 [US5] Document GNOME Shell extension pattern in system/shared/family/gnome/app/README.md

**Validation**:

```bash
# Verify no centralized systray file
! test -f system/shared/family/gnome/settings/systray.nix
! test -f system/shared/family/gnome/app/systray.nix

# Verify README exists with extension pattern
test -f system/shared/family/gnome/app/README.md
grep "GNOME Shell extensions" system/shared/family/gnome/app/README.md
```

**Dependencies**: None (documentation only)

______________________________________________________________________

## Phase 9: Polish & Documentation

**Goal**: Complete documentation, validation, and final testing

**Tasks**:

- [X] T026 [P] Update CLAUDE.md with cross-platform family architecture documentation
- [X] T027 [P] Create docs/features/028-gnome-family-system-integration.md user documentation
- [X] T028 Run `nix flake check` to validate all modules
- [ ] T029 Test full GNOME desktop installation on NixOS host with family = ["gnome"]

**Completion Criteria**:

- All documentation updated
- `nix flake check` passes
- Full integration test succeeds
- Ready for deployment

______________________________________________________________________

## Dependency Graph

### Story Completion Order

```
Phase 1 (Setup)
  ↓
Phase 2 (Foundational) ← BLOCKING for all user stories
  ↓
  ├─→ Phase 3 (US0) - Family App Discovery
  ├─→ Phase 4 (US1) - GNOME Desktop Settings
  │     ↓
  │   Phase 5 (US2) - System-Level Config
  │     ↓
  │   Phase 6 (US3) - Wayland
  ├─→ Phase 7 (US4) - Global Shortcuts
  └─→ Phase 8 (US5) - System Tray (documentation)
  ↓
Phase 9 (Polish)
```

### Critical Path

1. Phase 2 (Foundational) - MUST complete first
1. Phase 4 (US1) - Desktop settings foundation
1. Phase 5 (US2) - System-level verification
1. Phase 6 (US3) - Wayland depends on US1+US2
1. Phase 9 (Polish) - Final validation

### Parallel Opportunities

**After Phase 2 completes**, these can run in parallel:

- Phase 3 (US0) - Independent
- Phase 4 (US1) - Independent
- Phase 7 (US4) - Independent
- Phase 8 (US5) - Independent

**After Phase 4 completes**, these can run in parallel:

- Phase 5 (US2) - Verification tasks
- Continue Phase 3, 7, 8 if still in progress

______________________________________________________________________

## Parallel Execution Examples

### Maximum Parallelization (After Phase 2)

```bash
# Terminal 1: US0 - Family App Discovery
git checkout -b feat/us0-app-discovery
# Complete T006-T009

# Terminal 2: US1 - GNOME Desktop Settings
git checkout -b feat/us1-desktop-settings
# Complete T010-T015

# Terminal 3: US4 - Global Shortcuts
git checkout -b feat/us4-shortcuts
# Complete T022-T024

# Terminal 4: US5 - System Tray
git checkout -b feat/us5-systray
# Complete T025
```

**Merge Order**: Any order (all independent after Phase 2)

### Sequential with Validation Points

```bash
# 1. Foundational (MUST BE FIRST)
# Complete T003-T005
nix flake check  # Validate

# 2. US1 - Desktop Settings
# Complete T010-T015
nix flake check  # Validate

# 3. US2 - System-Level Config
# Complete T016-T018
nix eval .#nixosConfigurations.test-host.config.services.xserver  # Test

# 4. US3 - Wayland
# Complete T019-T021
nix flake check  # Validate

# 5. US0, US4, US5 in parallel
# Complete remaining stories

# 6. Polish
# Complete T026-T029
```

______________________________________________________________________

## Implementation Strategy

### Minimum Viable Product (MVP)

**Scope**: User Story 1 only (GNOME Desktop in settings/desktop/)

**Tasks**: Phase 1, Phase 2, Phase 4 (T001-T015)

**Deliverable**: GNOME desktop environment installable via `family = ["gnome"]`

**Validation**:

```bash
# Create test host
cat > system/nixos/host/test-gnome/default.nix <<EOF
{
  name = "test-gnome";
  family = ["gnome"];
  applications = [];
  settings = ["default"];
}
EOF

# Build
nix build .#nixosConfigurations.testuser-test-gnome.config.system.build.toplevel

# Deploy and test
# GNOME desktop should be available
```

### Full Feature Delivery

**Scope**: All user stories (US0-US5)

**Phases**: 1-9 (all tasks T001-T029)

**Deliverables**:

- Complete GNOME desktop environment
- Family app discovery without default.nix
- Wayland support
- Global shortcuts (Ctrl+Alt+Space)
- System tray documentation
- Full documentation

### Incremental Delivery Checkpoints

1. **Checkpoint 1** (After Phase 4): GNOME desktop installable
1. **Checkpoint 2** (After Phase 5): System-level config verified
1. **Checkpoint 3** (After Phase 6): Wayland working
1. **Checkpoint 4** (After Phase 7): Shortcuts configured
1. **Checkpoint 5** (After Phase 9): Production ready

______________________________________________________________________

## Testing Commands

### Syntax Validation

```bash
# Check all Nix files
nix flake check

# Format Nix files
just fmt

# Check specific module
nix-instantiate --parse system/shared/family/gnome/settings/desktop/gnome-core.nix
```

### Configuration Evaluation

```bash
# Evaluate GNOME desktop enabled
nix eval .#nixosConfigurations.HOST.config.services.xserver.desktopManager.gnome.enable

# Evaluate home-manager packages
nix eval .#nixosConfigurations.HOST.config.home-manager.users.USER.home.packages

# Check for gnome-tweaks (family app)
nix eval --json .#nixosConfigurations.HOST.config.home-manager.users.USER.home.packages \
  | jq 'map(select(.name | contains("gnome-tweaks")))'
```

### Build Tests

```bash
# Build NixOS configuration
nix build .#nixosConfigurations.USER-HOST.config.system.build.toplevel

# Build home-manager configuration
nix build .#nixosConfigurations.USER-HOST.config.home-manager.users.USER.home.activationPackage
```

### Integration Tests

```bash
# Full build and deploy
just install USER HOST

# Verify GNOME desktop after reboot
echo $XDG_SESSION_TYPE  # Should output: wayland
gnome-shell --version   # Should show GNOME version
```

______________________________________________________________________

## Notes

### Constitutional Compliance

- All modules MUST be \<200 lines per constitutional requirement
- Use `lib.mkDefault` for all options (user-overridable)
- Include module header documentation
- Platform-agnostic design (no `if NixOS then...` in family modules)

### Platform-Agnostic Design

Family modules should use generic NixOS options:

```nix
# GOOD (platform-agnostic)
services.xserver.desktopManager.gnome.enable = lib.mkDefault true;

# BAD (platform-specific)
if pkgs.stdenv.isLinux then
  services.xserver.desktopManager.gnome.enable = true
else
  throw "GNOME only on Linux";
```

### Breaking Changes

This feature includes breaking changes:

- Removes `gnome/app/default.nix` and `linux/app/default.nix`
- Moves `nautilus.nix` from `app/` to `settings/desktop/` (then deletes it)
- Changes family app discovery from auto-import to hierarchical

**Migration Path**: Document in CLAUDE.md and docs/

______________________________________________________________________

## Success Criteria

All tasks completed when:

- [ ] All 29 tasks checked off
- [ ] `nix flake check` passes
- [ ] GNOME desktop installs system-wide with `family = ["gnome"]`
- [ ] Family apps discovered hierarchically (user-selected)
- [ ] Wayland session works
- [ ] Shortcuts configured (Ctrl+Alt+Space)
- [ ] Documentation complete
- [ ] No constitutional violations
