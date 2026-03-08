# Tasks: GNOME Dock Module

**Feature**: 024-gnome-dock-module
**Generated**: 2025-12-19
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

Implements GNOME dock configuration using the same `user.docked` syntax as Darwin. Reuses the shared parsing library from Feature 023 and creates GNOME-specific resolution and activation modules.

______________________________________________________________________

## Phase 1: Setup & Directory Structure

### Task 1.1: Verify GNOME Family Directory Structure

- [x] Confirm `system/shared/family/gnome/` directory exists
- [x] Confirm `system/shared/family/gnome/lib/` directory exists (create if needed)
- [x] Confirm `system/shared/family/gnome/settings/` directory exists (create if needed)

**Acceptance**: Directory structure ready for new modules

### Task 1.2: Verify Shared Library Availability

- [x] Confirm `system/shared/lib/dock.nix` exists and exports expected functions
- [x] Document import path for GNOME modules

**Acceptance**: Shared parsing library accessible

______________________________________________________________________

## Phase 2: GNOME Library Module

### Task 2.1: Create GNOME Dock Library

- [x] Create `system/shared/family/gnome/lib/dock.nix`
- [x] Add module header documentation
- [x] Import shared parsing library from `system/shared/lib/dock.nix`

**File**: `system/shared/family/gnome/lib/dock.nix`
**Acceptance**: Module created with proper imports

### Task 2.2: Implement Desktop File Resolution

- [x] Implement `resolveDesktopFile` function
- [x] Search XDG directories in priority order:
  1. `~/.local/share/applications/`
  1. `/run/current-system/sw/share/applications/`
  1. `/usr/share/applications/`
- [x] Support exact match (e.g., `firefox.desktop`)
- [x] Support org-prefix match (e.g., `org.mozilla.firefox.desktop`)
- [x] Support partial match (e.g., `*firefox*.desktop`)
- [x] Return first match or null

**Acceptance**: FR-003, FR-004, FR-005 satisfied

### Task 2.3: Implement GNOME Entry Filtering

- [x] Implement `isGnomeSupported` predicate function
- [x] Return true for `type == "app"`
- [x] Return true for `type == "system"` AND `value == "trash"`
- [x] Return false for all other entries (separators, folders, unknown system items)

**Acceptance**: FR-009, FR-010 satisfied - unsupported items filtered out

### Task 2.4: Implement Favorites Generation

- [x] Implement `mkFavoritesFromDocked` function
- [x] Parse docked list using shared library
- [x] Filter to GNOME-supported entries only
- [x] Resolve each app name to .desktop filename
- [x] Filter out unresolved entries (null results)
- [x] Remove duplicates (keep first occurrence)
- [x] Return list of .desktop filenames

**Acceptance**: Converts `user.docked` to GNOME favorites array

### Task 2.5: Implement Trash Detection Helper

- [x] Implement `hasTrash` function
- [x] Check if any entry has `type == "system"` AND `value == "trash"`
- [x] Return boolean

**Acceptance**: Helper ready for trash.desktop conditional creation

______________________________________________________________________

## Phase 3: GNOME Settings Module

### Task 3.1: Create GNOME Dock Settings Module

- [x] Create `system/shared/family/gnome/settings/dock.nix`
- [x] Add module header documentation
- [x] Import GNOME dock library
- [x] Accept standard module arguments (`{ config, pkgs, lib, ... }`)

**File**: `system/shared/family/gnome/settings/dock.nix`
**Acceptance**: FR-002 satisfied - module created

### Task 3.2: Read User Dock Configuration

- [x] Extract `user.docked` from user config (via config path)
- [x] Handle case where `user.docked` is empty or not defined
- [x] Implement `hasDockConfig` check

**Acceptance**: FR-013 satisfied - empty config handled

### Task 3.3: Generate dconf Settings

- [x] Use `dconf.settings` option for GNOME favorites
- [x] Set path `org/gnome/shell` with `favorite-apps` key
- [x] Use `lib.mkIf hasDockConfig` to conditionally apply
- [x] Pass resolved favorites array

**Acceptance**: FR-006 satisfied - favorites set via dconf

### Task 3.4: Create Trash Desktop File

- [x] Use `home.file` to create `~/.local/share/applications/trash.desktop`
- [x] Use `lib.mkIf hasTrash` to only create when needed
- [x] Include required desktop entry fields:
  - `Type=Application`
  - `Name=Trash`
  - `Icon=user-trash-full`
  - `Exec=nautilus trash://`
- [x] Include optional fields: `Comment`, `Categories`, `StartupNotify`

**Acceptance**: FR-007, FR-008 satisfied - trash.desktop created correctly

______________________________________________________________________

## Phase 4: User Story 1 - Apps in GNOME Dock (P1)

### Task 4.1: Test Basic App Resolution

- [x] Create test configuration with `docked = ["firefox" "nautilus" "terminal"]`
- [x] Verify all three apps resolve to .desktop filenames
- [x] Verify favorites array contains correct entries

**Acceptance**: US1 Scenario 1 - apps appear as favorites

### Task 4.2: Test Missing App Handling

- [x] Create test configuration with `docked = ["firefox" "nonexistent" "terminal"]`
- [x] Verify nonexistent app is silently skipped
- [x] Verify Firefox and Terminal appear in favorites

**Acceptance**: US1 Scenario 2 - missing apps skipped

### Task 4.3: Test Empty Dock Array

- [x] Create test configuration with `docked = []`
- [x] Verify dconf settings not applied (no favorites modification)

**Acceptance**: US1 Scenario 3 - empty array handled

______________________________________________________________________

## Phase 5: User Story 2 - Trash in Dock (P2)

### Task 5.1: Test Trash in Favorites

- [x] Create test configuration with `docked = ["firefox" "<trash>"]`
- [x] Verify trash.desktop is created
- [x] Verify `trash.desktop` appears in favorites array
- [x] Verify order is correct (Firefox, then Trash)

**Acceptance**: US2 Scenario 1 - trash appears in dock

### Task 5.2: Test Trash Position

- [x] Create test configuration with `docked = ["<trash>" "firefox"]`
- [x] Verify Trash appears before Firefox in favorites

**Acceptance**: US2 Scenario 2 - trash position respected

### Task 5.3: Test No Trash Creation

- [x] Create test configuration without `<trash>`
- [x] Verify trash.desktop is NOT created

**Acceptance**: US2 Scenario 3 - no unnecessary file creation

______________________________________________________________________

## Phase 6: User Story 3 - Graceful Degradation (P2)

### Task 6.1: Test Separator Handling

- [x] Create test configuration with `docked = ["firefox" "|" "terminal"]`
- [x] Verify separator is silently ignored
- [x] Verify only Firefox and Terminal in favorites

**Acceptance**: US3 Scenario 1 - separators ignored

### Task 6.2: Test Folder Handling

- [x] Create test configuration with `docked = ["/Downloads" "firefox"]`
- [x] Verify folder is silently ignored
- [x] Verify only Firefox in favorites

**Acceptance**: US3 Scenario 2 - folders ignored

### Task 6.3: Test Thick Separator Handling

- [x] Create test configuration with `docked = ["firefox" "||" "terminal"]`
- [x] Verify thick separator is silently ignored
- [x] Verify only Firefox and Terminal in favorites

**Acceptance**: US3 Scenario 3 - thick separators ignored

### Task 6.4: Test Darwin-Specific System Items

- [x] Create test configuration with `docked = ["firefox" "<launchpad>" "terminal"]`
- [x] Verify `<launchpad>` is silently ignored
- [x] Verify only Firefox and Terminal in favorites

**Acceptance**: Unknown system items ignored

______________________________________________________________________

## Phase 7: Integration & Validation

### Task 7.1: Verify Module Size

- [x] Run line count on `system/shared/family/gnome/lib/dock.nix`
- [x] Confirm under 200 lines (constitutional requirement)
- [x] Run line count on `system/shared/family/gnome/settings/dock.nix`
- [x] Confirm under 200 lines

**Acceptance**: SC-005 satisfied

### Task 7.2: Run Flake Check

- [x] Execute `nix flake check`
- [x] Fix any evaluation errors
- [x] Verify no warnings

**Acceptance**: Configuration evaluates without errors

### Task 7.3: Verify Cross-Platform Compatibility

- [x] Confirm same `user.docked` config works on Darwin
- [x] Confirm same `user.docked` config works on GNOME
- [x] Document any platform-specific differences

**Acceptance**: SC-001 satisfied

______________________________________________________________________

## Phase 8: Documentation & Polish

### Task 8.1: Update CLAUDE.md

- [x] Add GNOME dock module to Active Technologies if needed
- [x] Document GNOME-specific behavior in dock section

### Task 8.2: Update User Documentation

- [x] Update `docs/features/023-user-dock-config.md` with GNOME information
- [x] Document platform differences (separators, folders not supported on GNOME)
- [x] Add GNOME-specific examples

### Task 8.3: Final Review

- [x] Review all new files for proper documentation headers
- [x] Verify imports are correct
- [x] Commit changes with descriptive message

**Acceptance**: Feature complete and documented

______________________________________________________________________

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| 1 | 2 | Setup & verification |
| 2 | 5 | GNOME dock library |
| 3 | 4 | GNOME settings module |
| 4 | 3 | User Story 1 (P1) |
| 5 | 3 | User Story 2 (P2) |
| 6 | 4 | User Story 3 (P2) |
| 7 | 3 | Integration & validation |
| 8 | 3 | Documentation & polish |

**Total**: 27 tasks across 8 phases
