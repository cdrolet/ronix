# Tasks: Cachix Integration

**Input**: Design documents from `/specs/034-cachix-integration/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No automated tests required - validation via manual testing and build verification

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a Nix configuration repository with the following structure:

- `system/shared/settings/` - Cross-platform system settings
- `system/darwin/settings/` - Darwin-specific settings
- `system/nixos/settings/` - NixOS-specific settings
- `user/{name}/default.nix` - Per-user configuration
- `justfile` - Command recipes

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and verification

- [X] T001 Verify nixpkgs has cachix package available (nix search nixpkgs cachix)
- [X] T002 Verify existing secrets infrastructure works (Feature 031 dependency)
- [X] T003 Verify Home Manager activation script pattern from existing modules

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: None - User Story 1 can be implemented immediately as it has no blocking dependencies

**⚠️ NOTE**: This feature builds on existing infrastructure (Feature 031 secrets, Home Manager). No foundational work needed.

**Checkpoint**: Can proceed directly to User Story 1

______________________________________________________________________

## Phase 3: User Story 1 - Binary Cache Usage (Priority: P1) 🎯 MVP

**Goal**: All users automatically benefit from default.cachix.org read-only cache access without any configuration

**Independent Test**: Run `just build <user> <host>`, verify packages download from default.cachix.org in build logs

### Implementation for User Story 1

- [X] T004 [US1] Create system/shared/settings/cachix.nix with read-only cache configuration
- [X] T005 [US1] Configure nix.settings.substituters with default.cachix.org (priority 10)
- [X] T006 [US1] Configure nix.settings.trusted-public-keys with default.cachix.org public key
- [X] T007 [US1] Add system-wide read-only authentication (hardcoded token)
- [X] T008 [US1] Verify auto-discovery imports cachix.nix via system/shared/settings/default.nix
- [X] T009 [US1] Test build on darwin host, verify cache usage in logs
- [X] T010 [US1] Run nix flake check to validate configuration

**Checkpoint**: At this point, all users should benefit from read-only cache access automatically

______________________________________________________________________

## Phase 4: User Story 2 - Optional Per-User Push (Priority: P1)

**Goal**: Users can opt-in to write access by configuring user.cachix.authToken in their secrets

**Independent Test**: Configure write access for one user, run build-and-push, verify build appears in cache

### Implementation for User Story 2

- [ ] T011 [US2] Add user.cachix options to user configuration contract (authToken, cacheName)
- [ ] T012 [US2] Implement netrc generation via Home Manager activation script in system/shared/settings/cachix.nix
- [ ] T013 [US2] Use existing secrets.mkActivationScript helper for per-user token resolution
- [ ] T014 [US2] Configure netrc file location (~/.config/nix/netrc) with 600 permissions
- [ ] T015 [US2] Add example user.cachix configuration to contracts/user-config.nix
- [ ] T016 [US2] Test with one user: set cachix.authToken secret, rebuild, verify netrc created
- [ ] T017 [US2] Test write access: manual cachix push default ./result
- [ ] T018 [US2] Run nix flake check to validate user configuration options

**Checkpoint**: Users with configured write access can now push builds to cache

______________________________________________________________________

## Phase 5: User Story 4 - Build and Push Command (Priority: P2)

**Goal**: Provide `just build-and-push` command for seamless build + push workflow

**Independent Test**: Run `just build-and-push <user> <host>`, verify build succeeds and push occurs (if auth configured)

**Note**: Implementing US4 before US3 because build-and-push is more fundamental than agent service

### Implementation for User Story 4

- [ ] T019 [US4] Add build-and-push recipe to justfile
- [ ] T020 [US4] Implement auto-detect user and host logic (reuse from build recipe)
- [ ] T021 [US4] Call just build first, then check for ~/.config/nix/netrc
- [ ] T022 [US4] If netrc exists, push with cachix push default ./result
- [ ] T023 [US4] If no netrc, show friendly message about read-only mode
- [ ] T024 [US4] Handle missing ./result symlink gracefully
- [ ] T025 [US4] Test build-and-push with user who has write access configured
- [ ] T026 [US4] Test build-and-push with user who has no cachix config (should build, skip push)
- [ ] T027 [US4] Test build failure (should not attempt push)

**Checkpoint**: Users have convenient one-command workflow for build + push

______________________________________________________________________

## Phase 6: User Story 3 - Cachix Deploy Agent (Priority: P2)

**Goal**: Run cachix-deploy agent as system service for remote deployments

**Independent Test**: Check service status, verify it's running and connected to Cachix

### Implementation for User Story 3 (Darwin)

- [ ] T028 [P] [US3] Add cachix.agent option to host configuration contract
- [ ] T029 [P] [US3] Create system/darwin/settings/cachix-agent.nix
- [ ] T030 [US3] Check config.cachix.agent option - only enable service if true
- [ ] T031 [US3] Create wrapper script to extract agent token from cdrolet's secrets.age using jq
- [ ] T032 [US3] Configure launchd service with KeepAlive, RunAtLoad
- [ ] T033 [US3] Set service to run cachix deploy agent default with CACHIX_AGENT_TOKEN env
- [ ] T034 [US3] Configure log paths (/var/log/cachix-agent.log)
- [ ] T035 [US3] Add agent token to cdrolet's secrets: just secrets-set cdrolet cachix.agentToken <token>
- [ ] T036 [US3] Enable agent in host config: add cachix.agent = true to system/darwin/host/{hostname}/default.nix
- [ ] T037 [US3] Test service start: sudo launchctl load system/cachix-deploy-agent
- [ ] T038 [US3] Verify service status and logs

### Implementation for User Story 3 (NixOS)

- [ ] T039 [P] [US3] Create system/nixos/settings/cachix-agent.nix
- [ ] T040 [US3] Check config.cachix.agent option - only enable service if true
- [ ] T041 [US3] Create wrapper script to extract agent token from cdrolet's secrets.age using jq
- [ ] T042 [US3] Configure systemd service with Restart=always, RestartSec=10s
- [ ] T043 [US3] Set service to run after network-online.target
- [ ] T044 [US3] Configure service ExecStart with wrapper script
- [ ] T045 [US3] Enable agent in host config if testing on NixOS: cachix.agent = true
- [ ] T046 [US3] Test service configuration (systemd-analyze verify)

**Checkpoint**: Agent service runs on both platforms and connects to Cachix

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and final validation

- [ ] T047 [P] Update CLAUDE.md with Cachix integration documentation
- [ ] T048 [P] Add Cachix setup instructions to CLAUDE.md (read-only + write access)
- [ ] T049 [P] Document just build-and-push usage in CLAUDE.md
- [ ] T050 [P] Document agent service management in CLAUDE.md (including cachix.agent = true in host config)
- [ ] T051 [P] Add troubleshooting section to CLAUDE.md
- [ ] T052 Validate quickstart.md scenarios manually
- [ ] T053 Test complete workflow: new user, configure write, build-and-push, verify cache
- [ ] T054 Test agent service deployment scenario (on host with cachix.agent = true)
- [ ] T055 Run final nix flake check
- [ ] T056 Clean up REVISED.md or move to archive if no longer needed
- [ ] T057 Update feature branch commit message for merge

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: N/A - skipped (no blocking prerequisites)
- **User Story 1 (Phase 3)**: Can start after Setup - No other dependencies
- **User Story 2 (Phase 4)**: Depends on User Story 1 completion (builds on system config)
- **User Story 4 (Phase 5)**: Depends on User Story 2 completion (needs write access infrastructure)
- **User Story 3 (Phase 6)**: Can run in parallel with US2/US4 (independent service)
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Independent - system-wide configuration
- **User Story 2 (P1)**: Depends on US1 - adds per-user write access layer
- **User Story 3 (P2)**: Independent - separate system service
- **User Story 4 (P2)**: Depends on US2 - needs write access infrastructure

### Within Each User Story

- System configuration before testing
- netrc generation before push testing
- Service configuration before service start
- All tasks within a story must complete before story is considered done

### Parallel Opportunities

- T001, T002, T003 can run in parallel (Setup phase)
- T028-T035 (Darwin agent) and T036-T041 (NixOS agent) can run in parallel
- T042-T046 (Documentation) can run in parallel
- User Story 3 (agent) can be developed in parallel with User Story 2/4 (different components)

______________________________________________________________________

## Parallel Example: User Story 3 (Agent Service)

```bash
# Darwin and NixOS agent implementations can run in parallel:
Task: "Create system/darwin/settings/cachix-agent.nix"
Task: "Create system/nixos/settings/cachix-agent.nix"

# Documentation tasks can run in parallel:
Task: "Update CLAUDE.md with Cachix integration documentation"
Task: "Add Cachix setup instructions to CLAUDE.md"
Task: "Document just build-and-push usage in CLAUDE.md"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (verify dependencies)
1. Complete Phase 3: User Story 1 (system-wide read-only cache)
1. **STOP and VALIDATE**: Test builds, verify cache usage
1. All users now benefit from faster builds - MVP complete!

### Incremental Delivery

1. Setup + US1 → All users get read-only cache (MVP!)
1. Add US2 → Users can opt into write access
1. Add US4 → Convenient build-and-push workflow
1. Add US3 → Remote deployment capability
1. Polish → Documentation and final validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + US1 together
1. Once US1 is done:
   - Developer A: User Story 2 (write access)
   - Developer B: User Story 3 (agent service - darwin)
   - Developer C: User Story 3 (agent service - nixos)
1. Developer A then implements User Story 4 (depends on US2)
1. Everyone contributes to Phase 7 (documentation)

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Test after each major task or logical group
- Commit after each completed user story
- Stop at any checkpoint to validate story independently
- Focus on US1 for MVP - it provides value to all users immediately
- US2-US4 are enhancements for power users who want to share builds
- Validation is via manual testing (`just build`, `just build-and-push`, service status checks)
