# Tasks: Multi-Provider Repository Support

**Input**: Design documents from `/specs/038-multi-provider-repositories/`\
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/repository-schema.nix

**Tests**: Not explicitly requested in specification - no test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **User schema**: `user/shared/lib/user-schema.nix`
- **Shared libraries**: `system/shared/lib/`
- **Settings modules**: `system/shared/settings/`
- **Existing git-repos**: `system/shared/settings/git-repos.nix` (will be refactored)

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create foundational library code that all provider handlers will use

- [x] T001 Create provider detection library in system/shared/lib/provider-detection.nix
- [x] T002 [P] Create repository validation library in system/shared/lib/repository-validation.nix
- [x] T003 Update user schema to support provider-agnostic repositories in user/shared/lib/user-schema.nix

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core provider detection and validation that MUST be complete before ANY provider handler can work

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Implement URL pattern detection for all providers (git, s3, proton-drive, hetzner) in system/shared/lib/provider-detection.nix
- [x] T005 Implement provider resolution with auto-detection and explicit override in system/shared/lib/provider-detection.nix
- [x] T006 Implement repository name extraction for path defaults in system/shared/lib/provider-detection.nix
- [x] T007 [P] Implement repository URL validation in system/shared/lib/repository-validation.nix
- [x] T008 [P] Implement authentication reference validation in system/shared/lib/repository-validation.nix
- [x] T009 [P] Implement path validation and sanitization in system/shared/lib/repository-validation.nix
- [x] T010 Add provider-agnostic repositories option to user schema in user/shared/lib/user-schema.nix

**Checkpoint**: Foundation ready - provider handler implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Git Repository Synchronization (Priority: P1) 🎯 MVP

**Goal**: Maintain existing git-repos functionality with new provider-agnostic schema, ensuring backward compatibility

**Independent Test**: Configure git repositories in user.repositories list, run system activation, verify repositories are cloned/updated to correct paths

### Implementation for User Story 1

- [x] T011 [US1] Refactor git-repos.nix to import provider detection library in system/shared/settings/git-repos.nix
- [x] T012 [US1] Add provider filtering logic to only process git repositories in system/shared/settings/git-repos.nix
- [x] T013 [US1] Update git-repos schema to use new user.repositories field in system/shared/settings/git-repos.nix
- [x] T014 [US1] Implement backward compatibility for existing git repository configurations in system/shared/settings/git-repos.nix
- [x] T015 [US1] Add logging to identify git provider handling each repository in system/shared/settings/git-repos.nix
- [x] T016 [US1] Update git helper library to use provider detection for repo name extraction in system/shared/lib/git.nix
- [x] T017 [US1] Test git repository cloning with auto-detected provider (github.com, gitlab.com URLs)
- [x] T018 [US1] Test git repository cloning with explicit provider override
- [x] T019 [US1] Test git repository updates (git pull) on existing clones
- [x] T020 [US1] Test backward compatibility with Feature 032 user configurations

**Checkpoint**: At this point, User Story 1 should be fully functional - git repositories work exactly as before with new schema

______________________________________________________________________

## Phase 4: User Story 2 - S3 Bucket Synchronization (Priority: P2)

**Goal**: Enable S3 bucket synchronization with support for AWS S3 and S3-compatible services (DigitalOcean, Backblaze, Wasabi, Hetzner)

**Independent Test**: Configure S3 bucket URLs in user.repositories, run activation with AWS credentials, verify files synced to local paths

### Implementation for User Story 2

- [x] T021 [P] [US2] Create S3 repository handler in system/shared/settings/s3-repos.nix
- [x] T022 [US2] Implement provider filtering for S3 URLs (s3://, .s3.amazonaws.com, .digitaloceanspaces.com, .wasabisys.com, .backblazeb2.com, .your-objectstorage.com) in system/shared/settings/s3-repos.nix
- [x] T023 [US2] Implement S3 sync activation script using aws-cli s3 sync in system/shared/settings/s3-repos.nix
- [x] T024 [US2] Add authentication integration with user.tokens secrets for S3 credentials in system/shared/settings/s3-repos.nix
- [x] T025 [US2] Implement S3-specific options handling (region, endpoint, syncOptions) in system/shared/settings/s3-repos.nix
- [x] T026 [US2] Add S3 bucket name extraction for default path resolution in system/shared/settings/s3-repos.nix
- [x] T027 [US2] Implement error isolation (failed S3 sync doesn't block other repos) in system/shared/settings/s3-repos.nix
- [x] T028 [US2] Add logging for S3 sync operations (bucket, region, files synced) in system/shared/settings/s3-repos.nix
- [x] T029 [US2] Add context validation using lib.optionalAttrs with options check in system/shared/settings/s3-repos.nix
- [x] T030 [US2] Test S3 native URI format (s3://bucket-name/path)
- [x] T031 [US2] Test AWS S3 HTTPS URL formats (virtual-hosted and path-style)
- [x] T032 [US2] Test S3-compatible services (DigitalOcean Spaces, Hetzner Object Storage)
- [x] T033 [US2] Test S3 custom endpoint configuration (MinIO)
- [x] T034 [US2] Test S3 sync with explicit provider override
- [x] T035 [US2] Test multiple S3 buckets syncing in parallel

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - git and S3 repos can coexist

______________________________________________________________________

## Phase 5: User Story 3 - Proton Drive Synchronization (Priority: P3)

**Goal**: Enable Proton Drive share synchronization for privacy-focused cloud storage

**Independent Test**: Configure Proton Drive share URLs in user.repositories, run activation with Proton credentials, verify files synced locally

### Implementation for User Story 3

- [x] T036 [P] [US3] Create Proton Drive repository handler in system/shared/settings/proton-drive-repos.nix
- [x] T037 [US3] Implement provider filtering for Proton Drive URLs (drive.proton.me/urls/\*) in system/shared/settings/proton-drive-repos.nix
- [x] T038 [US3] Implement Proton Drive sync activation script using rclone in system/shared/settings/proton-drive-repos.nix
- [x] T039 [US3] Add authentication integration with user.tokens secrets for Proton Drive in system/shared/settings/proton-drive-repos.nix
- [x] T040 [US3] Implement Proton Drive options handling (shareId, downloadOptions) in system/shared/settings/proton-drive-repos.nix
- [x] T041 [US3] Add Proton Drive share token extraction for default path in system/shared/settings/proton-drive-repos.nix
- [x] T042 [US3] Implement error isolation (failed Proton Drive sync doesn't block others) in system/shared/settings/proton-drive-repos.nix
- [x] T043 [US3] Add logging for Proton Drive sync operations in system/shared/settings/proton-drive-repos.nix
- [x] T044 [US3] Add context validation using lib.optionalAttrs with options check in system/shared/settings/proton-drive-repos.nix
- [x] T045 [US3] Test Proton Drive share link sync (https://drive.proton.me/urls/\*)
- [x] T046 [US3] Test Proton Drive with explicit provider override
- [x] T047 [US3] Test Proton Drive authentication failure handling
- [x] T048 [US3] Test network failure graceful degradation

**Checkpoint**: All three user stories (git, S3, Proton Drive) should now work independently and together

______________________________________________________________________

## Phase 6: User Story 4 - Generic Provider Extensibility (Priority: P4)

**Goal**: Validate architecture allows adding new providers without modifying core schema or shared libraries

**Independent Test**: Add a new provider handler (e.g., rsync), configure it in user.repositories with explicit provider field, verify it syncs independently

### Implementation for User Story 4

- [x] T049 [US4] Document provider handler interface in system/shared/lib/provider-detection.nix comments
- [x] T050 [US4] Create example custom provider handler template in system/shared/settings/custom-provider-template.nix
- [x] T051 [US4] Add validation for unknown provider types (log warning, skip gracefully) in system/shared/lib/provider-detection.nix
- [x] T052 [US4] Update quickstart.md with instructions for adding custom providers
- [x] T053 [US4] Test adding a new provider (rsync) without modifying shared code
- [x] T054 [US4] Test explicit provider override for custom provider
- [x] T055 [US4] Verify unknown provider logs warning and skips gracefully

**Checkpoint**: Architecture validated for extensibility - new providers can be added independently

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple provider handlers

- [x] T056 [P] Add comprehensive error messages for validation failures in system/shared/lib/repository-validation.nix
- [x] T057 [P] Add helpful diagnostics for provider auto-detection failures in system/shared/lib/provider-detection.nix
- [x] T058 [P] Update CLAUDE.md with Feature 038 technologies and patterns
- [x] T059 Document migration guide from Feature 032 git-repos in specs/038-multi-provider-repositories/MIGRATION.md
- [x] T060 Add example user configurations for all providers in specs/038-multi-provider-repositories/quickstart.md
- [x] T061 Validate all provider handlers follow constitutional context validation pattern
- [x] T062 Run nix flake check to validate all schemas and configurations
- [x] T063 Test complete user configuration with mixed providers (git + S3 + Proton Drive)
- [x] T064 Verify 10+ repositories from mixed providers sync successfully
- [x] T065 Test failure isolation (one provider failure doesn't block others)

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion (T001-T003) - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion (T004-T010)
- **User Story 2 (Phase 4)**: Depends on Foundational completion (T004-T010) - Can run in parallel with US1
- **User Story 3 (Phase 5)**: Depends on Foundational completion (T004-T010) - Can run in parallel with US1/US2
- **User Story 4 (Phase 6)**: Depends on at least one provider handler complete (US1, US2, or US3)
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Refactors existing git-repos.nix - Must complete first for backward compatibility
- **User Story 2 (P2)**: New S3 handler - Independent of US1, can run in parallel after Foundational
- **User Story 3 (P3)**: New Proton Drive handler - Independent of US1/US2, can run in parallel
- **User Story 4 (P4)**: Validates extensibility - Needs at least one handler complete

### Within Each User Story

**User Story 1 (Git)**:

1. T011-T016: Refactor git-repos.nix (sequential - same file)
1. T017-T020: Testing (can run in parallel)

**User Story 2 (S3)**:

1. T021: Create file
1. T022-T029: Implementation (sequential - same file)
1. T030-T035: Testing (can run in parallel)

**User Story 3 (Proton Drive)**:

1. T036: Create file
1. T037-T044: Implementation (sequential - same file)
1. T045-T048: Testing (can run in parallel)

**User Story 4 (Extensibility)**:

1. T049-T052: Documentation (can run in parallel)
1. T053-T055: Testing (sequential)

### Parallel Opportunities

**Phase 1 (Setup)**: All tasks can run in parallel:

- T001, T002, T003 (different files)

**Phase 2 (Foundational)**: Parallel groups:

- T004-T006: Sequential (same file: provider-detection.nix)
- T007-T009: All parallel (same file: repository-validation.nix, but independent functions)
- T010: Parallel with T007-T009 (different file: user-schema.nix)

**After Foundational Complete**: All user stories can run in parallel:

- Developer A: User Story 1 (T011-T020)
- Developer B: User Story 2 (T021-T035)
- Developer C: User Story 3 (T036-T048)

**Phase 7 (Polish)**: Many tasks can run in parallel:

- T056, T057, T058, T059, T060, T061: All parallel (different files/concerns)
- T062-T065: Sequential (testing/validation)

______________________________________________________________________

## Parallel Example: After Foundational Phase

```bash
# Three developers working in parallel on different providers:

# Developer A - Git Provider (US1)
Task: "Refactor git-repos.nix to import provider detection library"
Task: "Add provider filtering logic to only process git repositories"
Task: "Update git-repos schema to use new user.repositories field"

# Developer B - S3 Provider (US2) - Completely independent
Task: "Create S3 repository handler in system/shared/settings/s3-repos.nix"
Task: "Implement provider filtering for S3 URLs"
Task: "Implement S3 sync activation script using aws-cli"

# Developer C - Proton Drive Provider (US3) - Completely independent
Task: "Create Proton Drive repository handler in system/shared/settings/proton-drive-repos.nix"
Task: "Implement provider filtering for Proton Drive URLs"
Task: "Implement Proton Drive sync activation script using rclone"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003) - Library infrastructure
1. Complete Phase 2: Foundational (T004-T010) - Provider detection and validation
1. Complete Phase 3: User Story 1 (T011-T020) - Git provider refactored
1. **STOP and VALIDATE**: Test git repositories work with new schema
1. **Backward compatibility validated** - existing users not disrupted

### Incremental Delivery

1. **Foundation** (T001-T010) → Core libraries ready
1. **Git Provider** (T011-T020) → Test independently → Backward compatible ✓
1. **S3 Provider** (T021-T035) → Test independently → Cloud backup enabled ✓
1. **Proton Drive** (T036-T048) → Test independently → Privacy storage enabled ✓
1. **Extensibility** (T049-T055) → Validate architecture for future providers ✓
1. Each provider adds value without breaking previous ones

### Parallel Team Strategy

With multiple developers:

1. **Together**: Complete Setup (Phase 1) + Foundational (Phase 2)
1. **Once Foundational is done, split**:
   - Developer A: User Story 1 (Git - P1 priority)
   - Developer B: User Story 2 (S3 - P2 priority)
   - Developer C: User Story 3 (Proton Drive - P3 priority)
1. **Providers complete independently**, then:
   - One developer: User Story 4 (Extensibility validation)
   - All developers: Phase 7 (Polish & testing)

### Risk Mitigation

**Backward Compatibility Risk** (User Story 1):

- Priority P1 for a reason - must complete first
- Extensive testing with existing git configurations
- If US1 fails, entire feature blocked

**Provider Isolation Validation**:

- Critical: Failed S3 sync must not block git repos
- Test error isolation early in each provider implementation
- FR-010 requirement: "Failed repository sync MUST NOT block other repositories"

**Constitutional Compliance**:

- Each provider handler MUST use context validation: `lib.optionalAttrs ((options ? home) && conditions)`
- Module size \<200 lines per handler
- Run validation check in Phase 7 (T061)

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Context validation pattern REQUIRED per Constitution v2.3.0
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Provider handlers must be idempotent (safe to run multiple times)
- All activation scripts run after ["writeBoundary" "agenixInstall"]
