# Tasks: Segregate Settings Directories

**Input**: Design documents from `/specs/039-segregate-settings-directories/`\
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: Not requested for this feature (infrastructure refactoring)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Nix configuration repository:

- Settings: `system/{platform}/settings/`, `system/shared/family/{family}/settings/`
- Libraries: `system/shared/lib/`, `system/{platform}/lib/`
- User libs: `user/shared/lib/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No project initialization needed - existing repository

This phase can be skipped as we're working in an existing repository.

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Directory structure and discovery infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Discovery System Enhancement

- [x] T001 Add `discoverModulesInContext` function to system/shared/lib/discovery.nix
- [x] T002 Add unit-style validation for `discoverModulesInContext` in discovery.nix comments

### Directory Structure Creation

- [x] T003 [P] Create system/darwin/settings/system/ directory with default.nix
- [x] T004 [P] Create system/darwin/settings/user/ directory with default.nix
- [x] T005 [P] Create system/nixos/settings/system/ directory with default.nix
- [x] T006 [P] Create system/nixos/settings/user/ directory with default.nix
- [x] T007 [P] Create system/shared/settings/system/ directory with default.nix
- [x] T008 [P] Create system/shared/settings/user/ directory with default.nix
- [x] T009 [P] Create system/shared/family/gnome/settings/system/ directory with default.nix
- [x] T010 [P] Create system/shared/family/gnome/settings/user/ directory with default.nix
- [x] T011 [P] Create system/shared/family/linux/settings/system/ directory with default.nix
- [x] T012 [P] Create system/shared/family/linux/settings/user/ directory with default.nix

**Checkpoint**: Foundation ready - settings can now be categorized and moved

______________________________________________________________________

## Phase 3: User Story 1 - System Configuration Builds Without User Settings (Priority: P1) 🎯 MVP

**Goal**: Enable system-level configurations (darwin or nixos) to build successfully without encountering home-manager-specific settings.

**Independent Test**: Run `nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system` and `nix build .#nixosConfigurations.{any-nixos-host}.config.system.build.toplevel` - both should complete without errors related to undefined home-manager options.

### Settings Categorization and Migration - System Level

- [ ] T013 [P] [US1] Move system/darwin/settings/dock.nix → system/darwin/settings/system/dock.nix
- [ ] T014 [P] [US1] Move system/darwin/settings/system.nix → system/darwin/settings/system/system.nix
- [ ] T015 [P] [US1] Move system/darwin/settings/finder.nix → system/darwin/settings/system/finder.nix
- [ ] T016 [P] [US1] Move system/darwin/settings/firewall.nix → system/darwin/settings/system/firewall.nix
- [ ] T017 [P] [US1] Move system/darwin/settings/network.nix → system/darwin/settings/system/network.nix
- [ ] T018 [P] [US1] Move system/darwin/settings/power.nix → system/darwin/settings/system/power.nix
- [ ] T019 [P] [US1] Move system/darwin/settings/screen.nix → system/darwin/settings/system/screen.nix
- [ ] T020 [P] [US1] Move system/darwin/settings/security.nix → system/darwin/settings/system/security.nix
- [ ] T021 [P] [US1] Move system/darwin/settings/trackpad.nix → system/darwin/settings/system/trackpad.nix
- [ ] T022 [P] [US1] Move system/darwin/settings/ui.nix → system/darwin/settings/system/ui.nix
- [ ] T023 [P] [US1] Move system/darwin/settings/homebrew.nix → system/darwin/settings/system/homebrew.nix
- [ ] T024 [P] [US1] Move system/darwin/settings/applications.nix → system/darwin/settings/system/applications.nix
- [ ] T025 [P] [US1] Move system/darwin/settings/home-directory.nix → system/darwin/settings/system/home-directory.nix
- [ ] T026 [P] [US1] Move system/darwin/settings/window-borders.nix → system/darwin/settings/system/window-borders.nix
- [ ] T027 [P] [US1] Move system/nixos/settings/security.nix → system/nixos/settings/system/security.nix
- [ ] T028 [P] [US1] Move system/nixos/settings/network.nix → system/nixos/settings/system/network.nix
- [ ] T029 [P] [US1] Move system/nixos/settings/system.nix → system/nixos/settings/system/system.nix
- [ ] T030 [P] [US1] Move system/nixos/settings/user.nix → system/nixos/settings/system/user.nix
- [ ] T031 [P] [US1] Move system/nixos/settings/first-boot.nix → system/nixos/settings/system/first-boot.nix
- [ ] T032 [P] [US1] Move system/shared/family/gnome/settings/desktop/gnome-core.nix → system/shared/family/gnome/settings/system/desktop/gnome-core.nix
- [ ] T033 [P] [US1] Move system/shared/family/gnome/settings/desktop/gnome-optional.nix → system/shared/family/gnome/settings/system/desktop/gnome-optional.nix
- [ ] T034 [P] [US1] Move system/shared/family/gnome/settings/desktop/gnome-exclude.nix → system/shared/family/gnome/settings/system/desktop/gnome-exclude.nix
- [ ] T035 [P] [US1] Move system/shared/family/gnome/settings/wayland.nix → system/shared/family/gnome/settings/system/wayland.nix
- [ ] T036 [P] [US1] Move system/shared/family/gnome/settings/keyring.nix → system/shared/family/gnome/settings/system/keyring.nix

### Platform Library Updates - System Context

- [x] T037 [US1] Update system/darwin/lib/darwin.nix to import system/darwin/settings/system/default.nix
- [x] T038 [US1] Update system/nixos/lib/nixos.nix to import system/nixos/settings/system/default.nix (if exists)
- [x] T039 [US1] Update system/shared/lib/discovery.nix autoInstallFamilyDefaults to use settings/system/default.nix

### Validation

- [x] T040 [US1] Run nix flake check and verify no errors
- [x] T041 [US1] Build darwin configuration and verify system settings load correctly
- [x] T042 [US1] Build nixos configuration and verify system settings load correctly (if applicable)

**Checkpoint**: At this point, system builds should succeed without encountering user settings

______________________________________________________________________

## Phase 4: User Story 2 - Home Manager Builds Without System Settings (Priority: P1)

**Goal**: Enable home-manager configurations to build successfully without encountering system-specific settings.

**Independent Test**: Run `nix build .#homeConfigurations.cdrokar.activationPackage` in standalone home-manager mode - should complete without errors related to undefined system options.

### Settings Categorization and Migration - User Level

- [ ] T043 [P] [US2] Move system/darwin/settings/locale.nix → system/darwin/settings/user/locale.nix
- [ ] T044 [P] [US2] Move system/darwin/settings/fonts.nix → system/darwin/settings/user/fonts.nix
- [ ] T045 [P] [US2] Move system/darwin/settings/keyboard.nix → system/darwin/settings/user/keyboard.nix
- [ ] T046 [P] [US2] Move system/darwin/settings/wallpaper.nix → system/darwin/settings/user/wallpaper.nix
- [ ] T047 [P] [US2] Move system/nixos/settings/locale.nix → system/nixos/settings/user/locale.nix
- [ ] T048 [P] [US2] Move system/nixos/settings/keyboard.nix → system/nixos/settings/user/keyboard.nix
- [ ] T049 [P] [US2] Move system/shared/settings/password.nix → system/shared/settings/user/password.nix
- [ ] T050 [P] [US2] Move system/shared/settings/cachix.nix → system/shared/settings/user/cachix.nix
- [ ] T051 [P] [US2] Move system/shared/settings/fonts.nix → system/shared/settings/user/fonts.nix
- [ ] T052 [P] [US2] Move system/shared/settings/git-repos.nix → system/shared/settings/user/git-repos.nix
- [ ] T053 [P] [US2] Move system/shared/settings/proton-drive-repos.nix → system/shared/settings/user/proton-drive-repos.nix
- [ ] T054 [P] [US2] Move system/shared/settings/s3-repos.nix → system/shared/settings/user/s3-repos.nix
- [ ] T055 [P] [US2] Move system/shared/family/gnome/settings/ui.nix → system/shared/family/gnome/settings/user/ui.nix
- [ ] T056 [P] [US2] Move system/shared/family/gnome/settings/keyboard.nix → system/shared/family/gnome/settings/user/keyboard.nix
- [ ] T057 [P] [US2] Move system/shared/family/gnome/settings/power.nix → system/shared/family/gnome/settings/user/power.nix
- [ ] T058 [P] [US2] Move system/shared/family/gnome/settings/dock.nix → system/shared/family/gnome/settings/user/dock.nix
- [ ] T059 [P] [US2] Move system/shared/family/gnome/settings/shortcuts.nix → system/shared/family/gnome/settings/user/shortcuts.nix
- [ ] T060 [P] [US2] Move system/shared/family/gnome/settings/fonts.nix → system/shared/family/gnome/settings/user/fonts.nix
- [ ] T061 [P] [US2] Move system/shared/family/gnome/settings/wallpaper.nix → system/shared/family/gnome/settings/user/wallpaper.nix
- [ ] T062 [P] [US2] Move system/shared/family/linux/settings/keyboard.nix → system/shared/family/linux/settings/user/keyboard.nix
- [ ] T063 [P] [US2] Move system/shared/family/linux/settings/home-directory.nix → system/shared/family/linux/settings/user/home-directory.nix
- [ ] T064 [P] [US2] Move system/shared/family/linux/settings/fonts.nix → system/shared/family/linux/settings/user/fonts.nix

### Home Manager Library Updates - User Context

- [ ] T065 [US2] Update user/shared/lib/home.nix to import user settings from settings/user/default.nix
- [ ] T066 [US2] Update system/shared/lib/config-loader.nix to call discoverModulesInContext with "user" context for home-manager

### Validation

- [ ] T067 [US2] Run nix flake check and verify no errors
- [ ] T068 [US2] Build home-manager configuration in standalone mode and verify user settings load correctly
- [ ] T069 [US2] Verify system builds still work (US1 should not regress)

**Checkpoint**: At this point, both system and home-manager builds should work independently

______________________________________________________________________

## Phase 5: User Story 3 - Settings Automatically Discovered by Context (Priority: P2)

**Goal**: Settings are automatically discovered and loaded based on build context without requiring manual guards.

**Independent Test**: Add a new setting file to either settings/system/ or settings/user/ subdirectory and verify it's only loaded in the appropriate context without any manual `lib.optionalAttrs (options ? home)` checks.

### Guard Removal

- [ ] T070 [P] [US3] Remove `lib.optionalAttrs (options ? home)` from system/shared/settings/user/password.nix
- [ ] T071 [P] [US3] Audit all migrated settings for remaining guards and remove them
- [ ] T072 [P] [US3] Search codebase for `options ? home` pattern and document any remaining uses

### Discovery Verification

- [ ] T073 [US3] Create test setting in system/darwin/settings/system/test-system.nix and verify system loads it
- [ ] T074 [US3] Create test setting in system/darwin/settings/user/test-user.nix and verify home-manager loads it
- [ ] T075 [US3] Remove test settings after verification

### Validation

- [ ] T076 [US3] Run nix flake check and verify no errors
- [ ] T077 [US3] Grep codebase for remaining `options ? home` guards in settings files
- [ ] T078 [US3] Build all configurations (darwin, nixos, home-manager) and verify success

**Checkpoint**: Settings are now automatically discovered by context with zero manual guards

______________________________________________________________________

## Phase 6: User Story 4 - Clear Organization and Documentation (Priority: P3)

**Goal**: Developers understand where to place new settings based on whether they're system-level or user-level.

**Independent Test**: Review directory structure documentation and verify new contributors can correctly categorize settings.

### Cleanup

- [ ] T079 [P] [US4] Remove old system/darwin/settings/default.nix (replaced by subdirectory versions)
- [ ] T080 [P] [US4] Remove old system/nixos/settings/default.nix (replaced by subdirectory versions)
- [ ] T081 [P] [US4] Remove old system/shared/settings/default.nix (replaced by subdirectory versions)
- [ ] T082 [P] [US4] Remove old system/shared/family/gnome/settings/default.nix (replaced by subdirectory versions)
- [ ] T083 [P] [US4] Remove old system/shared/family/linux/settings/default.nix (replaced by subdirectory versions)

### Documentation

- [ ] T084 [P] [US4] Update CLAUDE.md with new settings directory structure
- [ ] T085 [P] [US4] Update CLAUDE.md with categorization criteria (system vs user)
- [ ] T086 [P] [US4] Update constitution.md if directory structure standard needs amendment
- [ ] T087 [P] [US4] Create docs/features/039-segregate-settings-directories.md user guide
- [ ] T088 [P] [US4] Add settings directory structure diagram to documentation

### Validation

- [ ] T089 [US4] Review documentation with fresh eyes to verify clarity
- [ ] T090 [US4] Verify directory structure matches documentation
- [ ] T091 [US4] Run final nix flake check and build all configurations

**Checkpoint**: Documentation is complete and directory structure is self-documenting

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements and validation

- [ ] T092 [P] Run final `nix flake check` across all configurations
- [ ] T093 [P] Build all user-host combinations and verify zero context mismatch errors
- [ ] T094 [P] Update .specify/memory/constitution.md version if needed (context validation improvement)
- [ ] T095 Commit and push final changes with descriptive commit message
- [ ] T096 Create pull request with feature summary and testing notes

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: SKIPPED - existing repository
- **Foundational (Phase 2)**: No dependencies - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2)
- **User Story 2 (Phase 4)**: Depends on User Story 1 (Phase 3) - builds on system context separation
- **User Story 3 (Phase 5)**: Depends on User Stories 1 & 2 (Phases 3 & 4) - requires settings migrated
- **User Story 4 (Phase 6)**: Depends on User Story 3 (Phase 5) - documents final structure
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: System settings separation - foundational, no dependencies on other stories
- **User Story 2 (P1)**: User settings separation - depends on US1 to avoid conflicts, but could theoretically be parallel if careful
- **User Story 3 (P2)**: Guard removal - depends on US1 & US2 (settings must be segregated first)
- **User Story 4 (P3)**: Documentation - depends on US3 (final structure must be in place)

### Within Each User Story

**User Story 1**:

1. All settings moves can happen in parallel (T013-T036 all [P])
1. Platform library updates must happen after moves (T037-T039)
1. Validation must happen after library updates (T040-T042)

**User Story 2**:

1. All settings moves can happen in parallel (T043-T064 all [P])
1. Home manager updates must happen after moves (T065-T066)
1. Validation must happen after updates (T067-T069)

**User Story 3**:

1. Guard removal tasks can happen in parallel (T070-T072 all [P])
1. Discovery verification must happen after guard removal (T073-T075)
1. Final validation (T076-T078)

**User Story 4**:

1. All cleanup tasks can happen in parallel (T079-T083 all [P])
1. All documentation tasks can happen in parallel (T084-T088 all [P])
1. Final validation (T089-T091)

### Parallel Opportunities

- **Phase 2**: All directory creation tasks (T003-T012) can run in parallel
- **Phase 3**: All settings migration tasks (T013-T036) can run in parallel
- **Phase 4**: All settings migration tasks (T043-T064) can run in parallel
- **Phase 5**: All guard removal tasks (T070-T072) can run in parallel
- **Phase 6**: All cleanup tasks (T079-T083) can run in parallel
- **Phase 6**: All documentation tasks (T084-T088) can run in parallel
- **Phase 7**: All final checks (T092-T094) can run in parallel

______________________________________________________________________

## Parallel Example: User Story 1 (System Settings)

```bash
# Launch all system settings migrations together:
Task: "Move system/darwin/settings/dock.nix → system/darwin/settings/system/dock.nix"
Task: "Move system/darwin/settings/system.nix → system/darwin/settings/system/system.nix"
Task: "Move system/darwin/settings/finder.nix → system/darwin/settings/system/finder.nix"
# ... (all T013-T036 can run in parallel)

# Then update platform libraries sequentially:
Task: "Update system/darwin/lib/darwin.nix to import system/darwin/settings/system/default.nix"
Task: "Update system/shared/lib/config-loader.nix resolveSettings to support context parameter"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (directory structure + discovery function)
1. Complete Phase 3: User Story 1 (system settings separation)
1. **STOP and VALIDATE**: Test system builds independently
1. System builds should work without user settings errors

### Incremental Delivery

1. Complete Foundational → Directory structure ready
1. Add User Story 1 → System settings separated → Test system builds
1. Add User Story 2 → User settings separated → Test home-manager builds
1. Add User Story 3 → Guards removed → Verify auto-discovery
1. Add User Story 4 → Documentation complete → Feature ready for merge

### Sequential Single-Developer Strategy

1. Phase 2: Create all directories and discovery function (1-2 hours)
1. Phase 3: Migrate system settings and update libraries (2-3 hours)
1. Phase 4: Migrate user settings and update home-manager (2-3 hours)
1. Phase 5: Remove guards and verify auto-discovery (1 hour)
1. Phase 6: Cleanup and documentation (1-2 hours)
1. Phase 7: Final polish and PR (1 hour)

**Total Estimated Time**: 8-12 hours for complete implementation

______________________________________________________________________

## Notes

- [P] tasks = different files, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story builds on previous ones (sequential dependency)
- Validate at each checkpoint to catch errors early
- Settings moves are bulk operations - can be scripted
- Guard removal should be thorough - grep for all `options ? home` occurrences
- Documentation is critical - this changes how developers add new settings
