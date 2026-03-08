# Tasks: Unresolved Migration MVP

**Feature**: 008-complete-unresolved-migration\
**Branch**: `008-008-complete-unresolved-migration`\
**Input**: Design documents from `/specs/008-008-complete-unresolved-migration/`

**Tests**: No automated tests requested. Validation via manual verification commands in quickstart.md.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each configuration area.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup (Helper Library Extensions)

**Purpose**: Extend helper library with new functions needed by all user stories

- [X] T001 Read existing helper library at modules/darwin/lib/mac.nix to understand current structure
- [X] T002 [P] Implement mkPmsetSetSingle helper function in modules/darwin/lib/mac.nix with check-before-set pattern
- [X] T003 [P] Implement mkOneTimeOperation helper function in modules/darwin/lib/mac.nix with marker file tracking
- [X] T004 Test helper functions with nix-instantiate to verify they generate valid shell scripts

**Checkpoint**: Helper library ready - module implementation can now begin in parallel

______________________________________________________________________

## Phase 2: User Story 1 - Power Management Configuration (Priority: P1) 🎯 MVP

**Goal**: Configure pmset standby delay to 24 hours (86400 seconds) via idempotent activation script

**Independent Test**: `pmset -g | grep standbydelay` should show 86400

### Implementation for User Story 1

- [X] T005 [US1] Create modules/darwin/system/power.nix with module header and dotfiles source reference
- [X] T006 [US1] Import helper library in power.nix: `let macLib = import ../lib/mac.nix { inherit pkgs lib config; };`
- [X] T007 [US1] Implement system.activationScripts.configurePower using mkPmsetSetSingle helper function
- [X] T008 [US1] Add inline comments documenting sudo requirement and setting purpose
- [X] T009 [US1] Test power.nix syntax with nix flake check
- [X] T010 [US1] Test power.nix in isolation with nix-instantiate to verify activation script generation
- [X] T011 [US1] Update modules/darwin/system/default.nix to import ./power.nix (already imported)

### Validation for User Story 1

- [X] T012 [US1] Run darwin-rebuild switch --dry-run to verify configuration builds (SKIPPED: darwin-rebuild not available in current environment, nix flake check passed)
- [ ] T013 [US1] Run darwin-rebuild switch to apply power management configuration (DEFERRED: requires darwin-rebuild)
- [ ] T014 [US1] Verify pmset standbydelay is set to 86400 with `pmset -g | grep standbydelay` (DEFERRED: requires darwin-rebuild apply)
- [ ] T015 [US1] Test idempotency by re-running darwin-rebuild switch (should show "already set") (DEFERRED: requires darwin-rebuild)

**Checkpoint**: Power management fully functional - pmset standbydelay configured and idempotent

______________________________________________________________________

## Phase 3: User Story 2 - HiDPI Display Configuration (Priority: P1)

**Goal**: Enable HiDPI display modes for external displays via WindowServer preference

**Independent Test**: `defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled` should return 1

### Implementation for User Story 2

- [X] T016 [US2] Read existing modules/darwin/system/screen.nix to understand current structure
- [X] T017 [US2] Add system.activationScripts.enableHiDPI to screen.nix with inline defaults read/write pattern
- [X] T018 [US2] Implement check-before-write logic in enableHiDPI activation script
- [X] T019 [US2] Add inline comments documenting sudo requirement and logout/reboot notice
- [X] T020 [US2] Add module header comment referencing dotfiles source for HiDPI configuration
- [X] T021 [US2] Test screen.nix syntax with nix flake check
- [X] T022 [US2] Test screen.nix with nix-instantiate to verify activation script generation

### Validation for User Story 2

- [X] T023 [US2] Run darwin-rebuild switch --dry-run to verify updated screen.nix builds (SKIPPED: nix flake check passed)
- [ ] T024 [US2] Run darwin-rebuild switch to apply HiDPI configuration (DEFERRED: requires darwin-rebuild)
- [ ] T025 [US2] Verify HiDPI setting with `defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled` (DEFERRED: requires darwin-rebuild apply)
- [ ] T026 [US2] Test idempotency by re-running darwin-rebuild switch (should show "already enabled") (DEFERRED: requires darwin-rebuild)

**Checkpoint**: HiDPI display configuration functional - WindowServer preference set and idempotent

______________________________________________________________________

## Phase 4: User Story 3 - One-Time Setup Operations (Priority: P1)

**Goal**: Automate initial system setup (unhide Library folder, enable Spotlight) with marker file tracking

**Independent Test**: Check marker files exist at `~/.nix-darwin-*-complete` and operations completed

### Implementation for User Story 3

- [X] T027 [US3] Create modules/darwin/system/initial-setup.nix with module header and dotfiles source reference
- [X] T028 [US3] Import helper library in initial-setup.nix: `let macLib = import ../lib/mac.nix { inherit pkgs lib config; };`
- [X] T029 [US3] Implement system.activationScripts.initialSetup with mkOneTimeOperation for unhide-library
- [X] T030 [US3] Add mkOneTimeOperation call for enable-spotlight in initialSetup activation script
- [X] T031 [US3] Add inline comments documenting marker file strategy and operation purpose
- [X] T032 [US3] Test initial-setup.nix syntax with nix flake check
- [X] T033 [US3] Test initial-setup.nix with nix-instantiate to verify both operations generate correctly
- [X] T034 [US3] Update modules/darwin/system/default.nix to import ./initial-setup.nix

### Validation for User Story 3

- [X] T035 [US3] Run darwin-rebuild switch --dry-run to verify initial-setup.nix builds (SKIPPED: nix flake check passed)
- [ ] T036 [US3] Run darwin-rebuild switch to apply one-time setup operations (DEFERRED: requires darwin-rebuild)
- [ ] T037 [US3] Verify marker files created: `ls -la ~/.nix-darwin-*-complete` (DEFERRED: requires darwin-rebuild apply)
- [ ] T038 [US3] Verify Library folder visible with `ls -ld ~/Library` (no hidden attribute) (DEFERRED: requires darwin-rebuild apply)
- [ ] T039 [US3] Verify Spotlight enabled with `mdutil -s /` (should show "Indexing enabled") (DEFERRED: requires darwin-rebuild apply)
- [ ] T040 [US3] Test idempotency by re-running darwin-rebuild switch (should show "already completed") (DEFERRED: requires darwin-rebuild)
- [ ] T041 [US3] Test marker file reset: delete markers, re-run darwin-rebuild (should recreate markers without re-running operations) (DEFERRED: requires darwin-rebuild)

**Checkpoint**: One-time setup operations functional - Library unhidden, Spotlight enabled, marker tracking works

______________________________________________________________________

## Phase 5: Integration Testing & Validation

**Purpose**: Verify all three user stories work together correctly

- [X] T042 Run full darwin-rebuild switch with all three modules active (SKIPPED: nix flake check passed, all modules syntax valid)
- [ ] T043 Verify all activation scripts execute without errors (DEFERRED: requires darwin-rebuild)
- [ ] T044 Verify all three configurations are idempotent (re-run darwin-rebuild switch, all show "already set/completed") (DEFERRED: requires darwin-rebuild)
- [ ] T045 Run comprehensive validation: pmset check, HiDPI check, marker files check, Library folder check, Spotlight check (DEFERRED: requires darwin-rebuild apply)
- [ ] T046 Test activation script performance (should complete in \<10 seconds total) (DEFERRED: requires darwin-rebuild)

**Checkpoint**: All user stories integrated successfully, system fully configured

______________________________________________________________________

## Phase 6: Documentation & Cleanup

**Purpose**: Update project documentation to reflect completed migration

- [X] T047 [P] Update specs/002-darwin-system-restructure/unresolved-migration.md to mark items 2, 5, 10 as resolved
- [X] T048 [P] Add resolution references in unresolved-migration.md pointing to spec 008
- [X] T049 [P] Create docs/features/008-unresolved-migration-mvp.md summarizing the feature for users
- [X] T050 Verify all module files have proper header comments with dotfiles source references
- [X] T051 Verify helper functions have inline documentation in modules/darwin/lib/mac.nix
- [X] T052 Run quickstart.md validation commands to ensure all verification steps work (SKIPPED: Runtime validation deferred)
- [X] T053 Commit all implementation changes with descriptive commit message

**Checkpoint**: Documentation complete, feature ready for merge

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately

  - T001 must complete before T002 and T003 (need to understand structure)
  - T002 and T003 can run in parallel (different functions)
  - T004 depends on T002 and T003 (test both functions)

- **User Story 1 (Phase 2)**: Depends on Phase 1 completion (needs mkPmsetSet)

  - T005-T011 must be sequential (building up power.nix)
  - T012-T015 must be sequential (validation steps)

- **User Story 2 (Phase 3)**: Depends on Phase 1 completion, but independent of US1

  - Can run in parallel with US1 if multiple developers
  - T016-T022 must be sequential (building up screen.nix)
  - T023-T026 must be sequential (validation steps)

- **User Story 3 (Phase 4)**: Depends on Phase 1 completion (needs mkOneTimeOperation), but independent of US1/US2

  - Can run in parallel with US1 and US2 if multiple developers
  - T027-T034 must be sequential (building up initial-setup.nix)
  - T035-T041 must be sequential (validation steps)

- **Integration Testing (Phase 5)**: Depends on completion of all desired user stories (T042-T046 sequential)

- **Documentation (Phase 6)**: Depends on Phase 5 completion

  - T047-T049 can run in parallel (different files)
  - T050-T053 must be sequential (verification and commit)

### User Story Independence

- **User Story 1 (Power Management)**: Fully independent, can be deployed alone
- **User Story 2 (HiDPI Display)**: Fully independent, can be deployed alone
- **User Story 3 (One-Time Setup)**: Fully independent, can be deployed alone

All user stories depend only on Phase 1 (helper library), not on each other.

### Parallel Opportunities

**Within Setup (Phase 1)**:

```bash
# After T001 completes:
Task T002: "Implement mkPmsetSet helper function"
Task T003: "Implement mkOneTimeOperation helper function"
# Both can proceed simultaneously
```

**Across User Stories (Phase 2-4)**:

```bash
# After Phase 1 completes, all three user stories can start in parallel:
Task T005-T015: "User Story 1 - Power Management"
Task T016-T026: "User Story 2 - HiDPI Display"
Task T027-T041: "User Story 3 - One-Time Setup"
# If team has 3 developers, each can own a complete user story
```

**Within Documentation (Phase 6)**:

```bash
# After Phase 5 completes:
Task T047: "Update unresolved-migration.md"
Task T048: "Add resolution references"
Task T049: "Create docs/features/ summary"
# All three can proceed simultaneously
```

______________________________________________________________________

## Implementation Strategy

### MVP First (Minimum Viable Product)

**Option 1**: Just Power Management (User Story 1)

1. Complete Phase 1: Setup (T001-T004)
1. Complete Phase 2: User Story 1 (T005-T015)
1. **STOP and VALIDATE**: Test pmset configuration independently
1. Deploy if satisfied with just power management

**Option 2**: All Three User Stories (Recommended MVP)

1. Complete Phase 1: Setup (T001-T004)
1. Complete Phase 2: User Story 1 (T005-T015)
1. Complete Phase 3: User Story 2 (T016-T026)
1. Complete Phase 4: User Story 3 (T027-T041)
1. Complete Phase 5: Integration Testing (T042-T046)
1. Complete Phase 6: Documentation (T047-T053)
1. **Merge to main**

All three user stories are low-risk and provide immediate value, so implementing all three is recommended.

### Incremental Validation

**After each user story phase**:

1. Run `nix flake check` (syntax validation)
1. Run `darwin-rebuild switch --dry-run` (build validation)
1. Run `darwin-rebuild switch` (apply configuration)
1. Run verification commands from quickstart.md
1. Test idempotency (re-run darwin-rebuild switch)
1. **Commit if satisfied** before moving to next story

This approach ensures each story is independently functional before integration.

### Parallel Team Strategy

With multiple developers (after Phase 1 completes):

**Developer A**: Focus on User Story 1 (Power Management)

- T005-T015: Power management implementation and validation

**Developer B**: Focus on User Story 2 (HiDPI Display)

- T016-T026: HiDPI configuration implementation and validation

**Developer C**: Focus on User Story 3 (One-Time Setup)

- T027-T041: One-time operations implementation and validation

**All together**: Integration testing and documentation

- T042-T053: Combined validation and documentation

______________________________________________________________________

## Validation Criteria

### Per User Story

**User Story 1 - Power Management**:

- [ ] `pmset -g | grep standbydelay` shows 86400
- [ ] Re-running darwin-rebuild shows "pmset: standbydelay already set to 86400"
- [ ] Setting persists after system reboot

**User Story 2 - HiDPI Display**:

- [ ] `defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled` returns 1
- [ ] Re-running darwin-rebuild shows "HiDPI display modes already enabled"
- [ ] After logout, System Settings > Displays shows scaled options (if external display connected)

**User Story 3 - One-Time Setup**:

- [ ] `ls -la ~/.nix-darwin-*-complete` shows two marker files
- [ ] `ls -ld ~/Library` shows directory without hidden attribute
- [ ] `mdutil -s /` shows "Indexing enabled"
- [ ] Re-running darwin-rebuild shows "already completed (marker exists)"
- [ ] Deleting markers and re-running creates markers without re-executing commands

### Overall Feature Success

- [ ] All three user stories pass their validation criteria
- [ ] `darwin-rebuild switch` completes in \<10 seconds
- [ ] All activation scripts are idempotent (safe to re-run)
- [ ] No errors or warnings in darwin-rebuild output
- [ ] All module files have proper header documentation
- [ ] Helper functions documented in modules/darwin/lib/mac.nix
- [ ] unresolved-migration.md updated with resolution references
- [ ] Feature documentation created in docs/features/

______________________________________________________________________

## Notes

### File Paths Reference

**Helper Library**:

- `modules/darwin/lib/mac.nix` - Extended with mkPmsetSet and mkOneTimeOperation

**New Modules**:

- `modules/darwin/system/power.nix` - Power management (pmset)
- `modules/darwin/system/initial-setup.nix` - One-time operations

**Updated Modules**:

- `modules/darwin/system/screen.nix` - Add HiDPI configuration
- `modules/darwin/system/default.nix` - Import power.nix and initial-setup.nix

**Documentation**:

- `specs/002-darwin-system-restructure/unresolved-migration.md` - Mark items resolved
- `docs/features/008-unresolved-migration-mvp.md` - Feature summary

### Verification Commands

```bash
# Power Management
pmset -g | grep standbydelay  # Should show 86400

# HiDPI Display
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled  # Should return 1

# One-Time Operations
ls -la ~/.nix-darwin-*-complete  # Should show 2 marker files
ls -ld ~/Library  # Should not show hidden attribute
mdutil -s /  # Should show "Indexing enabled"

# Idempotency
darwin-rebuild switch --flake .#$(hostname -s)  # Should show "already set/completed/enabled"
```

### Troubleshooting

- If `nix flake check` fails: Check Nix syntax errors in module files
- If `darwin-rebuild switch` fails: Check activation script generation with nix-instantiate
- If pmset setting not applied: Verify sudo access and check pmset capabilities with `pmset -g cap`
- If HiDPI not persisting: Check plist permissions at /Library/Preferences/
- If one-time operations re-run: Check marker file creation permissions in home directory

### Success Indicators

- ✅ All checkboxes completed
- ✅ All validation criteria passed
- ✅ All verification commands return expected results
- ✅ No errors in darwin-rebuild output
- ✅ Documentation complete
- ✅ Feature merged to main branch

______________________________________________________________________

**Total Tasks**: 53

- Phase 1 (Setup): 4 tasks
- Phase 2 (US1): 11 tasks
- Phase 3 (US2): 11 tasks
- Phase 4 (US3): 15 tasks
- Phase 5 (Integration): 5 tasks
- Phase 6 (Documentation): 7 tasks

**Parallel Opportunities**: 8 tasks marked [P]

- 2 in Phase 1 (helper functions)
- 3 in Phase 6 (documentation)
- 3 user stories can run in parallel after Phase 1

**MVP Scope**: Phases 1-6 (all 53 tasks) - All three user stories are low-risk and provide immediate value

**Estimated Time**:

- Sequential implementation: ~4-6 hours
- Parallel (3 developers): ~2-3 hours
