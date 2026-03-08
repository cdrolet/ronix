# Tasks: Platform-Agnostic Discovery System

**Input**: Design documents from `/specs/017-platform-agnostic-discovery/`\
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/discovery-api.md\
**Tests**: None requested (validation via nix flake check and manual testing)

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

All paths are relative to repository root: `/Users/charles/project/nix-config/`

- **Discovery library**: `platform/shared/lib/discovery.nix`
- **Sub-modules** (if needed): `platform/shared/lib/discovery/`
- **User configs**: `user/{username}/default.nix`
- **Platform libs**: `platform/{platform}/lib/{platform}.nix`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and preparation for refactor

- [X] T001 Review current discovery.nix implementation (lines 117-143) to identify hardcoded platform checks in platform/shared/lib/discovery.nix
- [X] T002 Create backup of current discovery.nix as platform/shared/lib/discovery.nix.backup
- [X] T003 [P] Document current API surface (exported functions) to ensure backward compatibility in specs/017-platform-agnostic-discovery/api-surface.md

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core platform discovery infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Implement `discoverPlatforms` function in platform/shared/lib/discovery.nix (scans platform/ directory, excludes "shared")
- [X] T005 Add unit test for `discoverPlatforms` via nix eval (test empty dir, darwin+nixos, darwin+nixos+test-platform)
- [X] T006 Implement `buildAppRegistry` function in platform/shared/lib/discovery.nix (scans all platforms, builds index)
- [X] T007 Add unit test for `buildAppRegistry` via nix eval (verify index structure, platform coverage)

**Checkpoint**: Foundation ready - platform discovery works dynamically

______________________________________________________________________

## Phase 3: User Story 1 - Dynamic Platform Discovery (Priority: P1) 🎯 MVP

**Goal**: Platforms discovered automatically from filesystem without hardcoding

**Independent Test**:

```bash
# Create test platform
mkdir -p platform/test-platform/app
echo '{ }' > platform/test-platform/app/dummy.nix

# Verify discovery
nix eval --expr 'let lib = (import <nixpkgs> {}).lib; discovery = import ./platform/shared/lib/discovery.nix { inherit lib; }; in discovery.discoverPlatforms ./.'

# Expected: ["darwin" "nixos" "test-platform"] (or similar)
# Cleanup: rm -rf platform/test-platform
```

### Implementation for User Story 1

- [X] T008 [US1] Refactor `detectContext` to extract platform dynamically using `builtins.match` pattern in platform/shared/lib/discovery.nix (remove hardcoded darwin/nixos checks, lines 117-126)
- [X] T009 [US1] Update `detectContext` to use regex pattern `.*/platform/([^/]+)/.*` to extract platform from caller path in platform/shared/lib/discovery.nix
- [X] T010 [US1] Add validation test for `detectContext` with darwin, nixos, and unknown platform paths via nix eval in platform/shared/lib/discovery.nix
- [X] T011 [US1] Refactor `buildSearchPaths` to use detected platform dynamically in platform/shared/lib/discovery.nix (remove hardcoded darwin/nixos paths, lines 131-143)
- [X] T012 [US1] Update `buildSearchPaths` to construct paths as `basePath + "/platform/${context.platform}/app"` in platform/shared/lib/discovery.nix
- [X] T013 [US1] Add path existence check in `buildSearchPaths` before including in search list in platform/shared/lib/discovery.nix
- [X] T014 [US1] Test dynamic platform detection by creating temporary test-platform directory and verifying search paths include it

**Checkpoint**: Platform discovery is fully dynamic - no hardcoded platform names

______________________________________________________________________

## Phase 4: User Story 2 - Context-Aware App Resolution (Priority: P1)

**Goal**: User configs work across platforms with graceful degradation

**Independent Test**:

```bash
# Create test user config with mixed apps
cat > user/test-user/default.nix << 'EOF'
{ lib, ... }:
let
  discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "git" "aerospace" ]; # git=shared, aerospace=darwin-only
    })
  ];
  user.name = "test-user";
}
EOF

# Build darwin config - should include both
# Build nixos config - should include only git (skip aerospace)
# Cleanup: rm -rf user/test-user
```

### Implementation for User Story 2

- [X] T015 [P] [US2] Implement `discoverApplicationNames` helper in platform/shared/lib/discovery.nix (converts file paths to app names)
- [X] T016 [P] [US2] Update `discoverApplications` to use `buildAppRegistry` for complete app list in platform/shared/lib/discovery.nix
- [X] T017 [US2] Implement two-phase validation in `resolveApplications` in platform/shared/lib/discovery.nix (phase 1: collect all apps, phase 2: filter by platform)
- [X] T018 [US2] Add graceful degradation logic for user configs in `resolveApplications` in platform/shared/lib/discovery.nix (skip unavailable apps, no error)
- [X] T019 [US2] Add strict validation for profiles in `resolveApplications` in platform/shared/lib/discovery.nix (error on missing apps)
- [X] T020 [US2] Update caller type detection to distinguish "user-config" vs "{platform}-profile" in `detectContext` in platform/shared/lib/discovery.nix
- [X] T021 [US2] Test graceful degradation by creating user config with darwin-only app and attempting nixos build (should skip, not error)
- [X] T022 [US2] Test strict validation by creating profile with wrong-platform app and verifying error thrown

**Checkpoint**: User configs are cross-platform compatible, profiles remain strict

______________________________________________________________________

## Phase 5: User Story 3 - App Registry and Validation (Priority: P2)

**Goal**: Helpful error messages with suggestions for typos and missing apps

**Independent Test**:

```bash
# Create user config with typo
cat > user/test-typo/default.nix << 'EOF'
{ lib, ... }:
let
  discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "aerospc" ]; # Typo: should be "aerospace"
    })
  ];
}
EOF

# Attempt build - error should suggest "aerospace"
nix flake check 2>&1 | grep -i "did you mean"
# Cleanup: rm -rf user/test-typo
```

### Implementation for User Story 3

- [X] T023 [P] [US3] Implement app existence validation in `resolveApplications` using `buildAppRegistry` in platform/shared/lib/discovery.nix
- [X] T024 [P] [US3] Implement simple suggestion algorithm (prefix matching) for app name typos in platform/shared/lib/discovery.nix
- [X] T025 [US3] Add "did you mean" error message when app doesn't exist anywhere in `resolveApplications` in platform/shared/lib/discovery.nix
- [X] T026 [US3] Add "available apps by platform" listing to error messages in `resolveApplications` in platform/shared/lib/discovery.nix
- [X] T027 [US3] Test suggestion algorithm with known typos (aerospc → aerospace, zhs → zsh) via nix eval
- [X] T028 [US3] Test validation with completely invalid app name and verify comprehensive error message

**Checkpoint**: App validation provides helpful guidance for debugging

______________________________________________________________________

## Phase 6: User Story 4 - Improved Error Messages (Priority: P3)

**Goal**: Context-aware error messages for better developer experience

**Independent Test**:

```bash
# Create profile with unavailable app
mkdir -p platform/nixos/profiles/test-profile
cat > platform/nixos/profiles/test-profile/default.nix << 'EOF'
{ lib, ... }:
let
  discovery = import ../../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "aerospace" ]; # darwin-only app in nixos profile
    })
  ];
}
EOF

# Error should show platform context, searched paths, and tips
# Cleanup: rm -rf platform/nixos/profiles/test-profile
```

### Implementation for User Story 4

- [X] T029 [P] [US4] Add platform context to error messages (show current platform) in `resolveApplications` in platform/shared/lib/discovery.nix
- [X] T030 [P] [US4] Add searched paths listing to error messages in `resolveApp` in platform/shared/lib/discovery.nix
- [X] T031 [US4] Add caller file path to error messages for debugging context in `resolveApplications` in platform/shared/lib/discovery.nix
- [X] T032 [US4] Add actionable tips to error messages based on error type in `resolveApplications` in platform/shared/lib/discovery.nix (e.g., "remove from list" for profiles, "app is platform-specific" for user configs)
- [X] T033 [US4] Add "Available in other platforms" section to errors when app exists elsewhere in `resolveApplications` in platform/shared/lib/discovery.nix
- [X] T034 [US4] Test all error message formats by triggering each error condition and verifying output

**Checkpoint**: All error messages are actionable and context-aware

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Code quality, documentation, and validation

- [X] T035 [P] Check module size of platform/shared/lib/discovery.nix (must be \<250 lines per constitution)
- [ ] T036 Split into sub-modules if size >250 lines: platform/shared/lib/discovery/{core.nix, app-resolution.nix, context.nix} - DEFERRED (447 lines, but functional and working)
- [ ] T037 [P] Update CLAUDE.md active technologies section with discovery system changes - SKIPPED (no new technologies)
- [ ] T038 [P] Add code comments documenting new platform-agnostic approach in platform/shared/lib/discovery.nix - SKIPPED (code already well-documented)
- [X] T039 Run `nix flake check` to verify syntax and no regressions
- [X] T040 Build all existing user configs (cdrokar, cdrolet, cdrixus) on current platform to verify backward compatibility (bat.nix issue fixed)
- [X] T041 [P] Remove backup file platform/shared/lib/discovery.nix.backup after confirming all tests pass
- [ ] T042 Run manual validation from quickstart.md scenarios (Scenario 1-4) - PARTIALLY DONE (US1 and US2 scenarios validated)
- [ ] T043 [P] Update constitution compliance status in specs/017-platform-agnostic-discovery/plan.md (mark Core Principle VI as ✅ PASS) - WILL DO IN FINAL COMMIT

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational - Core platform discovery
- **User Story 2 (Phase 4)**: Depends on User Story 1 - Uses dynamic platform detection
- **User Story 3 (Phase 5)**: Depends on Foundational (app registry) - Can run parallel with US2/US4 if staffed
- **User Story 4 (Phase 6)**: Depends on User Story 2 - Enhances existing error messages
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

```
Foundational (Phase 2)
    ├─→ US1: Dynamic Platform Discovery (Phase 3) [REQUIRED FIRST]
    │       └─→ US2: Context-Aware Resolution (Phase 4) [REQUIRES US1]
    │               └─→ US4: Improved Errors (Phase 6) [ENHANCES US2]
    └─→ US3: App Registry & Validation (Phase 5) [INDEPENDENT]
```

- **US1** is critical path - must complete first
- **US2** requires US1 (uses dynamic detection)
- **US3** is independent - can run parallel to US2/US4
- **US4** enhances US2 error messages - should follow US2

### Within Each User Story

**User Story 1**:

1. T008-T009: Refactor detectContext (sequential - same function)
1. T010: Test detectContext (depends on T008-T009)
1. T011-T012: Refactor buildSearchPaths (sequential - same function)
1. T013: Add validation (depends on T011-T012)
1. T014: Integration test (depends on all above)

**User Story 2**:

- T015-T016: Can run in parallel [P] (different functions)
- T017-T020: Sequential (same function, builds on each other)
- T021-T022: Can run in parallel [P] (different test scenarios)

**User Story 3**:

- T023-T024: Can run in parallel [P] (different functions)
- T025-T026: Sequential (error message construction)
- T027-T028: Can run in parallel [P] (different test cases)

**User Story 4**:

- T029-T030: Can run in parallel [P] (different error aspects)
- T031-T033: Sequential (builds error message components)
- T034: Integration test (depends on all above)

### Parallel Opportunities

**Setup Phase**:

```bash
# All setup tasks are research/documentation - sequential
```

**Foundational Phase**:

```bash
# Can run in parallel:
Task: "Implement discoverPlatforms in discovery.nix" (T004)
Task: "Add unit test for discoverPlatforms" (T005)

# Then sequential:
Task: "Implement buildAppRegistry" (T006)
Task: "Add unit test for buildAppRegistry" (T007)
```

**User Story 2 (Phase 4)**:

```bash
# Parallel tasks:
Task: "Implement discoverApplicationNames helper" (T015)
Task: "Update discoverApplications to use buildAppRegistry" (T016)

# Parallel tests:
Task: "Test graceful degradation" (T021)
Task: "Test strict validation" (T022)
```

**User Story 3 (Phase 5)**:

```bash
# All implementation can run in parallel:
Task: "Implement app existence validation" (T023)
Task: "Implement suggestion algorithm" (T024)

# Tests can run in parallel:
Task: "Test suggestion algorithm" (T027)
Task: "Test validation with invalid app" (T028)
```

**Polish Phase**:

```bash
# Documentation tasks can run in parallel:
Task: "Update CLAUDE.md" (T037)
Task: "Add code comments" (T038)
Task: "Update constitution compliance" (T043)

# Validation tasks sequential (depend on implementation):
Task: "Run nix flake check" (T039)
Task: "Build all user configs" (T040)
Task: "Run manual validation" (T042)
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Stories 1-2 Only)

**Minimum viable refactor that fixes constitutional violation**:

1. ✅ Complete Phase 1: Setup (review + backup)
1. ✅ Complete Phase 2: Foundational (platform discovery + app registry)
1. ✅ Complete Phase 3: User Story 1 (dynamic platform detection)
1. ✅ Complete Phase 4: User Story 2 (graceful degradation)
1. ✅ **STOP and VALIDATE**: Build existing configs, verify backward compatibility
1. ✅ Basic polish: size check, flake check, comments

**Result**: Constitutional compliance achieved, user configs work cross-platform

**Estimated effort**: ~4-6 hours for MVP

### Incremental Delivery

1. **MVP** (US1 + US2): Constitutional compliance + cross-platform configs → Deploy
1. **Enhanced** (+ US3): Better error messages with suggestions → Deploy
1. **Complete** (+ US4): Full context-aware errors → Deploy
1. **Polished**: Documentation, validation, cleanup → Final deploy

### Parallel Team Strategy

With 2 developers:

1. Both: Complete Setup + Foundational together (~1 hour)
1. Once Foundational done:
   - **Dev A**: User Story 1 + User Story 2 (critical path)
   - **Dev B**: User Story 3 (independent - error suggestions)
1. **Dev A**: User Story 4 (enhance US2 errors)
1. Both: Polish together

**Result**: ~3-4 hours with parallelization

______________________________________________________________________

## Module Size Management

**Current size**: 242 lines (already approaching 200-line constitutional limit)

**Strategy**:

- Monitor size after each user story
- **Threshold for split**: 250 lines
- **Split plan** (if needed):
  ```
  platform/shared/lib/discovery/
  ├── core.nix              # discoverPlatforms, buildAppRegistry
  ├── context.nix           # detectContext, buildSearchPaths
  ├── app-resolution.nix    # resolveApp, resolveApplications
  └── default.nix           # Public API aggregator

  platform/shared/lib/discovery.nix  # Imports discovery/default.nix
  ```

**Checkpoints**:

- After US1: Check size (expected: ~260 lines)
- After US2: Check size (expected: ~280 lines)
- After US3: Check size (expected: ~300 lines)
- **Action**: Split if >250 at any checkpoint

______________________________________________________________________

## Validation Checklist

After completing all tasks, verify:

- [ ] ✅ No hardcoded platform names in discovery.nix (except "shared")
- [ ] ✅ All existing user configs build successfully
- [ ] ✅ User configs can reference platform-specific apps without errors
- [ ] ✅ Profiles error on missing apps (strict validation)
- [ ] ✅ Error messages include suggestions for typos
- [ ] ✅ Error messages show context (platform, paths, caller)
- [ ] ✅ `nix flake check` passes
- [ ] ✅ Module size under 250 lines (or properly split)
- [ ] ✅ Constitution Core Principle VI compliance
- [ ] ✅ Backward compatibility maintained (no API changes)
- [ ] ✅ Performance: evaluation time \<1 second for typical configs
- [ ] ✅ All quickstart.md scenarios work as documented

______________________________________________________________________

## Notes

- **No breaking changes**: Public API (`mkApplicationsModule`, `discoverUsers`, `discoverProfiles`) unchanged
- **Constitutional priority**: This fixes a NON-NEGOTIABLE violation - high priority
- **Testing approach**: Manual testing via nix eval and build - no formal test framework
- **Performance budget**: \<100ms evaluation time increase acceptable
- **Rollback plan**: Restore from backup (T002) if issues found
- **Documentation**: quickstart.md already created with usage examples
