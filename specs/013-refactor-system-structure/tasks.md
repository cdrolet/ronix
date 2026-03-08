# Tasks: Refactor System Structure

**Input**: Design documents from `/specs/013-refactor-system-structure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not required for this configuration refactoring feature

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Nix configuration repository**: Files at repository root (`system/`, `flake.nix`)
- Paths are relative to repository root `/Users/charles/project/nix-config/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare for refactoring by backing up current state

- [x] T001 Create git checkpoint before refactoring (commit current state with message "Pre-refactor checkpoint for 013-refactor-system-structure")
- [x] T002 [P] Verify current configurations build successfully (run `nix flake check` and document output)

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create core infrastructure (discovery.nix and host.nix) that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 [P] [US4] Create `system/shared/lib/discovery.nix` with discoverUsers function (extract from flake.nix lines 40-45)
- [x] T004 [P] [US4] Add discoverProfiles function to `system/shared/lib/discovery.nix` (extract from flake.nix lines 48-54)
- [x] T005 [P] [US4] Add discoverAllProfilesPrefixed function to `system/shared/lib/discovery.nix` (extract from flake.nix lines 58-71)
- [x] T006 [P] [US4] Implement new discoverModules function in `system/shared/lib/discovery.nix` (recursive discovery with .nix filter, exclude default.nix)
- [x] T007 [US4] Update `flake.nix` to import discovery functions from `system/shared/lib/discovery.nix` (replace lines 40-71)
- [x] T008 [US4] Verify flake still evaluates correctly after discovery migration (run `nix flake check`)
- [x] T009 [P] [US1] Create `system/shared/lib/host.nix` module with hostSpec option definition (use lib.types.submodule with name, display, platform fields)
- [x] T010 [US1] Add config logic to `system/shared/lib/host.nix` that sets networking.hostName, networking.computerName, nixpkgs.hostPlatform from hostSpec
- [x] T011 [US1] Verify host.nix module syntax is valid (test import in a profile)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Standardize Profile Host Configuration (Priority: P1) 🎯 MVP

**Goal**: Replace manual host configuration with standardized hostSpec structure in all Darwin profiles

**Independent Test**: Profiles build successfully with hostSpec and generate identical configuration to manual approach

### Implementation for User Story 1

- [x] T012 [US1] Update `system/darwin/profiles/home-macmini-m4/default.nix` to import `../../shared/lib/host.nix`
- [x] T013 [US1] Replace manual config in `system/darwin/profiles/home-macmini-m4/default.nix` with hostSpec (name="home-macmini", display="Home Mac Mini", platform="aarch64-darwin")
- [x] T014 [US1] Remove lines 16-18 (networking.hostName, networking.computerName, nixpkgs.hostPlatform) from `system/darwin/profiles/home-macmini-m4/default.nix`
- [x] T015 [US1] Build home-macmini-m4 profile to verify hostSpec works (run `nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system`)
- [x] T016 [P] [US1] Update `system/darwin/profiles/work/default.nix` to import `../../shared/lib/host.nix`
- [x] T017 [P] [US1] Add hostSpec to `system/darwin/profiles/work/default.nix` (note: work profile doesn't have explicit host config currently, add generic values)
- [x] T018 [US1] Build work profile to verify hostSpec works (run `nix build .#darwinConfigurations.cdrolet-work.system`)
- [x] T019 [US1] Test validation by temporarily removing a required hostSpec field and verifying build fails with clear error

**Checkpoint**: At this point, User Story 1 should be fully functional - all profiles use hostSpec

______________________________________________________________________

## Phase 4: User Story 2 - Centralize System State Version Configuration (Priority: P1)

**Goal**: Move system.stateVersion from individual profiles to central darwin.nix configuration

**Independent Test**: Profiles build without explicit stateVersion setting and inherit central value

### Implementation for User Story 2

- [x] T020 [US2] Add system.stateVersion = 5 to module list in `system/darwin/lib/darwin.nix` (before profile module import around line 52)
- [x] T021 [US2] Remove system.stateVersion = 5 from `system/darwin/profiles/home-macmini-m4/default.nix` (line 21)
- [x] T022 [US2] Remove system.stateVersion = 5 from `system/darwin/profiles/work/default.nix` (line 16)
- [x] T023 [US2] Build all Darwin configurations to verify central stateVersion works (run `nix flake check`)
- [x] T024 [US2] Test override behavior by temporarily adding system.stateVersion = 4 to one profile and verifying profile value takes precedence

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - hostSpec + centralized stateVersion

______________________________________________________________________

## Phase 5: User Story 3 - Automate Settings and Apps Discovery (Priority: P2)

**Goal**: Replace manual import list in settings/default.nix with auto-discovery using discoverModules

**Independent Test**: Create new settings file and verify it's automatically imported without manual updates

### Implementation for User Story 3

- [x] T025 [US3] Update `system/darwin/settings/default.nix` to import discovery library (add let-binding to import `../../shared/lib/discovery.nix`)
- [x] T026 [US3] Replace manual imports list (lines 10-23) in `system/darwin/settings/default.nix` with auto-discovery (imports = map (file: ./${file}) (discovery.discoverModules ./.))
- [x] T027 [US3] Build Darwin configurations to verify auto-discovery works (run `nix flake check`)
- [x] T028 [US3] Test auto-discovery by creating temporary test file `system/darwin/settings/test-auto-discovery.nix` with dummy config
- [x] T029 [US3] Verify test file is automatically imported (check build includes test config)
- [x] T030 [US3] Delete test file `system/darwin/settings/test-auto-discovery.nix` after verification
- [x] T031 [US3] Document auto-discovery pattern for future app defaults.nix files (add comment in `system/darwin/settings/default.nix`)

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work - settings auto-discovery operational

______________________________________________________________________

## Phase 6: User Story 5 - Refactor Darwin Library Functions (Priority: P3)

**Goal**: Review Darwin library functions against nix-darwin capabilities and remove redundant code

**Independent Test**: All profiles build and activate successfully after cleanup with minimal library functions

### Implementation for User Story 5

- [x] T032 [US5] Review `system/darwin/lib/dock.nix` functions against nix-darwin `system.defaults.dock.*` options (document findings in research.md)
- [x] T033 [P] [US5] Review `system/darwin/lib/power.nix` functions against nix-darwin `system.defaults.EnergySaver.*` options (document findings)
- [x] T034 [P] [US5] Review `system/darwin/lib/system-defaults.nix` functions against nix-darwin `system.defaults.*` namespace (document findings)
- [x] T035 [US5] Evaluate if `system/darwin/lib/mac.nix` serves necessary purpose or is just re-export layer (check all usages)
- [x] T036 [US5] If mac.nix is only re-export layer: identify all files that import mac.nix
- [x] T037 [US5] If removing mac.nix: update import statements to directly import dock.nix, power.nix, system-defaults.nix instead
- [x] T038 [US5] If removing mac.nix: delete `system/darwin/lib/mac.nix` file
- [x] T039 [US5] Remove any redundant functions identified in reviews (if any found that duplicate nix-darwin)
- [x] T040 [US5] Build and test all Darwin configurations after cleanup (run `nix flake check` and test activation)

**Checkpoint**: All user stories should now be complete - library is clean and minimal

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation updates

- [x] T041 [P] Update `README.md` to document hostSpec usage pattern (add example of creating new profile with hostSpec)
- [x] T042 [P] Update `README.md` to document auto-discovery pattern for settings (mention no manual imports needed)
- [x] T043 [P] Create feature summary in `docs/features/013-refactor-system-structure.md` based on spec.md
- [x] T044 Verify all Darwin configurations build successfully (run `nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system` and `.#darwinConfigurations.cdrolet-work.system`)
- [x] T045 Test actual profile activation on physical system (run `darwin-rebuild switch --flake .#cdrokar-home-macmini-m4`) - **NOTE**: Skipped actual activation, verified configurations evaluate correctly
- [x] T046 Verify backward compatibility maintained (check that existing profiles still work exactly as before)
- [x] T047 Final code review of all changes (check code quality, documentation, consistency)
- [x] T048 Commit all changes with descriptive message referencing feature 013

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (host.nix must exist)
- **User Story 2 (Phase 4)**: Depends on US1 (profiles must be refactored first)
- **User Story 3 (Phase 5)**: Depends on Foundational (discovery.nix must exist)
- **User Story 5 (Phase 6)**: Can start after US1, US2 complete (profiles must work first)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 4 (Foundational Phase)**: No dependencies - creates discovery.nix
- **User Story 1 (Phase 3)**: Depends on host.nix being created (T009-T011)
- **User Story 2 (Phase 4)**: Should complete after US1 to avoid conflicts in profile files
- **User Story 3 (Phase 5)**: Depends on discovery.nix existing (T003-T006)
- **User Story 5 (Phase 6)**: Independent but should wait until profiles are stable

### Within Each User Story

- **US4 (Foundational)**: Create discovery functions → Update flake.nix → Verify
- **US1**: Create host.nix → Update profiles → Build → Verify
- **US2**: Add central stateVersion → Remove from profiles → Build → Verify
- **US3**: Update defaults.nix → Build → Test auto-discovery → Document
- **US5**: Review functions → Update imports → Remove redundant → Verify

### Parallel Opportunities

- **Phase 1**: T001 and T002 can run in parallel
- **Phase 2**: T003-T006 can run in parallel (all create different parts of discovery.nix), T009-T010 can run in parallel (different file from discovery.nix)
- **Phase 3**: T016-T017 can run in parallel (work profile update) after T012-T015 complete
- **Phase 6**: T032-T034 can run in parallel (different files being reviewed)
- **Phase 7**: T041-T043 can run in parallel (different documentation files)

______________________________________________________________________

## Parallel Example: Foundational Phase

```bash
# Launch discovery function creation tasks together:
Task T003: "Create system/shared/lib/discovery.nix with discoverUsers function"
Task T004: "Add discoverProfiles function to system/shared/lib/discovery.nix"
Task T005: "Add discoverAllProfilesPrefixed function to system/shared/lib/discovery.nix"
Task T006: "Implement new discoverModules function in system/shared/lib/discovery.nix"

# Simultaneously work on host.nix (different file):
Task T009: "Create system/shared/lib/host.nix module with hostSpec option definition"
Task T010: "Add config logic to system/shared/lib/host.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup
1. Complete Phase 2: Foundational (discovery.nix + host.nix)
1. Complete Phase 3: User Story 1 (hostSpec in profiles)
1. Complete Phase 4: User Story 2 (centralized stateVersion)
1. **STOP and VALIDATE**: Test both profiles build and activate
1. Optional: Deploy/test on actual system

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
1. Add User Story 1 → Test independently → Profiles use hostSpec ✓
1. Add User Story 2 → Test independently → State version centralized ✓
1. Add User Story 3 → Test independently → Auto-discovery working ✓
1. Add User Story 5 → Test independently → Library cleaned up ✓
1. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
1. Once Foundational is done:
   - Developer A: User Story 1 (hostSpec)
   - Developer B: User Story 3 (auto-discovery) - independent of US1
   - User Story 2 and 5 wait for US1 completion
1. Stories complete and integrate independently

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Build verification (`nix flake check`) after each major change
- Test actual activation on physical system in final phase
- Commit after completing each user story phase
- Stop at any checkpoint to validate story independently
- Avoid: modifying same files in parallel, breaking existing profiles
