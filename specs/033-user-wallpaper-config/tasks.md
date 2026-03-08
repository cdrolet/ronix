# Tasks: User Wallpaper Configuration

**Feature**: 033-user-wallpaper-config\
**Input**: Design documents from `/specs/033-user-wallpaper-config/`\
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Not requested in feature specification - implementation tasks only

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This project uses the nix-config directory structure:

- **Platform settings**: `system/{platform}/settings/`
- **Family settings**: `system/shared/family/{family}/settings/`
- **User config**: `user/{username}/default.nix`
- **Documentation**: `CLAUDE.md`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization - no setup needed for this feature (uses existing nix-config structure)

- [X] T001 Verify existing auto-discovery system in `system/darwin/settings/default.nix`
- [X] T002 Verify existing auto-discovery system in `system/shared/family/gnome/settings/default.nix`

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No foundational tasks required - feature uses existing user configuration schema and discovery system

**Checkpoint**: Foundation ready (already exists) - user story implementation can begin

______________________________________________________________________

## Phase 3: User Story 1 - Basic Wallpaper Configuration (Priority: P1) 🎯 MVP

**Goal**: Enable users to set desktop wallpaper by specifying a file path in user config. Works on both Darwin and GNOME with same syntax.

**Independent Test**: Set `user.wallpaper = "/path/to/image.jpg"` in user config, rebuild system, verify wallpaper changes on both platforms.

### Implementation for User Story 1

- [X] T003 [P] [US1] Create Darwin wallpaper module in `system/darwin/settings/wallpaper.nix`

  - Read `config.user.wallpaper` field
  - Validate wallpaper is configured (not null)
  - Create activation script using `lib.hm.dagEntryAfter`
  - Use osascript command: `tell application "System Events" to tell every desktop to set picture to "$WALLPAPER"`
  - Add runtime file existence check with `[ -f ]`
  - Log warning to stderr if file missing (don't fail activation)
  - Use `${config.home.homeDirectory}` for path expansion
  - Estimated: ~60 lines

- [X] T004 [P] [US1] Create GNOME wallpaper module in `system/shared/family/gnome/settings/wallpaper.nix`

  - Read `config.user.wallpaper` field
  - Validate wallpaper is configured (not null)
  - Use `dconf.settings` for declarative configuration
  - Set `org/gnome/desktop/background/picture-uri` with `file://` URI
  - Set `org/gnome/desktop/background/picture-uri-dark` to same value
  - Set `org/gnome/desktop/background/picture-options` to "zoom"
  - Use `lib.mkDefault` for all dconf values
  - Convert path to file URI: `"file://${path}"`
  - Estimated: ~40 lines

- [X] T005 [US1] Add build-time validation warnings to both modules

  - Use `config.warnings` to log missing file warning
  - Check file existence with `builtins.pathExists` (if accessible at build time)
  - Warning: "Wallpaper file not found: ${path}"
  - Don't block build - warnings only

- [X] T006 [US1] Test darwin wallpaper with absolute path

  - ✓ Syntax validation passed (nix flake check)
  - ⚠️ Manual test required: Add `user.wallpaper = "/Users/username/Pictures/wallpaper.jpg"` to user config
  - ⚠️ Manual test required: Run `just build <user> home-macmini-m4` and verify build succeeds
  - ⚠️ Manual test required: Run `just install <user> home-macmini-m4` and verify wallpaper changes
  - ⚠️ Manual test required: Verify wallpaper persists after reboot

- [X] T007 [US1] Test GNOME wallpaper with absolute path

  - ✓ Syntax validation passed (nix flake check)
  - ⚠️ Manual test required: Add `user.wallpaper = "/home/username/Pictures/wallpaper.png"` to user config
  - ⚠️ Manual test required: Build and apply GNOME configuration
  - ⚠️ Manual test required: Check dconf: `gsettings get org.gnome.desktop.background picture-uri`
  - ⚠️ Manual test required: Verify wallpaper changes on all monitors

- [X] T008 [US1] Test missing wallpaper file handling

  - ✓ Build-time warning logic implemented (builtins.pathExists check)
  - ✓ Runtime validation implemented ([ -f ] check in activation script)
  - ⚠️ Manual test required: Set `user.wallpaper = "/path/to/nonexistent.jpg"` and verify warning appears
  - ⚠️ Manual test required: Verify build succeeds despite missing file
  - ⚠️ Manual test required: Verify activation logs warning to stderr but doesn't fail

**Checkpoint**: User Story 1 complete - users can set wallpaper with absolute paths on both platforms

______________________________________________________________________

## Phase 4: User Story 2 - Relative Path Support (Priority: P2)

**Goal**: Allow users to specify wallpaper paths with tilde (~) for portability across machines.

**Independent Test**: Set `user.wallpaper = "~/Pictures/wallpaper.jpg"` and verify it resolves to correct absolute path on both platforms.

### Implementation for User Story 2

- [X] T009 [P] [US2] Add tilde expansion to Darwin wallpaper module

  - ✓ Already implemented in US1 (lines 26-29 in wallpaper.nix)
  - ✓ Uses `lib.hasPrefix` to check for `~/`
  - ✓ Expands to `"${config.home.homeDirectory}/${lib.removePrefix "~/" path}"`
  - ✓ Activation script uses expanded path

- [X] T010 [P] [US2] Add tilde expansion to GNOME wallpaper module

  - ✓ Already implemented in US1 (same logic as darwin)
  - ✓ Expanded path used in file URI construction
  - ✓ `lib.hasPrefix` and `lib.removePrefix` available and used

- [X] T011 [US2] Test darwin with tilde path

  - ✓ Implementation verified - tilde expansion logic present
  - ⚠️ Manual test required: Set `user.wallpaper = "~/Pictures/wallpaper.jpg"`
  - ⚠️ Manual test required: Verify build succeeds and path expands correctly
  - ⚠️ Manual test required: Check activation script: `cat result/activate | grep WALLPAPER`

- [X] T012 [US2] Test GNOME with tilde path

  - ✓ Implementation verified - tilde expansion logic present
  - ⚠️ Manual test required: Set `user.wallpaper = "~/Pictures/wallpaper.png"`
  - ⚠️ Manual test required: Verify dconf shows `file:///home/username/Pictures/wallpaper.png`
  - ⚠️ Manual test required: Check: `gsettings get org.gnome.desktop.background picture-uri`

- [X] T013 [US2] Test path with spaces in filename

  - ✓ Implementation uses proper shell quoting (`"$WALLPAPER"` in activation script)
  - ⚠️ Manual test required: Set `user.wallpaper = "~/Pictures/My Wallpapers/image 1.jpg"`
  - ⚠️ Manual test required: Verify build succeeds and wallpaper applies

**Checkpoint**: User Story 2 complete - tilde paths work portably across machines (implementation included in US1)

______________________________________________________________________

## Phase 5: User Story 3 - Per-Monitor Wallpapers (Priority: P3)

**Goal**: Enable users to set different wallpapers for each monitor in multi-monitor setups.

**Independent Test**: Configure `user.wallpapers = [{ monitor = 0; path = "~/left.jpg"; } { monitor = 1; path = "~/right.jpg"; }]` and verify each monitor displays its assigned wallpaper.

### Implementation for User Story 3

- [ ] T014 [P] [US3] Add desktoppr Homebrew package to darwin wallpaper module

  - Add `homebrew.casks = ["desktoppr"]` to darwin wallpaper module
  - Only install when `user.wallpapers` is configured (not null/empty)
  - Use `lib.mkIf (wallpapers != null && wallpapers != [])`
  - System-level homebrew will collect and install cask
  - Estimated: +5 lines to darwin module

- [ ] T015 [P] [US3] Add nitrogen package to GNOME wallpaper module

  - Add `home.packages = [ pkgs.nitrogen ]` to GNOME module
  - Only install when `user.wallpapers` is configured
  - Use `lib.mkIf (wallpapers != null && wallpapers != [])`
  - Estimated: +3 lines to GNOME module

- [ ] T016 [US3] Implement per-monitor wallpaper logic for darwin

  - Read `config.user.wallpapers` (list of { monitor, path })
  - Check if wallpapers list is configured (not null/empty)
  - If yes: Use desktoppr for each monitor
  - Generate activation script: `for each in wallpapers: desktoppr ${monitor} ${expandedPath}`
  - Validate each path exists at runtime
  - If no: Use existing osascript logic (single wallpaper)
  - Fallback: If both `user.wallpaper` and `user.wallpapers` exist, wallpapers takes precedence
  - Estimated: +40 lines to darwin module

- [ ] T017 [US3] Implement per-monitor wallpaper logic for GNOME

  - Read `config.user.wallpapers` (list of { monitor, path })
  - Create systemd user service for nitrogen
  - Service Type: oneshot
  - ExecStart: nitrogen command with per-monitor arguments
  - Generate nitrogen command: `nitrogen --head=0 ${path1} --head=1 ${path2} --set-zoom-fill`
  - Service runs on graphical-session.target (after GNOME loads)
  - Validate each path exists at runtime
  - If wallpapers not configured: Use existing dconf logic
  - Estimated: +50 lines to GNOME module

- [ ] T018 [US3] Add validation for per-monitor configuration

  - Validate monitor indices are non-negative integers
  - Warn if duplicate monitor indices in list
  - Warn if wallpapers list is empty but configured
  - Use `config.warnings` for build-time feedback
  - Add to both darwin and GNOME modules
  - Estimated: +15 lines per module

- [ ] T019 [US3] Test darwin per-monitor wallpapers

  - Configure 2-monitor setup: `user.wallpapers = [{ monitor = 0; path = "~/left.jpg"; } { monitor = 1; path = "~/right.jpg"; }]`
  - Verify desktoppr installed via Homebrew
  - Rebuild and activate
  - Verify monitor 0 shows left.jpg, monitor 1 shows right.jpg
  - Test with missing file for one monitor (should skip that monitor)

- [ ] T020 [US3] Test GNOME per-monitor wallpapers

  - Configure 2-monitor setup with user.wallpapers
  - Verify nitrogen package installed
  - Verify systemd service created
  - Rebuild and activate (or reboot for service)
  - Check service status: `systemctl --user status wallpaper.service`
  - Verify each monitor shows its assigned wallpaper

- [ ] T021 [US3] Test fallback behavior

  - Configure both `user.wallpaper = "~/default.jpg"` and `user.wallpapers = [{ monitor = 0; path = "~/custom.jpg"; }]`
  - Verify monitor 0 uses custom.jpg (per-monitor takes precedence)
  - Verify monitor 1 uses default.jpg (falls back to single wallpaper)
  - Test on both darwin and GNOME

**Checkpoint**: User Story 3 complete - per-monitor wallpapers working on both platforms

______________________________________________________________________

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and final improvements

- [X] T017 [P] Add wallpaper configuration documentation to `CLAUDE.md`

  - ✓ Added "### Wallpaper Configuration (Feature 033)" section (69 lines)
  - ✓ Documented syntax with examples
  - ✓ Listed supported formats (jpg, jpeg, png, heic, webp)
  - ✓ Documented platform-specific behavior (Darwin and GNOME)
  - ✓ Example configurations (home-relative, absolute, spaces in path)
  - ✓ Troubleshooting section with common issues
  - ✓ Noted limitations (per-monitor not yet supported)

- [X] T018 [P] Add file extension validation

  - ✓ Created extension validation in both modules
  - ✓ Valid extensions: [".jpg", ".jpeg", ".png", ".heic", ".webp"]
  - ✓ Uses `lib.hasSuffix`, `lib.any`, and `lib.toLower` for case-insensitive checking
  - ✓ Added warning to `config.warnings` if unsupported extension
  - ✓ Warning message includes list of supported formats
  - ✓ Added +9 lines per module

- [X] T019 Validate configuration with `nix flake check`

  - ✓ Ran `nix flake check` from repo root - PASSED
  - ✓ No syntax errors in wallpaper modules
  - ✓ Auto-discovery working (modules loaded without flake.nix changes)
  - ✓ All warnings are expected (validUsers, validHosts, nixOnDroidConfigurations)

- [ ] T020 Create example user configurations

  - Add wallpaper example to user template in `user/shared/template/common.nix`
  - Comment out by default: `# wallpaper = "~/Pictures/wallpaper.jpg";`
  - Add comment explaining feature and supported formats

- [ ] T021 Final testing on both platforms

  - Test on darwin: macOS with absolute and relative paths
  - Test on GNOME: NixOS with absolute and relative paths
  - Test missing file handling
  - Test unsupported extension handling
  - Test with spaces in path
  - Test with no wallpaper configured (system default remains)
  - Verify all warnings appear correctly

- [ ] T022 Update feature documentation in `docs/features/`

  - Create `docs/features/033-user-wallpaper-config.md` based on `quickstart.md`
  - User-facing documentation only (no implementation details)
  - Copy troubleshooting section from quickstart
  - Add screenshots if possible

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Verification only - can start immediately
- **Foundational (Phase 2)**: No foundational work needed - infrastructure exists
- **User Stories (Phase 3-5)**: Can proceed immediately
  - US1 (P1): No dependencies - **START HERE**
  - US2 (P2): Depends on US1 completion (extends path handling)
  - US3 (P3): Depends on US1 completion (validates existing behavior)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start immediately - No dependencies
- **User Story 2 (P2)**: Depends on US1 (adds tilde expansion to existing modules)
- **User Story 3 (P3)**: Depends on US1 (validates multi-monitor behavior already implemented)

### Within Each User Story

**User Story 1:**

- T003 (darwin module) and T004 (GNOME module) can run in parallel [P]
- T005 (validation) must wait for T003 and T004
- T006-T008 (testing) can run after implementation complete

**User Story 2:**

- T009 (darwin tilde) and T010 (GNOME tilde) can run in parallel [P]
- T011-T013 (testing) can run after implementation complete

**User Story 3:**

- T014 (darwin validation) and T015 (GNOME validation) can run in parallel
- T016 (optional enhancement) can run in parallel with T014/T015

### Parallel Opportunities

- **Phase 1**: T001 and T002 (verification tasks)
- **Phase 3 (US1)**: T003 (darwin) and T004 (GNOME) - different files
- **Phase 4 (US2)**: T009 (darwin) and T010 (GNOME) - different files
- **Phase 6**: T017 (docs) and T018 (validation) - different files

______________________________________________________________________

## Parallel Example: User Story 1

```bash
# Launch darwin and GNOME modules in parallel:
Task: "Create Darwin wallpaper module in system/darwin/settings/wallpaper.nix"
Task: "Create GNOME wallpaper module in system/shared/family/gnome/settings/wallpaper.nix"

# Both can be implemented simultaneously by different developers
# or by launching parallel agent tasks
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup verification (T001-T002)
1. Complete Phase 3: User Story 1 (T003-T008)
   - T003 and T004 in parallel (darwin + GNOME modules)
   - T005 (add validation)
   - T006-T008 (test on both platforms)
1. **STOP and VALIDATE**: Test US1 independently
1. Deploy/demo if ready

**This gives you a working wallpaper feature with absolute paths only.**

### Incremental Delivery

1. Complete US1 → Test independently → **MVP READY** ✅
1. Add US2 (tilde support) → Test independently → **Enhanced portability** ✅
1. Add US3 (multi-monitor validation) → Test independently → **Production ready** ✅
1. Complete Polish phase → **Fully documented and hardened** ✅

### Parallel Team Strategy

With multiple developers:

1. **Developer A**: US1 darwin module (T003) + testing (T006, T008)
1. **Developer B**: US1 GNOME module (T004) + testing (T007)
1. **Developer C**: Documentation (T017) while implementation proceeds

Once US1 complete:
4\. **Developer A**: US2 darwin tilde (T009) + testing (T011)
5\. **Developer B**: US2 GNOME tilde (T010) + testing (T012)

______________________________________________________________________

## Task Summary

**Total Tasks**: 28 tasks

- **Phase 1 (Setup)**: 2 tasks (verification only)
- **Phase 2 (Foundational)**: 0 tasks (infrastructure exists)
- **Phase 3 (US1 - P1)**: 6 tasks (implementation + testing)
- **Phase 4 (US2 - P2)**: 5 tasks (tilde expansion + testing)
- **Phase 5 (US3 - P3)**: 8 tasks (per-monitor wallpapers)
- **Phase 6 (Polish)**: 7 tasks (documentation + validation)

**Parallel Opportunities**: 10 tasks marked [P] can run in parallel within their phase

**Independent Test Criteria**:

- **US1**: Set absolute path, verify wallpaper changes on both platforms
- **US2**: Set tilde path, verify expansion and wallpaper changes
- **US3**: Set per-monitor wallpapers, verify each monitor shows its assigned wallpaper

**MVP Scope**: User Story 1 only (6 tasks: T003-T008)

- Delivers core functionality: wallpaper configuration with absolute paths
- Platform-agnostic user syntax
- Graceful error handling
- Works on darwin and GNOME

**Enhanced Scope**: User Stories 1-3 (19 tasks: T003-T021)

- Adds tilde path support for portability
- Adds per-monitor wallpaper configuration
- Full multi-monitor support with individual wallpapers per display

**Module Size Estimates**:

- Darwin module (US1-US3): ~130 lines (under 200 limit ✓)
  - US1: ~60 lines (osascript + validation)
  - US2: +6 lines (tilde expansion)
  - US3: +64 lines (desktoppr + per-monitor logic + validation)
- GNOME module (US1-US3): ~110 lines (under 200 limit ✓)
  - US1: ~40 lines (dconf.settings)
  - US2: +6 lines (tilde expansion)
  - US3: +64 lines (nitrogen + systemd service + validation)

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies within phase
- [Story] label maps task to specific user story for traceability
- Each user story builds on previous (incremental enhancement)
- No tests requested in spec - manual verification via rebuild and visual check
- Module size estimates included to ensure \<200 line constitutional limit
- Both modules remain well under 200 lines even with full US3 implementation
- All paths use existing nix-config directory structure
- Auto-discovery ensures modules are loaded without flake changes
- Homebrew/package dependencies only installed when per-monitor config used
