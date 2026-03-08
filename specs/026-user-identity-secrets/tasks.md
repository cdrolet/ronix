# Tasks: User Identity Secrets

**Feature**: 026-user-identity-secrets
**Generated**: 2025-12-21
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Overview

Implement the "mirror-path secret pattern" where `"<secret>"` placeholders in user configs auto-resolve to encrypted values. Organized by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)

______________________________________________________________________

## Phase 1: Setup

**Purpose**: Add agenix to flake and create helper infrastructure

- [ ] T001 Add agenix input to flake.nix
- [ ] T002 [P] Add secrets-\* commands to justfile
- [ ] T003 [P] Create secret resolution helper in system/shared/lib/secrets.nix
- [ ] T004 [P] Create optional age CLI app in system/shared/app/security/age.nix

**Checkpoint**: Infrastructure ready for agenix integration

______________________________________________________________________

## Phase 2: Foundational (User Story 4 - Initialize Secrets Infrastructure)

**Goal**: Set up agenix with real age keys so secrets can be encrypted and decrypted

**Independent Test**: Run `just secrets-init`, add key to secrets.nix, run `just secrets-edit cdrokar`

**⚠️ CRITICAL**: This phase MUST complete before other user stories can be tested

- [ ] T005 [US4] Generate age key using `just secrets-init`
- [ ] T006 [US4] Update secrets/secrets.nix with real public key (replace placeholder)
- [ ] T007 [US4] Add agenix Home Manager module to system/darwin/lib/darwin.nix
- [ ] T008 [P] [US4] Add agenix Home Manager module to system/nixos/lib/nixos.nix
- [ ] T009 [US4] Configure age.identityPaths in platform libs
- [ ] T010 [US4] Verify `nix flake check` passes with agenix integration

**Checkpoint**: Agenix infrastructure ready - can now encrypt/decrypt secrets

______________________________________________________________________

## Phase 3: User Story 3 - Freeform User Fields (Priority: P1)

**Goal**: Allow arbitrary fields in user config without schema changes

**Independent Test**: Add `user.tokens.test = "value"` to a user config, verify build succeeds

- [ ] T011 [US3] Update user/shared/lib/home-manager.nix to use freeformType for user options
- [ ] T012 [US3] Ensure core fields (name, email, fullName, timezone, locale) remain documented
- [ ] T013 [US3] Verify `nix flake check` passes with freeform schema

**Checkpoint**: Users can add arbitrary fields to their config

______________________________________________________________________

## Phase 4: User Story 1 - Simple Secret Placeholder (Priority: P1) 🎯 MVP

**Goal**: Use `"<secret>"` placeholder that auto-resolves from encrypted file

**Independent Test**: Set `user.email = "<secret>"`, create secret file with email, rebuild - git should have correct email

- [ ] T014 [US1] Implement isSecret helper function in system/shared/lib/secrets.nix
- [ ] T015 [US1] Implement secret detection in system/darwin/lib/darwin.nix
- [ ] T016 [P] [US1] Implement secret detection in system/nixos/lib/nixos.nix
- [ ] T017 [US1] Register age.secrets.userIdentity when user has secrets in darwin.nix
- [ ] T018 [P] [US1] Register age.secrets.userIdentity when user has secrets in nixos.nix
- [ ] T019 [US1] Create activation script to apply secret values to git config in darwin.nix
- [ ] T020 [P] [US1] Create activation script to apply secret values to git config in nixos.nix
- [ ] T021 [US1] Create test secret file secrets/user/cdrokar/default.age with email and fullName
- [ ] T022 [US1] Update user/cdrokar/default.nix: change email and fullName to `"<secret>"`
- [ ] T023 [US1] Verify rebuild succeeds and git config shows correct email

**Checkpoint**: Secret placeholder pattern working for primary user

______________________________________________________________________

## Phase 5: User Story 2 - Mirror Path Discovery (Priority: P1)

**Goal**: Secret paths auto-derived from source file location

**Independent Test**: Create new user, system expects secrets at mirrored path without configuration

- [ ] T024 [US2] Implement getUserSecretPath helper in system/shared/lib/secrets.nix
- [ ] T025 [US2] Implement userHasSecrets detection in system/shared/lib/secrets.nix
- [ ] T026 [US2] Update secrets/secrets.nix to use mirrored paths: `"user/cdrokar/default.age"`
- [ ] T027 [US2] Verify secret path derivation works for all existing users

**Checkpoint**: Secret paths automatically derived from user directory structure

______________________________________________________________________

## Phase 6: User Story 5 - Graceful Plain Text Fallback (Priority: P2)

**Goal**: Mix plain text and secret values in same config file

**Independent Test**: Use plain text timezone + secret email in same config, both work

- [ ] T028 [US5] Update activation script to only apply secrets for fields marked `"<secret>"`
- [ ] T029 [US5] Ensure plain text fields bypass secret resolution entirely
- [ ] T030 [US5] Implement clear error message when secret file missing but `"<secret>"` used
- [ ] T031 [US5] Implement clear error message when field missing in secret file
- [ ] T032 [US5] Verify mixed plain text and secrets work in user/cdrokar/default.nix

**Checkpoint**: Users can gradually migrate with mixed plain text and secrets

______________________________________________________________________

## Phase 7: Migration - Remaining Users

**Purpose**: Migrate cdrolet and cdrixus to use secrets

- [ ] T033 [P] Create secrets/user/cdrolet/default.age with email and fullName
- [ ] T034 [P] Create secrets/user/cdrixus/default.age with email and fullName
- [ ] T035 [P] Update user/cdrolet/default.nix: change email and fullName to `"<secret>"`
- [ ] T036 [P] Update user/cdrixus/default.nix: change email and fullName to `"<secret>"`
- [ ] T037 Update secrets/secrets.nix with entries for cdrolet and cdrixus
- [ ] T038 Verify `nix flake check` passes for all users

**Checkpoint**: All three users migrated to secrets

______________________________________________________________________

## Phase 8: Polish & Documentation

**Purpose**: Documentation and final cleanup

- [ ] T039 Create docs/features/026-user-identity-secrets.md with usage guide
- [ ] T040 [P] Update CLAUDE.md with secrets pattern documentation
- [ ] T041 [P] Verify all modules under 200 lines (constitutional requirement)
- [ ] T042 Run full validation: `nix flake check` + manual git config verification
- [ ] T043 Commit all changes with descriptive message

**Checkpoint**: Feature complete and documented

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - start immediately
- **Phase 2 (US4 - Infrastructure)**: Depends on Phase 1 - BLOCKS all other user stories
- **Phase 3 (US3 - Freeform)**: Depends on Phase 1 only - can run parallel to Phase 2
- **Phase 4 (US1 - Placeholder)**: Depends on Phase 2 and Phase 3
- **Phase 5 (US2 - Mirror Path)**: Depends on Phase 4
- **Phase 6 (US5 - Fallback)**: Depends on Phase 4
- **Phase 7 (Migration)**: Depends on Phases 4, 5, 6
- **Phase 8 (Polish)**: Depends on Phase 7

### User Story Independence

After Phase 2 (Infrastructure):

- **US3 (Freeform)**: Independent - schema change only
- **US1 (Placeholder)**: Core functionality - requires US3 for nested fields
- **US2 (Mirror Path)**: Refines US1 - path derivation
- **US5 (Fallback)**: Extends US1 - error handling and mixed mode

### Parallel Opportunities

**Phase 1 - All can run in parallel:**

```
T002, T003, T004 - Different files, no dependencies
```

**Phase 4 (US1) - Darwin and NixOS can be parallel:**

```
T015+T017+T019 (darwin) || T016+T018+T020 (nixos)
```

**Phase 7 (Migration) - All users can be parallel:**

```
T033+T035 (cdrolet) || T034+T036 (cdrixus)
```

______________________________________________________________________

## Implementation Strategy

### MVP First (US4 + US3 + US1 Only)

1. Complete Phase 1: Setup
1. Complete Phase 2: Infrastructure (US4)
1. Complete Phase 3: Freeform Schema (US3)
1. Complete Phase 4: Secret Placeholder (US1) - **THIS IS THE MVP**
1. **STOP and VALIDATE**: Test with cdrokar only
1. Continue to Phases 5-8 if MVP works

### Recommended Execution Order

1. T001 → T002, T003, T004 (parallel)
1. T005 → T006 → T007, T008 (parallel) → T009 → T010
1. T011 → T012 → T013
1. T014 → T015, T016 (parallel) → T017, T018 (parallel) → T019, T020 (parallel) → T021 → T022 → T023
1. T024 → T025 → T026 → T027
1. T028 → T029 → T030 → T031 → T032
1. T033, T034, T035, T036 (all parallel) → T037 → T038
1. T039 → T040, T041 (parallel) → T042 → T043

______________________________________________________________________

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| 1 | 4 | Setup |
| 2 | 6 | Infrastructure (US4) |
| 3 | 3 | Freeform Schema (US3) |
| 4 | 10 | Secret Placeholder (US1) - MVP |
| 5 | 4 | Mirror Path (US2) |
| 6 | 5 | Plain Text Fallback (US5) |
| 7 | 6 | User Migration |
| 8 | 5 | Documentation |

**Total**: 43 tasks across 8 phases

**MVP Scope**: Phases 1-4 (23 tasks) - delivers working `"<secret>"` placeholder for cdrokar
