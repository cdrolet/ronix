# Tasks: Per-User Secrets

**Input**: Design documents from `/specs/031-per-user-secrets/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/justfile-commands.md

**Tests**: Manual testing with `nix flake check` and build validation

**Organization**: Tasks organized by implementation phases from plan.md. This is an infrastructure feature focused on improving secret management security.

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions

- Repository root: `/Users/charles/project/nix-config/`
- User configs: `user/{username}/`
- System libs: `system/shared/lib/`
- Templates: `user/shared/templates/`
- Justfile: `justfile` (root)

______________________________________________________________________

## Phase 1: Setup & Infrastructure

**Purpose**: Update core secrets infrastructure for per-user keys

- [ ] T001 Update `user/shared/lib/secrets.nix` - Add `getUserPublicKey` function for per-user key detection
- [ ] T002 Update `user/shared/lib/secrets.nix` - Remove shared key fallback logic
- [ ] T003 Update `user/shared/lib/secrets.nix` - Update `mkAgenixSecrets` for per-user keys
- [ ] T004 Update `system/shared/lib/secrets-module.nix` - Change key detection to per-user only
- [ ] T005 Update `system/shared/lib/secrets-module.nix` - Remove shared key logic from agenix registration
- [ ] T006 Update `.gitignore` - Add patterns for private keys (key.txt, key-\*.txt)

**Checkpoint**: Core infrastructure updated for per-user key model

______________________________________________________________________

## Phase 2: User Templates

**Purpose**: Create user configuration templates

- [ ] T007 [P] Create `user/shared/templates/common.nix` - Essential apps template (git, zsh)
- [ ] T008 [P] Create `user/shared/templates/developer.nix` - Developer template (git, zsh, helix, ghostty, dock, fonts)
- [ ] T009 [P] Create `user/shared/templates/README.md` - Template documentation and usage guide

**Checkpoint**: Templates ready for user creation

______________________________________________________________________

## Phase 3: Build Command Simplification

**Purpose**: Simplify build commands by auto-detecting system from host

- [ ] T010 Add `_detect-system-for-host` helper to `justfile` - Search system/\*/host/ for hostname
- [ ] T011 Update `build` command in `justfile` - Remove system parameter, auto-detect from host
- [ ] T012 Update `install` command in `justfile` - Remove system parameter, auto-detect from host
- [ ] T013 Update `diff` command in `justfile` (if exists) - Remove system parameter, auto-detect from host

**Checkpoint**: Build commands simplified to `just build <user> <host>`

______________________________________________________________________

## Phase 4: User Management Commands

**Purpose**: Implement user creation and key management

- [ ] T014 Add `user-create` command to `justfile` - Interactive user creation with template selection
- [ ] T015 Add username validation to `user-create` - Pattern: `[a-z][a-z0-9-]*`
- [ ] T016 Add email prompt to `user-create` - Validate email format
- [ ] T017 Add fullName prompt to `user-create` - Default to username if empty
- [ ] T018 Add template selection to `user-create` - Choose between common/developer
- [ ] T019 Add template processing to `user-create` - Substitute REPLACE_USERNAME and REPLACE_EMAIL
- [ ] T020 Add conditional fullName insertion to `user-create` - Only if different from username
- [ ] T021 Add placeholder validation to `user-create` - Error if REPLACE\_\* remains
- [ ] T022 Add keypair generation call to `user-create` - Call `just secrets-init-user`
- [ ] T023 Add Bitwarden prompt to `user-create` - Optional save to Bitwarden
- [ ] T024 Add formatting step to `user-create` - Run `nix fmt` on generated config
- [ ] T025 Add git commit prompt to `user-create` - Optional commit with conventional message

**Checkpoint**: User creation workflow complete

______________________________________________________________________

## Phase 5: Key Management Commands

**Purpose**: Implement per-user key generation and rotation

- [ ] T026 Add `secrets-init-user` command to `justfile` - Generate per-user age keypair
- [ ] T027 Add user directory validation to `secrets-init-user` - Check user exists
- [ ] T028 Add key existence check to `secrets-init-user` - Prevent overwriting existing key
- [ ] T029 Add keypair generation to `secrets-init-user` - Use age-keygen
- [ ] T030 Add distribution options output to `secrets-init-user` - Show Bitwarden, manual, SSH options
- [ ] T031 Add `secrets-rotate-user` command to `justfile` - Rotate compromised per-user key
- [ ] T032 Add precondition checks to `secrets-rotate-user` - Validate secrets exist, old key exists
- [ ] T033 Add key backup to `secrets-rotate-user` - Backup old keys with .old suffix
- [ ] T034 Add decrypt step to `secrets-rotate-user` - Decrypt with old key
- [ ] T035 Add key regeneration to `secrets-rotate-user` - Generate new keypair
- [ ] T036 Add re-encryption to `secrets-rotate-user` - Encrypt with new key
- [ ] T037 Add distribution options output to `secrets-rotate-user` - Show Bitwarden, manual, SSH options
- [ ] T038 Add cleanup instructions to `secrets-rotate-user` - Remind to delete .old backups

**Checkpoint**: Key lifecycle management complete

______________________________________________________________________

## Phase 6: Bitwarden Integration

**Purpose**: Automate private key backup to Bitwarden

- [ ] T039 Add `_save-key-to-bitwarden` helper to `justfile` - Internal helper for Bitwarden save
- [ ] T040 Add Bitwarden CLI check to `_save-key-to-bitwarden` - Verify bw installed
- [ ] T041 Add login check to `_save-key-to-bitwarden` - Auto-login if needed
- [ ] T042 Add vault unlock to `_save-key-to-bitwarden` - Get session token
- [ ] T043 Add secure note creation to `_save-key-to-bitwarden` - Use jq to build JSON template
- [ ] T044 Add vault sync to `_save-key-to-bitwarden` - Sync after creation
- [ ] T045 Add retrieval instructions to `_save-key-to-bitwarden` - Show bw get item command
- [ ] T046 Add `secrets-save-to-bitwarden` public command to `justfile` - Wrapper for helper

**Checkpoint**: Bitwarden automation complete

______________________________________________________________________

## Phase 7: Audit & Inspection Commands

**Purpose**: Tools for auditing keys and user configurations

- [ ] T047 Add `secrets-list-keys` command to `justfile` - Show all encryption keys and status
- [ ] T048 Add per-user key detection to `secrets-list-keys` - Check for user/\*/public.age
- [ ] T049 Add private key detection to `secrets-list-keys` - Check ~/.config/agenix/key-\*.txt
- [ ] T050 Add user summary to `secrets-list-keys` - Count users with/without keys
- [ ] T051 Add `user-list-fields` command to `justfile` - Show all fields for a user
- [ ] T052 Add secret field highlighting to `user-list-fields` - Mark <secret> placeholders
- [ ] T053 Add secret count to `user-list-fields` - Display total encrypted fields

**Checkpoint**: Audit tools complete

______________________________________________________________________

## Phase 8: Enhanced Secret Commands

**Purpose**: Update existing secret commands for per-user key auto-detection

- [ ] T054 Update `secrets-set` command in `justfile` - Auto-detect per-user key
- [ ] T055 Update `secrets-edit` command in `justfile` - Auto-detect per-user private key
- [ ] T056 Update `secrets-list` command in `justfile` - Show key type per user
- [ ] T057 Add per-user key detection to secret operations - Check user/{name}/public.age first

**Checkpoint**: All secret commands updated

______________________________________________________________________

## Phase 9: Documentation

**Purpose**: Update project documentation

- [ ] T058 [P] Update `CLAUDE.md` - Replace Feature 027 references with Feature 031
- [ ] T059 [P] Update `CLAUDE.md` - Update command examples (remove system parameter)
- [ ] T060 [P] Update `CLAUDE.md` - Add Bitwarden integration documentation
- [ ] T061 [P] Update `README.md` - Update quickstart with new user-create command
- [ ] T062 [P] Update `README.md` - Update secrets examples for per-user keys
- [ ] T063 [P] Create `docs/features/031-per-user-secrets.md` - User-facing feature documentation

**Checkpoint**: Documentation complete

______________________________________________________________________

## Phase 10: Testing & Validation

**Purpose**: Comprehensive testing of the new secret management system

- [ ] T064 Test user creation with common template - Create test user, verify structure
- [ ] T065 Test user creation with developer template - Create test user, verify apps/dock/fonts
- [ ] T066 Test fullName defaulting - Create user without fullName, verify defaults to username
- [ ] T067 Test fullName custom value - Create user with custom fullName, verify added to config
- [ ] T068 Test template validation - Verify no REPLACE\_\* placeholders remain
- [ ] T069 Test keypair generation - Verify public key in user dir, private key in ~/.config/agenix/
- [ ] T070 Test key permissions - Verify private key has 0600 permissions
- [ ] T071 Test Bitwarden save - Save key to Bitwarden, verify secure note created
- [ ] T072 Test Bitwarden retrieval - Retrieve key from Bitwarden on different machine
- [ ] T073 Test secret operations - Set, edit, list secrets with per-user key
- [ ] T074 Test key rotation - Rotate key, verify secrets re-encrypted
- [ ] T075 Test build command simplification - Run `just build <user> <host>`, verify system detected
- [ ] T076 Test install command simplification - Run `just install <user> <host>`, verify system detected
- [ ] T077 Test secrets-list-keys - Verify shows all users and key status
- [ ] T078 Test user-list-fields - Verify shows all fields and marks secrets
- [ ] T079 Run `nix flake check` - Verify configuration syntax
- [ ] T080 Test darwin build - Build configuration on macOS
- [ ] T081 Test nixos build - Build configuration on Linux (if available)
- [ ] T082 Test git integration - Verify public keys committed, private keys ignored

**Checkpoint**: All functionality tested and validated

______________________________________________________________________

## Phase 11: Deployment & Cleanup

**Purpose**: Deploy to production and clean up old infrastructure

- [ ] T083 Remove old shared key infrastructure - Delete public.age from root
- [ ] T084 Remove old shared private key - Delete ~/.config/agenix/key.txt
- [ ] T085 Regenerate existing users - Create per-user keys for cdrokar, cdrolet, cdronix
- [ ] T086 Re-encrypt existing secrets - Update secrets files with new per-user keys
- [ ] T087 Commit all changes - Atomic commit with all user updates
- [ ] T088 Distribute private keys - Save to Bitwarden or distribute via secure channel
- [ ] T089 Test on all target machines - Verify builds and activations work
- [ ] T090 Update quickstart.md validation - Verify all quickstart examples work

**Checkpoint**: Feature deployed and old infrastructure removed

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - can start immediately
- **Phase 2 (Templates)**: Depends on Phase 1 completion
- **Phase 3 (Build Commands)**: Can run in parallel with Phase 2
- **Phase 4 (User Management)**: Depends on Phases 1, 2 completion
- **Phase 5 (Key Management)**: Depends on Phase 1 completion
- **Phase 6 (Bitwarden)**: Can run in parallel with Phase 5
- **Phase 7 (Audit Commands)**: Depends on Phase 1 completion
- **Phase 8 (Enhanced Commands)**: Depends on Phase 1 completion
- **Phase 9 (Documentation)**: Can run in parallel with implementation phases
- **Phase 10 (Testing)**: Depends on all implementation phases (1-8)
- **Phase 11 (Deployment)**: Depends on Phase 10 completion

### Within Each Phase

- Tasks marked [P] can run in parallel (different files)
- Sequential tasks have dependencies on previous tasks
- Template creation tasks (T007-T009) are fully parallel
- Documentation tasks (T058-T063) are fully parallel

### Parallel Opportunities

**Phase 1**: Sequential (modifying same files)

**Phase 2**: All tasks in parallel

```bash
# Create all templates simultaneously:
Task T007: "Create common.nix template"
Task T008: "Create developer.nix template"  
Task T009: "Create README.md"
```

**Phase 3**: Sequential (modifying justfile)

**Phase 4**: Sequential (building up user-create command)

**Phase 5**: Two parallel streams

```bash
# Stream 1: secrets-init-user (T026-T030)
# Stream 2: secrets-rotate-user (T031-T038)
```

**Phase 6**: Sequential (building up Bitwarden integration)

**Phase 7**: Two parallel streams

```bash
# Stream 1: secrets-list-keys (T047-T050)
# Stream 2: user-list-fields (T051-T053)
```

**Phase 8**: Sequential (updating existing commands)

**Phase 9**: All tasks in parallel

```bash
# Update all documentation simultaneously:
Task T058-T060: "Update CLAUDE.md"
Task T061-T062: "Update README.md"
Task T063: "Create feature doc"
```

**Phase 10**: Sequential (testing must follow implementation order)

**Phase 11**: Sequential (deployment steps must be ordered)

______________________________________________________________________

## Implementation Strategy

### MVP Approach (Minimal Working Feature)

1. **Phase 1**: Setup infrastructure (T001-T006)
1. **Phase 2**: Create templates (T007-T009)
1. **Phase 4**: Basic user creation (T014-T025)
1. **Phase 5**: Basic key management (T026-T030)
1. **Phase 10**: Core testing (T064-T069, T079)

At this point, you have:

- ✅ Per-user key infrastructure
- ✅ User creation with templates
- ✅ Key generation
- ✅ Basic functionality tested

**STOP and VALIDATE** before continuing with enhancements

### Full Feature Delivery

After MVP validation:

1. **Phase 3**: Simplify build commands
1. **Phase 5**: Add key rotation (T031-T038)
1. **Phase 6**: Bitwarden integration
1. **Phase 7**: Audit tools
1. **Phase 8**: Enhanced secret commands
1. **Phase 9**: Documentation
1. **Phase 10**: Full testing
1. **Phase 11**: Deployment

### Parallel Team Strategy

With multiple developers:

1. **Developer A**: Infrastructure (Phases 1, 3, 8)
1. **Developer B**: User management (Phases 2, 4)
1. **Developer C**: Key management (Phases 5, 6, 7)
1. **Developer D**: Documentation (Phase 9)
1. **All**: Testing and deployment (Phases 10, 11)

______________________________________________________________________

## Notes

- This is an infrastructure feature with no traditional user stories
- Tasks organized by logical implementation phases
- No tests framework (manual validation with `nix flake check`)
- [P] indicates parallelizable tasks (different files)
- Commit after each phase or logical group
- Bitwarden CLI is optional but recommended
- Private keys NEVER committed (enforced by .gitignore)
- Public keys ALWAYS committed to repository
- Validate with `nix flake check` frequently
- Test on both darwin and nixos if possible
