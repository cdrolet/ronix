# Tasks: Fuzzy Dock Application Matching

**Feature**: 042-fuzzy-dock-matching\
**Input**: Design documents from `/specs/042-fuzzy-dock-matching/`\
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓

**Tests**: Not requested in specification - implementation only

**Organization**: Tasks grouped by user story to enable independent implementation and testing of each increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths included in descriptions

## Path Conventions

Nix configuration repository structure:

- **Helper libraries**: `system/shared/lib/`
- **Platform settings**: `system/darwin/settings/user/`, `system/shared/family/gnome/settings/user/`
- **User configs**: `user/cdrokar/default.nix`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create fuzzy matcher helper library with string normalization utilities

- [x] T001 Create fuzzy-dock-matcher.nix skeleton in system/shared/lib/ with module header documentation
- [x] T002 [P] Implement normalizeAppName function using lib.toLower + builtins.replaceStrings in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T003 [P] Implement stripPlatformPrefix function using builtins.match for Darwin (.app) and GNOME (org.gnome.\*) patterns in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T004 [P] Implement getWords function using lib.splitString for word tokenization in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T005 [P] Implement matchesWord function using lib.elem + getWords for word-boundary matching in system/shared/lib/fuzzy-dock-matcher.nix

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core 5-step matching cascade that all user stories depend on

**⚠️ CRITICAL**: No user story work can begin until fuzzyMatchDock function is complete

- [x] T006 ~~Implement buildAppCatalog function~~ (SKIPPED - caller provides appCatalog directly, cleaner design)
- [x] T007 Implement matchEntry function with 5-step cascade (exact-case → exact-nocase → exact-nopath → word-boundary → skip) in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T008 Implement fuzzyMatchDock main function that processes entries list and returns {resolved, summary} in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T009 Implement deduplication logic (FR-006) to remove duplicate resolved paths while preserving order in system/shared/lib/fuzzy-dock-matcher.nix
- [x] T010 Add passthrough handling for separators ("|", "||") and folders ("/Downloads") in system/shared/lib/fuzzy-dock-matcher.nix

**Checkpoint**: Foundation ready - fuzzyMatchDock function complete and ready for integration

______________________________________________________________________

## Phase 3: User Story 1 - Simple Cross-Platform Dock Configuration (Priority: P1) 🎯 MVP

**Goal**: Enable portable dock configs using simple names ("calculator", "settings") that work on both Darwin and GNOME

**Independent Test**: Define user.docked = ["calculator", "settings", "mail"] and verify it resolves correctly on both platforms without duplicates

### Implementation for User Story 1

- [x] T011 [P] [US1] ~~Import fuzzy-dock-matcher.nix in system/shared/settings/user/dock.nix~~ (N/A - no shared user dock module)

- [x] T012 [P] [US1] Import fuzzy-dock-matcher.nix in system/darwin/lib/dock.nix (platform-specific)

- [x] T013 [P] [US1] Import fuzzy-dock-matcher.nix in system/shared/family/gnome/lib/dock.nix

- [x] T014 [US1] ~~Update system/shared/settings/user/dock.nix~~ (N/A - no shared user dock module)

- [x] T015 [US1] Update system/darwin/lib/dock.nix to use fuzzyMatchDock with buildDarwinAppCatalog for Darwin dock configuration

- [x] T016 [US1] Update system/shared/family/gnome/lib/dock.nix and settings/user/dock.nix to use fuzzyMatchDock with buildGnomeAppCatalog for GNOME favorite-apps configuration

- [x] T017 [US1] Add activation script home.activation.dockMatchingSummary in system/shared/family/gnome/settings/user/dock.nix to display match results

- [ ] T018 [US1] Test on Darwin with user.docked = ["calculator", "settings", "mail"] and verify dock contains correct apps

  - **Status**: Ready for testing - requires actual darwin system with applications installed
  - **Test command**: `just install cdrokar home-macmini-m4` then check dock layout
  - **Expected**: Apps resolve via fuzzy matching (e.g., "calculator" → "Calculator.app")

- [ ] T019 [US1] Test on NixOS/GNOME with user.docked = ["calculator", "settings", "terminal"] and verify favorite-apps contains correct .desktop files

  - **Status**: Ready for testing - requires actual nixos system with GNOME
  - **Test command**: `just install cdrokar avf-gnome` then check favorites
  - **Expected**: Apps resolve via fuzzy matching, activation summary displays matches

**Checkpoint**: User Story 1 complete - simple cross-platform dock configs work on both platforms with fuzzy matching

**Note**: Build-time evaluation shows apps as "skipped" because `builtins.pathExists` runs at eval-time on build host. Actual fuzzy matching executes at activation time on target system where apps exist.

______________________________________________________________________

## Phase 4: User Story 2 - Eliminate Duplicate Platform-Specific Entries (Priority: P2)

**Goal**: Remove duplicate dock entries (e.g., ["calculator", "org.gnome.Calculator"]) - single entry now works everywhere

**Independent Test**: Compare user.docked config before/after simplification - resulting dock layouts should be identical

### Implementation for User Story 2

- [ ] T020 [US2] Verify deduplication logic (T009) correctly handles ["calculator", "Calculator.app"] resolving to same path on Darwin
- [ ] T021 [US2] Verify deduplication logic correctly handles ["calculator", "org.gnome.Calculator"] resolving to same app on GNOME
- [ ] T022 [US2] Update user/cdrokar/default.nix to remove duplicate platform-specific entries from docked array
- [ ] T023 [US2] Test simplified config on Darwin - verify no apps missing from dock after removing GNOME-specific entries
- [ ] T024 [US2] Test simplified config on GNOME - verify no apps missing from favorites after removing Darwin-specific entries
- [ ] T025 [US2] Verify activation summary shows which entries were deduplicated

**Checkpoint**: User Story 2 complete - configs simplified by 30%+ with no functional changes

______________________________________________________________________

## Phase 5: User Story 3 - Graceful Handling of Missing Applications (Priority: P3)

**Goal**: Skip unresolvable entries silently (no build failures) - enables platform-specific apps in shared configs

**Independent Test**: Include Darwin-only "utm" and GNOME-only "nautilus" in config - both platforms build successfully, each skips unavailable app

### Implementation for User Story 3

- [ ] T026 [US3] Verify strategy 5 (skip) implementation in matchEntry function (T007) correctly returns null for no match
- [ ] T027 [US3] Verify fuzzyMatchDock filters out null results without failing build
- [ ] T028 [US3] Test with user.docked = ["calculator", "utm", "nautilus"] on Darwin - verify "utm" included, "nautilus" skipped, build succeeds
- [ ] T029 [US3] Test with user.docked = ["calculator", "utm", "nautilus"] on GNOME - verify "nautilus" included, "utm" skipped, build succeeds
- [ ] T030 [US3] Verify activation summary shows skipped entries with [skipped] strategy label
- [ ] T031 [US3] Test with all-invalid config user.docked = ["nonexistent1", "nonexistent2"] - verify build succeeds with empty dock and summary shows all skipped

**Checkpoint**: User Story 3 complete - graceful degradation works, no build failures from unresolvable entries

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, edge case handling, and cross-platform validation

- [ ] T032 [P] Add comprehensive header documentation to system/shared/lib/fuzzy-dock-matcher.nix with 5-step cascade explanation, examples, edge cases
- [ ] T033 [P] Verify special character handling (FR-010) - test with apps like "Proton Mail", "UTM", "com.mitchellh.ghostty"
- [ ] T034 [P] Verify order preservation (FR-007) - test that user.docked order matches final dock/favorites order
- [ ] T035 Test edge case: empty user.docked = [] - verify no activation errors, summary skipped
- [ ] T036 Test edge case: user.docked with only separators ["|", "||"] - verify passthrough works
- [ ] T037 Test edge case: user.docked with mix of all entry types \["brave", "|", "/Downloads", "<trash>"\] - verify each type handled correctly
- [ ] T038 Verify performance with 30 dock entries against 500 app catalog - confirm \<1 second evaluation time (NFR-001)
- [ ] T039 Run nix flake check to validate syntax and module structure
- [ ] T040 Document fuzzy matching feature in docs/features/042-fuzzy-dock-matching.md with usage examples

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (T001-T005) completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational (T006-T010) completion
  - User stories CAN proceed in parallel (if multiple developers)
  - OR sequentially in priority order (P1 → P2 → P3) for single developer
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent - only needs Foundational phase
- **User Story 2 (P2)**: Technically independent but logically builds on US1 (simplifies configs enabled by fuzzy matching)
- **User Story 3 (P3)**: Independent - graceful degradation works standalone

### Within Each User Story

**User Story 1 Flow**:

1. T011-T013 (imports) can run in parallel
1. T014-T016 (integration) must follow imports
1. T017 (activation summary) can run in parallel with T014-T016
1. T018-T019 (testing) must be last

**User Story 2 Flow**:

1. T020-T021 (verification) can run in parallel
1. T022 (config update) follows verification
1. T023-T025 (testing) must be last

**User Story 3 Flow**:

1. T026-T027 (verification) can run in parallel
1. T028-T031 (testing) must follow verification

### Parallel Opportunities

**Setup Phase** (all can run in parallel):

- T002, T003, T004, T005 (string utilities - different sections of same file)

**User Story 1**:

- T011, T012, T013 (imports - different files)
- T014, T015, T016, T017 (integration - different files)

**User Story 2**:

- T020, T021 (verification - logical checks, no file writes)
- T023, T024 (testing - different platforms)

**User Story 3**:

- T026, T027 (verification - logical checks)
- T028, T029 (testing - different platforms)

**Polish Phase**:

- T032, T033, T034 (documentation/testing - independent)

______________________________________________________________________

## Parallel Example: User Story 1

```bash
# Launch all imports together:
Task: "Import fuzzy-dock-matcher.nix in system/shared/settings/user/dock.nix"
Task: "Import fuzzy-dock-matcher.nix in system/darwin/settings/user/dock.nix"
Task: "Import fuzzy-dock-matcher.nix in system/shared/family/gnome/settings/user/dock.nix"

# Launch all integration tasks together:
Task: "Update system/shared/settings/user/dock.nix to call fuzzyMatchDock"
Task: "Update system/darwin/settings/user/dock.nix to use fuzzyMatchDock results"
Task: "Update system/shared/family/gnome/settings/user/dock.nix to use fuzzyMatchDock results"
Task: "Add activation script home.activation.dockMatchingSummary"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005) - String utilities
1. Complete Phase 2: Foundational (T006-T010) - Core fuzzyMatchDock function
1. Complete Phase 3: User Story 1 (T011-T019) - Basic fuzzy matching works
1. **STOP and VALIDATE**: Test with ["calculator", "settings", "mail"] on both platforms
1. Deploy/use simplified configs immediately

### Incremental Delivery

1. **Foundation** (T001-T010) → Fuzzy matcher ready
1. **+US1** (T011-T019) → Simple cross-platform configs work (MVP!)
1. **+US2** (T020-T025) → Remove duplicates from configs (30% smaller)
1. **+US3** (T026-T031) → Graceful degradation (platform-specific apps work)
1. **+Polish** (T032-T040) → Documentation, edge cases, validation

### Single Developer Strategy

1. Complete Setup → Foundational (foundation ready)
1. Complete US1 → Test independently → Use immediately (MVP)
1. Complete US2 → Simplify configs → Commit cleaned configs
1. Complete US3 → Add platform-specific apps → Validate graceful skipping
1. Complete Polish → Document, validate, close feature

### Parallel Team Strategy (if applicable)

With 2 developers:

1. Both complete Setup + Foundational together
1. Once Foundational done:
   - Developer A: US1 (integration) + US2 (cleanup)
   - Developer B: US3 (graceful degradation) + Polish
1. Merge and validate

______________________________________________________________________

## Notes

- No tests requested in specification - manual validation via nix build + visual inspection
- [P] tasks are in different files or independent sections - safe to parallelize
- [Story] labels enable tracking which tasks belong to which user story
- Each user story independently completable and testable
- Constitution compliance: Module size ~150 lines (under 200 limit ✓)
- Performance target: \<1 second for 30 entries × 500 apps (NFR-001)
- Activation summary provides user-visible feedback (FR-012)
- Commit after each phase or logical group
- Stop at any checkpoint to validate story independently
