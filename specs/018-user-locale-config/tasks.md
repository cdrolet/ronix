# Tasks: User Locale Configuration

**Feature**: 018-user-locale-config\
**Input**: Design documents from `/specs/018-user-locale-config/`\
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: No test tasks included (not requested in specification - configuration management feature)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Project Structure

Nix configuration repository with:

- User configs: `user/{username}/default.nix`
- Darwin platform lib: `platform/darwin/lib/`
- Darwin settings: `platform/darwin/settings/`
- Documentation: `docs/features/`

______________________________________________________________________

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create keyboard layout translation registry and infrastructure

- [X] T001 [P] Create keyboard layout translation registry in platform/darwin/lib/keyboard-layout-translation.nix
- [X] T002 [P] Discover KeyboardLayout IDs for initial layouts (us=0, canadian=29) via `defaults read com.apple.HIToolbox AppleSelectedInputSources`

**Checkpoint**: Translation registry created with at least 2 working layouts (us, canadian)

______________________________________________________________________

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Create darwin locale settings module in platform/darwin/settings/locale.nix
- [X] T004 Update platform/darwin/settings/default.nix to import locale.nix
- [X] T005 Analyze platform/darwin/lib/darwin.nix to understand userContext passing mechanism
- [X] T006 Update platform/darwin/lib/darwin.nix to pass full user config object (not just username string) via userContext

**Checkpoint**: Foundation ready - user config fields can be consumed by darwin settings

______________________________________________________________________

## Phase 3: User Story 1 - Configure Language Preferences (Priority: P1) 🎯 MVP

**Goal**: User can specify `languages` array in their config, and macOS system language preferences are automatically configured to match

**Independent Test**: Add `languages = ["en-CA" "fr-CA"]` to `user/cdrokar/default.nix`, build configuration, verify with `defaults read NSGlobalDomain AppleLanguages` showing correct array in priority order

### Implementation for User Story 1

- [X] T007 [US1] Implement language configuration logic in platform/darwin/settings/locale.nix (system.defaults.CustomUserPreferences."Apple Global Domain".AppleLanguages)
- [X] T008 [US1] Add `languages` field to user/cdrokar/default.nix with example values ["en-CA" "fr-CA"]
- [X] T009 [US1] Build configuration with `nix flake check` and `just build cdrokar home-macmini-m4`
- [ ] T010 [US1] Verify language settings applied with `defaults read NSGlobalDomain AppleLanguages` (MANUAL: requires darwin-rebuild switch)
- [X] T011 [US1] Test backward compatibility: build user config WITHOUT languages field (cdrolet), verify no errors

**Checkpoint**: Language preferences functional - users can declaratively set system languages

______________________________________________________________________

## Phase 4: User Story 3 - Configure Timezone (Priority: P1)

**Goal**: User can specify `timezone` field in their config, and macOS system timezone is automatically set

**Independent Test**: Add `timezone = "America/Toronto"` to `user/cdrokar/default.nix`, build configuration, verify with `sudo systemsetup -gettimezone` showing correct timezone

**Why before US2**: P1 priority (same as US1), simpler implementation than keyboard layouts, no translation layer needed

### Implementation for User Story 3

- [X] T012 [US3] Implement timezone configuration logic in platform/darwin/settings/locale.nix (time.timeZone)
- [X] T013 [US3] Add `timezone` field to user/cdrokar/default.nix with value "America/Toronto"
- [X] T014 [US3] Build configuration with `nix flake check` and `just build cdrokar home-macmini-m4`
- [ ] T015 [US3] Verify timezone applied with `sudo systemsetup -gettimezone` (MANUAL)
- [ ] T016 [US3] Test with different timezone value (e.g., "America/Vancouver"), verify updates correctly (MANUAL)

**Checkpoint**: Timezone configuration functional - users can declaratively set system timezone

______________________________________________________________________

## Phase 5: User Story 2 - Configure Keyboard Layout (Priority: P2)

**Goal**: User can specify `keyboardLayout` array with platform-agnostic names, and macOS keyboard layouts are automatically configured with translation to darwin-specific identifiers

**Independent Test**: Add `keyboardLayout = ["us" "canadian"]` to `user/cdrokar/default.nix`, build configuration, verify with `defaults read com.apple.HIToolbox AppleSelectedInputSources` showing both layouts with correct IDs

### Implementation for User Story 2

- [X] T017 [US2] Implement keyboard layout translation function in platform/darwin/settings/locale.nix (translateLayout helper)
- [X] T018 [US2] Implement keyboard layout configuration logic in platform/darwin/settings/locale.nix (system.defaults.CustomUserPreferences."com.apple.HIToolbox".AppleSelectedInputSources)
- [X] T019 [US2] Add `keyboardLayout` field to user/cdrokar/default.nix with values ["us" "canadian"]
- [X] T020 [US2] Build configuration with `nix flake check` and `just build cdrokar home-macmini-m4`
- [ ] T021 [US2] Verify keyboard layouts applied with `defaults read com.apple.HIToolbox AppleSelectedInputSources`
- [ ] T022 [US2] Test error handling: add unknown layout name (e.g., "invalid-layout"), verify helpful error message
- [ ] T023 [US2] Test error handling: add layout with null ID (e.g., "canadian-french"), verify error message instructs on ID discovery

**Checkpoint**: Keyboard layout configuration functional with translation layer and error handling

______________________________________________________________________

## Phase 6: User Story 4 - Configure Regional Locale (Priority: P2)

**Goal**: User can specify `locale` field in their config, and macOS regional settings (date/time/number format, measurements, currency) are automatically configured

**Independent Test**: Add `locale = "en_CA.UTF-8"` to `user/cdrokar/default.nix`, build configuration, verify with `defaults read NSGlobalDomain AppleLocale` and measurement unit settings showing Canadian conventions

### Implementation for User Story 4

- [X] T024 [US4] Implement locale encoding stripping helper in platform/darwin/settings/locale.nix (stripEncoding function)
- [X] T025 [US4] Implement metric/imperial detection helper in platform/darwin/settings/locale.nix (isMetric function)
- [X] T026 [US4] Implement locale configuration logic in platform/darwin/settings/locale.nix (system.defaults.CustomUserPreferences."Apple Global Domain".AppleLocale)
- [X] T027 [US4] Implement regional settings derivation in platform/darwin/settings/locale.nix (system.defaults.NSGlobalDomain measurement units)
- [X] T028 [US4] Add `locale` field to user/cdrokar/default.nix with value "en_CA.UTF-8"
- [X] T029 [US4] Build configuration with `nix flake check` and `just build cdrokar home-macmini-m4`
- [ ] T030 [US4] Verify locale applied with `defaults read NSGlobalDomain AppleLocale`
- [ ] T031 [US4] Verify measurement units with `defaults read NSGlobalDomain AppleMeasurementUnits` (should be "Centimeters")
- [ ] T032 [US4] Test with US locale "en_US.UTF-8", verify imperial measurements apply

**Checkpoint**: Regional locale configuration functional with automatic metric/imperial detection

______________________________________________________________________

## Phase 7: Integration & Multi-User Validation

**Purpose**: Verify all user stories work together and multi-user isolation is maintained

- [X] T033 Add all four locale fields to user/cdrokar/default.nix (languages, keyboardLayout, timezone, locale)
- [X] T034 Build complete configuration for cdrokar, verify all settings applied correctly
- [ ] T035 Add different locale settings to user/cdrolet/default.nix (e.g., fr-CA languages, canadian-french keyboard)
- [ ] T036 Build configurations for both cdrokar and cdrolet, verify no interference between users
- [ ] T037 Verify cdrixus config (without locale fields) builds successfully (backward compatibility)

**Checkpoint**: All user stories integrated, multi-user isolation verified, backward compatibility confirmed

______________________________________________________________________

## Phase 8: Refactoring & Code Cleanup

**Purpose**: Clean up existing hardcoded locale settings and ensure constitutional compliance

- [X] T038 Refactor platform/darwin/settings/keyboard.nix to remove hardcoded locale settings (AppleLanguages, AppleLocale, measurement units)
- [X] T039 Keep keyboard behavior settings in keyboard.nix (KeyRepeat, InitialKeyRepeat, etc.)
- [X] T040 Verify locale.nix module size is under 200 lines (constitutional requirement)
- [X] T041 If locale.nix exceeds 200 lines, split into separate modules (language.nix, keyboard-layout.nix, timezone.nix, regional.nix)
- [X] T042 Add comprehensive header documentation to locale.nix explaining purpose, dependencies, and usage

**Checkpoint**: Code cleanup complete, constitutional compliance verified

______________________________________________________________________

## Phase 9: Keyboard Layout Registry Expansion

**Purpose**: Discover remaining keyboard layout IDs for complete registry

- [ ] T043 [P] Discover KeyboardLayout ID for "canadian-french" layout via System Preferences + `defaults read`
- [ ] T044 [P] Discover KeyboardLayout ID for "british" layout
- [ ] T045 [P] Discover KeyboardLayout ID for "dvorak" layout
- [ ] T046 [P] Discover KeyboardLayout ID for "colemak" layout
- [ ] T047 [P] Discover KeyboardLayout ID for "french" layout
- [ ] T048 [P] Discover KeyboardLayout ID for "german" layout
- [ ] T049 [P] Discover KeyboardLayout ID for "spanish" layout
- [ ] T050 [P] Discover KeyboardLayout ID for "brazilian" layout
- [ ] T051 Update platform/darwin/lib/keyboard-layout-translation.nix with all discovered IDs

**Checkpoint**: Complete keyboard layout registry with all 10 initial layouts configured

______________________________________________________________________

## Phase 10: Documentation & Polish

**Purpose**: Create user-facing documentation and final validation

- [X] T052 [P] Create user documentation in docs/features/018-user-locale-config.md
- [X] T053 [P] Add usage examples for all four locale fields to documentation
- [X] T054 [P] Document keyboard layout discovery procedure for future expansion
- [X] T055 [P] Document troubleshooting steps (logout required for keyboard layouts, timezone verification, etc.)
- [X] T056 [P] Update CLAUDE.md if any new architectural patterns emerged
- [X] T057 Run full validation: `nix flake check`, build all users, verify all settings
- [X] T058 Run quickstart.md validation checklist to ensure all steps documented
- [ ] T059 Create commit with conventional commit message: "feat: add user locale configuration for darwin"

**Checkpoint**: Feature complete, documented, and ready for deployment

______________________________________________________________________

## Dependencies & Execution Order

### Phase Dependencies

1. **Setup (Phase 1)**: No dependencies - can start immediately
1. **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
1. **User Story 1 - Languages (Phase 3)**: Depends on Foundational (Phase 2)
1. **User Story 3 - Timezone (Phase 4)**: Depends on Foundational (Phase 2) - Can run parallel with US1
1. **User Story 2 - Keyboard (Phase 5)**: Depends on Foundational (Phase 2) AND Setup (translation registry) - Can run parallel with US1/US3
1. **User Story 4 - Regional (Phase 6)**: Depends on Foundational (Phase 2) - Can run parallel with US1/US2/US3
1. **Integration (Phase 7)**: Depends on ALL user stories (Phase 3-6) being complete
1. **Refactoring (Phase 8)**: Depends on Integration (Phase 7)
1. **Registry Expansion (Phase 9)**: Can run parallel with Phase 3-8 (independent keyboard ID discovery)
1. **Documentation (Phase 10)**: Depends on Refactoring (Phase 8)

### User Story Dependencies

- **User Story 1 (P1 - Languages)**: No dependencies on other stories - can start after Foundational
- **User Story 3 (P1 - Timezone)**: No dependencies on other stories - can start after Foundational
- **User Story 2 (P2 - Keyboard)**: Depends on translation registry (Phase 1) - otherwise independent
- **User Story 4 (P2 - Regional)**: No dependencies on other stories - can start after Foundational

**All user stories can be implemented in parallel** once Foundational phase is complete.

### Within Each User Story

- Implementation → Build → Verify → Test edge cases
- Each story should be fully functional before moving to next

### Parallel Opportunities

**Phase 1 - Setup**:

- T001 (create registry) and T002 (discover IDs) can overlap

**Phase 2 - Foundational**:

- T003 (create locale.nix) can be done in parallel with T005-T006 (analyze/update darwin.nix)
- T004 (update imports) depends on T003

**Phase 3-6 - User Stories**:

- Once Foundational complete, ALL FOUR user stories can be worked on in parallel
- Within each story, implementation tasks are sequential (logic → config → build → verify)

**Phase 9 - Registry Expansion**:

- All T043-T050 (keyboard ID discovery) can run in parallel
- T051 (update registry) depends on discoveries

**Phase 10 - Documentation**:

- All T052-T056 (documentation tasks) can run in parallel
- T057-T059 (validation & commit) run sequentially after docs

______________________________________________________________________

## Parallel Example: User Stories (After Foundational Phase)

```bash
# All user stories can start in parallel after Phase 2 completes:

# Developer A: User Story 1 (Languages)
Task: "T007 Implement language configuration logic in locale.nix"
Task: "T008 Add languages field to cdrokar config"
Task: "T009-T011 Build and verify"

# Developer B: User Story 3 (Timezone)  
Task: "T012 Implement timezone configuration logic in locale.nix"
Task: "T013 Add timezone field to cdrokar config"
Task: "T014-T016 Build and verify"

# Developer C: User Story 2 (Keyboard)
Task: "T017-T018 Implement keyboard configuration logic in locale.nix"
Task: "T019 Add keyboardLayout field to cdrokar config"
Task: "T020-T023 Build and verify"

# Developer D: User Story 4 (Regional)
Task: "T024-T027 Implement regional configuration logic in locale.nix"
Task: "T028 Add locale field to cdrokar config"  
Task: "T029-T032 Build and verify"
```

**Note**: In practice, all locale.nix modifications may need coordination to avoid merge conflicts, or developers can work on separate branches and integrate after each story validates independently.

______________________________________________________________________

## Parallel Example: Keyboard Layout Discovery (Phase 9)

```bash
# All keyboard layout ID discoveries can happen in parallel:

Task: "T043 Discover canadian-french layout ID"
Task: "T044 Discover british layout ID"
Task: "T045 Discover dvorak layout ID"
Task: "T046 Discover colemak layout ID"
Task: "T047 Discover french layout ID"
Task: "T048 Discover german layout ID"
Task: "T049 Discover spanish layout ID"
Task: "T050 Discover brazilian layout ID"

# Then update registry with all discovered IDs:
Task: "T051 Update keyboard-layout-translation.nix"
```

______________________________________________________________________

## Implementation Strategy

### MVP First (P1 User Stories Only)

1. **Phase 1**: Setup (T001-T002) - Translation registry with 2 layouts
1. **Phase 2**: Foundational (T003-T006) - Core infrastructure
1. **Phase 3**: User Story 1 - Languages (T007-T011)
1. **Phase 4**: User Story 3 - Timezone (T012-T016)
1. **STOP and VALIDATE**: Test P1 stories independently
1. **Deploy/Demo**: Basic locale configuration (languages + timezone) working

**MVP Deliverable**: Users can set languages and timezone declaratively

### Incremental Delivery

1. **Foundation** (Phase 1-2): Translation registry + core infrastructure
1. **MVP** (Phase 3-4): Languages + Timezone (P1 stories) → Deploy
1. **Enhanced** (Phase 5-6): Add Keyboard + Regional (P2 stories) → Deploy
1. **Complete** (Phase 7-10): Integration + Documentation + Registry expansion → Deploy

Each increment adds value without breaking previous functionality.

### Parallel Team Strategy

With multiple developers (after Foundational phase):

1. **Team completes Phase 1-2 together** (Setup + Foundational)
1. **Once Phase 2 done, split work**:
   - Developer A: User Story 1 (Languages)
   - Developer B: User Story 3 (Timezone)
   - Developer C: User Story 2 (Keyboard) - may coordinate with Dev A on locale.nix
   - Developer D: User Story 4 (Regional) - may coordinate with Dev A on locale.nix
1. **Stories integrate** in Phase 7 after all validate independently
1. **Parallel cleanup**: Phase 9 (registry expansion) + Phase 10 (documentation)

### Solo Developer Strategy

1. Complete Phase 1-2 (foundation)
1. Complete Phase 3 (US1 - Languages) → Validate independently
1. Complete Phase 4 (US3 - Timezone) → Validate independently
1. Complete Phase 5 (US2 - Keyboard) → Validate independently
1. Complete Phase 6 (US4 - Regional) → Validate independently
1. Complete Phase 7 (Integration) → Validate all together
1. Complete Phase 8 (Refactoring) → Clean up
1. Complete Phase 9 (Registry) while documenting in Phase 10

**Estimated Solo Time**: 6-8 hours (per quickstart.md estimate)

______________________________________________________________________

## Validation Checkpoints

### After Phase 2 (Foundational)

```bash
# Verify userContext passing works
nix flake check
just build cdrokar home-macmini-m4
# Check that userContext.user contains full config object
```

### After Phase 3 (User Story 1 - Languages)

```bash
# Verify language configuration
defaults read NSGlobalDomain AppleLanguages
# Expected: ( "en-CA", "fr-CA" )
```

### After Phase 4 (User Story 3 - Timezone)

```bash
# Verify timezone configuration
sudo systemsetup -gettimezone
# Expected: Time Zone: America/Toronto
```

### After Phase 5 (User Story 2 - Keyboard)

```bash
# Verify keyboard layouts
defaults read com.apple.HIToolbox AppleSelectedInputSources
# Expected: Array with US and Canadian layouts with correct IDs
```

### After Phase 6 (User Story 4 - Regional)

```bash
# Verify locale and measurements
defaults read NSGlobalDomain AppleLocale  # Expected: en_CA
defaults read NSGlobalDomain AppleMeasurementUnits  # Expected: Centimeters
defaults read NSGlobalDomain AppleMetricUnits  # Expected: 1
```

### After Phase 7 (Integration)

```bash
# Build all users
just build cdrokar home-macmini-m4
just build cdrolet home-macmini-m4
just build cdrixus home-macmini-m4

# Verify all settings for cdrokar
defaults read NSGlobalDomain AppleLanguages
sudo systemsetup -gettimezone
defaults read com.apple.HIToolbox AppleSelectedInputSources
defaults read NSGlobalDomain AppleLocale

# Verify cdrolet has different settings (no interference)
# Verify cdrixus builds successfully (backward compatibility)
```

### After Phase 8 (Refactoring)

```bash
# Verify module size
wc -l platform/darwin/settings/locale.nix
# Expected: < 200 lines

# Verify no duplication
grep -r "AppleLanguages" platform/darwin/settings/
# Should only appear in locale.nix, not keyboard.nix
```

### After Phase 10 (Final)

```bash
# Full validation
nix flake check  # Syntax validation
just build cdrokar home-macmini-m4  # Build test
just build cdrolet home-macmini-m4
just build cdrixus home-macmini-m4

# Apply configuration (optional)
darwin-rebuild switch --flake .#cdrokar-home-macmini-m4

# Verify all settings active after logout/login
```

______________________________________________________________________

## Task Summary

**Total Tasks**: 59

**By Phase**:

- Phase 1 (Setup): 2 tasks
- Phase 2 (Foundational): 4 tasks
- Phase 3 (US1 - Languages): 5 tasks
- Phase 4 (US3 - Timezone): 5 tasks
- Phase 5 (US2 - Keyboard): 7 tasks
- Phase 6 (US4 - Regional): 9 tasks
- Phase 7 (Integration): 5 tasks
- Phase 8 (Refactoring): 5 tasks
- Phase 9 (Registry Expansion): 9 tasks
- Phase 10 (Documentation): 8 tasks

**By User Story**:

- User Story 1 (Languages - P1): 5 tasks
- User Story 2 (Keyboard - P2): 7 tasks
- User Story 3 (Timezone - P1): 5 tasks
- User Story 4 (Regional - P2): 9 tasks
- Infrastructure/Setup: 11 tasks
- Integration/Refactoring: 10 tasks
- Registry/Documentation: 17 tasks

**Parallel Opportunities**: 25 tasks marked [P] can run in parallel

**MVP Scope** (Phases 1-4): 16 tasks (~3-4 hours)

**Full Implementation** (All phases): 59 tasks (~6-8 hours solo, 3-4 hours with 4-person team)

______________________________________________________________________

## Notes

- [P] tasks = different files or independent work, can run in parallel
- [Story] labels (US1, US2, US3, US4) map to user stories from spec.md
- Each user story validates independently before integration
- Constitutional requirement: locale.nix must be \<200 lines (verified in Phase 8)
- Keyboard layout discovery (Phase 9) can happen incrementally as layouts are needed
- Logout/login required for keyboard layout changes to take effect (documented in Phase 10)
- Backward compatibility critical: users without locale fields must build successfully
