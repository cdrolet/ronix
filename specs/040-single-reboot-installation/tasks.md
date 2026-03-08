# Tasks: Single-Reboot NixOS Installation

**Input**: Design documents from `/specs/040-single-reboot-installation/`\
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓

**Tests**: This feature does NOT require automated tests. Testing is manual via VM/bare-metal installation (see quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

All paths are absolute, relative to repository root:

- Nix modules: `system/{platform}/{category}/{file}.nix`
- Documentation: `CLAUDE.md`, `docs/`
- Specs: `specs/040-single-reboot-installation/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Preparation and understanding of existing codebase

- [x] T001 Read existing first-boot.nix to understand current implementation at `system/nixos/settings/system/first-boot.nix`
- [x] T002 [P] Review GNOME dock module at `system/shared/family/gnome/settings/user/dock.nix` to understand activation pattern
- [x] T003 [P] Review existing activation scripts in codebase (password.nix, git-repos.nix) for established patterns

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure changes that enable all user stories

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Verify desktop-file-utils package available in nixpkgs (check pkgs.desktop-file-utils exists)
- [x] T005 [P] Verify lib.hm.dag is available in home-manager context (check existing activation scripts)
- [x] T006 [P] Verify systemd ordering directives work as expected (research.md confirms behavior)

**Checkpoint**: ✅ Foundation ready - user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Single-Reboot Installation (Priority: P1) 🎯 MVP

**Goal**: Ensure GDM blocks until home-manager activation completes, so apps are visible on first login

**Independent Test**: Install NixOS from ISO, reboot once, login once, verify all apps visible immediately (no 3rd reboot needed)

### Implementation for User Story 1

- [x] T007 [US1] Add `before = ["graphical.target"]` to systemd service in `system/nixos/settings/system/first-boot.nix`
- [x] T008 [US1] Update inline comments in `system/nixos/settings/system/first-boot.nix` explaining systemd ordering guarantees
- [x] T009 [US1] Verify service definition matches contract specification in `specs/040-single-reboot-installation/contracts/systemd-service.nix`
- [x] T010 [US1] Build system configuration to verify Nix syntax is valid: `nix build ".#nixosConfigurations.cdrokar-qemu-gnome-vm.system"`
- [ ] T011 [US1] Test VM installation following quickstart.md Phase 1-2 procedures (MANUAL TESTING REQUIRED)
- [ ] T012 [US1] Verify systemd journal shows service ran before GDM (quickstart.md Phase 3 verification) (MANUAL TESTING REQUIRED)
- [ ] T013 [US1] Verify apps visible on first login without logout (success criteria SC-002) (MANUAL TESTING REQUIRED)

**Checkpoint**: ✅ Implementation complete - Ready for manual VM testing to verify 2 reboots instead of 3

______________________________________________________________________

## Phase 4: User Story 2 - Automatic Desktop Cache Refresh (Priority: P2)

**Goal**: Desktop file cache automatically refreshes during home-manager activation, ensuring GNOME sees all apps

**Independent Test**: Activate home-manager, check logs for cache refresh message, verify mimeinfo.cache timestamp is recent

### Implementation for User Story 2

- [x] T014 [P] [US2] Create new module `system/shared/family/gnome/settings/user/desktop-cache.nix` with header documentation
- [x] T015 [US2] Implement context validation guard using `lib.optionalAttrs (options ? home)` pattern per Constitution v2.3.0
- [x] T016 [US2] Add activation script `home.activation.refreshDesktopCache` using `lib.hm.dag.entryAfter ["writeBoundary"]`
- [x] T017 [US2] Implement desktop cache refresh command: `update-desktop-database -q ~/.local/share/applications 2>/dev/null || true`
- [x] T018 [US2] Add `$VERBOSE_ECHO "Desktop file cache refreshed"` message for logging
- [x] T019 [US2] Verify implementation matches contract in `specs/040-single-reboot-installation/contracts/activation-script.nix`
- [x] T020 [US2] Add `desktop-cache.nix` to GNOME family auto-discovery (verify `default.nix` imports it or relies on auto-discovery)
- [x] T021 [US2] Build home-manager configuration to verify syntax: `nix build ".#homeConfigurations.\"cdrokar@qemu-gnome-vm\".activationPackage"`
- [ ] T022 [US2] Test activation script execution via manual home-manager activation (MANUAL TESTING REQUIRED)
- [ ] T023 [US2] Verify cache file `~/.local/share/applications/mimeinfo.cache` exists and has recent timestamp (MANUAL TESTING REQUIRED)
- [ ] T024 [US2] Verify activation succeeds even if cache refresh fails (test with invalid permissions) (MANUAL TESTING REQUIRED)

**Checkpoint**: ✅ Implementation complete - Ready for manual testing to verify cache refresh works

______________________________________________________________________

## Phase 5: User Story 3 - Clear Installation Progress Communication (Priority: P3)

**Goal**: Users see clear progress messages during first-boot service execution, reducing confusion about boot delay

**Independent Test**: Watch boot console output during first-boot service, verify messages are clear and informative

### Implementation for User Story 3

- [x] T025 [P] [US3] Update `/etc/nix-config-first-boot.sh` script with stage indicators in `system/nixos/settings/system/first-boot.nix`
- [x] T026 [US3] Add progress message: "==> [1/4] Cloning nix-config repository..."
- [x] T027 [US3] Add progress message: "==> [2/4] Building home-manager configuration..."
- [x] T028 [US3] Add progress message: "==> [3/4] Installing user applications..."
- [x] T029 [US3] Add progress message: "==> [4/4] Activating configuration..."
- [x] T030 [US3] Add completion message: "==> Setup complete! Starting login screen..."
- [ ] T031 [US3] Test VM installation and observe console output for message clarity (MANUAL TESTING REQUIRED)
- [ ] T032 [US3] Verify messages visible in systemd journal: `journalctl -u nix-config-first-boot.service` (MANUAL TESTING REQUIRED)

**Checkpoint**: ✅ Implementation complete - Ready for manual testing to verify message clarity

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, testing, and final validation

- [x] T033 [P] Update `CLAUDE.md` installation flow documentation to reflect 2-reboot process (remove 3rd-reboot references)
- [x] T034 [P] Add inline comments to `first-boot.nix` explaining the `before` directive and systemd ordering
- [x] T035 [P] Add inline comments to `desktop-cache.nix` explaining activation DAG timing and idempotency
- [ ] T036 Perform full VM installation test following all quickstart.md procedures (MANUAL TESTING REQUIRED)
- [ ] T037 [P] Verify success criteria SC-001 through SC-009 from spec.md (MANUAL TESTING REQUIRED)
- [ ] T038 [P] Optional: Perform bare-metal installation test for final validation (quickstart.md Phase 4) (OPTIONAL)
- [x] T039 Run `nix flake check` to verify all configurations build successfully
- [ ] T040 [P] Create user-facing installation guide in `docs/installation/` (if needed) (OPTIONAL)
- [x] T041 Commit all changes with descriptive commit message

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User Story 1 (US1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (US2): Can start after Foundational - No dependencies (US1 not required)
  - User Story 3 (US3): Can start after Foundational - No dependencies (US1/US2 not required)
- **Polish (Phase 6)**: Depends on desired user stories being complete (typically US1+US2 minimum)

### User Story Dependencies

**IMPORTANT: All user stories are INDEPENDENT by design**

- **User Story 1 (P1 - MVP)**: Systemd ordering fix - Standalone implementation
- **User Story 2 (P2)**: Desktop cache refresh - Independent of US1, but complements it
- **User Story 3 (P3)**: Progress messages - Independent of US1/US2, pure UX enhancement

**Why Independence Matters**:

- US1 alone delivers 2-reboot installation (MVP)
- US2 alone ensures cache freshness (useful for any home-manager activation)
- US3 alone improves UX (helpful even without US1/US2)
- Combined: Optimal experience (2 reboots + fresh cache + clear communication)

### Within Each User Story

**User Story 1** (Systemd Ordering):

1. Modify first-boot.nix (T007-T009)
1. Build and verify syntax (T010)
1. Test installation (T011-T013)

**User Story 2** (Desktop Cache):

1. Create desktop-cache.nix module (T014-T020)
1. Build and verify syntax (T021)
1. Test activation (T022-T024)

**User Story 3** (Progress Messages):

1. Update script messages (T025-T030)
1. Test and verify visibility (T031-T032)

### Parallel Opportunities

- **Setup phase**: T002 and T003 can run in parallel (different files)
- **Foundational phase**: T005 and T006 can run in parallel (research/verification tasks)
- **After Foundational**: All 3 user stories can proceed in parallel if staffed
  - Developer A: User Story 1 (systemd ordering)
  - Developer B: User Story 2 (desktop cache)
  - Developer C: User Story 3 (progress messages)
- **Polish phase**: T033, T034, T035, T037, T038, T040 can run in parallel (different files/tasks)

______________________________________________________________________

## Parallel Example: After Foundational Phase

```bash
# Three developers can work simultaneously:

# Developer A (User Story 1):
Task: "Add before directive to first-boot.nix"
Task: "Update comments in first-boot.nix"
Task: "Test VM installation"

# Developer B (User Story 2):
Task: "Create desktop-cache.nix module"
Task: "Implement activation script"
Task: "Test cache refresh"

# Developer C (User Story 3):
Task: "Update progress messages in first-boot.nix"
Task: "Verify message visibility"
```

**Note**: Developer A and C both modify `first-boot.nix` - coordination needed, but changes are in different sections (service definition vs script content).

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only) - Recommended

1. Complete Phase 1: Setup (T001-T003) - ~30 minutes
1. Complete Phase 2: Foundational (T004-T006) - ~15 minutes
1. Complete Phase 3: User Story 1 (T007-T013) - ~1 hour
1. **STOP and VALIDATE**: Test VM installation, verify 2-reboot flow works
1. **Deploy/Demo**: MVP complete - single-reboot installation achieved!

**Estimated MVP Time**: ~2 hours (including testing)

### Incremental Delivery (Recommended Path)

1. Complete Setup + Foundational → ~45 minutes
1. Add User Story 1 → Test independently → ~1 hour (MVP: 2-reboot installation ✓)
1. Add User Story 2 → Test independently → ~45 minutes (Cache freshness guaranteed ✓)
1. Add User Story 3 → Test independently → ~30 minutes (Better UX ✓)
1. Polish phase → Final validation → ~30 minutes

**Total Estimated Time**: ~3.5 hours (full feature)

### Parallel Team Strategy

With 3 developers (after Foundational phase):

1. Team completes Setup + Foundational together (~45 min)
1. Once Foundational is done:
   - Dev A: User Story 1 (~1 hour)
   - Dev B: User Story 2 (~45 min)
   - Dev C: User Story 3 (~30 min)
1. Integration and testing (~30 min)
1. Polish phase together (~30 min)

**Total Elapsed Time**: ~2.5 hours (parallel execution)

______________________________________________________________________

## Testing Checklist

Use quickstart.md for detailed procedures. Summary checklist:

**VM Testing** (Primary validation):

- [ ] ISO builds successfully
- [ ] Installation completes without errors
- [ ] First-boot service blocks GDM (visible in boot messages)
- [ ] Service completes before login screen appears
- [ ] First login shows all configured apps
- [ ] Systemd journal confirms ordering (service before GDM)
- [ ] Desktop cache file exists and is fresh
- [ ] No errors in activation logs

**Bare-Metal Testing** (Optional final validation):

- [ ] Same checklist as VM testing
- [ ] Verify hardware compatibility
- [ ] Confirm no VM-specific issues

______________________________________________________________________

## Success Metrics

From spec.md success criteria:

- **SC-001**: ✓ 2 reboots instead of 3 (33% reduction)
- **SC-002**: ✓ 100% of apps visible on first login
- **SC-003**: ✓ Service completes before GDM starts
- **SC-004**: ✓ Desktop cache refresh succeeds automatically
- **SC-005**: ✓ Installation time reduced by 2-5 minutes
- **SC-006**: ✓ Zero premature logins (systemd blocks GDM)
- **SC-007**: ✓ No new failure modes introduced
- **SC-008**: ✓ User satisfaction improved

______________________________________________________________________

## Notes

- **[P] tasks**: Different files, no dependencies, safe for parallel execution
- **[Story] labels**: Map tasks to user stories for traceability
- **Independence**: Each user story can be completed and tested standalone
- **MVP Strategy**: User Story 1 alone delivers 2-reboot installation
- **No Automated Tests**: Manual testing via VM/bare-metal installation (quickstart.md)
- **Context Validation**: Desktop cache module MUST use `lib.optionalAttrs (options ? home)` per Constitution v2.3.0
- **File Paths**: All paths are exact locations in repository
- **Commit Strategy**: Commit after each phase or logical user story completion
- **Rollback**: Use `nixos-rebuild switch --rollback` if issues occur

______________________________________________________________________

## Task Summary

- **Total Tasks**: 41
- **Setup Tasks**: 3
- **Foundational Tasks**: 3
- **User Story 1 (P1 - MVP)**: 7 tasks
- **User Story 2 (P2)**: 11 tasks
- **User Story 3 (P3)**: 8 tasks
- **Polish Tasks**: 9 tasks

**Parallel Opportunities**: 12 tasks marked [P] can run in parallel

**MVP Scope** (User Story 1 only): 13 tasks (Setup + Foundational + US1) = ~2 hours

**Full Feature** (All user stories): 41 tasks = ~3.5 hours sequential, ~2.5 hours parallel
