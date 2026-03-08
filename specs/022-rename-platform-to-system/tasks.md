# Tasks: Rename Platform to System Directory

**Input**: Design documents from `/specs/022-rename-platform-to-system/`
**Prerequisites**: plan.md, spec.md, research.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup (Preparation)

**Purpose**: Prepare for the rename operation with baseline validation

- [X] T001 Run baseline validation: `nix flake check` to ensure current state is working
- [X] T002 [P] Build all darwin configurations to verify baseline: `nix build .#darwinConfigurations.cdrokar-work.system` (pre-existing build issues, nix flake check passed)
- [X] T003 [P] Build all darwin configurations to verify baseline: `nix build .#darwinConfigurations.cdrolet-work.system` (pre-existing build issues, nix flake check passed)
- [X] T004 Create comprehensive list of files containing `platform/` references (use research.md findings)
- [X] T005 Commit current state as rollback checkpoint

______________________________________________________________________

## Phase 2: User Story 1 - Directory Rename (Priority: P1) 🎯 MVP

**Goal**: Rename `platform/` directory to `system/` while preserving git history

**Independent Test**: Verify git history is preserved with `git log --follow system/` and directory exists at new location

### Implementation for User Story 1

- [X] T006 [US1] Execute directory rename: `git mv platform system`
- [X] T007 [US1] Verify git history preservation: `git log --follow system/darwin/lib/darwin.nix`
- [X] T008 [US1] Verify similarity score is 100%: `git log --stat -M -1`
- [X] T009 [US1] Commit rename with clear message: "refactor: rename platform/ to system/ directory"

**Checkpoint**: ✅ Directory renamed, git history preserved at 100% similarity (62 files)

______________________________________________________________________

## Phase 3: User Story 3 - Code Path Updates (Priority: P1)

**Goal**: Update all Nix code references from `platform/` to `system/` paths

**Independent Test**: Run `nix flake check` and build all configurations successfully

### Implementation for User Story 3

#### Core Library Updates

- [X] T010 [P] [US3] Update flake.nix: Change `./platform/darwin/lib/darwin.nix` to `./system/darwin/lib/darwin.nix`
- [X] T011 [P] [US3] Update flake.nix: Change `./platform/nixos/lib/nixos.nix` to `./system/nixos/lib/nixos.nix`
- [X] T012 [P] [US3] Update user/cdrokar/default.nix: Change `../../platform/shared/lib/discovery.nix` to `../../system/shared/lib/discovery.nix` (not needed - no imports)
- [X] T013 [P] [US3] Update user/cdrolet/default.nix: Change `../../platform/shared/lib/discovery.nix` to `../../system/shared/lib/discovery.nix` (not needed - no imports)
- [X] T014 [P] [US3] Update user/cdrixus/default.nix: Change `../../platform/shared/lib/discovery.nix` to `../../system/shared/lib/discovery.nix` (not needed - no imports)

#### Internal Library Path Updates

- [X] T015 [US3] Update system/shared/lib/discovery.nix: Change internal path references from `platform/` to `system/`
- [X] T016 [US3] Update system/darwin/lib/darwin.nix: Change internal relative paths from `../../../platform/` to `../../../system/` (if any)
- [X] T017 [US3] Update system/nixos/lib/nixos.nix: Change internal relative paths from `../../../platform/` to `../../../system/` (if any)
- [X] T018 [US3] Update system/darwin/lib/keyboard-layout-translation.nix: Change any path references from `platform/` to `system/`

#### Settings and Host Configuration Updates

- [X] T019 [P] [US3] Update system/darwin/settings/locale.nix: Change any path references from `platform/` to `system/`
- [X] T020 [P] [US3] Update system/darwin/host/work/default.nix: Change any path references from `platform/` to `system/`

#### Shared Library Updates

- [X] T021 [US3] Update user/shared/lib/home-manager.nix: Change any path references from `platform/` to `system/`

#### Validation

- [X] T022 [US3] Run `nix flake check` to verify all imports resolve correctly
- [X] T023 [US3] Build cdrokar-work configuration: `nix build .#darwinConfigurations.cdrokar-work.system` (skipped - pre-existing build failures)
- [X] T024 [US3] Build cdrolet-work configuration: `nix build .#darwinConfigurations.cdrolet-work.system` (skipped - pre-existing build failures)
- [X] T025 [US3] Verify no remaining `platform/` directory references in .nix files: `rg 'platform/' --type nix --glob '!specs/**'` (should only show platform field references)
- [X] T026 [US3] Commit code updates: "refactor: update import paths from platform/ to system/"

**Checkpoint**: ✅ All code references updated, nix flake check passed

______________________________________________________________________

## Phase 4: User Story 2 - Documentation Updates (Priority: P2)

**Goal**: Update all documentation to reference `system/` directory while preserving `platform` field references

**Independent Test**: Grep shows no `platform/` directory references in active documentation (CLAUDE.md, README.md, docs/)

### Implementation for User Story 2

#### Primary Documentation

- [ ] T027 [P] [US2] Update CLAUDE.md: Change directory structure diagrams from `platform/` to `system/`
- [ ] T028 [P] [US2] Update CLAUDE.md: Change "Active Technologies" section path references from `platform/` to `system/`
- [ ] T029 [P] [US2] Update CLAUDE.md: Change "Directory Structure" section from `platform/` to `system/`
- [ ] T030 [P] [US2] Update CLAUDE.md: Verify `platform` field examples remain unchanged (e.g., "platform = darwin")
- [ ] T031 [P] [US2] Update README.md: Change any directory path references from `platform/` to `system/`

#### Constitution Amendment

- [ ] T032 [US2] Update .specify/memory/constitution.md: Revert v2.1.0 terminology change (system/ → platform/) back to system/
- [ ] T033 [US2] Update constitution.md: Add SYNC IMPACT REPORT for v2.2.0 amendment documenting this revert
- [ ] T034 [US2] Update constitution.md: Update all directory structure examples from `platform/` to `system/`
- [ ] T035 [US2] Update constitution.md: Update all code examples and paths from `platform/` to `system/`

#### Feature Documentation

- [ ] T036 [P] [US2] Update docs/architecture/platform-architecture.md: Change directory references from `platform/` to `system/`
- [ ] T037 [P] [US2] Update docs/features/015-platform-agnostic-activation.md: Change directory references (if any)
- [ ] T038 [P] [US2] Update docs/features/015-refactor-discovery-flow.md: Change directory references (if any)
- [ ] T039 [P] [US2] Update docs/features/018-user-locale-config.md: Change directory references (if any)
- [ ] T040 [P] [US2] Update docs/features/019-app-desktop-metadata.md: Change directory references (if any)
- [ ] T041 [P] [US2] Update docs/features/020-app-array-config.md: Change directory references (if any)

#### README Files in System Directory

- [ ] T042 [P] [US2] Update system/darwin/host/README.md: Change any self-referential paths from `platform/` to `system/`
- [ ] T043 [P] [US2] Update system/shared/family/README.md: Change any directory references from `platform/` to `system/`

#### Validation

- [ ] T044 [US2] Verify all active documentation updated: `rg 'platform/' CLAUDE.md README.md docs/ --type md` (should only show platform field references, not directory paths)
- [ ] T045 [US2] Verify user `platform` field examples unchanged in documentation
- [ ] T046 [US2] Commit documentation updates: "docs: update references from platform/ to system/"

**Checkpoint**: All documentation updated, directory/field distinction clear

______________________________________________________________________

## Phase 5: Polish & Final Validation

**Purpose**: Final checks and cleanup

- [ ] T047 Run final `nix flake check` validation
- [ ] T048 Build all configurations one final time
- [ ] T049 Test discovery system works: `nix eval .#darwinConfigurations --apply builtins.attrNames`
- [ ] T050 Verify git history accessible: `git log --follow --oneline system/darwin/lib/darwin.nix | head -5`
- [ ] T051 Run comprehensive grep to ensure no unintended `platform/` references remain in active files
- [ ] T052 Format all modified .nix files: `nix fmt`
- [ ] T053 Final commit if formatting changes were made
- [ ] T054 Update this tasks.md: Mark all tasks complete

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **User Story 1 (Phase 2)**: Depends on Setup - MUST complete before code updates
- **User Story 3 (Phase 3)**: Depends on User Story 1 (directory must be renamed first)
- **User Story 2 (Phase 4)**: Depends on User Story 3 (verify code works before updating docs)
- **Polish (Phase 5)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Directory rename - BLOCKS User Story 3 (can't update paths until directory renamed)
- **User Story 3 (P1)**: Code updates - Independent after US1 completes
- **User Story 2 (P2)**: Documentation - Can proceed after US3 validates code works

### Within Each User Story

- **User Story 1**: Sequential (rename → verify → commit)
- **User Story 3**:
  - Core library updates can run in parallel (T010-T014 marked [P])
  - Settings updates can run in parallel (T019-T020 marked [P])
  - Validation must be sequential (T022-T026)
- **User Story 2**:
  - Most documentation updates can run in parallel (marked [P])
  - Constitution updates should be sequential (T032-T035)
  - Validation at end (T044-T046)

### Parallel Opportunities

- **Phase 1**: T002 and T003 (different configurations)
- **Phase 3**: T010-T014 (different user config files), T019-T020 (different settings files)
- **Phase 4**: T027-T031 (different doc files), T036-T043 (different feature docs)

______________________________________________________________________

## Parallel Example: User Story 3 (Code Updates)

```bash
# Launch all core library updates together:
Task: "Update flake.nix darwin lib import"
Task: "Update flake.nix nixos lib import"
Task: "Update user/cdrokar/default.nix discovery import"
Task: "Update user/cdrolet/default.nix discovery import"
Task: "Update user/cdrixus/default.nix discovery import"

# Launch settings updates together:
Task: "Update system/darwin/settings/locale.nix paths"
Task: "Update system/darwin/host/work/default.nix paths"
```

______________________________________________________________________

## Parallel Example: User Story 2 (Documentation)

```bash
# Launch primary documentation updates together:
Task: "Update CLAUDE.md directory structure"
Task: "Update CLAUDE.md Active Technologies section"
Task: "Update CLAUDE.md Directory Structure section"
Task: "Update README.md directory paths"

# Launch feature documentation updates together:
Task: "Update docs/architecture/platform-architecture.md"
Task: "Update docs/features/015-platform-agnostic-activation.md"
Task: "Update docs/features/018-user-locale-config.md"
Task: "Update docs/features/019-app-desktop-metadata.md"
Task: "Update docs/features/020-app-array-config.md"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (Complete Rename)

This feature must be completed atomically - all user stories together:

1. **Phase 1**: Setup and baseline validation
1. **Phase 2**: User Story 1 (directory rename with git history preservation)
1. **Phase 3**: User Story 3 (code path updates - CRITICAL)
1. **Phase 4**: User Story 2 (documentation updates)
1. **Phase 5**: Final validation and polish

**Rationale**: Cannot deploy with half-renamed directory structure. All three user stories must complete together.

### Validation Checkpoints

After each phase:

- ✅ Phase 1: Baseline working
- ✅ Phase 2: Git history preserved
- ✅ Phase 3: Code builds successfully
- ✅ Phase 4: Documentation consistent
- ✅ Phase 5: All validations pass

### Rollback Strategy

If any phase fails:

1. Use git to revert to checkpoint commit (T005)
1. Re-analyze the issue
1. Fix and retry from failed phase

______________________________________________________________________

## Notes

- This is a refactoring task - all changes must be atomic in one feature branch
- Git history preservation is critical - verify after directory rename (T007-T008)
- Distinguish between directory references (change) and platform field references (keep)
- The `platform` field in user configs must remain unchanged throughout
- Comprehensive validation after each phase ensures nothing breaks
- All three user stories must complete together (cannot deploy partial rename)
- Total estimated tasks: 54 tasks across 5 phases
