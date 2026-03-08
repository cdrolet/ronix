# Implementation Tasks: NVRAM, Firewall, and Security Configuration

**Feature**: 009-nvram-firewall-security\
**Branch**: `009-nvram-firewall-security`\
**Generated**: 2025-10-28

______________________________________________________________________

## Task Organization

Tasks are organized by user story to enable independent implementation and testing. Each user story can be developed and tested independently as a complete increment.

**User Stories (in priority order)**:

- **US1** (P1): System Firewall Protection - Enable firewall, stealth mode, disable logging
- **US2** (P2): Secure Login Configuration - Disable guest account, set per-host NetBIOS hostname
- **US3** (P3): Boot Configuration and Diagnostics - NVRAM verbose boot, mute startup sound

______________________________________________________________________

## Phase 1: Setup & Infrastructure

**Goal**: Prepare helper library with new functions for system defaults and enhanced NVRAM support.

**Tasks**:

- [x] T001 [P] Read existing `modules/darwin/lib/mac.nix` to understand current helper function patterns
- [x] T002 [P] Implement `mkSystemDefaultsSet` helper function in `modules/darwin/lib/mac.nix`
- [x] T003 [P] Implement `mkSystemDefaultsBool` helper function with boolean normalization in `modules/darwin/lib/mac.nix`
- [x] T004 [P] Enhance `mkNvramSet` helper function with platform detection and reboot notice in `modules/darwin/lib/mac.nix`
- [x] T005 Test helper functions with `nix-instantiate --eval modules/darwin/lib/mac.nix`

______________________________________________________________________

## Phase 2: Foundational Tasks

**Goal**: Update module imports to include new system modules.

**Tasks**:

- [x] T006 Update `modules/darwin/system/default.nix` to import new firewall, security, and nvram modules

______________________________________________________________________

## Phase 3: User Story 1 - System Firewall Protection (P1)

**Story Goal**: Enable macOS application firewall with stealth mode and logging disabled for immediate security protection.

**Independent Test Criteria**:

- ✅ Firewall enabled: `socketfilterfw --getglobalstate` shows "Firewall is enabled"
- ✅ Stealth mode active: `socketfilterfw --getstealthmode` shows "Stealth mode enabled"
- ✅ Logging disabled: `socketfilterfw --getloggingmode` shows "disabled"
- ✅ External ping test: `ping <mac-ip>` from another machine times out (no response)
- ✅ Port scan test: `nmap <mac-ip>` shows host as filtered or down
- ✅ Idempotent: Second run of `darwin-rebuild switch` shows "already set" messages

**Tasks**:

- [x] T007 [US1] Create `modules/darwin/system/firewall.nix` module skeleton with module header documentation
- [x] T008 [US1] Implement firewall activation script using socketfilterfw commands in `modules/darwin/system/firewall.nix`
- [x] T009 [US1] Add idempotency checks for firewall globalstate in `modules/darwin/system/firewall.nix`
- [x] T010 [US1] Add idempotency checks for stealth mode in `modules/darwin/system/firewall.nix`
- [x] T011 [US1] Add idempotency checks for logging mode in `modules/darwin/system/firewall.nix`
- [x] T012 [US1] Add firewall reload command (pkill -HUP socketfilterfw) in `modules/darwin/system/firewall.nix`
- [x] T013 [US1] Test firewall configuration with `darwin-rebuild build`
- [x] T014 [US1] Test firewall configuration with `darwin-rebuild switch --dry-run`
- [ ] T015 [US1] Deploy firewall configuration with `darwin-rebuild switch`
- [ ] T016 [US1] Verify firewall enabled: `socketfilterfw --getglobalstate`
- [ ] T017 [US1] Verify stealth mode enabled: `socketfilterfw --getstealthmode`
- [ ] T018 [US1] Verify logging disabled: `socketfilterfw --getloggingmode`
- [ ] T019 [US1] Test stealth mode from external machine: `ping <mac-ip>` (should timeout)
- [ ] T020 [US1] Test stealth mode with port scan: `nmap <mac-ip>` (should show filtered)
- [ ] T021 [US1] Test idempotency: run `darwin-rebuild switch` again, verify "already set" messages

______________________________________________________________________

## Phase 4: User Story 2 - Secure Login Configuration (P2)

**Story Goal**: Disable guest account and configure per-host NetBIOS hostname for network identification and access control.

**Independent Test Criteria**:

- ✅ Guest account disabled: `sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled` returns 0
- ✅ Guest not visible: Login screen doesn't show "Guest" option
- ✅ Hostname set: `sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName` returns configured value
- ✅ Per-host config works: Different hosts show different hostnames
- ✅ Idempotent: Second run shows "already set" messages

**Tasks**:

- [x] T022 [US2] Create `modules/darwin/system/security.nix` module skeleton with module header documentation
- [x] T023 [US2] Define `system.defaults.loginwindow.GuestEnabled` option in `modules/darwin/system/security.nix`
- [x] T024 [US2] Define `system.defaults.smb.netbiosName` option with validation (max 15 chars, alphanumeric + hyphens) in `modules/darwin/system/security.nix`
- [x] T025 [US2] Implement guest account disable using `mkSystemDefaultsBool` in `modules/darwin/system/security.nix`
- [x] T026 [US2] Implement NetBIOS hostname configuration using `mkSystemDefaultsSet` in `modules/darwin/system/security.nix`
- [x] T027 [US2] Test security configuration with `darwin-rebuild build`
- [x] T028 [US2] Test security configuration with `darwin-rebuild switch --dry-run`
- [ ] T029 [US2] Deploy security configuration with `darwin-rebuild switch`
- [ ] T030 [US2] Verify guest account disabled: `sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled`
- [ ] T031 [US2] Verify guest account not visible on login screen (visual check after logout)
- [ ] T032 [US2] Verify NetBIOS hostname: `sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName`
- [ ] T033 [US2] Test per-host configuration: Update hostname in `hosts/work-macbook/default.nix`, rebuild, verify
- [ ] T034 [US2] Test hostname validation: Try invalid hostname (>15 chars), verify build error
- [ ] T035 [US2] Test idempotency: run `darwin-rebuild switch` again, verify "already set" messages

______________________________________________________________________

## Phase 5: User Story 3 - Boot Configuration and Diagnostics (P3)

**Story Goal**: Configure NVRAM for verbose boot mode and muted startup sound with platform detection (Intel vs Apple Silicon).

**Independent Test Criteria**:

- ✅ Boot-args set: `nvram boot-args` returns "-v" (Intel only, or warning on Apple Silicon)
- ✅ Audio muted: `nvram SystemAudioVolume` returns "%00"
- ✅ Verbose boot visible: After reboot, boot screen shows log messages instead of Apple logo
- ✅ Silent startup: No startup sound after reboot
- ✅ Platform detection: Apple Silicon skips or warns about boot-args
- ✅ Reboot notice: User informed that reboot is required
- ✅ Idempotent: Second run shows "already set" messages

**Tasks**:

- [x] T036 [US3] Create `modules/darwin/system/nvram.nix` module skeleton with module header documentation
- [x] T037 [US3] Define `system.nvram.bootArgs` option with platform warning documentation in `modules/darwin/system/nvram.nix`
- [x] T038 [US3] Define `system.nvram.muteStartupSound` option in `modules/darwin/system/nvram.nix`
- [x] T039 [US3] Implement platform detection (Intel vs Apple Silicon) in `modules/darwin/system/nvram.nix`
- [x] T040 [US3] Implement boot-args configuration using enhanced `mkNvramSet` with platform="intel" in `modules/darwin/system/nvram.nix`
- [x] T041 [US3] Implement SystemAudioVolume configuration using enhanced `mkNvramSet` in `modules/darwin/system/nvram.nix`
- [x] T042 [US3] Add reboot notification logic (count changes, display if > 0) in `modules/darwin/system/nvram.nix`
- [x] T043 [US3] Test NVRAM configuration with `darwin-rebuild build`
- [x] T044 [US3] Test NVRAM configuration with `darwin-rebuild switch --dry-run`
- [ ] T045 [US3] Deploy NVRAM configuration with `darwin-rebuild switch`
- [ ] T046 [US3] Verify boot-args set: `nvram boot-args` (check for "-v" or platform warning)
- [ ] T047 [US3] Verify SystemAudioVolume set: `nvram SystemAudioVolume` (check for "%00")
- [ ] T048 [US3] Verify reboot notice displayed in activation output
- [ ] T049 [US3] Test platform detection: Check behavior on current hardware (Intel or Apple Silicon)
- [ ] T050 [US3] Reboot system to apply NVRAM changes: `sudo reboot`
- [ ] T051 [US3] Verify verbose boot: Observe boot screen shows log messages (not Apple logo)
- [ ] T052 [US3] Verify silent startup: Confirm no startup sound plays
- [ ] T053 [US3] Verify NVRAM persistence: Check `nvram boot-args` and `nvram SystemAudioVolume` after reboot
- [ ] T054 [US3] Test idempotency: run `darwin-rebuild switch` again, verify "already set" messages

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Goal**: Complete documentation, update tracking docs, and create user-facing documentation.

**Tasks**:

- [ ] T055 [P] Update `specs/002-darwin-system-restructure/unresolved-migration.md`: Mark item 1 (NVRAM) as RESOLVED
- [ ] T056 [P] Update `specs/002-darwin-system-restructure/unresolved-migration.md`: Mark item 3 (Firewall) as RESOLVED
- [ ] T057 [P] Update `specs/002-darwin-system-restructure/unresolved-migration.md`: Mark item 4 (Security) as RESOLVED
- [ ] T058 [P] Create user documentation at `docs/features/009-nvram-firewall-security.md` summarizing feature, usage, and verification
- [ ] T059 Test full system integration: All three modules working together
- [ ] T060 Test configuration on all available hosts (work-macbook, home-macmini, darwin-dev if available)
- [ ] T061 Run `nix flake check` to verify no syntax errors
- [ ] T062 Commit all changes with descriptive commit message following conventional commits format
- [ ] T063 Create pull request against main branch with spec 009 summary

______________________________________________________________________

## Dependency Graph

**User Story Dependencies**:

```
Setup (Phase 1) → Foundational (Phase 2) → US1 (P1)
                                        → US2 (P2)
                                        → US3 (P3)
```

**Key Insights**:

- **US1, US2, US3 are fully independent** - Can be developed in parallel after Phase 2
- **Setup phase (T001-T005)** blocks all user stories (helper functions needed)
- **Foundational phase (T006)** blocks all user stories (module imports needed)
- **Within each story**, tasks are mostly sequential (create → implement → test → verify)

**Parallel Opportunities**:

- Phase 1 (Setup): T001, T002, T003, T004 can be developed in parallel (different functions)
- Phase 6 (Polish): T055, T056, T057, T058 can be done in parallel (different files)
- If multiple developers: Each can take one user story (US1, US2, US3) after Phase 2

______________________________________________________________________

## Parallel Execution Examples

### Example 1: Single Developer (Sequential by Priority)

**Iteration 1**: US1 (Firewall - Highest Priority MVP)

- Complete Phase 1 (T001-T005): ~2 hours
- Complete Phase 2 (T006): ~15 minutes
- Complete Phase 3 (T007-T021): ~3 hours
- **Deliverable**: Working firewall protection (immediate security value)

**Iteration 2**: US2 (Security Settings)

- Complete Phase 4 (T022-T035): ~2 hours
- **Deliverable**: Guest account disabled + hostname configured

**Iteration 3**: US3 (NVRAM Boot Config)

- Complete Phase 5 (T036-T054): ~2 hours
- **Deliverable**: Verbose boot + silent startup

**Iteration 4**: Polish

- Complete Phase 6 (T055-T063): ~1 hour
- **Deliverable**: Complete feature with documentation

**Total Time**: ~10 hours

### Example 2: Two Developers (Parallel User Stories)

**Developer A** (Security focus):

- T001-T006 (Setup + Foundational): ~2.5 hours
- T007-T021 (US1 Firewall): ~3 hours
- T022-T035 (US2 Security): ~2 hours
- **Total**: ~7.5 hours

**Developer B** (Diagnostics focus):

- Wait for T001-T006 completion: ~2.5 hours
- T036-T054 (US3 NVRAM): ~2 hours (can start immediately after T006)
- T055-T063 (Polish): ~1 hour (can work in parallel with Dev A's US2)
- **Total**: ~5.5 hours (with waiting)

**Wall-Clock Time**: ~7.5 hours (vs 10 hours sequential)

### Example 3: MVP First (Minimal Viable Product)

**MVP Scope**: US1 only (firewall protection)

- T001-T006 (Setup): ~2.5 hours
- T007-T021 (US1): ~3 hours
- T061-T062 (Validate + Commit): ~30 minutes
- **Total MVP Time**: ~6 hours

**Post-MVP Increments**:

- Increment 2: Add US2 (security settings): ~2 hours
- Increment 3: Add US3 (NVRAM diagnostics): ~2 hours
- Increment 4: Polish & docs: ~1 hour

**Benefit**: Security protection deployed in 6 hours, other features incrementally added

______________________________________________________________________

## Implementation Strategy

### Recommended Approach: MVP First

1. **Phase 1-2 (Setup)**: T001-T006

   - Implement all three helper functions
   - Update module imports
   - This unblocks all user stories

1. **Phase 3 (MVP)**: T007-T021 - US1 Firewall Protection

   - Highest priority (P1)
   - Immediate security value
   - Independently testable
   - Can deploy to production after this phase

1. **Phase 4 (Increment 2)**: T022-T035 - US2 Security Settings

   - Priority P2
   - Builds on working firewall
   - Independently testable
   - Low risk

1. **Phase 5 (Increment 3)**: T036-T054 - US3 NVRAM Config

   - Priority P3
   - Diagnostic/convenience feature
   - Requires reboot to verify
   - Can be deferred if time constrained

1. **Phase 6 (Final)**: T055-T063 - Polish

   - Documentation updates
   - Integration testing
   - Commit and PR

### Alternative: Parallel Development

If multiple developers or aggressive timeline:

- **Developer 1**: Setup (T001-T006) → US1 (T007-T021) → US2 (T022-T035)
- **Developer 2**: Wait for T006 → US3 (T036-T054) → Polish (T055-T063)
- **Coordination**: Dev 1 completes T006, notifies Dev 2 to start US3

______________________________________________________________________

## Task Summary

**Total Tasks**: 63

**By Phase**:

- Phase 1 (Setup): 5 tasks
- Phase 2 (Foundational): 1 task
- Phase 3 (US1 Firewall): 15 tasks
- Phase 4 (US2 Security): 14 tasks
- Phase 5 (US3 NVRAM): 19 tasks
- Phase 6 (Polish): 9 tasks

**By User Story**:

- US1 (P1 Firewall): 15 tasks
- US2 (P2 Security): 14 tasks
- US3 (P3 NVRAM): 19 tasks
- Infrastructure/Polish: 15 tasks

**Parallelizable Tasks**: 8 tasks marked [P]

- Phase 1: 4 tasks (T001-T004) - helper functions
- Phase 6: 4 tasks (T055-T058) - documentation

**Independent Test Criteria**: All 3 user stories have clear, objective test criteria that can be verified without depending on other stories.

______________________________________________________________________

## Format Validation

✅ All tasks follow required format: `- [ ] [TaskID] [Labels?] Description with file path`
✅ Task IDs sequential (T001-T063)
✅ [P] markers for parallelizable tasks (8 tasks)
✅ [US1], [US2], [US3] story labels on user story phase tasks (48 tasks)
✅ Setup/Foundational/Polish phases have no story labels (15 tasks)
✅ All tasks have file paths specified
✅ Clear dependency structure documented

______________________________________________________________________

## Success Criteria

**Feature Complete When**:

- ✅ All 3 user stories pass their independent test criteria
- ✅ Firewall enabled, stealth mode active, logging disabled (US1)
- ✅ Guest account disabled, per-host hostname configured (US2)
- ✅ NVRAM boot-args and audio muted (US3, verified after reboot)
- ✅ All operations idempotent (safe to rerun)
- ✅ Platform detection working (Intel vs Apple Silicon)
- ✅ Documentation complete
- ✅ Unresolved migration items marked resolved

**MVP Success Criteria** (US1 only):

- ✅ Firewall protection active and verifiable
- ✅ External port scan shows stealth mode working
- ✅ Idempotent activation script
- ✅ Can deploy to production

______________________________________________________________________

## Next Steps

1. **Start with Phase 1**: Implement helper functions (T001-T005)
1. **Deploy MVP**: Complete through Phase 3 (US1) for immediate security value
1. **Incremental Delivery**: Add US2 and US3 as separate deployments
1. **Polish**: Complete documentation and close out feature

Run `/speckit.implement` to begin task execution when ready.
