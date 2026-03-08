# Tasks: Application Desktop Metadata

**Input**: Design documents from `/specs/019-app-desktop-metadata/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/desktop-metadata-schema.nix

**Tests**: No explicit test tasks generated - validation occurs through `nix flake check` and platform-specific activation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Nix configuration management project following the User/System Split architecture:

- **Shared libs**: `platform/shared/lib/`
- **Platform libs**: `platform/darwin/lib/`, `platform/nixos/lib/`
- **App configs**: `platform/shared/app/{category}/`, `platform/{platform}/app/{category}/`
- **Documentation**: `docs/features/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create validation library and documentation foundation

- [x] T001 Create shared validation library at platform/shared/lib/desktop-metadata.nix
- [x] T002 [P] Create user documentation template at docs/features/019-app-desktop-metadata.md
- [x] T003 [P] Update CLAUDE.md with desktop metadata conventions

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core validation and schema that ALL user stories depend on

**⚠️ CRITICAL**: No user story implementation (file associations, autostart, paths) can begin until this phase is complete

- [x] T004 Implement desktop metadata type definition in platform/shared/lib/desktop-metadata.nix
- [x] T005 Implement validateDesktopMetadata function in platform/shared/lib/desktop-metadata.nix
- [x] T006 Implement helper functions (getDesktopPath, hasDesktopFeatures, getAvailablePlatforms) in platform/shared/lib/desktop-metadata.nix
- [x] T007 Add validation error messages with actionable guidance in platform/shared/lib/desktop-metadata.nix
- [x] T008 Test validation library with nix flake check

**Checkpoint**: Foundation ready - validation library is functional, user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Define File Associations for Applications (Priority: P1) 🎯 MVP

**Goal**: Enable declaring file type associations in application configs and register them with the platform's native file association mechanism

**Independent Test**: Add file associations to a test application (e.g., zed-editor with [".json"]), activate configuration, verify double-clicking .json files opens the declared application

**Acceptance Criteria**:

1. Application config with file associations activates successfully
1. Declared file types open with the application after activation
1. Platform-specific precedence rules apply for conflicting associations
1. Validation error occurs if associations declared without platform path

### Implementation for User Story 1

- [x] T009 [P] [US1] Add darwin file association processing to platform/darwin/lib/darwin.nix
- [x] T010 [P] [US1] Add nixos file association processing to platform/nixos/lib/nixos.nix
- [x] T011 [P] [US1] Add desktop metadata with file associations to platform/shared/app/editor/helix.nix (example)
- [x] T012 [US1] Integrate validation into darwin platform lib (import and use shared validation) in platform/darwin/lib/darwin.nix
- [x] T013 [US1] Integrate validation into nixos platform lib (import and use shared validation) in platform/nixos/lib/nixos.nix
- [x] T014 [US1] Build test configuration (darwin): just build cdrokar darwin home-macmini-m4
- [ ] T015 [US1] Activate and verify file associations work on darwin
- [ ] T016 [US1] Test validation error: add associations without path, verify error message
- [ ] T017 [US1] Test backward compatibility: verify apps without desktop metadata still work

**Checkpoint**: At this point, file associations should be fully functional and testable independently on both platforms

______________________________________________________________________

## Phase 4: User Story 2 - Configure Application Autostart (Priority: P2)

**Goal**: Enable declaring autostart behavior in application configs and create platform-native autostart configuration (LaunchAgents, systemd services)

**Independent Test**: Add autostart=true to a test application config, log out and back in, verify application launches automatically

**Acceptance Criteria**:

1. Application with autostart=true launches at user login
1. Application with autostart=false or omitted does not autostart
1. Validation error occurs if autostart enabled without platform path

### Implementation for User Story 2

- [ ] T018 [P] [US2] Add darwin autostart processing (LaunchAgent creation) to platform/darwin/lib/darwin.nix
- [ ] T019 [P] [US2] Add nixos autostart processing (systemd user service) to platform/nixos/lib/nixos.nix
- [ ] T020 [P] [US2] Add desktop metadata with autostart to platform/darwin/app/aerospace.nix (example)
- [ ] T021 [US2] Build test configuration with autostart enabled: just build cdrokar home-macmini-m4
- [ ] T022 [US2] Activate and verify autostart works on darwin (check ~/Library/LaunchAgents/)
- [ ] T023 [US2] Test validation error: enable autostart without path, verify error message
- [ ] T024 [US2] Verify file associations (US1) still work after adding autostart code

**Checkpoint**: At this point, both file associations AND autostart should work independently and together

______________________________________________________________________

## Phase 5: User Story 3 - Declare Platform-Specific Desktop Paths (Priority: P3)

**Goal**: Ensure platform path infrastructure is solid, handles edge cases, and provides clear errors

**Independent Test**: Declare desktop paths for multiple platforms in an app config, activate on different platforms, verify only the active platform's path is used

**Acceptance Criteria**:

1. Apps with paths for multiple platforms use only the active platform's path
1. Apps with paths for one platform work on that platform, gracefully degrade on others
1. Validation clearly identifies missing paths when required

### Implementation for User Story 3

- [ ] T025 [P] [US3] Test multi-platform paths: add darwin and nixos paths to same app
- [ ] T026 [P] [US3] Test platform-specific app: add darwin-only path (aerospace)
- [ ] T027 [US3] Verify cross-platform app on darwin uses darwin path
- [ ] T028 [US3] Verify platform-specific app gracefully skips desktop features on unsupported platform
- [ ] T029 [US3] Add comprehensive path validation test cases in platform/shared/lib/desktop-metadata.nix
- [ ] T030 [US3] Test empty path error handling
- [ ] T031 [US3] Test missing platform path with associations error message
- [ ] T032 [US3] Test missing platform path with autostart error message

**Checkpoint**: All user stories should now be independently functional with comprehensive validation

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, examples, and repository-wide consistency

- [ ] T033 [P] Complete user documentation in docs/features/019-app-desktop-metadata.md
- [ ] T034 [P] Add desktop metadata to 3-5 more applications as examples (editors, browsers, tools)
- [ ] T035 [P] Document troubleshooting steps in docs/features/019-app-desktop-metadata.md
- [ ] T036 [P] Add platform-specific notes (Spotlight limitation, XDG MIME) to documentation
- [ ] T037 Verify quickstart.md examples match implemented functionality
- [ ] T038 Run full system build on both platforms: darwin and nixos
- [ ] T039 Final validation: nix flake check on complete repository
- [ ] T040 Create migration guide for adding desktop metadata to existing apps

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001) - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1 - File Associations)**:

  - Can start after Foundational (Phase 2)
  - No dependencies on other stories
  - Fully independent implementation and testing

- **User Story 2 (P2 - Autostart)**:

  - Can start after Foundational (Phase 2)
  - Independent from US1 (different code paths)
  - Should verify US1 still works after US2 implementation (T024)

- **User Story 3 (P3 - Desktop Paths)**:

  - Can start after Foundational (Phase 2)
  - Validates infrastructure used by US1 and US2
  - Adds edge case handling and error messages

### Within Each User Story

**User Story 1** (File Associations):

1. Platform processing (T009, T010) can run in parallel
1. Example app (T011) can run in parallel with platform code
1. Validation integration (T012, T013) depends on platform processing
1. Testing (T014-T017) is sequential after integration

**User Story 2** (Autostart):

1. Platform processing (T018, T019) can run in parallel
1. Example app (T020) can run in parallel with platform code
1. Testing (T021-T024) is sequential after platform processing

**User Story 3** (Desktop Paths):

1. All test cases (T025-T032) can run in parallel once infrastructure exists
1. This phase is primarily validation and edge case testing

### Parallel Opportunities

**Phase 1 (Setup)**:

- T002 and T003 can run in parallel with T001

**Phase 2 (Foundational)**:

- T004-T007 are sequential (building the same file)
- T008 must come last

**Phase 3 (User Story 1)**:

- T009, T010, T011 can all run in parallel (different files)
- T012 and T013 can run in parallel (different files)
- T014-T017 are sequential (testing)

**Phase 4 (User Story 2)**:

- T018, T019, T020 can all run in parallel (different files)
- T021-T024 are sequential (testing)

**Phase 5 (User Story 3)**:

- T025, T026 can run in parallel
- T029-T032 can run in parallel

**Phase 6 (Polish)**:

- T033, T034, T035, T036 can all run in parallel (different files)

______________________________________________________________________

## Parallel Example: User Story 1

```bash
# Launch darwin and nixos file association processing together:
Task 1: "Add darwin file association processing to platform/darwin/lib/darwin.nix"
Task 2: "Add nixos file association processing to platform/nixos/lib/nixos.nix"
Task 3: "Add desktop metadata with file associations to platform/shared/app/editor/zed.nix"

# Then integrate validation (can also run in parallel):
Task 4: "Integrate validation into darwin platform lib in platform/darwin/lib/darwin.nix"
Task 5: "Integrate validation into nixos platform lib in platform/nixos/lib/nixos.nix"
```

______________________________________________________________________

## Parallel Example: User Story 2

```bash
# Launch darwin and nixos autostart processing together:
Task 1: "Add darwin autostart processing to platform/darwin/lib/darwin.nix"
Task 2: "Add nixos autostart processing to platform/nixos/lib/nixos.nix"
Task 3: "Add desktop metadata with autostart to platform/darwin/app/aerospace.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. **Complete Phase 1**: Setup (T001-T003)
1. **Complete Phase 2**: Foundational validation library (T004-T008) - CRITICAL
1. **Complete Phase 3**: User Story 1 - File Associations (T009-T017)
1. **STOP and VALIDATE**:
   - Test file associations independently on darwin
   - Verify validation errors work correctly
   - Confirm backward compatibility
1. **Deploy/Demo**: MVP is ready - file associations working!

**MVP Deliverable**: Configuration authors can declare file associations in app configs, and they are registered with the platform after activation. This is the most fundamental desktop integration feature.

### Incremental Delivery

1. **Foundation**: Setup + Foundational (T001-T008) → Validation library ready
1. **MVP**: Add User Story 1 (T009-T017) → Test independently → Deploy/Demo
1. **Enhancement 1**: Add User Story 2 (T018-T024) → Test independently → Deploy/Demo
1. **Enhancement 2**: Add User Story 3 (T025-T032) → Validate edge cases → Deploy/Demo
1. **Polish**: Complete documentation and examples (T033-T040)

Each story adds value without breaking previous stories.

### Parallel Team Strategy

With multiple developers:

1. **Together**: Complete Setup + Foundational (T001-T008)
1. **Once Foundational is done**:
   - **Developer A**: User Story 1 - File Associations (T009-T017)
   - **Developer B**: User Story 2 - Autostart (T018-T024)
   - **Developer C**: User Story 3 - Path Validation (T025-T032)
1. **Together**: Polish and documentation (T033-T040)

Stories complete and integrate independently.

______________________________________________________________________

## Task Summary

### Total Tasks: 40

**By Phase**:

- Phase 1 (Setup): 3 tasks
- Phase 2 (Foundational): 5 tasks - **BLOCKS ALL STORIES**
- Phase 3 (US1 - File Associations): 9 tasks
- Phase 4 (US2 - Autostart): 7 tasks
- Phase 5 (US3 - Desktop Paths): 8 tasks
- Phase 6 (Polish): 8 tasks

**By User Story**:

- User Story 1 (P1): 9 tasks - **MVP PRIORITY**
- User Story 2 (P2): 7 tasks
- User Story 3 (P3): 8 tasks
- Infrastructure: 16 tasks (Setup + Foundational + Polish)

**Parallel Opportunities**: 18 tasks marked [P] can run concurrently

**Independent Test Criteria**:

- **US1**: File associations work - double-click file opens declared app
- **US2**: Autostart works - app launches at login
- **US3**: Platform paths validated - correct path used per platform

**Suggested MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1 only)

- **Total MVP tasks**: 17 tasks
- **Estimated effort**: 1-2 days for experienced Nix developer
- **Deliverable**: File associations fully functional with validation

______________________________________________________________________

## Notes

- **[P] tasks**: Different files, can run in parallel without conflicts
- **[Story] label**: Maps task to specific user story for traceability
- **Each user story**: Independently completable and testable
- **Validation**: Occurs through `nix flake check` and platform activation tests
- **Backward compatibility**: Critical requirement - apps without metadata must continue working
- **Platform isolation**: Darwin and NixOS processing completely independent
- **Commit strategy**: Commit after each task or logical group
- **Stop at checkpoints**: Validate each story independently before proceeding
- **Error handling**: All validation errors must be actionable with clear guidance

______________________________________________________________________

## File Paths Reference

**New Files**:

- `platform/shared/lib/desktop-metadata.nix` - Validation library (T001, T004-T007)
- `docs/features/019-app-desktop-metadata.md` - User documentation (T002, T033)

**Modified Files**:

- `platform/darwin/lib/darwin.nix` - Darwin processing (T009, T012, T018)
- `platform/nixos/lib/nixos.nix` - NixOS processing (T010, T013, T019)
- `platform/shared/app/editor/zed.nix` - Example with file associations (T011)
- `platform/darwin/app/aerospace.nix` - Example with autostart (T020)
- `CLAUDE.md` - Updated conventions (T003)

**No Changes Required**:

- `flake.nix` - No changes needed
- Application discovery system - Remains compatible
- User configurations - Backward compatible
