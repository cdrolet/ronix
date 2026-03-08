# Tasks: Platform-Agnostic Activation System

**Input**: Design documents from `/specs/015-platform-agnostic-activation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: This feature uses manual validation - no automated test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup & Research

**Purpose**: Validate research findings and prepare for implementation

- [X] T001 Verify activation script exists at `result/sw/bin/darwin-rebuild` on darwin after build
- [X] T002 [P] Document activation script location for current platform in research.md
- [X] T003 [P] Test error messages from activation script with intentionally broken config
- [X] T004 Verify `./result` symlink behavior and cleanup

**Checkpoint**: Research validated - implementation can begin

______________________________________________________________________

## Phase 2: User Story 1 - Build Configuration Uniformly (Priority: P1) 🎯 MVP

**Goal**: Developers can build configurations using `nix build` uniformly across platforms without calling platform-specific tools

**Independent Test**:

1. Run `just build cdrokar darwin home-macmini-m4`
1. Verify `./result` symlink exists
1. Verify build uses only `nix build` command
1. Verify build works identically on any platform

### Implementation for User Story 1

- [X] T005 [US1] Read current `_rebuild-command` implementation in /Users/charles/project/nix-config/justfile
- [X] T006 [US1] Modify `_rebuild-command` to use `nix build` for build operations in /Users/charles/project/nix-config/justfile
- [X] T007 [US1] Update `_rebuild-command` to get flake output path via `_flake-output-path` helper in /Users/charles/project/nix-config/justfile
- [X] T008 [US1] Test `just build cdrokar darwin home-macmini-m4` produces valid result symlink
- [X] T009 [US1] Test `just build` with invalid configuration shows clear error messages
- [X] T010 [US1] Verify build performance is within 10% of baseline (measure and document)

**Checkpoint**: Build command works uniformly across platforms, US1 complete and testable

______________________________________________________________________

## Phase 3: User Story 2 - Activate Configuration Uniformly (Priority: P1) 🎯 MVP

**Goal**: Developers can activate configurations using activation scripts from build outputs, not external tools

**Independent Test**:

1. Run `just build cdrokar darwin home-macmini-m4`
1. Run `just install cdrokar darwin home-macmini-m4`
1. Verify activation uses script from `./result` (not external darwin-rebuild)
1. Verify system configuration is applied

### Implementation for User Story 2

- [X] T011 [US2] Add result symlink validation to `_rebuild-command` in /Users/charles/project/nix-config/justfile
- [X] T012 [US2] Implement activation script detection for darwin in `_rebuild-command` in /Users/charles/project/nix-config/justfile
- [X] T013 [US2] Add error handling for missing result symlink in /Users/charles/project/nix-config/justfile
- [X] T014 [US2] Implement platform-specific sudo handling (both darwin and nixos require sudo) in /Users/charles/project/nix-config/justfile
- [X] T015 [US2] Add clear error messages for missing activation scripts in /Users/charles/project/nix-config/justfile
- [X] T016 [US2] Test `just install` on darwin with existing build result
- [X] T017 [US2] Test `just install` without build result shows error "Build result not found. Run 'just build' first."
- [X] T018 [US2] Test activation failure shows clear error message and doesn't partially activate
- [X] T019 [US2] Verify backward compatibility - existing workflows still function

**Checkpoint**: Install command works uniformly across platforms, US2 complete and testable

______________________________________________________________________

## Phase 4: User Story 3 - Add New Platform Support Easily (Priority: P2)

**Goal**: Adding a new platform requires only updating `_flake-output-path` helper, no changes to build/install logic

**Independent Test**:

1. Add hypothetical "kali" platform to `_flake-output-path`
1. Verify `just build` and `just install` logic doesn't need modification
1. Document process in quickstart.md

### Implementation for User Story 3

- [X] T020 [US3] Document extensibility pattern in /Users/charles/project/nix-config/justfile comments
- [X] T021 [US3] Add example for adding new platform in /Users/charles/project/nix-config/specs/015-platform-agnostic-activation/quickstart.md
- [X] T022 [US3] Verify `_rebuild-command` uses only data from helpers, no hardcoded platform logic
- [X] T023 [US3] Create extensibility validation checklist in /Users/charles/project/nix-config/specs/015-platform-agnostic-activation/quickstart.md

**Checkpoint**: Extensibility validated, US3 complete

______________________________________________________________________

## Phase 5: User Story 4 - Platform Delegation Research (Priority: P3)

**Goal**: Research feasibility of delegating platform-specific flake logic to platform library files

**Independent Test**: Complete feasibility assessment with clear recommendation (IMPLEMENT, DEFER, or REJECT)

### Research Tasks for User Story 4

- [ ] T024 [US4] Read current flake.nix and identify all platform-specific code in /Users/charles/project/nix-config/flake.nix
- [ ] T025 [US4] Research Nix dynamic import capabilities (builtins.readDir, import expressions)
- [ ] T026 [US4] Investigate conditional flake input loading based on filesystem
- [ ] T027 [US4] Create prototype platform library file in /Users/charles/project/nix-config/platform/darwin/lib/flake-delegate.nix
- [ ] T028 [US4] Test prototype: Load platform library and verify outputs work
- [ ] T029 [US4] Measure performance impact of dynamic discovery vs static (benchmark with hyperfine or similar)
- [ ] T030 [US4] Search Nix community for similar patterns (nixos-unified, flake-utils, etc.)
- [ ] T031 [US4] Document findings in /Users/charles/project/nix-config/specs/015-platform-agnostic-activation/research.md
- [ ] T032 [US4] Make recommendation: IMPLEMENT (≥80% reduction, \<5% perf impact), DEFER (feasible but complex), or REJECT (not feasible)

### Conditional Implementation (only if T032 recommends IMPLEMENT)

- [ ] T033 [US4] [OPTIONAL] Create standard platform library template
- [ ] T034 [US4] [OPTIONAL] Implement dynamic platform discovery in flake.nix
- [ ] T035 [US4] [OPTIONAL] Migrate darwin platform logic to platform library file
- [ ] T036 [US4] [OPTIONAL] Migrate nixos platform logic to platform library file
- [ ] T037 [US4] [OPTIONAL] Test full workflow with delegated platform libraries
- [ ] T038 [US4] [OPTIONAL] Measure and verify performance within acceptable range

**Checkpoint**: Platform delegation research complete, optional implementation done if feasible

______________________________________________________________________

## Phase 6: Documentation & Polish

**Purpose**: User-facing documentation and final validation

- [X] T039 Create user documentation in /Users/charles/project/nix-config/docs/features/015-platform-agnostic-activation.md
- [X] T040 [P] Document build workflow with examples in user guide (covered by T039)
- [X] T041 [P] Document install workflow with examples in user guide (covered by T039)
- [X] T042 [P] Add troubleshooting section with common errors in user guide (covered by T039)
- [X] T043 [P] Document extensibility process for adding new platforms in user guide (covered by T039)
- [X] T044 Update CLAUDE.md if activation approach impacts project guidelines (already updated)
- [X] T045 Final validation: All success criteria from spec.md met (see validation-report.md)
- [X] T046 Final validation: Backward compatibility verified - existing commands unchanged (see validation-report.md)
- [X] T047 Commit implementation with clear description of changes (commit add555a)

**Checkpoint**: Feature complete, documented, and ready for use

______________________________________________________________________

## Implementation Strategy

### MVP Scope (Recommended First Delivery)

**Phase 2 (US1) + Phase 3 (US2)**:

- Uniform build command across platforms
- Uniform activation command across platforms
- Error handling and validation
- Basic documentation

**Value**: Complete core functionality, immediately useful, validates architecture

**Estimated Effort**: Small (1-2 justfile functions modified, ~50 lines of code)

### Incremental Delivery

1. **Sprint 1**: US1 + US2 (MVP) - Core activation improvement
1. **Sprint 2**: US3 - Document extensibility, validate design
1. **Sprint 3**: US4 - Research platform delegation (optional enhancement)
1. **Sprint 4**: Documentation polish and final validation

______________________________________________________________________

## Dependencies

### User Story Dependencies

```
Phase 1 (Setup/Research) → Must complete before any user story
    ↓
Phase 2 (US1: Build) → Independent, can start after Phase 1
    ↓
Phase 3 (US2: Activate) → Depends on US1 (needs build working)
    ↓
Phase 4 (US3: Extensibility) → Depends on US1 + US2 (validates design)
    ↓
Phase 5 (US4: Platform Delegation) → Independent research, can run in parallel with US1-US3
    ↓
Phase 6 (Documentation) → Depends on US1 + US2 (minimum), US3 + US4 (full)
```

### Critical Path

1. Phase 1 (Setup) - 1 hour
1. Phase 2 (US1) - 2-3 hours
1. Phase 3 (US2) - 3-4 hours
1. Phase 6 (Docs) - 2 hours

**Total Critical Path**: ~8-10 hours

### Parallel Opportunities

**After Phase 1 Complete**:

- US4 (Platform Delegation Research) can run in parallel with US1/US2/US3
- Documentation tasks (T040, T041, T042, T043) can run in parallel within Phase 6

**Within Phases**:

- Setup tasks T002, T003, T004 can run in parallel
- Documentation tasks T040-T043 can run in parallel

______________________________________________________________________

## Task Validation

### Checklist Format Compliance

✅ All tasks follow format: `- [ ] [TID] [P?] [Story?] Description with file path`
✅ Task IDs sequential: T001 through T047
✅ [P] markers on parallelizable tasks
✅ [Story] labels on user story tasks (US1, US2, US3, US4)
✅ File paths included in descriptions

### Independent Test Criteria

- **US1**: Build command works, creates result symlink, shows errors
- **US2**: Install command works, uses activation script, handles errors
- **US3**: Extensibility validated, documented
- **US4**: Research complete with recommendation

### Task Coverage

- Setup & Research: 4 tasks
- US1 (Build Uniformly): 6 tasks
- US2 (Activate Uniformly): 9 tasks
- US3 (Easy Platform Addition): 4 tasks
- US4 (Platform Delegation): 9 research + 6 optional implementation
- Documentation & Polish: 9 tasks

**Total**: 47 tasks (32 required + 15 optional)

______________________________________________________________________

## Notes

### Research Task R5 (Platform Delegation)

This is an exploratory task (US4, Priority P3). The research phase (T024-T032) is required to make an informed decision, but the implementation phase (T033-T038) is conditional:

- **IMPLEMENT**: If research shows ≥80% code reduction with \<5% performance impact
- **DEFER**: If feasible but too complex for this feature (create follow-up spec)
- **REJECT**: If not technically feasible or doesn't provide sufficient benefit

### Backward Compatibility

All tasks maintain backward compatibility:

- Command signatures unchanged (`just build`, `just install`)
- Output format unchanged
- Existing configurations work without modification
- Only internal implementation changes (how activation happens, not what happens)

### Testing Approach

This feature uses manual validation instead of automated tests:

- Each user story has "Independent Test" criteria
- Manual testing on darwin platform (primary target)
- Error case testing with intentionally broken configs
- Performance benchmarking for build times

### File Changes Summary

**Modified Files**:

- `/Users/charles/project/nix-config/justfile` - Update `_rebuild-command` helper (primary change)

**New Files**:

- `/Users/charles/project/nix-config/docs/features/015-platform-agnostic-activation.md` - User documentation
- `/Users/charles/project/nix-config/platform/darwin/lib/flake-delegate.nix` - Optional, if US4 research recommends IMPLEMENT

**Updated Files**:

- `/Users/charles/project/nix-config/specs/015-platform-agnostic-activation/research.md` - R5 findings
- `/Users/charles/project/nix-config/specs/015-platform-agnostic-activation/quickstart.md` - Extensibility examples
