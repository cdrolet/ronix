# Tasks: Nested Secrets Support

**Feature**: 029-nested-secrets-support
**Branch**: `029-nested-secrets-support`
**Input**: Design documents from `/specs/029-nested-secrets-support/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Task Summary

- **Total Tasks**: 18
- **Setup Phase**: 2 tasks
- **Foundational Phase**: 4 tasks (BLOCKING)
- **User Story 1 (P1)**: 3 tasks - Store Multiple SSH Keys
- **User Story 2 (P2)**: 3 tasks - Configure Apps with Nested Secrets
- **User Story 3 (P3)**: 3 tasks - CLI Support for Nested Paths
- **Polish Phase**: 3 tasks

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Verify prerequisites and understand current implementation

- [X] T001 Read current implementation in user/shared/lib/secrets.nix
- [X] T002 [P] Verify jq getpath() works in current nixpkgs version

______________________________________________________________________

## Phase 2: Foundational (BLOCKING)

**Purpose**: Core helper functions that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Add `pathToAttrList` function to convert dotted paths to Nix attribute lists in user/shared/lib/secrets.nix
- [X] T004 [P] Add `fieldToVarName` function to convert dotted paths to shell variable names in user/shared/lib/secrets.nix
- [X] T005 Update `mkJqExtract` to use jq `getpath()` with `split(".")` for nested extraction in user/shared/lib/secrets.nix
- [X] T006 Run `nix flake check` to validate secrets.nix changes

**Validation**:

```bash
nix flake check
```

**Checkpoint**: Foundation ready - user story implementation can now begin

______________________________________________________________________

## Phase 3: User Story 1 - Store Multiple SSH Keys (Priority: P1)

**Goal**: Enable detection and resolution of nested secrets in `config.user.*` attribute paths

**Independent Test**:

1. Set `user.sshKeys.personal = "<secret>"` in a user config
1. Verify `mkActivationScript` can detect the nested secret placeholder
1. Verify jq can extract from nested JSON structure

### Implementation for User Story 1

- [X] T007 [US1] Update `mkActivationScript` to use `lib.attrByPath` for nested config value lookup in user/shared/lib/secrets.nix
- [X] T008 [US1] Update `mkActivationScript` to use `fieldToVarName` for generating shell variables from nested paths in user/shared/lib/secrets.nix
- [X] T009 [US1] Verify existing git.nix activation still works (backward compatibility test) by running `nix flake check`

**Checkpoint**: Nested secrets can be detected and resolved at activation time

______________________________________________________________________

## Phase 4: User Story 2 - Configure Apps with Nested Secrets (Priority: P2)

**Goal**: Create example SSH module demonstrating nested secrets usage for real-world SSH key management

**Independent Test**:

1. Create SSH app module with nested secret fields
1. Verify activation script generates correct jq extraction commands
1. Verify SSH keys would be deployed to correct paths

### Implementation for User Story 2

- [X] T010 [US2] Create system/shared/app/dev/ssh.nix with SSH client configuration
- [X] T011 [US2] Add activation script for `sshKeys.personal` with correct file permissions in system/shared/app/dev/ssh.nix
- [X] T012 [US2] Run `nix flake check` to validate SSH module

**Checkpoint**: SSH app demonstrates end-to-end nested secrets usage

______________________________________________________________________

## Phase 5: User Story 3 - CLI Support for Nested Paths (Priority: P3)

**Goal**: Update justfile recipes to support dotted path syntax for nested secrets

**Independent Test**:

1. Run `just secrets-set cdrokar sshKeys.personal "test-key"`
1. Decrypt secrets.age and verify nested JSON structure created
1. Run `just secrets-list` and verify nested paths displayed

### Implementation for User Story 3

- [X] T013 [US3] Update `secrets-set` recipe to parse dotted paths and create nested JSON using jq in justfile
- [X] T014 [US3] Update `secrets-list` recipe to display nested paths with hierarchy indication in justfile
- [X] T015 [US3] Test CLI with `just secrets-set cdrokar sshKeys.test "value"` and verify JSON structure

**Checkpoint**: CLI supports full nested secrets workflow

______________________________________________________________________

## Phase 6: Polish & Documentation

**Purpose**: Documentation updates and final validation

- [X] T016 [P] Update CLAUDE.md Secrets Management section with nested secrets examples
- [X] T017 [P] Create docs/features/029-nested-secrets-support.md with user documentation
- [X] T018 Run full validation: `nix flake check` and test activation with nested secrets

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKING - All user stories depend on this
    ↓
    ├──→ Phase 3 (US1) - Core nested detection
    │         ↓
    │    Phase 4 (US2) - SSH app example (depends on US1)
    │         ↓
    │    Phase 5 (US3) - CLI support (independent of US2)
    ↓
Phase 6 (Polish) - After all user stories
```

### User Story Dependencies

| Story | Depends On | Can Parallelize With |
|-------|------------|----------------------|
| US1 | Foundational (Phase 2) | None - must be first |
| US2 | US1 (needs nested detection) | US3 after US1 done |
| US3 | Foundational only | US2 after US1 done |

### Within Each User Story

1. Implementation tasks in order
1. Validation task at end
1. Complete story before next priority

### Parallel Opportunities

**After Foundational Phase**:

- T007, T008 can run in parallel (different functions)
- T013, T014 can run in parallel (different recipes)
- T016, T017 can run in parallel (different files)

______________________________________________________________________

## Parallel Example: Foundational Phase

```bash
# These can run in parallel (different functions, same file):
Task: "Add pathToAttrList function" (T003)
Task: "Add fieldToVarName function" (T004)
```

## Parallel Example: Polish Phase

```bash
# These can run in parallel (different files):
Task: "Update CLAUDE.md" (T016)
Task: "Create feature documentation" (T017)
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
1. Complete Phase 2: Foundational (T003-T006) - **CRITICAL**
1. Complete Phase 3: User Story 1 (T007-T009)
1. **STOP and VALIDATE**: Test nested secret detection works
1. Can deploy/demo core capability

**MVP Deliverable**: Nested secrets work in activation scripts

### Full Feature Delivery

1. Complete MVP (Phases 1-3)
1. Add User Story 2: SSH module example (T010-T012)
1. Add User Story 3: CLI support (T013-T015)
1. Polish: Documentation (T016-T018)

**Full Deliverable**: Complete nested secrets with CLI and documentation

______________________________________________________________________

## Validation Commands

```bash
# After each phase
nix flake check

# Test nested jq extraction
echo '{"sshKeys":{"personal":"test"}}' | jq -r 'getpath("sshKeys.personal" | split("."))'

# Test CLI (after US3)
just secrets-set cdrokar sshKeys.test "test-value"
just secrets-list

# Full activation test
just build cdrokar home-macmini-m4
```

______________________________________________________________________

## Success Criteria Mapping

| Criterion | Tasks | Verification |
|-----------|-------|--------------|
| SC-001: 4 levels deep | T003, T005 | Test `a.b.c.d` path |
| SC-002: Same activation pattern | T007, T008 | git.nix unchanged |
| SC-003: \<10s CLI | T013 | Time `secrets-set` |
| SC-004: Actionable errors | T007 | Test missing path |
| SC-005: Backward compatible | T009 | git.nix still works |
| SC-006: \<100ms overhead | T005 | Profile activation |

______________________________________________________________________

## Notes

- [P] tasks = different files/functions, no dependencies
- [Story] label maps task to specific user story
- Each user story independently testable after completion
- Commit after each task or logical group
- secrets.nix must stay under 200 lines (constitutional requirement)
- Use `lib.mkDefault` for all new options
