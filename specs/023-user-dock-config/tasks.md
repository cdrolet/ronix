# Tasks: User Dock Configuration

**Input**: Design documents from `/specs/023-user-dock-config/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested - manual activation testing per quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## User Stories (from spec.md)

| Story | Priority | Description |
|-------|----------|-------------|
| US1 | P1 | Define Dock Items in User Config |
| US2 | P2 | Visual Separators |
| US3 | P2 | Graceful Missing Item Handling |
| US4 | P3 | Trash in Dock |

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Add user option and shared parsing utilities

- [x] T001 Add `docked` option to user module in `user/shared/lib/home-manager.nix`
- [x] T002 [P] Create shared dock parsing library at `system/shared/lib/dock.nix`

______________________________________________________________________

## Phase 2: Foundational (Darwin Core)

**Purpose**: Core Darwin infrastructure that enables all user stories

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Add `resolveAppPath` function to `system/darwin/lib/dock.nix`
- [x] T004 Add `resolveFolderPath` function to `system/darwin/lib/dock.nix`
- [x] T005 Add `mkDockFromUserConfig` function to `system/darwin/lib/dock.nix`
- [x] T006 Modify `system/darwin/settings/dock.nix` to read `user.docked` from config
- [x] T007 Remove hardcoded app list from `system/darwin/settings/dock.nix`

**Checkpoint**: Darwin dock module now reads from user config instead of hardcoded values

______________________________________________________________________

## Phase 3: User Story 1 - Define Dock Items in User Config (Priority: P1)

**Goal**: Users can specify applications and folders in `docked` array, dock displays them in order

**Independent Test**: Add `docked = ["zen" "brave" "/Downloads"]` to user config, run `just install`, verify dock shows those items

### Implementation for User Story 1

- [x] T008 [US1] Implement case-insensitive app name matching in `system/darwin/lib/dock.nix`
- [x] T009 [US1] Implement folder fallback resolution ($HOME first, then absolute) in `system/darwin/lib/dock.nix`
- [x] T010 [US1] Add dock item ordering by array position in `system/darwin/lib/dock.nix`
- [x] T011 [US1] Update user `cdrokar` config with sample `docked` array in `user/cdrokar/default.nix`
- [x] T012 [US1] Test: Run `just build cdrokar home-macmini-m4` and verify no errors
- [x] T013 [US1] Test: Run `just install cdrokar home-macmini-m4` and verify dock displays correct items

**Checkpoint**: User Story 1 complete - apps and folders appear in dock from user config

______________________________________________________________________

## Phase 4: User Story 2 - Visual Separators (Priority: P2)

**Goal**: Users can add `|` and `||` to create visual separators between dock groups

**Independent Test**: Add `docked = ["zen" "|" "zed"]` and verify separator appears between apps

### Implementation for User Story 2

- [x] T014 [US2] Add separator detection (`|` and `||`) to parsing in `system/shared/lib/dock.nix`
- [x] T015 [US2] Implement `mkDockAddSpacer` call for `|` entries in `system/darwin/lib/dock.nix`
- [x] T016 [US2] Implement thick spacer (small-spacer) for `||` entries in `system/darwin/lib/dock.nix`
- [x] T017 [US2] Test: Update `user/cdrokar/default.nix` with separators and verify visual grouping

**Checkpoint**: User Story 2 complete - separators visually group dock items

______________________________________________________________________

## Phase 5: User Story 3 - Graceful Missing Item Handling (Priority: P2)

**Goal**: Missing applications or folders are silently skipped without errors

**Independent Test**: Add `docked = ["zen" "nonexistent-app" "brave"]` and verify only Zen and Brave appear

### Implementation for User Story 3

- [x] T018 [US3] Add null-safe resolution in `resolveAppPath` (return null if not found) in `system/darwin/lib/dock.nix`
- [x] T019 [US3] Add null-safe resolution in `resolveFolderPath` (return null if not found) in `system/darwin/lib/dock.nix`
- [x] T020 [US3] Filter out null entries before generating activation script in `system/darwin/lib/dock.nix`
- [x] T021 [US3] Implement consecutive separator collapsing in `system/shared/lib/dock.nix`
- [x] T022 [US3] Implement leading/trailing separator removal in `system/shared/lib/dock.nix`
- [x] T023 [US3] Test: Add nonexistent app to `docked`, verify no errors and app is skipped

**Checkpoint**: User Story 3 complete - missing items silently skipped

______________________________________________________________________

## Phase 6: User Story 4 - Trash in Dock (Priority: P3)

**Goal**: Users can include `<trash>` in dock (no-op on darwin, functional on GNOME)

**Independent Test**: Add `docked = ["zen" "<trash>"]` and verify no errors (darwin ignores it)

### Implementation for User Story 4

- [x] T024 [US4] Add system item detection (`<name>` pattern) to parsing in `system/shared/lib/dock.nix`
- [x] T025 [US4] Implement `<trash>` as no-op on darwin in `system/darwin/lib/dock.nix`
- [x] T026 [US4] Add skip logic for unrecognized system items in `system/darwin/lib/dock.nix`
- [x] T027 [US4] Test: Add `<trash>` to `docked`, verify darwin activation succeeds

**Checkpoint**: User Story 4 complete - system items handled per platform

______________________________________________________________________

## Phase 7: GNOME Implementation (Future)

**Purpose**: Extend dock configuration to GNOME desktop

**Note**: Lower priority - can be implemented after darwin is complete

- [ ] T028 [P] Create GNOME dock library at `system/shared/family/gnome/lib/dock.nix`
- [ ] T029 [P] Create GNOME dock settings at `system/shared/family/gnome/settings/dock.nix`
- [ ] T030 Implement `.desktop` file resolution in `system/shared/family/gnome/lib/dock.nix`
- [ ] T031 Implement gsettings activation for favorite-apps in `system/shared/family/gnome/settings/dock.nix`
- [ ] T032 Implement trash.desktop creation for `<trash>` in `system/shared/family/gnome/lib/dock.nix`

**Checkpoint**: GNOME dock configuration functional

______________________________________________________________________

## Phase 8: Polish & Documentation

**Purpose**: Final cleanup and documentation

- [x] T033 [P] Update `CLAUDE.md` with dock configuration documentation
- [x] T034 [P] Create user documentation at `docs/features/023-user-dock-config.md`
- [x] T035 Verify module size \<200 lines, refactor if needed
- [x] T036 Run `nix flake check` to validate all configurations
- [x] T037 Run quickstart.md validation scenarios

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Core functionality - implement first
  - US2 (P2): Can proceed after US1
  - US3 (P2): Can proceed after US1
  - US4 (P3): Can proceed after US1
- **GNOME (Phase 7)**: Independent of Darwin stories, but requires Phase 1-2
- **Polish (Phase 8)**: Depends on at least US1-US3 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends on Foundational only - MVP
- **User Story 2 (P2)**: Enhances US1 (separators between items)
- **User Story 3 (P2)**: Hardens US1 (error handling)
- **User Story 4 (P3)**: Extends US1 (system items)

### Parallel Opportunities

Within each phase, tasks marked [P] can run in parallel:

- T001 and T002 can run in parallel (Phase 1)
- T028 and T029 can run in parallel (Phase 7)
- T033 and T034 can run in parallel (Phase 8)

______________________________________________________________________

## Parallel Example: Setup Phase

```bash
# Launch both setup tasks together:
Task: "Add docked option to user module in user/shared/lib/home.nix"
Task: "Create shared dock parsing library at system/shared/lib/dock.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
1. Complete Phase 2: Foundational
1. Complete Phase 3: User Story 1
1. **STOP and VALIDATE**: Test with `just install`
1. Commit and document

### Incremental Delivery

1. Setup + Foundational → Foundation ready
1. Add User Story 1 → Test → MVP complete
1. Add User Story 2 → Test → Separators work
1. Add User Story 3 → Test → Error handling robust
1. Add User Story 4 → Test → System items supported
1. (Optional) Add GNOME support
1. Polish and document

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Darwin implementation is primary focus
- GNOME implementation is secondary/future
- No automated tests requested - use manual activation testing
- Commit after each phase completion
