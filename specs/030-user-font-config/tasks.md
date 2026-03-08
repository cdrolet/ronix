# Tasks: User Font Configuration

**Feature**: 030-user-font-config
**Branch**: `030-user-font-config`
**Input**: Design documents from `/specs/030-user-font-config/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Task Summary

- **Total Tasks**: 21
- **Setup Phase**: 2 tasks
- **Foundational Phase**: 3 tasks (BLOCKING)
- **User Story 1 (P1)**: 4 tasks - Declare Fonts in User Config
- **User Story 2 (P2)**: 5 tasks - Private Font Repositories
- **User Story 3 (P3)**: 3 tasks - Desktop Font Configuration
- **User Story 4 (P4)**: 2 tasks - Apps Reference Default Font
- **Polish Phase**: 2 tasks

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Verify prerequisites and understand current structure

- [X] T001 Read current user schema in user/shared/lib/home-manager.nix
- [X] T002 [P] Read existing GNOME settings pattern in system/shared/family/gnome/settings/ui.nix

______________________________________________________________________

## Phase 2: Foundational (BLOCKING)

**Purpose**: Add fonts option to user schema - MUST complete before ANY user story

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Add `fonts` option with submodule type to user/shared/lib/home-manager.nix
- [X] T004 Add `fonts.default` field (type: nullOr str) to user/shared/lib/home-manager.nix
- [X] T005 Add `fonts.packages` and `fonts.repositories` fields (type: listOf str) to user/shared/lib/home-manager.nix

**Validation**:

```bash
nix flake check
```

**Checkpoint**: Schema ready - user story implementation can now begin

______________________________________________________________________

## Phase 3: User Story 1 - Declare Fonts in User Config (Priority: P1) MVP

**Goal**: Users can declare fonts.packages and have them installed via Home Manager

**Independent Test**:

1. Add `fonts.packages = ["fira-code"];` to a user config
1. Run `just build <user> <host>`
1. Verify fira-code package is in home.packages

### Implementation for User Story 1

- [X] T006 [US1] Create system/shared/settings/fonts.nix with basic module structure
- [X] T007 [US1] Implement font package installation via home.packages in system/shared/settings/fonts.nix
- [X] T008 [US1] Add logic to include fonts.default in packages list if not already present in system/shared/settings/fonts.nix
- [X] T009 [US1] Import fonts.nix in system/shared/settings/default.nix

**Checkpoint**: Users can declare fonts.packages and have them installed

______________________________________________________________________

## Phase 4: User Story 2 - Private Font Repositories (Priority: P2)

**Goal**: Users with sshKeys.fonts can clone private font repos; others skip silently

**Independent Test**:

1. Set `sshKeys.fonts = "<secret>"` and `fonts.repositories = ["git@github.com:cdrolet/d-fonts.git"]`
1. Run activation
1. Verify repo cloned to ~/.local/share/fonts/private/

### Implementation for User Story 2

- [X] T010 [US2] Update system/shared/app/security/ssh.nix to deploy sshKeys.fonts to ~/.ssh/id_fonts
- [X] T011 [US2] Add activation script to clone/update private repos in system/shared/settings/fonts.nix
- [X] T012 [US2] Implement silent skip when sshKeys.fonts is not configured in system/shared/settings/fonts.nix
- [X] T013 [US2] Add logic to symlink font files from cloned repos to user font directory in system/shared/settings/fonts.nix
- [X] T014 [US2] Add font cache refresh (fc-cache) for Linux in system/shared/settings/fonts.nix

**Checkpoint**: Private font repos clone with deploy key, skip without

______________________________________________________________________

## Phase 5: User Story 3 - Desktop Font Configuration (Priority: P3)

**Goal**: Default font configured on GNOME; Darwin placeholder created

**Independent Test**:

1. Set `fonts.default = "fira-code"` on GNOME system
1. Run activation
1. Verify `gsettings get org.gnome.desktop.interface monospace-font-name` shows Fira Code

### Implementation for User Story 3

- [X] T015 [US3] Create system/shared/family/gnome/settings/fonts.nix with dconf monospace font configuration
- [X] T016 [US3] Add font name mapping (package name → font family name) in system/shared/family/gnome/settings/fonts.nix
- [X] T017 [US3] Create system/darwin/settings/fonts.nix as placeholder (no-op with comment explaining limitation)

**Checkpoint**: GNOME monospace font configured from fonts.default

______________________________________________________________________

## Phase 6: User Story 4 - Apps Reference Default Font (Priority: P4)

**Goal**: App modules can use config.user.fonts.default for consistent font configuration

**Independent Test**:

1. Set `fonts.default = "fira-code"` in user config
1. Check an app module uses this value with fallback

### Implementation for User Story 4

- [X] T018 [US4] Update one example app (e.g., system/shared/app/terminal/ghostty.nix or similar) to use config.user.fonts.default with fallback
- [X] T019 [US4] Document the pattern in quickstart.md (already done, verify accuracy)

**Checkpoint**: Apps can reference fonts.default with sensible fallback

______________________________________________________________________

## Phase 7: Polish & Documentation

**Purpose**: Documentation updates and final validation

- [X] T020 [P] Update CLAUDE.md with fonts configuration documentation
- [X] T021 Run full validation: `nix flake check` and test with sample user config

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKING - All user stories depend on this
    ↓
    ├──→ Phase 3 (US1) - Core font packages
    │         ↓
    │    Phase 4 (US2) - Private repos (depends on US1 for fonts.nix base)
    │         ↓
    │    Phase 5 (US3) - Desktop config (depends on US1 for fonts.default)
    │         ↓
    │    Phase 6 (US4) - App integration (depends on US1 for schema)
    ↓
Phase 7 (Polish) - After all user stories
```

### User Story Dependencies

| Story | Depends On | Can Parallelize With |
|-------|------------|----------------------|
| US1 | Foundational (Phase 2) | None - must be first |
| US2 | US1 (needs fonts.nix base) | US3 after US1 done |
| US3 | US1 (needs fonts.default) | US2 after US1 done |
| US4 | US1 (needs schema) | US2, US3 after US1 done |

### Within Each User Story

1. Implementation tasks in order
1. Validation at checkpoint
1. Complete story before next priority

### Parallel Opportunities

**After Foundational Phase**:

- T006, T007, T008 are sequential (same file)
- T015, T017 can run in parallel (different files) after US1 complete
- T018, T020 can run in parallel (different files)

______________________________________________________________________

## Parallel Example: After US1 Complete

```bash
# These can run in parallel (different platforms):
Task: "Create system/shared/family/gnome/settings/fonts.nix" (T015)
Task: "Create system/darwin/settings/fonts.nix" (T017)
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
1. Complete Phase 2: Foundational (T003-T005) - **CRITICAL**
1. Complete Phase 3: User Story 1 (T006-T009)
1. **STOP and VALIDATE**: Test font package installation
1. Can deploy/demo core capability

**MVP Deliverable**: Users can declare fonts.packages and have them installed

### Full Feature Delivery

1. Complete MVP (Phases 1-3)
1. Add User Story 2: Private repositories (T010-T014)
1. Add User Story 3: Desktop configuration (T015-T017)
1. Add User Story 4: App integration (T018-T019)
1. Polish: Documentation (T020-T021)

**Full Deliverable**: Complete font management with private repos and desktop integration

______________________________________________________________________

## Validation Commands

```bash
# After each phase
nix flake check

# Test font installation (after US1)
just build cdrokar home-macmini-m4

# Test private repo (after US2)
just install cdrokar home-macmini-m4
ls ~/.local/share/fonts/private/

# Test GNOME config (after US3, on GNOME)
gsettings get org.gnome.desktop.interface monospace-font-name
```

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story independently testable after completion
- Commit after each task or logical group
- fonts.nix must stay under 200 lines (constitutional requirement)
- Use `lib.mkDefault` for all new options
