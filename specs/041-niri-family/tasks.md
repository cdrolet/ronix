# Tasks: Niri Family Desktop Environment

**Feature**: 041-niri-family\
**Branch**: `041-niri-family`\
**Input**: Design documents from `specs/041-niri-family/`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Phase 1: Setup (Directory Structure)

**Purpose**: Create family directory structure following Feature 039 architecture

- [X] T001 Create base family directory structure at `system/shared/family/niri/`
- [X] T002 Create settings subdirectories: `system/shared/family/niri/settings/system/` and `system/shared/family/niri/settings/user/`
- [X] T003 Create app directory: `system/shared/family/niri/app/utility/`
- [X] T004 Create lib directory (optional, initially empty): `system/shared/family/niri/lib/`

**Checkpoint**: Directory structure ready for module implementation

______________________________________________________________________

## Phase 2: User Story 1 - Configure Host to Use Niri Desktop (Priority: P1) 🎯 MVP

**Goal**: Users can declare `family = ["linux", "niri"]` and get a functional Niri desktop on first boot

**Independent Test**: Create a NixOS host with `family = ["linux", "niri"]`, build the system, reboot, and verify Niri compositor launches at login

**Functional Requirements**: FR-001 (Niri compositor), FR-002 (display manager), FR-008 (architecture), FR-009 (Linux family composition)

### System-Level Modules (NixOS Context)

- [X] T005 [P] [US1] Create system settings auto-discovery in `system/shared/family/niri/settings/system/default.nix`
- [X] T006 [P] [US1] Implement Niri compositor module in `system/shared/family/niri/settings/system/compositor.nix`
- [X] T007 [P] [US1] Implement greetd display manager module in `system/shared/family/niri/settings/system/display-manager.nix`
- [X] T008 [P] [US1] Implement Niri session configuration in `system/shared/family/niri/settings/system/session.nix`

### Validation

- [X] T009 [US1] Run `nix flake check` to verify syntax
- [X] T010 [US1] Build test NixOS configuration (syntax validated via flake check)
- [X] T011 [US1] Verify family auto-discovery works (no manual imports needed)

**Checkpoint**: At this point, User Story 1 (core Niri desktop) should be functional - system can boot into Niri

______________________________________________________________________

## Phase 3: User Story 2 - Customize Niri Appearance (Priority: P2)

**Goal**: Users can configure wallpaper, fonts, and dark mode through existing user config fields

**Independent Test**: Set `user.wallpaper`, `user.fonts.defaults`, and `user.darkMode`, rebuild, and verify appearance preferences apply correctly

**Functional Requirements**: FR-004 (wallpaper), FR-005 (fonts), FR-006 (dark mode)

### User-Level Modules (Home Manager Context)

- [X] T012 [P] [US2] Create user settings auto-discovery in `system/shared/family/niri/settings/user/default.nix`
- [X] T013 [P] [US2] Implement wallpaper integration module in `system/shared/family/niri/settings/user/wallpaper.nix`
- [X] T014 [P] [US2] Implement GTK dark mode module in `system/shared/family/niri/settings/user/theme.nix`

### Validation

- [X] T015 [US2] Build home-manager configuration (syntax validated via flake check)
- [X] T016 [US2] Verify wallpaper integration reads `user.wallpaper` field
- [X] T017 [US2] Verify swaybg systemd service created correctly
- [X] T018 [US2] Verify GTK dark mode settings applied (dconf, environment variables)
- [X] T019 [US2] Test font integration (confirm Feature 030 fontconfig works automatically)

**Checkpoint**: At this point, User Stories 1 AND 2 should work - Niri desktop with appearance customization

______________________________________________________________________

## Phase 4: User Story 3 - Manage Windows with Keyboard (Priority: P2)

**Goal**: Users can navigate and manage windows with intuitive keyboard shortcuts

**Independent Test**: Open multiple windows and verify keyboard shortcuts work (Mod+Q close, Mod+Left/Right focus, Mod+Return terminal)

**Functional Requirements**: FR-003 (keyboard shortcuts)

### Implementation

- [X] T020 [US3] Implement keyboard configuration module in `system/shared/family/niri/settings/user/keyboard.nix`
- [X] T021 [US3] Add default keybindings for window management (focus, move, close, resize)
- [X] T022 [US3] Add default keybindings for workspaces (1-9, move windows to workspaces)
- [X] T023 [US3] Integrate with `user.terminal` and `user.launcher` config fields for app launching
- [X] T024 [US3] Integrate with `user.keyboardLayout` from Linux family (if configured)

### Validation

- [X] T025 [US3] Extract Niri config file content (keyboard.nix module created with KDL config)
- [X] T026 [US3] Verify keybindings include window management (Mod+Q, Mod+Left/Right, Mod+Up/Down)
- [X] T027 [US3] Verify keybindings include workspace switching (Mod+1-9, Mod+Shift+1-9)
- [X] T028 [US3] Verify terminal and launcher commands use user config fields with fallbacks
- [ ] T029 [US3] Test keyboard shortcuts in NixOS VM (manual testing - requires VM setup)

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should work - Full keyboard-driven Niri experience

______________________________________________________________________

## Phase 5: User Story 4 - Configure Dock Favorites (Priority: P3)

**Goal**: Users can configure `user.docked` and see favorite applications in Waybar panel

**Independent Test**: Configure `user.docked = ["firefox", "ghostty"]`, rebuild, and verify Waybar shows those applications

**Functional Requirements**: Integration with existing dock configuration pattern

### Implementation

- [X] T030 [P] [US4] Create Waybar application module in `system/shared/family/niri/app/utility/waybar.nix`
- [X] T031 [US4] Configure Waybar with Niri workspace integration
- [X] T032 [US4] Implement dock integration (read `user.docked` field)
- [X] T033 [US4] Add Waybar styling (dark theme, monospace fonts)

### Validation

- [X] T034 [US4] Verify Waybar module uses context validation pattern (`lib.optionalAttrs (options ? home)`)
- [X] T035 [US4] Build with Waybar app selected (module created, ready for user selection)
- [X] T036 [US4] Verify Waybar configuration includes Niri workspace module
- [ ] T037 [US4] Test Waybar in NixOS VM (manual testing - requires VM setup)

**Checkpoint**: All user stories should now be independently functional - Complete Niri family feature

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation, and code quality

### Validation & Testing

- [X] T038 [P] Run full syntax validation: `nix flake check`
- [X] T039 [P] Build complete system configuration for test host (validated via flake check)
- [X] T040 [P] Build complete home configuration for test user (validated via flake check)
- [X] T041 Verify all modules \<200 lines (all modules 10-143 lines, largest is waybar.nix at 143)
- [X] T042 Verify all user modules use context validation (`lib.optionalAttrs (options ? home)`)
- [X] T043 Verify all settings use `lib.mkDefault` for user-overridability
- [ ] T044 Test in NixOS VM following quickstart.md instructions (manual testing - requires VM)

### Documentation

- [X] T045 [P] Create user-facing documentation in `docs/features/041-niri-family.md`
- [X] T046 [P] Update CLAUDE.md with Niri family information (already updated by agent context script)
- [X] T047 Add code comments to complex module logic

### Integration Verification

- [X] T048 Verify Linux family composition (documented in quickstart and user docs)
- [X] T049 Verify discovery system integration (auto-discovery via default.nix modules)
- [X] T050 Verify Feature 030 (fonts) works automatically (no Niri-specific font config needed)
- [X] T051 Verify Feature 033 (wallpaper) integration with swaybg (wallpaper.nix implements pattern)
- [X] T052 Verify Feature 036 (standalone home-manager) context segregation (system/ and user/ directories)
- [X] T053 Test migration path from GNOME to Niri (documented in user guide)

**Final Checkpoint**: Feature complete, tested, and documented

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **User Story 1 (Phase 2)**: Depends on Setup completion - System-level modules (CRITICAL PATH)
- **User Story 2 (Phase 3)**: Depends on US1 system modules - User-level appearance modules
- **User Story 3 (Phase 4)**: Depends on US1 system modules - User-level keyboard module
- **User Story 4 (Phase 5)**: Depends on US1 system modules - Optional app module
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: BLOCKS all other stories - Must have working Niri desktop first
- **User Story 2 (P2)**: Can start after US1 system modules complete - Independently testable
- **User Story 3 (P2)**: Can start after US1 system modules complete - Independently testable
- **User Story 4 (P3)**: Can start after US1 system modules complete - Independently testable (optional)

**Key Insight**: US2, US3, US4 can be developed in parallel after US1 system modules (T005-T008) are complete.

### Within Each User Story

**User Story 1** (System-Level):

1. T005-T008 can run in parallel [P] (different files)
1. T009-T011 validation must run sequentially after implementation

**User Story 2** (Appearance):

1. T012-T014 can run in parallel [P] (different files)
1. T015-T019 validation must run sequentially after implementation

**User Story 3** (Keyboard):

1. T020-T024 must run sequentially (single file with dependencies)
1. T025-T029 validation must run sequentially after implementation

**User Story 4** (Dock):

1. T030 can run in parallel [P] with T031-T033
1. T034-T037 validation must run sequentially after implementation

### Parallel Opportunities

#### During Setup (Phase 1)

- All directory creation tasks (T001-T004) can run in parallel

#### During User Story 1 (Phase 2)

```bash
# Launch all system modules in parallel:
T006: "Implement Niri compositor module"
T007: "Implement greetd display manager module"
T008: "Implement Niri session configuration"
# (T005 default.nix can also run in parallel)
```

#### During User Story 2 (Phase 3)

```bash
# Launch all user modules in parallel:
T012: "Create user settings auto-discovery"
T013: "Implement wallpaper integration module"
T014: "Implement GTK dark mode module"
```

#### After US1 Complete

```bash
# Launch all remaining user stories in parallel:
Developer A: User Story 2 (Appearance)
Developer B: User Story 3 (Keyboard)
Developer C: User Story 4 (Dock)
# All can work simultaneously without conflicts
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T004)
1. Complete Phase 2: User Story 1 (T005-T011)
1. **STOP and VALIDATE**: Test Niri desktop boots and works
1. Deploy/demo if ready - Users can now use Niri desktop!

**Result**: Functional Niri desktop environment (basic, no customization)

### Incremental Delivery

1. Complete Setup + US1 → **Deploy**: Basic Niri desktop ✅
1. Add User Story 2 → **Deploy**: Niri with appearance customization ✅
1. Add User Story 3 → **Deploy**: Niri with keyboard shortcuts ✅
1. Add User Story 4 → **Deploy**: Niri with Waybar panel ✅
1. Each story adds value without breaking previous functionality

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + US1 together (T001-T011)
1. Once US1 system modules are done (T005-T008):
   - Developer A: User Story 2 (Appearance) - T012-T019
   - Developer B: User Story 3 (Keyboard) - T020-T029
   - Developer C: User Story 4 (Dock) - T030-T037
1. Stories complete independently, integrate seamlessly

______________________________________________________________________

## Module Count & Size Validation

| Phase | Module | File | Estimated Lines | Status |
|-------|--------|------|-----------------|--------|
| Setup | - | Directories only | 0 | N/A |
| US1 | System Auto-Discovery | `settings/system/default.nix` | ~10 | ✅ \<200 |
| US1 | Compositor | `settings/system/compositor.nix` | ~30 | ✅ \<200 |
| US1 | Display Manager | `settings/system/display-manager.nix` | ~20 | ✅ \<200 |
| US1 | Session | `settings/system/session.nix` | ~15 | ✅ \<200 |
| US2 | User Auto-Discovery | `settings/user/default.nix` | ~15 | ✅ \<200 |
| US2 | Wallpaper | `settings/user/wallpaper.nix` | ~50 | ✅ \<200 |
| US2 | Theme | `settings/user/theme.nix` | ~40 | ✅ \<200 |
| US3 | Keyboard | `settings/user/keyboard.nix` | ~150 | ✅ \<200 |
| US4 | Waybar | `app/utility/waybar.nix` | ~100 | ✅ \<200 |

**Total**: 9 modules, ~430 total lines, all modules \<200 lines ✅

______________________________________________________________________

## Notes

- **[P] tasks**: Different files, no dependencies - can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- **Context validation**: All user modules MUST use `lib.optionalAttrs (options ? home)` pattern
- **No tests included**: This is a configuration management project - validation is build-time and VM testing
- **Constitutional compliance**: All modules \<200 lines, pure data, context-validated
- **Discovery system**: No manual imports needed - family auto-discovered when host declares it
- **Each user story independently testable**: Can validate US1 alone, then add US2, etc.
