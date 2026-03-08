# Tasks: NixOS Settings Modules

**Feature**: 025-nixos-settings-modules
**Generated**: 2025-12-20
**Completed**: 2025-12-21
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

Create NixOS settings modules inspired by Darwin, with Linux family keyboard remapping and GNOME desktop settings. All use the auto-discovery pattern.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Verify directory structure and shared library availability

- [x] T001 Verify `system/nixos/settings/` directory exists (create if needed)
- [x] T002 [P] Verify `system/shared/family/linux/settings/` directory exists (create if needed)
- [x] T003 [P] Verify `system/shared/lib/discovery.nix` is available for auto-discovery

**Checkpoint**: Directory structure ready for module creation ✅

______________________________________________________________________

## Phase 2: User Story 1 - NixOS Core System Settings (Priority: P1)

**Goal**: NixOS machines have sensible default settings for security, networking, and system behavior

**Independent Test**: Build NixOS configuration, verify security/network/locale defaults applied

### Implementation

- [x] T004 [US1] Create auto-discovery `system/nixos/settings/default.nix`
- [x] T005 [P] [US1] Create `system/nixos/settings/security.nix` with firewall, sudo, polkit
- [x] T006 [P] [US1] Create `system/nixos/settings/locale.nix` reading user.timezone and user.locale
- [x] T007 [P] [US1] Create `system/nixos/settings/keyboard.nix` with repeat rate matching Darwin
- [x] T008 [P] [US1] Create `system/nixos/settings/network.nix` with NetworkManager defaults
- [x] T009 [P] [US1] Create `system/nixos/settings/system.nix` with boot, Nix settings, GC

**Checkpoint**: NixOS core settings complete and independently testable ✅

______________________________________________________________________

## Phase 3: User Story 2 - Linux Keyboard Layout Matching Mac (Priority: P1)

**Goal**: Linux systems have Mac-style keyboard modifier remapping for cross-platform consistency

**Independent Test**: Deploy with `family = ["linux"]`, verify Super/Ctrl swapped to match Mac layout

### Implementation

- [x] T010 [US2] Create auto-discovery `system/shared/family/linux/settings/default.nix`
- [x] T011 [US2] Create `system/shared/family/linux/settings/keyboard.nix` with Mac-style XKB remapping

**Checkpoint**: Linux keyboard remapping complete and independently testable ✅

______________________________________________________________________

## Phase 4: User Story 3 - GNOME Desktop Settings (Priority: P2)

**Goal**: GNOME desktops have consistent UI, keyboard, and power settings via dconf

**Independent Test**: Deploy with `family = ["gnome"]`, verify dconf settings applied

### Implementation

- [x] T012 [US3] Update `system/shared/family/gnome/settings/default.nix` with auto-discovery pattern
- [x] T013 [P] [US3] Create `system/shared/family/gnome/settings/ui.nix` with dark mode, fonts, animations
- [x] T014 [P] [US3] Create `system/shared/family/gnome/settings/keyboard.nix` with shortcuts, input sources
- [x] T015 [P] [US3] Create `system/shared/family/gnome/settings/power.nix` with screen timeout, suspend

**Checkpoint**: GNOME settings complete and independently testable ✅

______________________________________________________________________

## Phase 5: User Story 4 - Auto-Discovery Pattern (Priority: P1)

**Goal**: New settings modules are automatically discovered without manual import updates

**Independent Test**: Add a test `.nix` file, verify it's imported on next build

### Validation

- [x] T016 [US4] Verify NixOS settings auto-discovery works (add test file, build, remove)
- [x] T017 [P] [US4] Verify Linux family settings auto-discovery works
- [x] T018 [P] [US4] Verify GNOME family settings auto-discovery works

**Checkpoint**: Auto-discovery validated across all settings directories ✅

______________________________________________________________________

## Phase 6: Integration & Validation

**Purpose**: Verify all modules work together and meet constitutional requirements

- [x] T019 Run `nix flake check` and fix any errors
- [x] T020 [P] Verify all modules are under 200 lines (constitutional requirement)
- [x] T021 [P] Verify Darwin configurations still work unchanged
- [x] T022 Update CLAUDE.md with new NixOS/Linux/GNOME settings info

**Checkpoint**: All settings modules validated and documented ✅

______________________________________________________________________

## Phase 7: Documentation & Polish

**Purpose**: User documentation and final cleanup

- [x] T023 Create `docs/features/025-nixos-settings-modules.md` with usage guide
- [x] T024 [P] Update `specs/025-nixos-settings-modules/quickstart.md` if needed
- [x] T025 Commit all changes with descriptive message

**Checkpoint**: Feature complete and documented ✅

______________________________________________________________________

## Summary

| Phase | Tasks | Focus | Status |
|-------|-------|-------|--------|
| 1 | 3 | Setup | ✅ Complete |
| 2 | 6 | NixOS Core (US1) | ✅ Complete |
| 3 | 2 | Linux Keyboard (US2) | ✅ Complete |
| 4 | 4 | GNOME (US3) | ✅ Complete |
| 5 | 3 | Auto-Discovery (US4) | ✅ Complete |
| 6 | 4 | Integration | ✅ Complete |
| 7 | 3 | Documentation | ✅ Complete |

**Total**: 25 tasks across 7 phases - **ALL COMPLETE**
