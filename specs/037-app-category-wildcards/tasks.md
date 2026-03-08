# Tasks: App Category Wildcards

**Input**: Design documents from `/specs/037-app-category-wildcards/`\
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/discovery-api.md ✓

**Tests**: Not explicitly requested in spec - implementation tasks only (validation via nix flake check)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Nix configuration library extension. All changes are in `system/shared/lib/discovery.nix`.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No setup needed - extending existing discovery.nix

- [x] T001 Read existing discovery.nix to understand current implementation in system/shared/lib/discovery.nix
- [x] T002 Verify nix flake check passes before modifications

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core wildcard detection and expansion functions that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until these helper functions are complete

- [x] T003 [P] Implement isWildcard function in system/shared/lib/discovery.nix
- [x] T004 [P] Implement extractCategory function in system/shared/lib/discovery.nix
- [x] T005 [P] Implement listAppsInCategory helper in system/shared/lib/discovery.nix
- [x] T006 [P] Implement listAppsInCategorySafe wrapper in system/shared/lib/discovery.nix
- [x] T007 Implement buildWildcardSearchPaths function in system/shared/lib/discovery.nix
- [x] T008 Run nix flake check to verify foundational functions compile

**Checkpoint**: Foundation ready - user story implementation can now begin

______________________________________________________________________

## Phase 3: User Story 1 - Install All Apps in a Category (Priority: P1) 🎯 MVP

**Goal**: Users can install all apps in a category using `"category/*"` pattern

**Independent Test**: User adds `"browser/*"` to applications array, runs `just install`, all browsers are installed

### Implementation for User Story 1

- [ ] T009 [US1] Implement expandCategoryWildcard function in system/shared/lib/discovery.nix
- [ ] T010 [US1] Add validation for multi-level wildcards (error if `"*/*/*"`) in expandCategoryWildcard
- [ ] T011 [US1] Add warning for empty category expansion in expandCategoryWildcard
- [ ] T012 [US1] Create test user config user/test-wildcard-us1/default.nix with applications = ["browser/\*"]
- [ ] T013 [US1] Run nix flake check to verify User Story 1 functions compile
- [ ] T014 [US1] Test build with just build test-wildcard-us1 home-macmini-m4 (verify browsers installed)

**Checkpoint**: Category wildcards work - users can install all apps in a category

______________________________________________________________________

## Phase 4: User Story 2 - Mix Wildcards and Explicit App Names (Priority: P1) 🎯 MVP Extension

**Goal**: Users can combine wildcard patterns with explicit app names in same applications array

**Independent Test**: User config with `["dev/*", "zen", "obsidian"]` installs all dev apps plus zen and obsidian without duplicates

### Implementation for User Story 2

- [ ] T015 [US2] Implement expandGlobalWildcard function in system/shared/lib/discovery.nix
- [ ] T016 [US2] Implement expandWildcards coordinator function in system/shared/lib/discovery.nix
- [ ] T017 [US2] Add lib.unique deduplication in expandWildcards
- [ ] T018 [US2] Modify resolveApplications to call expandWildcards before resolution in system/shared/lib/discovery.nix
- [ ] T019 [US2] Create test user config user/test-wildcard-us2/default.nix with applications = ["browser/\*", "brave", "git"]
- [ ] T020 [US2] Run nix flake check to verify User Story 2 integration
- [ ] T021 [US2] Test build to verify brave is not duplicated (appears once in final app list)

**Checkpoint**: Wildcards and explicit apps work together with proper deduplication

______________________________________________________________________

## Phase 5: User Story 3 - Platform-Specific Category Wildcards (Priority: P2)

**Goal**: Wildcard patterns automatically discover apps from correct platform hierarchy (darwin vs nixos)

**Independent Test**: Same user config with `"browser/*"` works on both darwin and nixos, installing platform-appropriate browsers

### Implementation for User Story 3

- [ ] T022 [US3] Verify buildWildcardSearchPaths handles darwin platform (system/darwin/app → system/shared/app)
- [ ] T023 [US3] Verify buildWildcardSearchPaths handles nixos platform (system/nixos/app → system/shared/app)
- [ ] T024 [US3] Test darwin build with user/test-wildcard-us3/default.nix (applications = ["productivity/\*"])
- [ ] T025 [US3] Test nixos build with same user config (verify platform-specific apps discovered)

**Checkpoint**: Wildcards work cross-platform without config changes

______________________________________________________________________

## Phase 6: User Story 4 - Hierarchical Discovery with Wildcards (Priority: P2)

**Goal**: Category wildcards respect hierarchical discovery (system → families → shared)

**Independent Test**: GNOME user with `"productivity/*"` gets apps from system/nixos/app/productivity/ → system/shared/family/gnome/app/productivity/ → system/shared/app/productivity/

### Implementation for User Story 4

- [ ] T026 [US4] Verify buildWildcardSearchPaths integrates family paths correctly
- [ ] T027 [US4] Verify expandCategoryWildcard searches all hierarchy levels in order
- [ ] T028 [US4] Create test nixos host with family = ["linux", "gnome"] in system/nixos/host/test-wildcard-us4/default.nix
- [ ] T029 [US4] Create test user user/test-wildcard-us4/default.nix with applications = ["utility/\*"]
- [ ] T030 [US4] Test build to verify family-specific apps (geary from gnome/app/productivity/) are discovered
- [ ] T031 [US4] Verify first-match-wins behavior (no duplicates when app exists in multiple hierarchy levels)

**Checkpoint**: Hierarchical discovery works correctly with wildcards

______________________________________________________________________

## Phase 7: User Story 5 - Validation and Error Handling (Priority: P3)

**Goal**: Clear error messages when wildcard patterns are invalid or produce unexpected results

**Independent Test**: User adds `"nonexistent-category/*"` and receives clear warning; invalid patterns like `"dev/lang/*"` produce errors

### Implementation for User Story 5

- [ ] T032 [US5] Implement validateWildcardPattern function in system/shared/lib/discovery.nix (if not already in expandCategoryWildcard)
- [ ] T033 [US5] Add error for empty pattern in validateWildcardPattern
- [ ] T034 [US5] Add error message with available categories when wildcard matches zero apps
- [ ] T035 [US5] Create test user config user/test-wildcard-us5/default.nix with applications = ["invalid/\*"]
- [ ] T036 [US5] Verify warning message appears during nix flake check
- [ ] T037 [US5] Test multi-level wildcard error with applications = ["dev/lang/\*"]
- [ ] T038 [US5] Verify error message explains only single-level wildcards supported

**Checkpoint**: All validation and error handling complete

______________________________________________________________________

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Export functions, documentation, and final validation

- [ ] T039 [P] Export new functions in discovery.nix exports section (isWildcard, extractCategory, expandWildcards, etc.)
- [ ] T040 [P] Update CLAUDE.md with wildcard syntax documentation (add to "Application Wildcards" section)
- [ ] T041 [P] Add migration examples to CLAUDE.md (before/after user configs)
- [ ] T042 [P] Add troubleshooting section to CLAUDE.md
- [ ] T043 Run full nix flake check to verify all changes
- [ ] T044 Test real user config migration (e.g., migrate cdrokar to use browser/\*)
- [ ] T045 Verify backward compatibility (existing configs without wildcards still work)
- [ ] T046 Clean up test user configs (or keep for regression testing)
- [ ] T047 Review quickstart.md examples match implementation
- [ ] T048 Final validation: Test "\*" global wildcard on darwin
- [ ] T049 Final validation: Test "\*" global wildcard on nixos

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001-T002) - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase (T003-T008) completion
  - US1 (Phase 3): Can start after Foundational
  - US2 (Phase 4): Depends on US1 (T009) completion (extends expandWildcards)
  - US3 (Phase 5): Can start after US2 (T015-T018) - tests platform integration
  - US4 (Phase 6): Can start after US2 (T015-T018) - tests hierarchy integration
  - US5 (Phase 7): Can start after US1 (T009) - adds validation to existing functions
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on Foundational (Phase 2)
- **User Story 2 (P1)**: Depends on User Story 1 (needs expandCategoryWildcard to exist)
- **User Story 3 (P2)**: Depends on User Story 2 (tests integration with existing functions)
- **User Story 4 (P2)**: Depends on User Story 2 (tests hierarchy with wildcard expansion)
- **User Story 5 (P3)**: Depends on User Story 1 (adds validation to expandCategoryWildcard)

### Within Each User Story

- US1: expandCategoryWildcard → validation → test config → build test
- US2: expandGlobalWildcard → expandWildcards → modify resolveApplications → test
- US3: Verify platform paths → test darwin → test nixos
- US4: Verify hierarchy paths → test with families → verify deduplication
- US5: Validation logic → test invalid patterns → verify error messages

### Parallel Opportunities

**Phase 2 (Foundational)**:

- T003, T004, T005, T006 can run in parallel (different helper functions)

**Phase 3 (US1)**:

- No parallel tasks (sequential implementation of single function)

**Phase 4 (US2)**:

- T015, T016 can run in parallel (different functions)

**Phase 5 (US3)**:

- T024, T025 can run in parallel (different platform tests)

**Phase 6 (US4)**:

- No parallel tasks (sequential testing of hierarchy)

**Phase 7 (US5)**:

- T035, T037 can run in parallel (different test configs)

**Phase 8 (Polish)**:

- T039, T040, T041, T042 can run in parallel (different documentation tasks)
- T048, T049 can run in parallel (different platform tests)

______________________________________________________________________

## Parallel Example: Foundational Phase

```bash
# Launch all foundational helper functions together:
Task: "Implement isWildcard function in system/shared/lib/discovery.nix"
Task: "Implement extractCategory function in system/shared/lib/discovery.nix"
Task: "Implement listAppsInCategory helper in system/shared/lib/discovery.nix"
Task: "Implement listAppsInCategorySafe wrapper in system/shared/lib/discovery.nix"
```

## Parallel Example: Phase 8 (Documentation)

```bash
# Launch all documentation tasks together:
Task: "Export new functions in discovery.nix exports section"
Task: "Update CLAUDE.md with wildcard syntax documentation"
Task: "Add migration examples to CLAUDE.md"
Task: "Add troubleshooting section to CLAUDE.md"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only)

1. Complete Phase 1: Setup (T001-T002)
1. Complete Phase 2: Foundational (T003-T008) - CRITICAL
1. Complete Phase 3: User Story 1 (T009-T014) - Basic category wildcards
1. Complete Phase 4: User Story 2 (T015-T021) - Mixed patterns + deduplication
1. **STOP and VALIDATE**: Test US1 + US2 independently with real user config
1. Can deploy/demo basic wildcard functionality

### Incremental Delivery

1. Setup + Foundational → Foundation ready
1. Add US1 → Category wildcards work → Test independently
1. Add US2 → Wildcards + explicit apps work → Test independently → **MVP COMPLETE**
1. Add US3 → Cross-platform wildcards → Test independently
1. Add US4 → Hierarchical discovery → Test independently
1. Add US5 → Validation/errors → Test independently → **FEATURE COMPLETE**
1. Polish → Documentation + final tests → **READY FOR PR**

### Parallel Team Strategy (if applicable)

With multiple developers (unlikely for library extension):

1. Team completes Setup + Foundational together (T001-T008)
1. Once Foundational is done:
   - Developer A: User Story 1 (T009-T014)
   - Developer B: Wait for US1, then User Story 2 (T015-T021)
   - Developer C: User Story 5 validation (T032-T038) in parallel with US2
1. After US2 complete:
   - Developer A: User Story 3 (T022-T025)
   - Developer B: User Story 4 (T026-T031)
1. All: Polish (T039-T049) in parallel

**Realistic for solo developer**: Complete sequentially in priority order (P1 → P1 → P2 → P2 → P3)

______________________________________________________________________

## Summary

**Total Tasks**: 49 tasks

**Task Count per User Story**:

- Setup: 2 tasks
- Foundational: 6 tasks (BLOCKS all stories)
- User Story 1 (P1): 6 tasks - Category wildcards
- User Story 2 (P1): 7 tasks - Mixed patterns + deduplication
- User Story 3 (P2): 4 tasks - Cross-platform support
- User Story 4 (P2): 6 tasks - Hierarchical discovery
- User Story 5 (P3): 7 tasks - Validation and errors
- Polish: 11 tasks - Documentation + final validation

**Parallel Opportunities**: 13 tasks can run in parallel (marked with [P])

**Independent Test Criteria**:

- US1: `"browser/*"` installs all browsers
- US2: `["browser/*", "brave"]` dedups correctly
- US3: Same config works on darwin and nixos
- US4: GNOME families get family-specific apps
- US5: Invalid patterns show clear errors

**Suggested MVP Scope**: User Stories 1 + 2 (basic wildcard functionality + deduplication)

**Format Validation**: ✅ All 49 tasks follow checklist format with ID, optional [P], optional [Story], and file paths

______________________________________________________________________

## Notes

- All tasks modify single file: `system/shared/lib/discovery.nix`
- No test files created (validation via nix flake check + real builds)
- Test user configs can be kept or deleted after validation
- Each user story builds on previous (incremental enhancement)
- Backward compatible: existing configs without wildcards unaffected
- Total estimated implementation: ~200 lines added to discovery.nix
