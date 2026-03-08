# Tasks: Darwin System Defaults Restructuring and Migration

**Input**: Design documents from `/specs/002-darwin-system-restructure/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: No automated tests requested for this feature (configuration management)
**Organization**: Tasks grouped by user story for independent implementation

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

Configuration management project with Nix modules under `modules/darwin/` and documentation under `specs/002-darwin-system-restructure/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and branch setup

- [ ] T001 Verify current branch is 002-darwin-system-restructure
- [ ] T002 Capture baseline system state with `defaults read > /tmp/before-restructure.txt`
- [ ] T003 Create modules/darwin/system/ directory structure
- [ ] T004 [P] Create specs/002-darwin-system-restructure/unresolved-migration.md file
- [ ] T005 [P] Create specs/002-darwin-system-restructure/deprecated-settings.md file

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core restructuring that MUST complete before migration

**⚠️ CRITICAL**: No migration work can begin until restructuring is complete

- [ ] T006 Read current modules/darwin/defaults.nix and analyze existing settings
- [ ] T007 Create modules/darwin/system/default.nix as module aggregator (imports all topic modules)
- [ ] T008 Update modules/darwin/defaults.nix to become import-only (remove settings, add `imports = [ ./system ];`)
- [ ] T009 Validate syntax with `nix flake check`

**Checkpoint**: Foundation ready - topic module creation can begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Restructure Darwin System Defaults (Priority: P1) 🎯 MVP

**Goal**: Reorganize existing system defaults from monolithic defaults.nix into topic-specific modules under system/ folder

**Independent Test**: Run `darwin-rebuild build` and verify all existing settings still apply correctly without adding new configurations. Compare system state before/after with `defaults read`.

### Implementation for User Story 1

**Create Topic Modules** (all parallelizable - different files):

- [ ] T010 [P] [US1] Create modules/darwin/system/dock.nix with Dock settings from defaults.nix
- [ ] T011 [P] [US1] Create modules/darwin/system/finder.nix with Finder settings from defaults.nix
- [ ] T012 [P] [US1] Create modules/darwin/system/trackpad.nix with trackpad settings from defaults.nix
- [ ] T013 [P] [US1] Create modules/darwin/system/keyboard.nix with system-wide keyboard settings from defaults.nix (NSGlobalDomain KeyRepeat, InitialKeyRepeat)
- [ ] T014 [P] [US1] Create modules/darwin/system/screen.nix with screencapture settings from defaults.nix
- [ ] T015 [P] [US1] Create modules/darwin/system/security.nix (empty initially, placeholder for US2)
- [ ] T016 [P] [US1] Create modules/darwin/system/network.nix (empty initially, placeholder for US2)
- [ ] T017 [P] [US1] Create modules/darwin/system/power.nix (empty initially, placeholder for US2)
- [ ] T018 [P] [US1] Create modules/darwin/system/ui.nix with NSGlobalDomain visual settings from defaults.nix (AppleInterfaceStyle, AppleShowScrollBars, NSNav/PMPrinting expand states)
- [ ] T019 [P] [US1] Create modules/darwin/system/accessibility.nix (empty initially, placeholder for US2)
- [ ] T020 [P] [US1] Create modules/darwin/system/applications.nix with CustomUserPreferences from defaults.nix
- [ ] T021 [P] [US1] Create modules/darwin/system/system.nix with NSGlobalDomain system-wide settings from defaults.nix (automatic substitution settings)

**Documentation** (parallelizable with implementation):

- [ ] T022 [P] [US1] Add header documentation to each topic module explaining purpose, options, examples
- [ ] T023 [P] [US1] Verify each module is under 200 lines per constitutional requirement

**Validation**:

- [ ] T024 [US1] Update system/default.nix imports list to include all 12 topic modules
- [ ] T025 [US1] Run `nix flake check` to validate syntax
- [ ] T026 [US1] Run `darwin-rebuild build --flake .` to verify build succeeds
- [ ] T027 [US1] Capture post-restructure state with `defaults read > /tmp/after-restructure.txt`
- [ ] T028 [US1] Compare before/after with `diff /tmp/before-restructure.txt /tmp/after-restructure.txt` (should be identical except timestamps)
- [ ] T029 [US1] Test apply on darwin host with `darwin-rebuild switch --flake .` (dry-run first)
- [ ] T030 [US1] Verify system behavior: Dock, Finder, trackpad, keyboard all work as before

**Checkpoint**: At this point, restructuring is complete. All existing settings work identically from new modular structure. Ready for migration.

______________________________________________________________________

## Phase 4: User Story 2 - Migrate Dotfiles System Defaults (Priority: P2)

**Goal**: Migrate macOS system defaults from ~/project/dotfiles/scripts/sh/darwin/system.sh to appropriate Nix files

**Independent Test**: Compare system defaults before/after migration using `defaults read` commands. Verify settings from system.sh are now active through Nix configuration.

### Analysis Phase

- [ ] T031 [US2] Read ~/project/dotfiles/scripts/sh/darwin/system.sh and categorize all `defaults write` commands by domain
- [ ] T032 [US2] Identify deprecated settings (e.g., Dashboard-related) and document in deprecated-settings.md
- [ ] T033 [US2] Identify settings requiring sudo or activation scripts and document in unresolved-migration.md
- [ ] T034 [US2] Create migration mapping table: bash command → nix-darwin option → target file

### Migration Implementation (by topic - can be partially parallelized)

**Dock Settings**:

- [ ] T035 [US2] Migrate dock commands from system.sh to modules/darwin/system/dock.nix (disable_recent_apps, highlight, spring loading, indicators, animations, auto-hide, translucent apps, minimize animation, size, Mission Control, Spaces settings)

**Finder Settings**:

- [ ] T036 [US2] Migrate finder commands from system.sh to modules/darwin/system/finder.nix (folders first, quit menu, animations, show files, status bar, path bar, Quick Look, POSIX path, network .DS_Store, extension warning, empty trash, secure trash, list view, search scope, spring loading, Info panes)

**Desktop Settings**:

- [ ] T037 [US2] Migrate desktop hot corner settings to modules/darwin/system/finder.nix (top left Mission Control, top right Desktop, hide external/internal/network/removable media icons)

**Keyboard Settings**:

- [ ] T038 [US2] Migrate keyboard commands to modules/darwin/system/keyboard.nix (full keyboard access, press-and-hold disable, key repeat rate, initial delay, languages, locales, measurement units)

**Trackpad Settings**:

- [ ] T039 [US2] Migrate trackpad commands to modules/darwin/system/trackpad.nix (tap to click globally, corner right-click, trackpad right-click, secondary click)

**Screen/Display Settings**:

- [ ] T040 [US2] Migrate screen commands to modules/darwin/system/screen.nix (font smoothing, screenshot shadow/location/format, HiDPI modes, separate Spaces)

**UI/Visual Settings**:

- [ ] T041 [US2] Migrate visual effects commands to modules/darwin/system/ui.nix (reduce motion, window animations, accent color, menu bar transparency, sidebar icon size, scroll bars, natural scrolling)

**Security Settings**:

- [ ] T042 [US2] Migrate security commands to modules/darwin/system/security.nix (guest account, software update frequency, screen saver password, delay, crash reporter, diagnostic reports, firewall settings)

**Network Settings**:

- [ ] T043 [US2] Migrate network commands to modules/darwin/system/network.nix (AirDrop over Ethernet)

**Power Settings**:

- [ ] T044 [US2] Migrate power commands to modules/darwin/system/power.nix (battery percentage, standby delay)

**System Settings**:

- [ ] T045 [US2] Migrate system-wide commands to modules/darwin/system/system.nix (resume disable, verbose boot, save to disk, smart quotes/dashes disable, text selection in Quick Look, open confirmation dialog, expand save/print panels, window dragging)

**Application-Specific Settings**:

- [ ] T046 [US2] Migrate Activity Monitor settings to modules/darwin/system/applications.nix (show all processes, sort by CPU, refresh frequency)
- [ ] T047 [US2] Migrate Siri settings to modules/darwin/system/applications.nix (disable Siri, hide from menu bar)
- [ ] T048 [US2] Migrate disk utility settings to modules/darwin/system/applications.nix (verification, auto-open, debug menu, advanced options)
- [ ] T049 [US2] Migrate TextEdit settings to modules/darwin/system/applications.nix (plain text mode, UTF-8 encoding)
- [ ] T050 [US2] Migrate Help Viewer settings to modules/darwin/system/applications.nix (dev mode)
- [ ] T051 [US2] Migrate Calculator settings to modules/darwin/system/applications.nix (programmer view, base 10, thousand separator)
- [ ] T052 [US2] Migrate Safari settings to modules/darwin/system/applications.nix (debug menu, develop menu, developer extras, thumbnails, search, inspector, home page, safe downloads, backspace navigation, bookmarks bar, sidebar)
- [ ] T053 [US2] Migrate Mail settings to modules/darwin/system/applications.nix (animations, address format, send shortcut, threaded mode, inline attachments, spell checking)
- [ ] T054 [US2] Migrate Address Book settings to modules/darwin/system/applications.nix (debug menu)
- [ ] T055 [US2] Migrate iCal settings to modules/darwin/system/applications.nix (debug menu)
- [ ] T056 [US2] Migrate Time Machine settings to modules/darwin/system/applications.nix (disable new disk prompts)
- [ ] T057 [US2] Migrate Mac App Store settings to modules/darwin/system/applications.nix (WebKit developer tools, debug menu)
- [ ] T058 [US2] Migrate Messages settings to modules/darwin/system/applications.nix (emoji substitution, smart quotes)
- [ ] T059 [US2] Migrate iTunes settings to modules/darwin/system/applications.nix (Ping disable, search shortcut, media keys) if not deprecated
- [ ] T060 [US2] Migrate Printing settings to modules/darwin/system/applications.nix (quit when finished, expand print panel)

**Spotlight Settings** (special handling):

- [ ] T061 [US2] Analyze Spotlight indexing order command and determine if supported in nix-darwin or document in unresolved-migration.md

**Service Management** (document as unresolved):

- [ ] T062 [US2] Document startup applications (AeroSpace, ProtonVPN, etc.) in unresolved-migration.md as requiring LaunchAgents
- [ ] T063 [US2] Document dock items configuration in unresolved-migration.md as requiring separate management
- [ ] T064 [US2] Document `brew services start borders` in unresolved-migration.md as requiring nix-darwin service configuration

**Procedural Operations** (document as unresolved):

- [ ] T065 [US2] Document `killall` commands in unresolved-migration.md (happen automatically on darwin-rebuild)
- [ ] T066 [US2] Document `mdutil -i on /` in unresolved-migration.md (one-time indexing operation)
- [ ] T067 [US2] Document `chflags nohidden` for Library in unresolved-migration.md (one-time operation)

### Validation

- [ ] T068 [US2] Review unresolved-migration.md and ensure all unsupported settings documented with explanations and alternatives
- [ ] T069 [US2] Review deprecated-settings.md and ensure all skipped settings documented with reasoning
- [ ] T070 [US2] Run `nix flake check` to validate all migrations
- [ ] T071 [US2] Run `darwin-rebuild build --flake .` to verify build succeeds
- [ ] T072 [US2] Test apply on darwin host with `darwin-rebuild switch --flake .`
- [ ] T073 [US2] Run verification script from quickstart.md to check all migrated settings apply correctly
- [ ] T074 [US2] Spot-check key settings with `defaults read` commands (Activity Monitor, Dock, Finder, Safari, etc.)

**Checkpoint**: All applicable settings from system.sh are now migrated. System reflects both original defaults.nix and system.sh configurations.

______________________________________________________________________

## Phase 5: User Story 3 - Establish Standard Module Structure (Priority: P3)

**Goal**: Document the darwin system folder structure as the standard pattern for all module types

**Independent Test**: Review documentation and verify it clearly explains the organizational pattern and how to apply it to new modules

### Documentation

- [ ] T075 [US3] Create architecture decision record in docs/architecture/system-module-organization.md explaining topic-based pattern
- [ ] T076 [US3] Document setting placement rules (application-specific vs system-wide, shortcuts, etc.) in architecture doc
- [ ] T077 [US3] Create examples showing how to apply pattern to nixos modules (future work)
- [ ] T078 [US3] Create examples showing how to apply pattern to nix-on-linux modules (future work)
- [ ] T079 [US3] Update project README.md with link to system module organization pattern

**Checkpoint**: Standard structure is documented and ready for application to other module types in future work.

______________________________________________________________________

## Phase 6: User Story 4 - Update Project Constitution (Priority: P3)

**Goal**: Update constitution with organizational principles derived from this restructuring work

**Independent Test**: Review constitution document and verify it contains principles about module organization, file structure, and configuration management

### Constitution Updates

- [ ] T080 [US4] Add principle to .specify/memory/constitution.md: "System defaults MUST be organized by topic domain in separate modules"
- [ ] T081 [US4] Add principle to .specify/memory/constitution.md: "Application-specific settings belong to application modules, not input mechanism modules"
- [ ] T082 [US4] Add principle to .specify/memory/constitution.md: "Module aggregators (default.nix) MUST be import-only with no setting definitions"
- [ ] T083 [US4] Add principle to .specify/memory/constitution.md: "Migration from imperative scripts MUST focus on intent, not literal translation"
- [ ] T084 [US4] Add principle to .specify/memory/constitution.md: "Unsupported migrations MUST be documented in unresolved-migration.md with alternatives"
- [ ] T085 [US4] Add example to constitution showing darwin/system/ structure as reference pattern
- [ ] T086 [US4] Update constitution version to 1.7.0 with MINOR bump and amendment date
- [ ] T087 [US4] Add SYNC IMPACT REPORT to constitution documenting module organization principles

**Checkpoint**: Constitution updated with all derived organizational principles.

______________________________________________________________________

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, validation, and final cleanup

- [ ] T088 [P] Create user-facing feature summary in docs/features/002-darwin-system-restructure.md explaining what was restructured and how to add new settings
- [ ] T089 [P] Update docs/features/002-darwin-system-restructure.md with links to unresolved-migration.md and deprecated-settings.md
- [ ] T090 [P] Add migration verification script from quickstart.md to repository as scripts/verify-darwin-migration.sh
- [ ] T091 Verify all topic modules have header documentation with purpose, options, examples
- [ ] T092 Verify each module is under 200 lines (split if necessary)
- [ ] T093 Run full quickstart.md validation checklist (pre-migration, post-restructure, post-migration, regression)
- [ ] T094 Test configuration on all darwin hosts (work-macbook, home-macmini, darwin-dev)
- [ ] T095 Document rollback procedure in quickstart.md
- [ ] T096 Final `darwin-rebuild switch --flake .` on all darwin hosts

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational completion - No dependencies on other stories
- **User Story 2 (Phase 4)**: Depends on US1 completion (needs restructured modules to migrate into)
- **User Story 3 (Phase 5)**: Depends on US1 completion (needs structure to document) - Can run in parallel with US2
- **User Story 4 (Phase 6)**: Depends on US1 completion (needs patterns to codify) - Can run in parallel with US2 and US3
- **Polish (Phase 7)**: Depends on desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: BLOCKING for US2 - restructuring must complete before migration
- **User Story 2 (P2)**: Depends on US1 - migrates settings into restructured modules
- **User Story 3 (P3)**: Depends on US1 - documents the structure created by US1, can run parallel with US2
- **User Story 4 (P3)**: Depends on US1 - codifies patterns from US1, can run parallel with US2 and US3

### Within Each User Story

**User Story 1**:

- T010-T021 (module creation) can all run in parallel - different files
- T022-T023 (documentation) can run in parallel with implementation
- T024-T030 (validation) must run sequentially after implementation

**User Story 2**:

- T031-T034 (analysis) must run first sequentially
- T035-T060 (migration by topic) can run mostly in parallel - different files, some logical grouping recommended
- T061-T067 (unresolved documentation) can run in parallel
- T068-T074 (validation) must run sequentially after implementation

**User Story 3**:

- T075-T079 (documentation) can run mostly in parallel

**User Story 4**:

- T080-T085 (constitution updates) should run sequentially to avoid merge conflicts
- T086-T087 (versioning) must run last

### Parallel Opportunities

- **Phase 1**: T004-T005 can run in parallel
- **Phase 3**: T010-T021 all parallel (12 modules), T022-T023 parallel with each other and with implementation
- **Phase 4**: T035-T060 largely parallel (by topic domain), T061-T067 parallel
- **Phase 5**: T075-T079 mostly parallel
- **Phase 7**: T088-T090 parallel, T094 can test hosts in parallel

______________________________________________________________________

## Parallel Example: User Story 1

```bash
# Launch all module creation tasks together:
Task: "Create modules/darwin/system/dock.nix"
Task: "Create modules/darwin/system/finder.nix"
Task: "Create modules/darwin/system/trackpad.nix"
Task: "Create modules/darwin/system/keyboard.nix"
Task: "Create modules/darwin/system/screen.nix"
Task: "Create modules/darwin/system/security.nix"
Task: "Create modules/darwin/system/network.nix"
Task: "Create modules/darwin/system/power.nix"
Task: "Create modules/darwin/system/ui.nix"
Task: "Create modules/darwin/system/accessibility.nix"
Task: "Create modules/darwin/system/applications.nix"
Task: "Create modules/darwin/system/system.nix"

# While modules are being created, launch documentation tasks:
Task: "Add header documentation to each topic module"
Task: "Verify each module is under 200 lines"
```

______________________________________________________________________

## Parallel Example: User Story 2

```bash
# After analysis complete, launch migration tasks by topic (can be done in waves):

# Wave 1: Core UI components
Task: "Migrate dock commands to dock.nix"
Task: "Migrate finder commands to finder.nix"
Task: "Migrate desktop hot corner settings to finder.nix"

# Wave 2: Input devices
Task: "Migrate keyboard commands to keyboard.nix"
Task: "Migrate trackpad commands to trackpad.nix"

# Wave 3: Display and system
Task: "Migrate screen commands to screen.nix"
Task: "Migrate UI/visual commands to ui.nix"
Task: "Migrate system-wide commands to system.nix"

# Wave 4: Security and power
Task: "Migrate security commands to security.nix"
Task: "Migrate network commands to network.nix"
Task: "Migrate power commands to power.nix"

# Wave 5: Applications (can all run in parallel - different sections of same file)
Task: "Migrate Activity Monitor settings"
Task: "Migrate Safari settings"
Task: "Migrate Mail settings"
# ... etc for all applications

# Parallel with implementation: Document unresolved items
Task: "Document startup applications in unresolved-migration.md"
Task: "Document dock items in unresolved-migration.md"
Task: "Document procedural operations in unresolved-migration.md"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
1. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
1. Complete Phase 3: User Story 1
1. **STOP and VALIDATE**: Test restructured configuration independently
1. Deploy to darwin hosts if validation passes

**MVP Delivered**: Existing system defaults now organized in maintainable topic-based modules. Zero functional changes, purely structural improvement.

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
1. Add User Story 1 → Test independently → Deploy (MVP!)
   - **Value**: Improved maintainability, clearer organization, easier to find settings
1. Add User Story 2 → Test independently → Deploy
   - **Value**: Comprehensive system configuration, migration from dotfiles complete
1. Add User Story 3 + 4 in parallel → Document and codify
   - **Value**: Reusable pattern, constitutional backing, future-proofed

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
1. Once Foundational done:
   - Team completes User Story 1 together (many parallel tasks T010-T021)
1. Once US1 done:
   - Developer A: User Story 2 (migration implementation)
   - Developer B: User Story 3 (documentation)
   - Developer C: User Story 4 (constitution)
1. All converge for Phase 7: Polish

______________________________________________________________________

## Task Count Summary

- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 4 tasks
- **Phase 3 (User Story 1)**: 21 tasks (12 parallelizable)
- **Phase 4 (User Story 2)**: 44 tasks (many parallelizable)
- **Phase 5 (User Story 3)**: 5 tasks (mostly parallelizable)
- **Phase 6 (User Story 4)**: 8 tasks (mostly sequential)
- **Phase 7 (Polish)**: 9 tasks (some parallelizable)

**Total**: 96 tasks

- **Parallelizable**: ~40 tasks marked [P]
- **User Story 1**: 21 tasks
- **User Story 2**: 44 tasks
- **User Story 3**: 5 tasks
- **User Story 4**: 8 tasks
- **Setup/Infrastructure**: 18 tasks

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies within same phase
- [Story] label maps task to specific user story for traceability
- User Story 1 BLOCKS User Story 2 (restructuring must complete before migration)
- User Stories 3 and 4 can run in parallel with US2 after US1 completes
- Each validation checkpoint ensures story works independently
- Commit after each logical group of tasks
- Test incrementally, don't wait until end
- Use quickstart.md for detailed testing procedures
