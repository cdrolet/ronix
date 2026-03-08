# Tasks: Simplified Application Configuration

**Feature**: 020-app-array-config\
**Input**: Design documents from `/specs/020-app-array-config/`\
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: No test tasks included (not requested in specification)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Nix configuration repository structure
- Primary modification: `user/shared/lib/home-manager.nix`
- Testing: `user/{username}/default.nix` files
- Documentation: `CLAUDE.md` and `docs/features/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project validation and prerequisite checks

- [x] T001 Verify nix flake check passes with current configuration
- [x] T002 Document current state of user/shared/lib/home-manager.nix (line count, structure)
- [x] T003 [P] Create backup of existing user configurations for rollback testing

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core implementation that MUST be complete before ANY user story validation can begin

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Add user.applications option definition to user/shared/lib/home-manager.nix
- [x] T005 Implement conditional import logic in user/shared/lib/home-manager.nix config section
- [x] T006 Run nix flake check to validate syntax and type system
- [x] T007 Verify module size remains under 200 lines (constitutional requirement)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Basic Application Declaration (Priority: P1) 🎯 MVP

**Goal**: Enable users to declare applications in a simple array within their user configuration structure, eliminating manual discovery imports

**Independent Test**: Create a test user configuration with applications array, build it, and verify all specified applications are imported and available in the environment

### Implementation for User Story 1

- [ ] T008 [US1] Create test user configuration user/test-user/default.nix with applications array
- [ ] T009 [US1] Add applications field to test user config with minimal app set ["git"]
- [ ] T010 [US1] Build test user configuration with just build test-user home (or appropriate profile)
- [ ] T011 [US1] Verify git application imported and available in test user environment
- [ ] T012 [US1] Expand applications array to ["git" "zsh" "helix"] in test user config
- [ ] T013 [US1] Rebuild and verify all three applications imported correctly
- [ ] T014 [US1] Test empty applications array ([]) builds successfully with no imports
- [ ] T015 [US1] Test null applications value (or omitted field) builds successfully
- [ ] T016 [US1] Test invalid application name produces clear error message with suggestions
- [ ] T017 [US1] Clean up test user configuration (optional: keep for future reference)

**Checkpoint**: At this point, User Story 1 should be fully functional - users can declare apps in a simple array

______________________________________________________________________

## Phase 4: User Story 2 - Migration from Explicit Discovery (Priority: P2)

**Goal**: Provide clear migration path for existing users to move from explicit discovery imports to simplified array-based approach

**Independent Test**: Take an existing user configuration with explicit discovery, convert to array-based approach, verify identical application imports

### Implementation for User Story 2

- [ ] T018 [US2] Select existing user config for migration (e.g., user/cdrokar/default.nix)
- [ ] T019 [US2] Document current applications list from explicit mkApplicationsModule call
- [ ] T020 [US2] Build current configuration to establish baseline
- [ ] T021 [US2] Remove discovery library import from user config imports section
- [ ] T022 [US2] Remove mkApplicationsModule call from user config imports section
- [ ] T023 [US2] Add applications array to user structure with same application names
- [ ] T024 [US2] Build migrated configuration with just build cdrokar home-macmini-m4
- [ ] T025 [US2] Verify identical applications imported (compare with baseline from T020)
- [ ] T026 [US2] Count lines removed vs lines added (should be 8-12 line reduction)
- [ ] T027 [US2] Validate user environment functionality unchanged after migration

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - migration path proven

______________________________________________________________________

## Phase 5: User Story 3 - Platform-Specific Application Handling (Priority: P3)

**Goal**: Ensure system gracefully handles platform-specific applications without manual platform checks

**Independent Test**: Create configuration with mixed shared and platform-specific apps, build on different platforms (if available), verify graceful handling

### Implementation for User Story 3

- [ ] T028 [US3] Add platform-specific app to test configuration (e.g., "aerospace" on darwin)
- [ ] T029 [US3] Build configuration on native platform and verify app imported
- [ ] T030 [US3] Test configuration with mix of shared and platform-specific apps ["git" "zsh" "aerospace"]
- [ ] T031 [US3] Verify shared apps imported on all platforms, platform-specific gracefully handled
- [ ] T032 [US3] Document platform-specific app behavior in user documentation
- [ ] T033 [US3] Validate error messages for platform-unavailable apps are clear (if applicable)

**Checkpoint**: All user stories should now be independently functional - platform handling works gracefully

______________________________________________________________________

## Phase 6: Backward Compatibility Validation

**Goal**: Ensure 100% of existing user configurations continue to work without modification

**Independent Test**: Build all existing user configurations without any changes and verify success

- [ ] T034 Build existing user cdrokar with original explicit discovery pattern
- [ ] T035 Build existing user cdrolet with original explicit discovery pattern
- [ ] T036 Build existing user cdrixus with original explicit discovery pattern
- [ ] T037 Verify all builds complete successfully (backward compatibility confirmed)
- [ ] T038 Run nix flake check across entire repository
- [ ] T039 Document backward compatibility test results

**Checkpoint**: Backward compatibility verified - existing configs unaffected

______________________________________________________________________

## Phase 7: Documentation & Polish

**Purpose**: Complete documentation and finalize implementation

- [ ] T040 [P] Update CLAUDE.md with new user configuration pattern (replace old discovery template)
- [ ] T041 [P] Create user documentation in docs/features/020-app-array-config.md
- [ ] T042 [P] Add example configurations showing both old and new patterns
- [ ] T043 [P] Document migration steps for users who want to switch
- [ ] T044 [P] Update "Adding Content" → "New User" section in CLAUDE.md
- [ ] T045 Document edge cases and error handling in user guide
- [ ] T046 Add troubleshooting section for common issues
- [ ] T047 Run alejandra formatter on modified files
- [ ] T048 Final nix flake check validation
- [ ] T049 Review module size (must be under 200 lines per constitution)
- [ ] T050 Run quickstart.md validation checklist

**Checkpoint**: Feature complete and documented

______________________________________________________________________

## Phase 8: Optional Migration (Can be done incrementally post-merge)

**Purpose**: Migrate remaining user configurations to new pattern (optional, gradual)

**Note**: These tasks are optional and can be done at any time after merge. They do not block feature completion.

- [ ] T051 [P] Migrate user/cdrolet/default.nix to applications array pattern (if not done in US2)
- [ ] T052 [P] Migrate user/cdrixus/default.nix to applications array pattern
- [ ] T053 [P] Build and validate each migrated user configuration
- [ ] T054 [P] Document line count reduction for each migration (should be 8-12 lines)
- [ ] T055 [P] Commit each user migration separately for easy rollback if needed

**Checkpoint**: All users migrated to simplified pattern (optional goal)

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if testing capacity allows)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Backward Compat (Phase 6)**: Should happen after US1 complete (can overlap with US2/US3)
- **Documentation (Phase 7)**: Depends on all user stories being complete
- **Optional Migration (Phase 8)**: Can happen anytime after merge, no blocking dependencies

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after US1 complete (needs working implementation to migrate to)
- **User Story 3 (P3)**: Can start after US1 complete (needs basic functionality working)

### Within Each User Story

- Build baseline before making changes (for comparison)
- Modify configuration files
- Build modified configuration
- Verify functionality matches expectations
- Document results

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T003 independent)
- All Foundational tasks are sequential (modifying same file)
- User Stories could theoretically run in parallel if testing on different machines/platforms
- All Documentation tasks marked [P] can run in parallel (different files)
- All Optional Migration tasks marked [P] can run in parallel (different user files)

______________________________________________________________________

## Parallel Example: Documentation Phase

```bash
# Launch all documentation tasks together:
Task: "Update CLAUDE.md with new user configuration pattern"
Task: "Create user documentation in docs/features/020-app-array-config.md"
Task: "Add example configurations showing both old and new patterns"
Task: "Document migration steps for users who want to switch"
Task: "Update 'Adding Content' → 'New User' section in CLAUDE.md"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (~5 min)
1. Complete Phase 2: Foundational (~20 min) - CRITICAL
1. Complete Phase 3: User Story 1 (~15 min)
1. **STOP and VALIDATE**: Test User Story 1 independently
1. Run backward compat checks (Phase 6: ~10 min)
1. Basic documentation (Phase 7: ~15 min)
1. **Total MVP time: ~65 minutes**

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (~25 min)
1. Add User Story 1 → Test independently → **MVP READY** (~15 min)
1. Add User Story 2 → Migration path proven (~20 min)
1. Add User Story 3 → Platform handling complete (~15 min)
1. Backward compat validation → Confidence in release (~10 min)
1. Complete documentation → Ready to merge (~15 min)
1. **Total feature time: ~100 minutes (under 2 hours)**

### Sequential Strategy (Recommended)

Single developer implementation:

1. Phase 1: Setup (validate current state)
1. Phase 2: Foundational (core implementation)
1. Phase 3: User Story 1 (test basic functionality)
1. Phase 6: Backward Compat (verify no breakage)
1. Phase 4: User Story 2 (prove migration)
1. Phase 5: User Story 3 (platform handling)
1. Phase 7: Documentation (complete feature)
1. Phase 8: Optional Migration (can defer to post-merge)

______________________________________________________________________

## Task Statistics

- **Total Tasks**: 55 tasks
- **Setup Phase**: 3 tasks
- **Foundational Phase**: 4 tasks (BLOCKING)
- **User Story 1**: 10 tasks (MVP)
- **User Story 2**: 10 tasks
- **User Story 3**: 6 tasks
- **Backward Compatibility**: 6 tasks
- **Documentation**: 11 tasks
- **Optional Migration**: 5 tasks

### Tasks by User Story

- **US1 (P1)**: 10 tasks - Basic application declaration
- **US2 (P2)**: 10 tasks - Migration from explicit discovery
- **US3 (P3)**: 6 tasks - Platform-specific handling

### Parallel Opportunities

- **Setup phase**: 1 task can run in parallel (T003)
- **Documentation phase**: 5 tasks can run in parallel (T040-T044)
- **Optional migration**: 3 tasks can run in parallel (T051-T053)
- **Total parallelizable**: ~9 tasks (16% of total)

### Independent Test Criteria

- **US1**: Create test config with array, build, verify apps imported
- **US2**: Migrate existing config, build, verify identical imports
- **US3**: Test platform-specific apps, verify graceful handling

### Suggested MVP Scope

**Minimum Viable Product** (ready to merge and use):

- Phase 1: Setup
- Phase 2: Foundational
- Phase 3: User Story 1
- Phase 6: Backward Compatibility (essential for confidence)
- Phase 7: Basic documentation (T040, T041, T048)

**MVP delivers**:

- Working applications array feature
- Backward compatible with existing configs
- Basic documentation for users
- **Estimated time**: 65-75 minutes

**Post-MVP** (can be done in follow-up PRs):

- Phase 4: User Story 2 (migration guide)
- Phase 5: User Story 3 (platform documentation)
- Phase 7: Complete documentation
- Phase 8: Optional user migrations

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each logical group of tasks (per user story)
- Stop at any checkpoint to validate story independently
- Module MUST remain under 200 lines (constitutional requirement)
- Backward compatibility is non-negotiable (SC-004)
- No tests requested in specification (validation via builds only)

______________________________________________________________________

## Success Validation

After completing all tasks, verify against success criteria:

- [ ] **SC-001**: Users can declare apps in ≤3 lines (single array line)
- [ ] **SC-002**: Config files reduced by 8-12 lines (verify in US2)
- [ ] **SC-003**: New users don't need discovery knowledge (verify with test user)
- [ ] **SC-004**: 100% backward compatibility (verify in Phase 6)
- [ ] **SC-005**: No performance regression (compare build times)
- [ ] **SC-006**: Users only edit applications array (no imports to touch)

All success criteria should be met upon task completion.
