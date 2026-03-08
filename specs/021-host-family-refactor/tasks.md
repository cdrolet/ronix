# Tasks: Host/Family Architecture Refactoring

**Input**: Design documents from `/specs/021-host-family-refactor/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not requested in specification - tasks focus on implementation and validation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Repository root: `/Users/charles/project/nix-config/`
- Platform libs: `platform/{platform}/lib/`
- Discovery system: `platform/shared/lib/discovery.nix`
- Hosts: `platform/{platform}/host/{name}/`
- Families: `platform/shared/family/{name}/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch setup and directory structure preparation

- [X] T001 Rename branch from 021-host-flavor-refactor to 021-host-family-refactor
- [X] T002 [P] Update CLAUDE.md to document family terminology and cross-platform semantics
- [X] T003 [P] Update README.md to reference host/family architecture

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Extend discovery system with hierarchical search in platform/shared/lib/discovery.nix
- [X] T005 Implement discoverWithHierarchy function for platform → families → shared search
- [X] T006 Add validation function for family existence checks in discovery.nix
- [X] T007 Add validation function to reject "\*" wildcard in settings arrays
- [X] T008 Create helper function for auto-installing family defaults (app/default.nix, settings/default.nix)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Define Host Configuration (Priority: P1) 🎯 MVP

**Goal**: Establish hosts as pure data entities without imports, providing immediate value by simplifying host configuration management

**Independent Test**: Create a new darwin host with pure data structure, build the system (`nix build`), verify host settings are applied correctly

### Directory Migration for User Story 1

- [X] T009 [US1] Rename platform/darwin/profiles/ to platform/darwin/host/
- [X] T010 [P] [US1] Create host schema documentation in platform/darwin/host/README.md

### Host Configuration Conversion for User Story 1

- [X] T011 [US1] Convert platform/darwin/host/home-macmini-m4/default.nix to pure data format
- [X] T012 [P] [US1] Convert platform/darwin/host/work/default.nix to pure data format

**Pure data format**:

```nix
{ ... }:
{
  name = "host-name";
  family = [];  # Darwin hosts typically don't share cross-platform
  applications = ["*"];
  settings = ["default"];
}
```

### Platform Library Updates for User Story 1

- [X] T013 [US1] Update platform/darwin/lib/darwin.nix to load host configs as pure data (pre-module evaluation)
- [X] T014 [US1] Extract host.name, host.family, host.applications, host.settings in darwin.nix
- [X] T015 [US1] Add validation in darwin.nix: check family references exist, reject "\*" in settings
- [X] T016 [US1] Implement app resolution using discovery system in darwin.nix
- [X] T017 [US1] Implement settings resolution with "default" keyword support in darwin.nix
- [X] T018 [US1] Generate imports list combining host data + resolved apps + resolved settings
- [X] T019 [US1] Pass imports to home-manager.users.{user}.imports in darwin.nix

### Validation for User Story 1

- [X] T020 [US1] Run `nix flake check` to validate host configurations
- [X] T021 [US1] Build home-macmini-m4 configuration with `nix build ".#darwinConfigurations.cdrokar-home-macmini-m4.system"`
- [X] T022 [US1] Build work configuration with `nix build ".#darwinConfigurations.cdrokar-work.system"`
- [X] T023 [US1] Verify all apps and settings applied correctly for both hosts

**Checkpoint**: At this point, User Story 1 should be fully functional - pure data hosts work without families

______________________________________________________________________

## Phase 4: User Story 2 - Use Shared Families (Priority: P2)

**Goal**: Enable cross-platform reusability - multiple platforms (nixos, kali, ubuntu) can share common family configurations

**Independent Test**: Create "linux" family with common settings/apps, reference from multiple platform hosts (nixos, kali), verify all hosts receive family configuration

### Create Family Infrastructure for User Story 2

- [X] T024 [US2] Create directory structure platform/shared/family/
- [X] T025 [P] [US2] Create family schema documentation in platform/shared/family/README.md

### Example Linux Family for User Story 2

- [X] T026 [US2] Create platform/shared/family/linux/ directory structure
- [X] T027 [P] [US2] Create platform/shared/family/linux/app/default.nix with common Linux apps
- [X] T028 [P] [US2] Create platform/shared/family/linux/app/htop.nix
- [X] T029 [P] [US2] Create platform/shared/family/linux/app/tmux.nix
- [X] T030 [P] [US2] Create platform/shared/family/linux/settings/default.nix with common Linux settings

### Example GNOME Family for User Story 2

- [X] T031 [US2] Create platform/shared/family/gnome/ directory structure
- [X] T032 [P] [US2] Create platform/shared/family/gnome/app/default.nix with GNOME apps
- [X] T033 [P] [US2] Create platform/shared/family/gnome/settings/default.nix with GNOME settings

### Platform Library Updates for Family Support

- [X] T034 [US2] Update darwin.nix to auto-install family defaults when family array is non-empty
- [X] T035 [US2] Add family path resolution loop for each family in array in darwin.nix
- [X] T036 [US2] Update app resolution to search: platform → family1 → family2 → ... → shared
- [X] T037 [US2] Update settings resolution to search: platform → family1 → family2 → ... → shared

### Validation for User Story 2

- [X] T038 [US2] Create test host platform/darwin/host/test-family/default.nix referencing a family
- [X] T039 [US2] Build test configuration to verify family defaults are auto-installed
- [X] T040 [US2] Verify family apps and settings are resolved via hierarchical discovery
- [X] T041 [US2] Remove test host after successful validation

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - hosts can use families or remain standalone

______________________________________________________________________

## Phase 5: User Story 3 - Application and Setting Discovery Hierarchy (Priority: P3)

**Goal**: Complete flexibility of hierarchical resolution - platform-specific implementations override more general ones with proper fallbacks

**Independent Test**: Create app in multiple tiers (platform, family, shared), verify platform-specific version is used, then remove platform version and verify fallback to family

### Enhanced Discovery Implementation for User Story 3

- [X] T042 [US3] Update discoverWithHierarchy to handle multiple families in array order
- [X] T043 [US3] Implement first-match semantics strictly (no merging across tiers)
- [X] T044 [US3] Add logging/debug output for discovery path resolution (optional)

### Create Test Scenarios for User Story 3

- [X] T045 [P] [US3] Create test app in platform/darwin/app/editor/test-helix.nix (tier 1)
- [X] T046 [P] [US3] Create test app in platform/shared/family/linux/app/test-helix.nix (tier 2)
- [X] T047 [P] [US3] Create test app in platform/shared/app/editor/test-helix.nix (tier 3)
- [X] T048 [US3] Create test host requesting test-helix
- [X] T049 [US3] Verify tier 1 (platform) is used first
- [X] T050 [US3] Remove tier 1, rebuild, verify tier 2 (family) is used
- [X] T051 [US3] Remove tier 2, rebuild, verify tier 3 (shared) is used
- [X] T052 [US3] Clean up test files after validation

### Validate Multi-Family Composition

- [X] T053 [US3] Create test host with `family = ["linux", "gnome"]`
- [X] T054 [US3] Request app that exists in gnome family but not linux family
- [X] T055 [US3] Verify search order: platform → linux → gnome → shared
- [X] T056 [US3] Request app that exists in linux family
- [X] T057 [US3] Verify linux family version is used (first match)
- [X] T058 [US3] Clean up test host after validation

**Checkpoint**: All user stories should now be independently functional with complete hierarchical discovery

______________________________________________________________________

## Phase 6: Migration & Cleanup

**Purpose**: Complete migration from old profile structure to new host/family structure

### Update Documentation

- [X] T059 [P] Update justfile commands to use "host" terminology instead of "profile"
- [X] T060 [P] Update just list-profiles to just list-hosts
- [X] T061 [P] Update CLAUDE.md with final family semantics documentation
- [X] T062 [P] Create migration guide in docs/ explaining old→new structure

### Remove Old Structure

- [X] T063 Delete old platform/darwin/profiles/ directory (already renamed to host/)
- [X] T064 [P] Remove any references to "profile" in flake.nix comments
- [X] T065 [P] Search codebase for remaining "profile" references and update to "host" or "family"

### Validation & Testing

- [X] T066 Run `nix flake check` for final validation
- [X] T067 Build all darwin configurations to ensure no regressions
- [X] T068 [P] Test `just install cdrokar home-macmini-m4` command
- [X] T069 [P] Test `just install cdrokar work` command
- [X] T070 Verify all existing functionality still works

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T071 [P] Add error messages for non-existent family references
- [ ] T072 [P] Add error messages for "\*" wildcard in settings (helpful message)
- [ ] T073 [P] Add helpful error when app/setting not found in any tier
- [ ] T074 [P] Format all Nix files with alejandra formatter
- [ ] T075 Validate quickstart.md examples match actual implementation
- [ ] T076 [P] Update constitutional compliance checklist
- [ ] T077 Run final smoke tests on all configurations

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3, 4, 5)**: All depend on Foundational phase completion
  - User stories CAN proceed in parallel (if staffed) after Phase 2
  - Or sequentially in priority order: P1 (Phase 3) → P2 (Phase 4) → P3 (Phase 5)
- **Migration (Phase 6)**: Depends on all user stories being complete
- **Polish (Phase 7)**: Depends on Migration completion

### User Story Dependencies

- **User Story 1 (P1 - Phase 3)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2 - Phase 4)**: Depends on User Story 1 completion (needs host loading infrastructure)
- **User Story 3 (P3 - Phase 5)**: Depends on User Story 2 completion (needs family system)

**Note**: While US2 builds on US1 and US3 builds on US2, each delivers independently testable value.

### Within Each User Story

**User Story 1**:

- Directory migration before conversion
- Host conversions can run in parallel (T011, T012 marked [P])
- Platform library updates must be sequential (T013-T019)
- Validation after all implementation complete

**User Story 2**:

- Family infrastructure before examples
- Linux family app tasks can run in parallel (T028, T029 marked [P])
- GNOME family tasks can run in parallel (T032, T033 marked [P])
- Platform library updates sequential
- Validation after implementation

**User Story 3**:

- Discovery implementation first
- Test scenario creation can run in parallel (T045, T046, T047 marked [P])
- Validation sequential (depends on test scenarios)

### Parallel Opportunities

- **Setup (Phase 1)**: T002, T003 marked [P] can run in parallel
- **Foundational (Phase 2)**: All tasks sequential (same file: discovery.nix)
- **User Story 1**: T012 can run parallel with T011 (different host files)
- **User Story 2**: Family app/settings creation highly parallel (multiple [P] tasks)
- **User Story 3**: Test app creation highly parallel (T045, T046, T047 marked [P])
- **Migration (Phase 6)**: Documentation tasks highly parallel (T059-T062, T064-T065 marked [P])
- **Polish (Phase 7)**: Most tasks highly parallel (T071-T074, T076 marked [P])

______________________________________________________________________

## Parallel Example: User Story 2

```bash
# Launch all Linux family app tasks together:
Task: "Create platform/shared/family/linux/app/htop.nix"
Task: "Create platform/shared/family/linux/app/tmux.nix"

# Launch all GNOME family tasks together:
Task: "Create platform/shared/family/gnome/app/default.nix with GNOME apps"
Task: "Create platform/shared/family/gnome/settings/default.nix with GNOME settings"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
1. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
1. Complete Phase 3: User Story 1 (pure data hosts)
1. **STOP and VALIDATE**: Test hosts independently without families
1. Can deploy/use at this point - basic functionality complete

**Deliverable**: Pure data hosts work, simplified configuration management achieved

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
1. Add User Story 1 → Test independently → **MVP READY** (pure data hosts)
1. Add User Story 2 → Test independently → **Cross-platform sharing enabled**
1. Add User Story 3 → Test independently → **Complete hierarchical resolution**
1. Complete Migration → **Old structure removed**
1. Complete Polish → **Production ready**

Each story adds value without breaking previous functionality.

### Sequential Team Strategy (Recommended)

Given Nix's nature (single developer typically):

1. Complete Setup + Foundational
1. Implement User Story 1 completely (T009-T023)
1. Validate and commit
1. Implement User Story 2 completely (T024-T041)
1. Validate and commit
1. Implement User Story 3 completely (T042-T058)
1. Validate and commit
1. Complete Migration and Polish

### Parallel Team Strategy (If Multiple Developers)

With multiple developers:

1. Team completes Setup + Foundational together
1. Once Foundational is done:
   - Developer A: User Story 1 (darwin platform library updates)
   - Developer B: User Story 2 (create family examples)
   - Developer C: Documentation and migration tasks
1. Coordinate integration points (platform library changes)

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- **Nix-specific**: `nix flake check` after each phase
- **Nix-specific**: `nix build` to test configurations
- Commit after completing each user story phase
- Stop at any checkpoint to validate story independently
- **Critical Path**: Foundational Phase (T004-T008) blocks everything
- **No tests**: Validation through Nix builds and manual verification
- **Constitutional requirement**: All modules must be \<200 lines

______________________________________________________________________

## Validation Checkpoints

### After User Story 1 (Phase 3)

```bash
cd /Users/charles/project/nix-config
nix flake check
nix build ".#darwinConfigurations.cdrokar-home-macmini-m4.system"
nix build ".#darwinConfigurations.cdrokar-work.system"
# Both should build successfully with pure data hosts
```

### After User Story 2 (Phase 4)

```bash
# Create test host with family reference
# Build and verify family defaults are auto-installed
nix build ".#darwinConfigurations.test-family.system"
# Verify htop, tmux from linux family are present
```

### After User Story 3 (Phase 5)

```bash
# Test hierarchical resolution with test apps in multiple tiers
# Build and verify correct tier is selected (first match)
# Remove tiers sequentially and verify fallback behavior
```

### Final Validation (After Phase 6)

```bash
nix flake check
just build cdrokar home-macmini-m4
just build cdrokar work
# All commands should work with new host/family terminology
```

______________________________________________________________________

## Task Count Summary

- **Phase 1 (Setup)**: 3 tasks
- **Phase 2 (Foundational)**: 5 tasks (CRITICAL PATH)
- **Phase 3 (User Story 1)**: 15 tasks (MVP)
- **Phase 4 (User Story 2)**: 18 tasks
- **Phase 5 (User Story 3)**: 17 tasks
- **Phase 6 (Migration)**: 12 tasks
- **Phase 7 (Polish)**: 7 tasks

**Total**: 77 tasks

**Parallel Opportunities**: 24 tasks marked [P] (31%)

**MVP Scope**: Phases 1-3 (23 tasks) delivers pure data hosts without families

**Suggested First Milestone**: Complete Phase 3, validate, commit before proceeding to families
