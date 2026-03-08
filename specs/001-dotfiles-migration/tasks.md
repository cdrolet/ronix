# Tasks: Dotfiles to Nix Configuration Migration

**Input**: Design documents from `/specs/001-dotfiles-migration/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are NOT requested in the feature specification. This is an infrastructure migration, not application code.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

All paths are relative to repository root: `/Users/charles/project/nix-config/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic Nix structure

- [ ] T001 Create root flake.nix with inputs (nixpkgs, nix-darwin, home-manager, sops-nix) per contracts/flake-schema.md
- [ ] T002 [P] Create .envrc file with `use flake` for direnv integration
- [ ] T003 [P] Create justfile with install, update, check, and format commands
- [ ] T004 [P] Create .gitignore for Nix-specific files (result, .direnv/)
- [ ] T005 Initialize flake.lock with `nix flake lock`
- [ ] T006 Create directory structure: hosts/, modules/darwin/, modules/nixos/, modules/shared/, home/, profiles/, overlays/, secrets/
- [ ] T007 [P] Create .sops.yaml configuration for secrets management in secrets/.sops.yaml
- [ ] T008 [P] Create README.md with project overview and quick links to quickstart.md

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core modules and configurations that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T009 Create core Nix daemon module in modules/shared/nix.nix (flakes, gc, settings)
- [ ] T010 [P] Create core fonts module in modules/shared/fonts.nix (Nerd Fonts, FiraCode)
- [ ] T011 [P] Create core users module in modules/shared/users.nix (user account creation)
- [ ] T012 Create Home Manager user base configuration in home/default.nix per contracts/home-manager-schema.md
- [ ] T013 [P] Create home packages list in home/packages.nix (CLI tools: zoxide, ripgrep, fd, bat, eza, delta, procs, xh, helix, lazygit)
- [ ] T014 Create modular zsh configuration structure in home/programs/zsh/ (default.nix as aggregator)
- [ ] T015 [P] Migrate zsh module 10.environment in home/programs/zsh/environment.nix (PATH, EDITOR, environment vars)
- [ ] T016 [P] Migrate zsh module 40.completion in home/programs/zsh/completion.nix
- [ ] T017 [P] Migrate zsh module 50.tools in home/programs/zsh/tools.nix (tool initialization: zoxide, atuin)
- [ ] T018 [P] Migrate zsh module 55.directory in home/programs/zsh/directory.nix (directory navigation)
- [ ] T019 [P] Migrate zsh module 60.syntax in home/programs/zsh/syntax.nix (syntax highlighting)
- [ ] T020 [P] Migrate zsh module 62.history in home/programs/zsh/history.nix
- [ ] T021 [P] Migrate zsh module 64.editor in home/programs/zsh/editor.nix (editor bindings)
- [ ] T022 [P] Migrate zsh module 66.suggestions in home/programs/zsh/suggestions.nix (auto-suggestions)
- [ ] T023 [P] Migrate zsh module 80.os in home/programs/zsh/os.nix (platform-specific configs)
- [ ] T024 Wire all zsh modules together in home/programs/zsh/default.nix

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

______________________________________________________________________

## Phase 3: User Story 1 - Initial System Setup from Scratch (Priority: P1) 🎯 MVP

**Goal**: User can run single installation command on fresh macOS or NixOS and get complete dev environment

**Independent Test**: Run install script on fresh VM, verify all tools/configs present, shell starts \<200ms

### Implementation for User Story 1

#### macOS Installation (T025-T037)

- [ ] T025 [P] [US1] Create install.sh script that installs Determinate Systems Nix installer and builds darwin config
- [ ] T026 [P] [US1] Create macOS system defaults module in modules/darwin/defaults.nix (dock, finder, keyboard settings)
- [ ] T027 [P] [US1] Create work-macbook host config in hosts/work-macbook/default.nix
- [ ] T028 [P] [US1] Create work-macbook hardware config in hosts/work-macbook/hardware-configuration.nix
- [ ] T029 [P] [US1] Create work-macbook darwin config in hosts/work-macbook/configuration.nix
- [ ] T030 [P] [US1] Create home-macmini host config in hosts/home-macmini/default.nix
- [ ] T031 [P] [US1] Create home-macmini hardware config in hosts/home-macmini/hardware-configuration.nix
- [ ] T032 [P] [US1] Create home-macmini darwin config in hosts/home-macmini/configuration.nix
- [ ] T033 [P] [US1] Create darwin-dev host config in hosts/darwin-dev/default.nix
- [ ] T034 [P] [US1] Create darwin-dev hardware config in hosts/darwin-dev/hardware-configuration.nix
- [ ] T035 [P] [US1] Create darwin-dev darwin config in hosts/darwin-dev/configuration.nix
- [ ] T036 [US1] Add darwinConfigurations for all darwin hosts to flake.nix outputs
- [ ] T037 [US1] Test install.sh on fresh macOS VM, verify all packages and configs applied

#### NixOS Installation (T038-T043)

- [ ] T038 [P] [US1] Create nixos-dev host config in hosts/nixos-dev/default.nix
- [ ] T039 [P] [US1] Create nixos-dev hardware config in hosts/nixos-dev/hardware-configuration.nix
- [ ] T040 [P] [US1] Create nixos-dev system config in hosts/nixos-dev/configuration.nix
- [ ] T041 [P] [US1] Create NixOS desktop module in modules/nixos/desktop.nix (X11/Wayland, display manager)
- [ ] T042 [US1] Add nixosConfigurations.nixos-dev to flake.nix outputs
- [ ] T043 [US1] Test NixOS rebuild on fresh NixOS VM, verify all packages and configs applied

#### Program Configurations (T044-T051)

- [ ] T044 [P] [US1] Create git configuration in home/programs/git.nix (userName, userEmail, aliases, delta)
- [ ] T045 [P] [US1] Create starship configuration in home/programs/starship.nix
- [ ] T046 [P] [US1] Create atuin configuration in home/programs/atuin.nix
- [ ] T047 [P] [US1] Create helix configuration in home/programs/helix.nix
- [ ] T048 [P] [US1] Create lazygit configuration in home/programs/lazygit.nix
- [ ] T049 [P] [US1] Create bat configuration in home/programs/bat.nix
- [ ] T050 [P] [US1] Create shell aliases in home/shell/aliases.nix
- [ ] T051 [US1] Import all program configs in home/default.nix

#### Profiles (T052-T056)

- [ ] T052 [P] [US1] Create work-restricted profile in profiles/work-restricted/default.nix (kitty only, no ghostty/aerospace)
- [ ] T053 [P] [US1] Create personal profile in profiles/personal/default.nix (all apps including ghostty, aerospace, borders)
- [ ] T054 [P] [US1] Create development profile in profiles/development/default.nix (languages, tools, editors)
- [ ] T055 [P] [US1] Create server profile in profiles/server/default.nix (minimal)
- [ ] T056 [US1] Configure hosts to import appropriate profiles (work-macbook→work-restricted, home-macmini→personal+development)

#### Platform-Specific Apps (T057-T061)

- [ ] T057 [P] [US1] Create kitty module in modules/darwin/kitty.nix (for work-macbook)
- [ ] T058 [P] [US1] Create ghostty configuration in home/programs/ghostty.nix (for unrestricted hosts)
- [ ] T059 [P] [US1] Create aerospace module in modules/darwin/aerospace.nix (for unrestricted macOS hosts)
- [ ] T060 [P] [US1] Create borders module in modules/darwin/borders.nix (for unrestricted macOS hosts)
- [ ] T061 [US1] Add conditional imports for platform-specific apps in host configs

#### Development Languages (T062-T066)

- [ ] T062 [P] [US1] Add Node.js to development profile in profiles/development/languages.nix
- [ ] T063 [P] [US1] Add Python to development profile in profiles/development/languages.nix
- [ ] T064 [P] [US1] Add Go to development profile in profiles/development/languages.nix
- [ ] T065 [P] [US1] Add Rust to development profile in profiles/development/languages.nix
- [ ] T066 [P] [US1] Add Ruby to development profile in profiles/development/languages.nix

#### Validation (T067)

- [ ] T067 [US1] Run quickstart.md installation scenarios on both macOS and NixOS, verify SC-001, SC-002, SC-003, SC-007

**Checkpoint**: At this point, User Story 1 should be fully functional - fresh system installs work on both platforms

______________________________________________________________________

## Phase 4: User Story 4 - System Rollback and Recovery (Priority: P2)

**Goal**: User can quickly rollback to previous working configuration after breaking change

**Independent Test**: Apply breaking change, rollback to previous generation, verify system works

**Note**: Rollback is enabled by default in Nix/NixOS, but we add documentation and convenience commands

### Implementation for User Story 4

- [ ] T068 [P] [US4] Add rollback command to justfile: `just rollback`
- [ ] T069 [P] [US4] Add list-generations command to justfile: `just generations`
- [ ] T070 [P] [US4] Document rollback procedures in quickstart.md (already exists, verify completeness)
- [ ] T071 [P] [US4] Add generation cleanup to justfile: `just clean-old <days>`
- [ ] T072 [US4] Configure automatic garbage collection in modules/shared/nix.nix (delete-older-than 30d)
- [ ] T073 [US4] Test rollback scenario: apply breaking config, rollback, verify system restored (verify SC-006)

**Checkpoint**: Rollback capability is documented and tested

______________________________________________________________________

## Phase 5: User Story 2 - Configuration Updates and Synchronization (Priority: P2)

**Goal**: User can modify config files, apply changes across machines, handle build failures gracefully

**Independent Test**: Modify config file, run update command, verify changes applied without breaking system

### Implementation for User Story 2

- [ ] T074 [P] [US2] Add update command to justfile: `just update` (runs nix flake update)
- [ ] T075 [P] [US2] Add build command to justfile: `just build` (test without applying)
- [ ] T076 [P] [US2] Add switch command to justfile: `just switch` (apply config changes)
- [ ] T077 [P] [US2] Add check command to justfile: `just check` (runs nix flake check)
- [ ] T078 [P] [US2] Document update workflow in quickstart.md (already exists, verify)
- [ ] T079 [P] [US2] Create pre-commit hook template for nix fmt check (optional, for users who want it)
- [ ] T080 [US2] Test update scenario: modify package list, run build, run switch, verify changes applied (verify SC-004)
- [ ] T081 [US2] Test error handling: introduce syntax error, verify clear error message (verify SC-012)

**Checkpoint**: Configuration update workflow is smooth and well-documented

______________________________________________________________________

## Phase 6: User Story 3 - Cross-Platform Configuration Management (Priority: P3)

**Goal**: Same config repository works on both macOS and NixOS, platform-specific features work correctly

**Independent Test**: Build same repo on macOS and NixOS, verify platform-specific modules applied correctly

### Implementation for User Story 3

- [ ] T082 [P] [US3] Add pkgs.stdenv.isDarwin guards to all darwin-specific modules
- [ ] T083 [P] [US3] Add pkgs.stdenv.isLinux guards to all nixos-specific modules
- [ ] T084 [P] [US3] Create cross-platform test in justfile: `just test-platforms`
- [ ] T085 [P] [US3] Document platform-specific features in README.md (which modules are darwin-only, linux-only)
- [ ] T086 [US3] Verify shared configs work on both platforms (git, zsh, helix, etc.)
- [ ] T087 [US3] Verify platform-specific configs are skipped gracefully on wrong platform
- [ ] T088 [US3] Test macOS build includes aerospace/borders, NixOS build skips them (verify SC-005, FR-034)

**Checkpoint**: Cross-platform config management works seamlessly

______________________________________________________________________

## Phase 7: Nix-on-Linux Support - Kali Pentest VM (Priority: P3)

**Goal**: Support Kali Linux VM with Home Manager only (no system modules)

**Independent Test**: Install Nix on Kali, apply homeConfiguration, verify terminal environment works

### Implementation for Nix-on-Linux

- [ ] T089 [P] Create kali-pentest host config in hosts/kali-pentest/default.nix (Home Manager only)
- [ ] T090 [P] Create kali-pentest home config in hosts/kali-pentest/home.nix
- [ ] T091 [P] Create pentest profile in profiles/pentest/default.nix
- [ ] T092 [P] Add pentest tools to profiles/pentest/tools.nix (CLI security tools available in nixpkgs)
- [ ] T093 Add homeConfigurations.kali-pentest to flake.nix outputs
- [ ] T094 Document Kali installation in quickstart.md (install Nix, apply home-manager config)
- [ ] T095 Test on Kali VM: install Nix, apply home config, verify terminal environment

**Checkpoint**: Kali Linux VM with Nix-on-Linux works

______________________________________________________________________

## Phase 8: Nix-on-Droid Support - GrapheneOS Pixel Phone (Priority: P3)

**Goal**: Support GrapheneOS Pixel with Nix-on-Droid for terminal environment

**Independent Test**: Install Nix-on-Droid app, apply config, verify terminal tools work

### Implementation for Nix-on-Droid

- [ ] T096 [P] Create pixel-phone host config in hosts/pixel-phone/default.nix (Nix-on-Droid config)
- [ ] T097 [P] Create pixel-phone home config in hosts/pixel-phone/home.nix
- [ ] T098 [P] Create mobile profile in profiles/mobile/default.nix
- [ ] T099 [P] Add mobile-optimized CLI tools to profiles/mobile/terminal.nix (smaller packages, touch-friendly)
- [ ] T100 Add nixOnDroidConfigurations.pixel-phone to flake.nix outputs
- [ ] T101 Document Android installation in quickstart.md (install from F-Droid, clone repo, apply config)
- [ ] T102 Test on Android device: install Nix-on-Droid, apply config, verify terminal environment

**Checkpoint**: GrapheneOS Pixel with Nix-on-Droid works

______________________________________________________________________

## Phase 9: Secrets Management (Priority: P2)

**Goal**: Encrypted secrets stored in repo, decrypted at runtime

**Independent Test**: Add secret, encrypt with sops, reference in module, verify decrypted correctly

### Implementation for Secrets

- [ ] T103 [P] Create age key generation instructions in secrets/README.md
- [ ] T104 [P] Create example secrets file in secrets/work/secrets.yaml (encrypted)
- [ ] T105 [P] Create example secrets file in secrets/personal/secrets.yaml (encrypted)
- [ ] T106 [P] Document secrets workflow in quickstart.md (how to add/edit/use secrets)
- [ ] T107 Create sops-nix integration module that imports sops-nix
- [ ] T108 Add example secret usage in one module (e.g., git config with encrypted token)
- [ ] T109 Test secrets: encrypt a test secret, decrypt at build time, verify never committed unencrypted (verify SC-011, FR-024)

**Checkpoint**: Secrets management is functional and documented

______________________________________________________________________

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T110 [P] Add formatter configuration to flake.nix (alejandra)
- [ ] T111 [P] Format all Nix files with `alejandra .`
- [ ] T112 [P] Create comprehensive README.md with architecture overview, directory structure, and links
- [ ] T113 [P] Create MIGRATION.md documenting step-by-step migration from old dotfiles
- [ ] T114 [P] Add troubleshooting section to quickstart.md for common issues
- [ ] T115 [P] Document shell startup performance optimization tips
- [ ] T116 [P] Add system-level overlay examples in overlays/default.nix (optional package customizations)
- [ ] T117 Run complete quickstart.md validation on all platforms (macOS, NixOS, Kali, Android)
- [ ] T118 Verify all success criteria: SC-001 through SC-012
- [ ] T119 Final flake check: `nix flake check --all-systems`
- [ ] T120 Create .github/workflows/ci.yml for automated flake checks (optional, but recommended)

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2)
- **User Story 4 (Phase 4)**: Depends on US1 (need working config to rollback from)
- **User Story 2 (Phase 5)**: Depends on US1 (need working config to update)
- **User Story 3 (Phase 6)**: Depends on US1 (need both platforms working)
- **Nix-on-Linux (Phase 7)**: Depends on Foundational (Phase 2) - can run in parallel with US1
- **Nix-on-Droid (Phase 8)**: Depends on Foundational (Phase 2) - can run in parallel with US1
- **Secrets (Phase 9)**: Depends on US1 (need host configs to reference secrets)
- **Polish (Phase 10)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories ✅ **MVP**
- **User Story 4 (P2)**: Can start after US1 completes - Needs working config to test rollback
- **User Story 2 (P2)**: Can start after US1 completes - Needs working config to update
- **User Story 3 (P3)**: Can start after US1 completes - Needs both platforms working
- **Nix-on-Linux**: Can start after Foundational - Independent of US1 but similar workflow
- **Nix-on-Droid**: Can start after Foundational - Independent of US1 but similar workflow

### Within Each Phase

**Phase 1 (Setup)**: T001 must complete before T005 (flake.lock needs flake.nix). All others can run in parallel.

**Phase 2 (Foundational)**:

- T009-T011 can run in parallel (core modules)
- T012 depends on nothing
- T013 can run in parallel with T012
- T014 must complete before T015-T023 (zsh modules need structure)
- T015-T023 can all run in parallel (different zsh modules)
- T024 depends on T015-T023 completion (wiring modules together)

**Phase 3 (US1)**:

- macOS hosts (T027-T035) can all run in parallel
- NixOS hosts (T038-T040) can all run in parallel
- Program configs (T044-T051) can all run in parallel
- Profiles (T052-T056) can all run in parallel
- Platform apps (T057-T061) can all run in parallel
- Languages (T062-T066) can all run in parallel
- T036 depends on T027-T035 (add hosts to flake after creating them)
- T042 depends on T038-T040
- T037 depends on T036 (test after adding to flake)
- T043 depends on T042

**Phase 4-10**: Most tasks within each phase can run in parallel (marked with [P])

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel (T002, T003, T004, T007, T008)
- All Foundational core modules can run in parallel (T009, T010, T011)
- All zsh modules can run in parallel (T015-T023)
- All macOS host configs can run in parallel (T027-T035)
- All program configs can run in parallel (T044-T051)
- All profiles can run in parallel (T052-T055)
- All platform-specific apps can run in parallel (T057-T060)
- All languages can run in parallel (T062-T066)
- Multiple user stories can be worked on in parallel by different team members after Foundational completes

______________________________________________________________________

## Parallel Example: User Story 1

```bash
# Launch all macOS host configs together:
Task: "Create work-macbook host config in hosts/work-macbook/default.nix"
Task: "Create home-macmini host config in hosts/home-macmini/default.nix"
Task: "Create darwin-dev host config in hosts/darwin-dev/default.nix"

# Launch all program configurations together:
Task: "Create git configuration in home/programs/git.nix"
Task: "Create starship configuration in home/programs/starship.nix"
Task: "Create helix configuration in home/programs/helix.nix"
Task: "Create lazygit configuration in home/programs/lazygit.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup → Project structure ready
1. Complete Phase 2: Foundational → Core modules and zsh config migrated
1. Complete Phase 3: User Story 1 → Installation works on both platforms
1. **STOP and VALIDATE**: Test installation on fresh macOS and NixOS VMs
1. Verify success criteria: SC-001, SC-002, SC-003, SC-007, SC-008, SC-009
1. **Deploy/Use**: Start using the nix-config on real machines

### Incremental Delivery

1. Complete Setup + Foundational → Can build basic config ✅
1. Add User Story 1 → Installation works → **Deploy to real machines (MVP!)** 🎯
1. Add User Story 4 → Rollback capability → Safer to experiment
1. Add User Story 2 → Update workflow → Easy maintenance
1. Add User Story 3 → Cross-platform polished → Multi-platform ready
1. Add Nix-on-Linux → Kali VM supported → Security testing env
1. Add Nix-on-Droid → Android supported → Mobile terminal env
1. Add Secrets → Sensitive data handled → Production ready
1. Polish → Documentation complete → Shareable config

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
1. Once Foundational is done:
   - Developer A: User Story 1 (macOS parts)
   - Developer B: User Story 1 (NixOS parts)
   - Developer C: Program configurations (git, zsh, helix, etc.)
   - Developer D: Profiles (work-restricted, personal, development)
1. Stories integrate at flake.nix level
1. After US1 complete, add US2, US3, US4 in any order

______________________________________________________________________

## Notes

- [P] tasks = different files, no dependencies - can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- **No tests needed** - this is infrastructure configuration, verified by building and running
- All paths relative to repo root: `/Users/charles/project/nix-config/`
- Constitution compliance verified in plan.md (v1.5.0)
- Blueprint directory structure followed throughout

______________________________________________________________________

## Success Criteria Mapping

- **SC-001**: Verified by T037 (macOS install \<30min)
- **SC-002**: Verified by T043 (NixOS rebuild \<15min)
- **SC-003**: Verified by T067 (60+ apps migrated)
- **SC-004**: Verified by T080 (single command updates)
- **SC-005**: Verified by T088 (cross-platform builds)
- **SC-006**: Verified by T073 (rollback \<2min)
- **SC-007**: Verified by T067 (shell startup \<200ms)
- **SC-008**: Verified by T067 (shell functions/aliases work)
- **SC-009**: Verified by T067 (editor configs work)
- **SC-010**: Verified by T056 (new machine \<10min)
- **SC-011**: Verified by T109 (secrets never exposed)
- **SC-012**: Verified by T081 (clear error messages)

**Total Tasks**: 120
**Parallelizable Tasks**: 71 (59%)
**User Story Breakdown**:

- Setup: 8 tasks
- Foundational: 16 tasks (BLOCKS all stories)
- US1 (P1 - MVP): 43 tasks ⭐
- US4 (P2 - Rollback): 6 tasks
- US2 (P2 - Updates): 8 tasks
- US3 (P3 - Cross-platform): 7 tasks
- Nix-on-Linux: 7 tasks
- Nix-on-Droid: 7 tasks
- Secrets: 7 tasks
- Polish: 11 tasks

**Recommended MVP Scope**: Phase 1 + Phase 2 + Phase 3 (User Story 1) = 67 tasks
