# Tasks: User Colocated Secrets

**Input**: Design documents from `/specs/027-user-colocated-secrets/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: No automated tests requested. Validation via `nix flake check` and manual testing.

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add agenix to flake and create foundational helpers

- [x] T001 Add agenix input to flake.nix with nixpkgs.follows
- [x] T002 [P] Create secret resolution helper in user/shared/lib/secrets.nix
- [x] T003 [P] Update user schema with freeformType in user/shared/lib/home-manager.nix

______________________________________________________________________

## Phase 2: Foundational (Justfile Commands)

**Purpose**: Create wrapper commands that all user stories depend on

**⚠️ CRITICAL**: Justfile commands are the foundation - all secrets operations use them

- [x] T004 Add `secrets-init` command to justfile (generates keypair, creates public.age)
- [x] T005 Add `secrets-edit` command to justfile (interactive mode - opens editor)
- [x] T006 Add `secrets-list` command to justfile (lists all user secret files)
- [x] T007 Add `secrets-show-pubkey` command to justfile (displays public key)

**Checkpoint**: Run `just secrets-init` to verify keypair generation works ✓

______________________________________________________________________

## Phase 3: User Story 3 - Auto-Initialize Secrets Infrastructure (Priority: P1) 🎯 MVP

**Goal**: First-time users can run one command to set up encryption infrastructure

**Independent Test**: On fresh repo, run `just secrets-init`, verify `public.age` created and `~/.config/agenix/key.txt` exists

### Implementation for User Story 3

- [x] T008 [US3] Test `just secrets-init` creates keypair correctly
- [x] T009 [US3] Test `just secrets-init` is idempotent (safe to run twice)
- [x] T010 [US3] Verify public.age format is valid age public key

**Checkpoint**: `just secrets-init` works - shared keypair is ready ✓

______________________________________________________________________

## Phase 4: User Story 2 - Shared Key Simplicity (Priority: P1)

**Goal**: Single shared key encrypts all user secrets

**Independent Test**: Create secrets for multiple users, verify all use same public key from `public.age`

### Implementation for User Story 2

- [x] T011 [US2] Verify `secrets-edit` reads from `public.age` at repo root
- [x] T012 [US2] Test encryption uses shared key (decrypt with shared private key works)
- [x] T013 [US2] Document shared key model in repo (update CLAUDE.md if needed)

**Checkpoint**: Shared key model is working - no per-user keys needed ✓

______________________________________________________________________

## Phase 5: User Story 1 - Colocated Secret Files (Priority: P1)

**Goal**: Secrets stored directly in user directories alongside config

**Independent Test**: Run `just secrets-edit cdrokar`, verify `user/cdrokar/secrets.age` is created (not `secrets/users/...`)

### Implementation for User Story 1

- [x] T014 [US1] Ensure `secrets-edit` creates file at `user/{username}/secrets.age`
- [x] T015 [US1] Ensure `secrets-edit` auto-creates empty JSON `{}` if file missing
- [x] T016 [US1] Verify no `secrets/` directory is created
- [x] T017 [US1] Test with cdrokar user: create and verify secret file location

**Checkpoint**: Secrets are colocated in user directories ✓

______________________________________________________________________

## Phase 6: User Story 7 - One-Command Secret Addition (Priority: P1)

**Goal**: Single command adds secret to both config and secrets file

**Independent Test**: Run `just secrets-edit cdrokar email "test@example.com"`, verify both files updated

### Implementation for User Story 7

- [x] T018 [US7] Extend `secrets-edit` command to accept optional field and value arguments in justfile
- [x] T019 [US7] Implement JSON update logic (add/update field in decrypted secrets, re-encrypt)
- [x] T020 [US7] Implement Nix config update logic (add `field = "<secret>";` to default.nix) - Note: Prints guidance instead of auto-edit
- [x] T021 [US7] Support nested field paths (e.g., `tokens.github` → nested JSON structure)
- [x] T022 [US7] Test one-command mode: `just secrets-edit cdrokar email "me@example.com"`
- [x] T023 [US7] Test nested path: `just secrets-edit cdrokar tokens.github "ghp_xxx"`
- [x] T024 [US7] Verify interactive mode still works when no field/value provided

**Checkpoint**: One command updates both config and secrets atomically ✓

______________________________________________________________________

## Phase 7: User Story 5 - Freeform User Fields (Priority: P1)

**Goal**: Users can add arbitrary fields without schema changes

**Independent Test**: Add `user.tokens.openai = "<secret>"` without modifying any schema, verify build succeeds

### Implementation for User Story 5

- [x] T025 [US5] Verify user schema uses freeformType (from T003)
- [x] T026 [US5] Test arbitrary nested field: `user.services.aws.secretKey = "<secret>"`
- [x] T027 [US5] Verify apps can reference `config.user.tokens.github` when field exists

**Checkpoint**: Freeform fields work without schema changes

______________________________________________________________________

## Phase 8: User Story 4 - Simple Secret Placeholder (Priority: P1)

**Goal**: `"<secret>"` placeholder triggers automatic secret resolution

**Independent Test**: Set `user.email = "<secret>"` in config, create corresponding secret, rebuild - git should use correct email

### Implementation for User Story 4

- [x] T028 [US4] Implement secret detection logic in platform libs (darwin.nix, nixos.nix)
- [x] T029 [US4] Implement agenix integration - register secrets with age.secrets
- [x] T030 [US4] Implement activation script to resolve secrets at activation time
- [x] T031 [US4] Implement nested path resolution (e.g., `tokens.github` from JSON)
- [x] T032 [US4] Test with cdrokar: set `email = "<secret>"`, add secret, rebuild
- [x] T033 [US4] Verify git config uses resolved email value

**Checkpoint**: Secret placeholders resolve correctly at activation time ✓

______________________________________________________________________

## Phase 9: User Story 6 - Graceful Plain Text Fallback (Priority: P2)

**Goal**: Mix plain text and secrets in same config

**Independent Test**: Use `email = "<secret>"` and `timezone = "America/Toronto"` together, both should work

### Implementation for User Story 6

- [x] T034 [US6] Verify plain text values pass through unchanged
- [x] T035 [US6] Verify config builds when user has no secrets.age file (all plain text)
- [x] T036 [US6] Implement clear error message when `"<secret>"` used but file missing
- [x] T037 [US6] Implement clear error message when field missing from secrets JSON

**Checkpoint**: Mixed plain text and secrets work together ✓

______________________________________________________________________

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, validation

- [x] T038 [P] Update CLAUDE.md with secrets commands and patterns
- [x] T039 [P] Run `nix flake check` to validate all configurations
- [x] T040 [P] Test full flow: init → add secret → rebuild → verify
- [x] T041 [P] Remove any spec 026 artifacts if present (secrets/ directory, secrets.nix)
- [x] T042 Commit public.age to repository (but NOT private key)
- [x] T043 Run quickstart.md validation steps

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately ✓
- **Foundational (Phase 2)**: Depends on Setup - creates all justfile commands ✓
- **US3 (Phase 3)**: Depends on Phase 2 - tests `secrets-init` ✓
- **US2 (Phase 4)**: Depends on Phase 3 - needs keypair to exist ✓
- **US1 (Phase 5)**: Depends on Phase 2 - tests file locations ✓
- **US7 (Phase 6)**: Depends on Phase 5 - extends `secrets-edit` command ✓
- **US5 (Phase 7)**: Depends on Phase 1 (T003) - needs freeformType (partial)
- **US4 (Phase 8)**: Depends on Phases 5, 7 - needs secrets and schema
- **US6 (Phase 9)**: Depends on Phase 8 - builds on placeholder resolution
- **Polish (Phase 10)**: Depends on all user stories

### Critical Path

```
T001 (flake) → T004-T007 (justfile) → T008-T010 (US3) → T028-T033 (US4)
                    ↓
              T014-T017 (US1) → T018-T024 (US7)
```

### Parallel Opportunities

Within Setup (Phase 1):

```
T001 (flake.nix) can run parallel with:
  - T002 (secrets.nix)
  - T003 (user-schema.nix)
```

Within Foundational (Phase 2):

```
T004-T007 are sequential (same file: justfile)
```

User Stories can partially overlap:

```
After Phase 2 complete:
  - US1 (file locations) and US5 (freeform) can run in parallel
  - US7 depends on US1
  - US4 depends on US1 and US5
```

______________________________________________________________________

## Parallel Example: Setup Phase

```bash
# Launch all setup tasks together:
Task: "Add agenix input to flake.nix"
Task: "Create secret resolution helper in user/shared/lib/secrets.nix"
Task: "Update user schema with freeformType"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Stories 1-3)

1. Complete Phase 1: Setup (agenix, helpers) ✓
1. Complete Phase 2: Justfile commands ✓
1. Complete Phase 3: US3 - Auto-init works ✓
1. Complete Phase 5: US1 - Colocated files work ✓
1. **STOP and VALIDATE**: Can create and encrypt secrets ✓
1. This is a functional MVP - secrets can be managed ✓

### Full Feature

7. Complete Phase 6: US7 - One-command mode ✓
1. Complete Phase 8: US4 - Placeholder resolution (IN PROGRESS)
1. Complete Phase 9: US6 - Plain text fallback
1. Complete Phase 10: Polish

### Incremental Delivery

| Milestone | What Works | User Value | Status |
|-----------|------------|------------|--------|
| After Phase 3 | `just secrets-init` | Keypair ready | ✓ |
| After Phase 5 | `just secrets-edit <user>` | Can create/edit secrets | ✓ |
| After Phase 6 | `just secrets-edit <user> <field> <value>` | One-command add | ✓ |
| After Phase 8 | `"<secret>"` placeholders | Secrets resolve at build | |
| After Phase 9 | Mixed plain/secret | Full flexibility | |

______________________________________________________________________

## Notes

- No automated tests - validation via `nix flake check` and manual testing
- Justfile commands are bash scripts embedded in justfile
- Secret resolution happens at activation time, not evaluation time
- Private key (`~/.config/agenix/key.txt`) must never be committed
- Public key (`public.age`) should be committed
