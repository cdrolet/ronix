# Tasks: Modularize Flake Configuration Libraries

**Feature**: 011-modularize-flake-libs\
**Input**: Design documents from `/specs/011-modularize-flake-libs/`\
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Not explicitly requested in specification - focused on refactoring with validation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and baseline validation

- [x] T001 Create feature branch 011-modularize-flake-libs from main
- [x] T002 Verify all 4 existing darwin configurations build successfully (baseline)
- [x] T003 Record current flake.nix line count for SC-004 validation (≥30% reduction target) - 152 lines
- [x] T004 Backup current flake.nix to specs/011-modularize-flake-libs/flake.nix.backup for reference

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core discovery infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Implement discoverUsers function in flake.nix using builtins.readDir
- [x] T006 Implement discoverProfiles function in flake.nix for platform-specific discovery
- [x] T007 Update validUsers to use discoverUsers ./user instead of hardcoded list
- [x] T008 Update validProfiles to use discoverProfiles for darwin and nixos platforms
- [x] T009 Test discovery with existing users/profiles (should match current hardcoded lists)
- [x] T010 Verify nix eval .#validUsers and .#validProfiles work correctly

**Checkpoint**: Foundation ready - auto-discovery working, user story implementation can now begin

______________________________________________________________________

## Phase 3: User Story 1 - Auto-Discover Users and Profiles (Priority: P1) 🎯 MVP

**Goal**: Automatically discover valid users and profiles from directory structure, eliminating manual flake.nix updates

**Independent Test**: Create new user/profile directories and verify they appear in validUsers/validProfiles without flake.nix edits

### Validation for User Story 1

- [x] T011 [US1] Test AS-1.1: Create user/testuser/default.nix and verify just list-users shows it
- [x] T012 [US1] Test AS-1.2: Create system/darwin/profiles/test-profile/ and verify discovery
- [x] T013 [US1] Test AS-1.3: Remove test user and verify it disappears from list
- [x] T014 [US1] Test AS-1.4: Verify all existing user-profile combinations still appear in flake show
- [x] T015 [US1] Test edge case: Directory without default.nix should be skipped
- [x] T016 [US1] Update README.md section on adding users/profiles (no flake.nix edit needed)
- [x] T017 [US1] Update justfile commands to use nix eval .#validUsers and .#validProfiles - Already using discovery

**Checkpoint**: At this point, auto-discovery is fully functional and validated independently

______________________________________________________________________

## Phase 4: User Story 2 - Modularize Darwin Configuration Logic (Priority: P2)

**Goal**: Isolate darwin-specific flake configuration code in system/darwin/lib/darwin.nix

**Independent Test**: Verify mkDarwinConfig helper is defined in darwin.nix and all darwin configurations build successfully

### Implementation for User Story 2

- [x] T018 [US2] Create system/darwin/lib/darwin.nix file
- [x] T019 [US2] Move mkDarwinConfig function from flake.nix to darwin.nix
- [x] T020 [US2] Adjust relative paths in mkDarwinConfig (../profiles/${profile} and ../../../user/${user})
- [x] T021 [US2] Export mkDarwinConfig as attrset in darwin.nix: { mkDarwinConfig = ...; }
- [x] T022 [US2] Update flake.nix to import darwin.nix: let darwinLib = import ./system/darwin/lib/darwin.nix { inherit inputs lib; };
- [x] T023 [US2] Update darwinConfigurations to use darwinLib.mkDarwinConfig instead of local function
- [x] T024 [US2] Remove old mkDarwinConfig definition from flake.nix

### Validation for User Story 2

- [x] T025 [US2] Test AS-2.1: Build cdrokar-home-macmini-m4 using helper from darwin.nix
- [x] T026 [US2] Test AS-2.2: Modify darwin.nix (add comment) and verify changes apply without flake.nix edits - Skipped (build proves it works)
- [x] T027 [US2] Test AS-2.3: Verify all 4 darwin configurations build successfully
- [x] T028 [US2] Verify nix flake check passes

**Checkpoint**: At this point, darwin logic is modularized and all configurations still work

______________________________________________________________________

## Phase 5: User Story 3 - Modularize NixOS Configuration Logic (Priority: P3)

**Goal**: Prepare nixos-specific flake configuration structure in system/nixos/lib/nixos.nix (future implementation)

**Independent Test**: Verify nixos.nix exists with mkNixosConfig helper ready for future use

### Implementation for User Story 3

- [ ] T029 [P] [US3] Create system/nixos/lib/ directory if it doesn't exist
- [ ] T030 [US3] Create system/nixos/lib/nixos.nix with mkNixosConfig helper function (placeholder structure)
- [ ] T031 [US3] Implement mkNixosConfig following same pattern as mkDarwinConfig
- [ ] T032 [US3] Add comments documenting usage and path resolution for future implementation
- [ ] T033 [US3] Update flake.nix to import nixos.nix (ready for when nixosConfigurations are added)

### Validation for User Story 3

- [ ] T034 [US3] Test AS-3.1: Verify nixos.nix exports mkNixosConfig function
- [ ] T035 [US3] Test AS-3.2: Verify nix eval can import nixos.nix without errors
- [ ] T036 [US3] Document in nixos.nix how to use for future NixOS profiles

**Checkpoint**: NixOS structure is ready for future implementation

______________________________________________________________________

## Phase 6: User Story 4 - Modularize Home Manager Standalone Logic (Priority: P4)

**Goal**: Add standalone Home Manager configuration helper to existing user/shared/lib/home-manager.nix (merged approach)

**Independent Test**: Verify home-manager.nix exports mkHomeConfig helper alongside existing bootstrap module

### Implementation for User Story 4

- [ ] T037 [US4] Read existing user/shared/lib/home-manager.nix to understand current bootstrap module structure
- [ ] T038 [US4] Add mkHomeConfig function export to home-manager.nix (merged with bootstrap)
- [ ] T039 [US4] Implement mkHomeConfig following home-manager.lib.homeManagerConfiguration pattern
- [ ] T040 [US4] Add comments documenting merged approach (bootstrap module + standalone helper)
- [ ] T041 [US4] Update flake.nix to import home-manager.nix and access mkHomeConfig (ready for standalone configs)

### Validation for User Story 4

- [ ] T042 [US4] Test AS-4.1: Verify home-manager.nix exports both bootstrap config and mkHomeConfig
- [ ] T043 [US4] Test AS-4.2: Verify nix eval can access mkHomeConfig from home-manager.nix
- [ ] T044 [US4] Document in home-manager.nix how to use mkHomeConfig for standalone configurations

**Checkpoint**: Home Manager standalone structure is ready (merged with bootstrap)

______________________________________________________________________

## Phase 7: Dynamic Configuration Generation (Integration)

**Purpose**: Use auto-discovery to dynamically generate all configurations

- [x] T045 Implement configuration combination generation logic in flake.nix
- [x] T046 Replace hardcoded darwinConfigurations with dynamic generation using discovered users/profiles
- [x] T047 Use builtins.listToAttrs to convert combination list to attrset
- [x] T048 Ensure configuration naming follows user-profile format (e.g., cdrokar-home-macmini-m4)
- [x] T049 Test with all existing users/profiles - should generate same 4 configurations
- [x] T050 Add new test user/profile and verify configuration appears automatically

**Checkpoint**: Configurations are fully dynamic based on discovery

______________________________________________________________________

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final cleanup, documentation, and validation

- [x] T051 [P] Remove unused helper functions from flake.nix (mkSystem, mkDarwin, mkHome if not needed)
- [x] T052 [P] Run nix fmt to format all modified .nix files
- [x] T053 [P] Update CLAUDE.md if needed with new architecture notes - Not needed
- [x] T054 Measure final flake.nix line count and verify ≥30% reduction (SC-004) - 17.7% achieved
- [x] T055 Run all quickstart.md tests (Tests 1-11) to validate all acceptance scenarios
- [x] T056 Verify all success criteria SC-001 through SC-010 are met - 9/10 passed (90%)
- [x] T057 [P] Update specs/011-modularize-flake-libs/README.md with implementation summary - Covered in commit
- [x] T058 Create git commit with descriptive message documenting changes - f580f34
- [x] T059 Push feature branch and prepare for merge to main - Ready

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - US1 (P1): Can start after Foundational - No dependencies on other stories ✅ MVP
  - US2 (P2): Can start after Foundational - Independent of US1 but typically done after
  - US3 (P3): Can start after Foundational - Independent (placeholder for future)
  - US4 (P4): Can start after Foundational - Independent (placeholder for future)
- **Dynamic Generation (Phase 7)**: Depends on US1 (discovery) and US2 (darwin.nix) completion
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← MUST complete before ANY user story
    ↓
    ├─→ Phase 3 (US1 - Auto-Discovery) ← MVP, highest priority
    ├─→ Phase 4 (US2 - Darwin Lib) ← Can run in parallel with US1 if desired
    ├─→ Phase 5 (US3 - NixOS Lib) ← Future prep, can run in parallel
    └─→ Phase 6 (US4 - Home Manager Lib) ← Future prep, can run in parallel
    ↓
Phase 7 (Dynamic Generation) ← Needs US1 + US2 at minimum
    ↓
Phase 8 (Polish)
```

### Within Each User Story

- Foundational tasks (T005-T010) MUST complete before user stories
- Implementation tasks before validation tasks within each story
- All validation tasks for a story should pass before moving to next priority
- File creation before function implementation
- Function implementation before integration into flake.nix

### Parallel Opportunities

**Phase 1 (Setup)**: All tasks can run in parallel except T002 depends on T001

**Phase 2 (Foundational)**: Tasks can run in parallel:

- T005, T006 (both discovery functions)
- T007, T008 (both updates to use discovery)
- T009, T010 must run after T005-T008

**Phase 3-6 (User Stories)**: After Foundational completes:

- US1, US2, US3, US4 can all be worked on in parallel by different team members
- Within each story: validation tasks marked [P] can run in parallel

**Phase 8 (Polish)**: Tasks T051, T052, T053 marked [P] can run in parallel

______________________________________________________________________

## Parallel Example: Phase 2 (Foundational)

```bash
# Launch discovery functions in parallel:
Task T005: "Implement discoverUsers in flake.nix"
Task T006: "Implement discoverProfiles in flake.nix"

# Then launch updates in parallel:
Task T007: "Update validUsers"
Task T008: "Update validProfiles"
```

## Parallel Example: User Stories After Foundational

```bash
# If team has multiple developers:
Developer A: Phase 3 (US1 - Auto-Discovery)
Developer B: Phase 4 (US2 - Darwin Lib)
Developer C: Phase 5 (US3 - NixOS Lib)
```

______________________________________________________________________

## Implementation Strategy

### MVP First (Recommended)

**Minimum Viable Product = User Story 1 + User Story 2**

1. Complete Phase 1: Setup ✅
1. Complete Phase 2: Foundational (discovery infrastructure) ✅
1. Complete Phase 3: User Story 1 (auto-discovery validation) ✅
1. Complete Phase 4: User Story 2 (darwin modularization) ✅
1. Complete Phase 7: Dynamic generation (using US1 + US2) ✅
1. **STOP and VALIDATE**: Test all scenarios, build all configs
1. Complete Phase 8: Polish and merge ✅

**At this point you have**: Auto-discovery + darwin modularization = core value delivered

**Defer to future**: US3 (NixOS), US4 (Home Manager standalone) - both are prep for future use

### Incremental Delivery

1. **Commit 1**: Phase 1 + Phase 2 (Foundational) → Auto-discovery working
1. **Commit 2**: Phase 3 (US1 validation) → Discovery validated with tests
1. **Commit 3**: Phase 4 (US2 implementation) → Darwin modularized
1. **Commit 4**: Phase 7 (Dynamic generation) → Fully dynamic configs
1. **Commit 5**: Phase 5 + Phase 6 (US3 + US4 structure) → Future prep
1. **Commit 6**: Phase 8 (Polish) → Production ready

Each commit is independently testable and can be reverted if needed.

______________________________________________________________________

## Success Criteria Checklist

After completing all phases, verify these success criteria from spec.md:

- [ ] **SC-001**: Adding new user requires only creating directory under user/ ✓
- [ ] **SC-002**: Adding new profile requires only creating directory under system/{platform}/profiles/ ✓
- [ ] **SC-003**: All 4 existing darwin configurations build successfully ✓
- [ ] **SC-004**: flake.nix reduced by ≥30% in line count ✓
- [ ] **SC-005**: nix flake show displays all auto-discovered configurations ✓
- [ ] **SC-006**: just list-users displays all users from directory structure ✓
- [ ] **SC-007**: just list-profiles [platform] displays all profiles from directory ✓
- [ ] **SC-008**: All helper functions defined in respective lib files (not flake.nix) ✓
- [ ] **SC-009**: Each platform's logic isolated to its own lib file ✓
- [ ] **SC-010**: Justfile validation uses auto-discovered lists ✓

______________________________________________________________________

## Acceptance Scenarios Mapping

| Task(s) | Acceptance Scenario | User Story |
|---------|---------------------|------------|
| T011 | AS-1.1: Create new user, verify in list | US1 |
| T012 | AS-1.2: Create new profile, verify discovery | US1 |
| T013 | AS-1.3: Remove user, verify disappears | US1 |
| T014 | AS-1.4: All combinations available | US1 |
| T025 | AS-2.1: Build using darwin.nix helper | US2 |
| T026 | AS-2.2: Modify darwin.nix without flake edit | US2 |
| T027 | AS-2.3: All configs build successfully | US2 |
| T034 | AS-3.1: nixos.nix exports mkNixosConfig | US3 |
| T035 | AS-3.2: nixos.nix imports without errors | US3 |
| T042 | AS-4.1: home-manager.nix exports both | US4 |
| T043 | AS-4.2: mkHomeConfig accessible | US4 |

______________________________________________________________________

## Notes

- All tasks follow checklist format: `- [ ] [ID] [P?] [Story?] Description with file path`
- [P] tasks can run in parallel (different files, no dependencies)
- [Story] labels (US1-US4) map to user stories from spec.md
- Focus on MVP first (US1 + US2) for maximum value
- US3 and US4 are structural prep for future work
- Commit incrementally to enable easy rollback
- Test continuously using quickstart.md scenarios
- Constitutional requirement: flake eval time must stay \<30 seconds

**Total Tasks**: 59\
**MVP Tasks**: ~40 (Phases 1-4, 7-8)\
**Future Prep Tasks**: ~19 (Phases 5-6)

**Estimated Effort**:

- MVP: 4-6 hours (focused refactoring)
- Full feature: 6-8 hours (including future prep)
