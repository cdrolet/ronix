# Tasks: App Exclusion Patterns

**Input**: Design documents from `/specs/043-app-exclusion-patterns/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/discovery-api.md, quickstart.md

**Tests**: Not requested in spec — no test tasks included.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup

**Purpose**: No new files or project setup needed. All changes are in `system/shared/lib/discovery.nix`.

- [X] T001 Read and understand current `resolveApplications` pipeline in `system/shared/lib/discovery.nix` (lines ~358-475)

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add helper functions that all user stories depend on. These are internal functions in `system/shared/lib/discovery.nix` within the Feature 037 wildcard section.

- [X] T002 [P] Add `isExclusion` predicate function in `system/shared/lib/discovery.nix` — detects `"!"` prefix using `lib.hasPrefix "!" str`
- [X] T003 [P] Add `stripExclusion` function in `system/shared/lib/discovery.nix` — removes `"!"` prefix using `lib.removePrefix "!" str`
- [X] T004 Add `classifyApplicationEntries` function in `system/shared/lib/discovery.nix` — splits apps list into `{ wildcards, exclusions, explicits }` attrset, stripping `!` from exclusions
- [X] T005 Refactor the wildcard expansion block in `resolveApplications` to use `classifyApplicationEntries` — replace the current `expandedApps` computation with classification-based pipeline (expand only wildcards bucket, pass exclusions and explicits separately)

**Checkpoint**: Helper functions in place. `resolveApplications` classifies input but does not yet filter exclusions. Existing behavior unchanged (exclusion entries would be treated as explicit includes and fail resolution — acceptable intermediate state).

______________________________________________________________________

## Phase 3: User Story 1 - Exclude Specific App by Name (Priority: P1)

**Goal**: Support `"!appname"` to exclude a single app from wildcard results.

**Independent Test**: `applications = ["*", "!docker"]` builds successfully and docker is not in the resolved app list. Verify with `just build <user> <host>`.

### Implementation for User Story 1

- [X] T006 [US1] Add exclusion subtraction logic in `resolveApplications` in `system/shared/lib/discovery.nix` — after expanding wildcards, filter out app names that appear in the `exclusions` list (handle non-wildcard exclusions only: names without `*`)
- [X] T007 [US1] Add explicit include union logic in `resolveApplications` in `system/shared/lib/discovery.nix` — after subtraction, union `explicits` back into the list so explicit names override exclusions
- [X] T008 [US1] Move deduplication (`lib.unique`) to after the union step in `resolveApplications` in `system/shared/lib/discovery.nix`
- [X] T009 [US1] Validate with `nix flake check` and `just build cdrokar home-macmini-m4` — existing `["*"]` config must produce identical results

**Checkpoint**: `["*", "!docker"]` excludes docker. `["*", "!docker", "docker"]` includes docker (explicit wins). `["!docker"]` alone produces empty list. Existing configs unchanged.

______________________________________________________________________

## Phase 4: User Story 2 - Exclude Entire Category (Priority: P1)

**Goal**: Support `"!category/*"` to exclude all apps in a category from wildcard results.

**Independent Test**: `applications = ["*", "!ai/*"]` builds successfully and no AI category apps are installed.

### Implementation for User Story 2

- [X] T010 [US2] Expand exclusion wildcards in `resolveApplications` in `system/shared/lib/discovery.nix` — for each exclusion entry that `isWildcard` (after stripping `!`), call `expandCategoryWildcard` with `wildcardSearchPaths` to get list of excluded app names
- [X] T011 [US2] Merge expanded exclusion wildcards with explicit exclusion names into a single `excludedNames` list in `resolveApplications` in `system/shared/lib/discovery.nix`
- [X] T012 [US2] Suppress the "matched zero apps" warning from `expandCategoryWildcard` when called for exclusion patterns in `system/shared/lib/discovery.nix` — exclusions matching zero apps should be silent per FR-005
- [X] T013 [US2] Validate with `nix flake check` — ensure `"!category/sub/*"` triggers multi-level wildcard error (existing validation handles this after stripping `!`)

**Checkpoint**: `["*", "!ai/*"]` excludes all AI apps. `["*", "!ai/*", "!games/*"]` excludes both categories. Multi-level `"!ai/sub/*"` rejected with error.

______________________________________________________________________

## Phase 5: User Story 3 - Mix Inclusions and Exclusions (Priority: P2)

**Goal**: Full combination of wildcards, exclusions, and explicit includes works correctly.

**Independent Test**: `applications = ["*", "!ai/*", "chatgpt"]` installs everything except AI category but re-includes chatgpt.

### Implementation for User Story 3

- [X] T014 [US3] Verify end-to-end processing order in `resolveApplications` in `system/shared/lib/discovery.nix` — confirm pipeline is: classify → expand wildcards → expand exclusion wildcards → subtract → union explicits → deduplicate → resolve
- [X] T015 [US3] Validate complex combination with `just build cdrokar home-macmini-m4` using a temporarily modified user config with mixed patterns in `user/cdrokar/default.nix`

**Checkpoint**: All three user stories work together. Complex combinations like `["dev/*", "!docker", "browser/*", "!firefox"]` resolve correctly.

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and cleanup.

- [X] T016 [P] Add exclusion pattern documentation to `CLAUDE.md` — update the "Discovery System" section and user config examples with `!` syntax
- [X] T017 [P] Add header comment for the new exclusion functions section in `system/shared/lib/discovery.nix`
- [X] T018 Run `just fmt` to format all modified files
- [X] T019 Run `nix flake check` for final validation
- [X] T020 Run quickstart.md scenarios as validation — verify each example from `specs/043-app-exclusion-patterns/quickstart.md` builds correctly

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — read-only
- **Foundational (Phase 2)**: Depends on Phase 1 — adds helper functions
- **US1 (Phase 3)**: Depends on Phase 2 — uses `classifyApplicationEntries`
- **US2 (Phase 4)**: Depends on Phase 3 — extends exclusion logic to handle wildcards
- **US3 (Phase 5)**: Depends on Phase 4 — validates full pipeline
- **Polish (Phase 6)**: Depends on Phase 5 — all functionality complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational only — single-name exclusions
- **US2 (P1)**: Depends on US1 — extends exclusion to category wildcards (same subtraction logic)
- **US3 (P2)**: Depends on US2 — validates the complete pipeline, no new code expected

### Parallel Opportunities

- T002 and T003 can run in parallel (independent helper functions)
- T016 and T017 can run in parallel (different files)
- Within each phase, tasks marked [P] can run in parallel

______________________________________________________________________

## Parallel Example: Phase 2

```
# Launch helper functions in parallel:
Task: "Add isExclusion predicate in system/shared/lib/discovery.nix"
Task: "Add stripExclusion function in system/shared/lib/discovery.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Read existing code
1. Complete Phase 2: Add helper functions
1. Complete Phase 3: Single-name exclusion support
1. **STOP and VALIDATE**: `["*", "!docker"]` works, existing configs unchanged
1. This alone delivers significant value

### Incremental Delivery

1. Foundation → helpers in place
1. Add US1 → single-name exclusions work → validate
1. Add US2 → category exclusions work → validate
1. Add US3 → mixed patterns validated → validate
1. Polish → docs updated, formatted, checked

______________________________________________________________________

## Notes

- All changes are in ONE file: `system/shared/lib/discovery.nix`
- No new files created
- No changes to callers (config-loader.nix, darwin.nix, nixos.nix, home-manager.nix)
- Function signature of `resolveApplications` is unchanged
- Existing configs without `!` entries produce identical results
- Commit after each phase checkpoint
