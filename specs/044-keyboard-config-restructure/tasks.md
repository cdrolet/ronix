# Tasks: Keyboard Configuration Restructure

**Input**: Design documents from `/specs/044-keyboard-config-restructure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/keyboard-schema.nix

**Tests**: No test tasks — verification via `nix flake check` and `just build`.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup

**Purpose**: No setup needed — all changes are modifications to existing files.

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Update the user schema. This MUST complete before any consumer modules are updated.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Replace `keyboardLayout` option with `keyboard` submodule (containing `layout` and `macStyleMappings` fields) in `user/shared/lib/user-schema.nix`

**Checkpoint**: Schema updated. `keyboard.layout` (list, default null) and `keyboard.macStyleMappings` (bool, default true) available.

______________________________________________________________________

## Phase 3: User Story 1 — Restructured Keyboard Layout Configuration (Priority: P1)

**Goal**: All modules read from `keyboard.layout` instead of `keyboardLayout`. All user configs and templates migrated. Identical behavior.

**Independent Test**: `nix flake check` passes. `just build cdrokar avf-gnome` succeeds. Keyboard layouts applied correctly on all platforms.

### Implementation for User Story 1

- [x] T002 [P] [US1] Update `user/cdrokar/default.nix`: replace `keyboardLayout = [...]` with `keyboard.layout = [...]`
- [x] T003 [P] [US1] Update `user/shared/template/developer.nix`: replace `keyboardLayout` with `keyboard.layout`
- [x] T004 [P] [US1] Update `user/shared/template/basic-english.nix`: replace `keyboardLayout` with `keyboard.layout`
- [x] T005 [P] [US1] Update `user/shared/template/basic-french.nix`: replace `keyboardLayout` with `keyboard.layout`
- [x] T006 [P] [US1] Update Darwin keyboard settings to read from `keyboard.layout` in `system/darwin/settings/system/keyboard.nix`
- [x] T007 [P] [US1] Update Linux family keyboard settings to read from `keyboard.layout` in `system/shared/family/linux/settings/system/keyboard.nix`
- [x] T008 [P] [US1] Update GNOME keyboard settings to read from `keyboard.layout` in `system/shared/family/gnome/settings/user/keyboard.nix`
- [x] T009 [P] [US1] Update Niri keyboard settings to read from `keyboard.layout` in `system/shared/family/niri/settings/user/keyboard.nix`
- [x] T010 [US1] Run `nix flake check` to verify all configurations build successfully

**Checkpoint**: All modules read `keyboard.layout`. Behavior identical to before. `nix flake check` passes.

______________________________________________________________________

## Phase 4: User Story 2 — Mac-Style Modifier Mapping Toggle (Priority: P2)

**Goal**: `keyboard.macStyleMappings` controls Super/Ctrl swap on Linux. Default `true` preserves existing behavior.

**Independent Test**: Build with `macStyleMappings = true` → XKB swap options present. Build with `macStyleMappings = false` → XKB swap options absent.

### Implementation for User Story 2

- [x] T011 [P] [US2] Make XKB swap options conditional on `keyboard.macStyleMappings` in `system/shared/family/linux/settings/system/keyboard.nix`
- [x] T012 [P] [US2] Make GNOME dconf xkb-options conditional on `keyboard.macStyleMappings` in `system/shared/family/gnome/settings/user/keyboard.nix`
- [x] T013 [US2] Run `nix flake check` to verify builds pass with default macStyleMappings value

**Checkpoint**: Mac-style swap is now toggleable. Default behavior unchanged.

______________________________________________________________________

## Phase 5: User Story 3 — Consistent Keyboard Configuration for New Users (Priority: P3)

**Goal**: Templates show the grouped `keyboard` block so new users see the organized structure.

**Independent Test**: Run `just user-create`, select developer template, verify output contains `keyboard` block.

### Implementation for User Story 3

- [x] T014 [P] [US3] Add `macStyleMappings = true` to keyboard block in `user/shared/template/developer.nix`
- [x] T015 [P] [US3] Add `macStyleMappings = true` to keyboard block in `user/shared/template/basic-english.nix`
- [x] T016 [P] [US3] Add `macStyleMappings = true` to keyboard block in `user/shared/template/basic-french.nix`

**Checkpoint**: All templates show complete `keyboard` block with both fields.

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T017 Run `nix flake check` for final validation
- [ ] T018 Run `just build cdrokar avf-gnome` to verify full NixOS build
- [ ] T019 Run quickstart.md verification steps

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — start immediately. BLOCKS all user stories.
- **US1 (Phase 3)**: Depends on Phase 2 (schema must exist before consumers update)
- **US2 (Phase 4)**: Depends on Phase 3 (modules must read `keyboard.*` before adding conditional logic)
- **US3 (Phase 5)**: Depends on Phase 3 (templates already migrated to `keyboard.layout` in US1)
- **Polish (Phase 6)**: Depends on all stories complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only. Core migration.
- **US2 (P2)**: Depends on US1 (needs modules already reading `keyboard.*`)
- **US3 (P3)**: Depends on US1 (templates already have `keyboard.layout` from US1; US3 adds `macStyleMappings`)

### Within Each User Story

- All tasks marked [P] within a story can run in parallel
- Validation task (flake check) runs after all implementation tasks

### Parallel Opportunities

- T002–T009 (US1): All 8 file changes are independent — can run in parallel
- T011–T012 (US2): Both file changes are independent — can run in parallel
- T014–T016 (US3): All 3 template changes are independent — can run in parallel

______________________________________________________________________

## Parallel Example: User Story 1

```text
# All US1 tasks touch different files — launch in parallel:
T002: Update user/cdrokar/default.nix
T003: Update user/shared/template/developer.nix
T004: Update user/shared/template/basic-english.nix
T005: Update user/shared/template/basic-french.nix
T006: Update system/darwin/settings/system/keyboard.nix
T007: Update system/shared/family/linux/settings/system/keyboard.nix
T008: Update system/shared/family/gnome/settings/user/keyboard.nix
T009: Update system/shared/family/niri/settings/user/keyboard.nix

# Then validate:
T010: nix flake check
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (update schema)
1. Complete Phase 3: User Story 1 (migrate all consumers)
1. **STOP and VALIDATE**: `nix flake check` passes, keyboard layouts work identically
1. This alone delivers the restructured namespace

### Incremental Delivery

1. Phase 2 → Schema ready
1. Phase 3 (US1) → All modules migrated → Validate (MVP!)
1. Phase 4 (US2) → macStyleMappings toggle works → Validate
1. Phase 5 (US3) → Templates complete → Validate
1. Phase 6 → Final polish and verification

______________________________________________________________________

## Notes

- All [P] tasks touch different files — safe to parallelize
- Constitution requires: no backward compatibility shims, all changes in same commit scope
- Spec contract files (`specs/018-*/contracts/`) are historical — not modified
- Total: 19 tasks across 6 phases
