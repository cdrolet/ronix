# Implementation Tasks: Complete Dock Migration from Dotfiles

**Feature**: 007-complete-dock-migration\
**Branch**: 007-007-complete-dock-migration\
**Status**: Ready for Implementation\
**Generated**: 2025-10-27

______________________________________________________________________

## Overview

This document provides a complete task breakdown for migrating the actual Dock configuration from dotfiles to `modules/darwin/system/dock.nix`. Tasks are organized by user story to enable independent implementation and testing.

**Key Metrics**:

- **Total Tasks**: 14
- **User Stories**: 2 (US1: Dock Items, US2: Dock Preferences)
- **Parallelizable Tasks**: 3
- **Files Modified**: 2 (`dock.nix`, `unresolved-migration.md`)

______________________________________________________________________

## Implementation Strategy

### MVP Scope (Minimum Viable Product)

**User Story 1 ONLY**: Dock Items Migration

- Provides immediate value (correct Dock layout)
- Independently testable (visual verification)
- Foundation for US2 (preferences can be added later)

### Incremental Delivery

1. **Phase 1**: Setup (verify prerequisites)
1. **Phase 2**: Foundational (read current dock.nix)
1. **Phase 3**: US1 - Dock Items (14 apps, 3 spacers, 1 folder)
1. **Phase 4**: US2 - Dock Preferences (13 nix-darwin + 2 activation script)
1. **Phase 5**: Polish (documentation updates, validation)

Each phase delivers a working, testable increment.

______________________________________________________________________

## Task Dependency Graph

```
User Story Completion Order:

Setup Phase (T001)
    ↓
Foundational Phase (T002-T003)
    ↓
    ├─→ US1: Dock Items (T004-T008) ─────────┐
    │   ├─ T004 [P]: Backup current          │
    │   ├─ T005 [P]: Clear placeholder       │  Can work in parallel
    │   ├─ T006: Add 14 apps                 │  (different sections)
    │   ├─ T007: Add 3 spacers + folder      │
    │   └─ T008: Test US1                    │
    │                                         │
    └─→ US2: Dock Preferences (T009-T011) ───┤
        ├─ T009 [P]: Add nix-darwin prefs    │
        ├─ T010: Add activation script prefs │
        └─ T011: Test US2                    │
                                              ↓
Polish Phase (T012-T014)
    ├─ T012: Update unresolved-migration.md
    ├─ T013: Final validation
    └─ T014: Commit changes
```

**Key Dependencies**:

- US1 and US2 are independent (can be implemented in parallel after T003)
- T008 must complete before T011 (cumulative testing)
- T012-T014 require both US1 and US2 complete

______________________________________________________________________

## Phase 1: Setup & Prerequisites

**Goal**: Verify all prerequisites for Dock configuration migration

### Tasks

- [X] T001 Verify prerequisites (helper library, dotfiles source)

**Details**:

```bash
# Check helper library exists
ls modules/darwin/lib/mac.nix

# Check dotfiles source exists
cat ~/project/dotfiles/scripts/sh/darwin/system.sh | grep -A 20 "dockItems"

# Verify on correct branch
git branch --show-current  # Should be 007-007-complete-dock-migration
```

______________________________________________________________________

## Phase 2: Foundational Tasks

**Goal**: Understand current state and prepare for rewrite

### Tasks

- [X] T002 Read and analyze current dock.nix structure in modules/darwin/system/dock.nix
- [X] T003 Review dotfiles Dock configuration in ~/project/dotfiles/scripts/sh/darwin/system.sh

**T002 Details**: Identify what to preserve (structure, comments) vs replace (content)

**T003 Details**: Extract exact app paths, settings, verify against research.md mapping

______________________________________________________________________

## Phase 3: User Story 1 - Dock Items Migration

**Story Goal**: Configure all 17 Dock items from dotfiles (14 apps, 3 spacers, 1 folder)

**Acceptance Criteria**:

- ✅ All 17 items from dotfiles `dockItems` array are configured
- ✅ Apps are added in correct order with explicit positions
- ✅ Spacers placed between app groups (after position 6, 11, 15)
- ✅ Downloads folder added with fan view, stack display, dateadded sort
- ✅ Configuration is idempotent (uses helper functions with checks)

### Tasks

- [X] T004 [P] [US1] Create backup of current dock.nix as dock.nix.bak
- [X] T005 [P] [US1] Delete placeholder Dock items from activation script in modules/darwin/system/dock.nix
- [X] T006 [US1] Add 14 applications with explicit positions using mkDockAddApp in modules/darwin/system/dock.nix
- [X] T007 [US1] Add 3 spacers and Downloads folder using mkDockAddSpacer and mkDockAddFolder in modules/darwin/system/dock.nix
- [X] T008 [US1] Test US1: Build and verify Dock items with darwin-rebuild switch

**T006 Application List** (in order):

```nix
# Position 1-6: Main applications
${macLib.mkDockAddApp { path = "/Applications/Zen.app"; position = 1; }}
${macLib.mkDockAddApp { path = "/Applications/Brave Browser.app"; position = 2; }}
${macLib.mkDockAddApp { path = "/System/Applications/Mail.app"; position = 3; }}
${macLib.mkDockAddApp { path = "/System/Applications/Maps.app"; position = 4; }}
${macLib.mkDockAddApp { path = "/Applications/Bitwarden.app"; position = 5; }}
${macLib.mkDockAddApp { path = "/Applications/Qobuz.app"; position = 6; }}

# Position 8-11: Development applications (spacer at position 7)
${macLib.mkDockAddApp { path = "/Applications/Zed.app"; position = 8; }}
${macLib.mkDockAddApp { path = "/Applications/Ghostty.app"; position = 9; }}
${macLib.mkDockAddApp { path = "/Applications/Obsidian.app"; position = 10; }}
${macLib.mkDockAddApp { path = "/Applications/UTM.app"; position = 11; }}

# Position 13-15: System utilities (spacer at position 12)
${macLib.mkDockAddApp { path = "/System/Applications/System Settings.app"; position = 13; }}
${macLib.mkDockAddApp { path = "/System/Applications/Utilities/Activity Monitor.app"; position = 14; }}
${macLib.mkDockAddApp { path = "/System/Applications/Utilities/Print Center.app"; position = 15; }}
```

**T007 Spacers and Folder**:

```nix
# Spacer after main apps (position 7)
${macLib.mkDockAddSpacer}

# Spacer after dev apps (position 12)
${macLib.mkDockAddSpacer}

# Spacer after system utilities (position 16)
${macLib.mkDockAddSpacer}

# Downloads folder (position 17)
${macLib.mkDockAddFolder {
  path = "/Users/${primaryUser}/Downloads";
  view = "fan";
  display = "stack";
  sort = "dateadded";
}}
```

**T008 Test Commands**:

```bash
# Build configuration
cd ~/project/nix-config
darwin-rebuild switch --flake .#home-macmini

# Verify Dock items
dockutil --list | wc -l  # Should show 14 (apps + folder, spacers not counted)

# Visual verification: Check Dock shows all apps in correct order
```

**Independent Test Criteria for US1**:

- [ ] Dock contains exactly 14 applications + 1 folder
- [ ] Applications appear in correct order (Zen, Brave, Mail, Maps, Bitwarden, Qobuz, Zed, Ghostty, Obsidian, UTM, System Settings, Activity Monitor, Print Center)
- [ ] 3 visible spacers separate app groups
- [ ] Downloads folder appears at end with stack display
- [ ] No errors during `darwin-rebuild switch`
- [ ] Rerunning `darwin-rebuild switch` succeeds without changes (idempotency)

______________________________________________________________________

## Phase 4: User Story 2 - Dock Preferences Migration

**Story Goal**: Configure all 15 Dock preferences from dotfiles (13 nix-darwin + 2 activation script)

**Acceptance Criteria**:

- ✅ All 15 Dock settings from dotfiles are migrated
- ✅ 13 settings use nix-darwin `system.defaults.dock.*` (declarative)
- ✅ 2 settings use activation script with `defaults write` (imperative fallback)
- ✅ All preferences take effect after `darwin-rebuild switch`

### Tasks

- [X] T009 [P] [US2] Add 13 nix-darwin Dock preferences to system.defaults.dock in modules/darwin/system/dock.nix
- [X] T010 [US2] Add 2 activation script preferences before Dock items configuration in modules/darwin/system/dock.nix
- [X] T011 [US2] Test US2: Verify all Dock preferences with defaults read commands

**T009 nix-darwin Preferences**:

```nix
system.defaults.dock = {
  show-recents = false;                    # Disable recent apps
  show-process-indicators = true;          # Show indicator lights
  launchanim = false;                      # Disable opening animations
  autohide-delay = 0.0;                    # Remove auto-hiding delay
  autohide-time-modifier = 0.0;            # Remove hiding animation
  autohide = true;                         # Enable auto-hide
  showhidden = true;                       # Make hidden apps translucent
  mineffect = "scale";                     # Set minimize animation
  tilesize = 36;                           # Set dock size
  minimize-to-application = true;          # Minimize to app icon
  expose-animation-duration = 0.1;         # Speed up Mission Control
  expose-group-apps = false;               # Don't group by app
  mru-spaces = false;                      # Don't rearrange Spaces
};
```

**T010 Activation Script Preferences** (add at beginning of activation script):

```bash
# Additional Dock preferences not available in nix-darwin
defaults write com.apple.dock mouse-over-hilite-stack -bool true  # Enable highlight hover
defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true  # Enable spring loading
```

**T011 Test Commands**:

```bash
# Test nix-darwin preferences
defaults read com.apple.dock autohide  # Should return 1
defaults read com.apple.dock tilesize  # Should return 36
defaults read com.apple.dock show-recents  # Should return 0
defaults read com.apple.dock mineffect  # Should return "scale"
defaults read com.apple.dock expose-group-apps  # Should return 0

# Test activation script preferences
defaults read com.apple.dock mouse-over-hilite-stack  # Should return 1
defaults read com.apple.dock enable-spring-load-actions-on-all-items  # Should return 1
```

**Independent Test Criteria for US2**:

- [ ] Dock auto-hides when cursor moves away
- [ ] Dock size is visibly smaller (36px icons)
- [ ] No "Recent Applications" section in Dock
- [ ] Running apps show indicator lights (dots under icons)
- [ ] Hidden apps appear translucent
- [ ] Minimize animation uses scale effect (not genie)
- [ ] Windows minimize into app icon (not separate Dock position)
- [ ] Mission Control animations are fast (\<0.1s)
- [ ] Spaces don't auto-rearrange when switching
- [ ] All 15 `defaults read` commands return expected values

______________________________________________________________________

## Phase 5: Polish & Documentation

**Goal**: Complete documentation and final validation

### Tasks

- [X] T012 Update specs/002-darwin-system-restructure/unresolved-migration.md to mark item #8 as resolved
- [X] T013 Run final validation checklist from quickstart.md
- [X] T014 Commit all changes with descriptive message

**T012 Details**: Edit unresolved-migration.md:

```markdown
## 8. Dock Items Configuration

**Configuration**: [MOVED TO COMPLETED]

**Status**: ✅ RESOLVED (Spec 007)

**Solution**: Migrated to `modules/darwin/system/dock.nix` using helper library functions from spec 006. All 17 Dock items and 15 Dock preferences now configured declaratively.

**Reference**: See `specs/007-007-complete-dock-migration/spec.md`
```

**T013 Validation Checklist** (from quickstart.md):

- [ ] All 14 applications appear in Dock
- [ ] 3 spacers visible as separators
- [ ] Downloads folder at end of Dock
- [ ] Dock auto-hides when cursor leaves
- [ ] Dock size is noticeably smaller (36px)
- [ ] No "Recent Applications" section
- [ ] Running apps show indicator dots
- [ ] Hidden apps appear translucent
- [ ] Minimize animation uses "scale" effect
- [ ] Windows minimize into app icon
- [ ] Mission Control animations are fast
- [ ] Spaces don't auto-rearrange

**T014 Commit Message**:

```
feat: complete Dock migration from dotfiles (spec 007)

User Story 1: Dock Items
- Migrate all 17 Dock items from dotfiles (14 apps, 3 spacers, 1 folder)
- Use helper library functions (mkDockAddApp, mkDockAddSpacer, mkDockAddFolder)
- Configure explicit positions for correct order

User Story 2: Dock Preferences
- Migrate 13 preferences via nix-darwin system.defaults.dock
- Migrate 2 preferences via activation script (not in nix-darwin)
- All preferences tested and validated

Documentation:
- Update unresolved-migration.md (mark item #8 resolved)
- Idempotent configuration (safe to rerun)

Completes spec 007 (child of spec 002)
Uses helper library from spec 006
```

______________________________________________________________________

## Parallel Execution Opportunities

### Within User Story 1

Tasks T004, T005 can run in parallel:

```bash
# Terminal 1
git checkout -b us1-backup
# T004: Create backup
cp modules/darwin/system/dock.nix modules/darwin/system/dock.nix.bak

# Terminal 2
git checkout -b us1-implementation
# T005: Start deleting placeholder content
vim modules/darwin/system/dock.nix
```

### Across User Stories

US1 (T004-T008) and US2 (T009-T011) can be implemented in parallel:

```bash
# Developer A: Works on US1
git checkout -b feature/us1-dock-items
# Implement T004-T008

# Developer B: Works on US2 (simultaneously)
git checkout -b feature/us2-dock-preferences
# Implement T009-T011

# Merge both when complete
```

**Benefit**: 2 developers can complete implementation in parallel, reducing time by ~50%

______________________________________________________________________

## Task Checklist Summary

**Phase 1: Setup** (1 task)

- [ ] T001 Verify prerequisites

**Phase 2: Foundational** (2 tasks)

- [ ] T002 Read current dock.nix
- [ ] T003 Review dotfiles Dock configuration

**Phase 3: US1 - Dock Items** (5 tasks)

- [ ] T004 [P] [US1] Backup current dock.nix
- [ ] T005 [P] [US1] Delete placeholder items
- [ ] T006 [US1] Add 14 applications
- [ ] T007 [US1] Add 3 spacers + folder
- [ ] T008 [US1] Test US1 completion

**Phase 4: US2 - Dock Preferences** (3 tasks)

- [ ] T009 [P] [US2] Add nix-darwin preferences
- [ ] T010 [US2] Add activation script preferences
- [ ] T011 [US2] Test US2 completion

**Phase 5: Polish** (3 tasks)

- [ ] T012 Update unresolved-migration.md
- [ ] T013 Final validation
- [ ] T014 Commit changes

**Total**: 14 tasks (3 parallelizable)

______________________________________________________________________

## Implementation Notes

### Code Structure

The final `dock.nix` should have this structure:

```nix
{ config, lib, pkgs, ... }:

let
  macLib = import ../lib/mac.nix { inherit pkgs lib config; };
  primaryUser = config.users.primaryUser or "charles";
in
{
  # Section 1: nix-darwin Dock preferences (US2 - T009)
  system.defaults.dock = {
    # 13 settings
  };

  # Section 2: Activation script (US2 - T010 + US1 - T006-T007)
  system.activationScripts.configureDock = {
    text = ''
      # Additional preferences (T010)
      defaults write com.apple.dock mouse-over-hilite-stack -bool true
      defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool true
      
      # Configure Dock items (T006-T007)
      ${macLib.mkDockClear}
      
      # Main applications (T006)
      ${macLib.mkDockAddApp { path = "/Applications/Zen.app"; position = 1; }}
      # ... (all 14 apps)
      
      # Spacers and folder (T007)
      ${macLib.mkDockAddSpacer}  # After position 6
      ${macLib.mkDockAddSpacer}  # After position 11
      ${macLib.mkDockAddSpacer}  # After position 15
      ${macLib.mkDockAddFolder { path = "/Users/${primaryUser}/Downloads"; view = "fan"; display = "stack"; sort = "dateadded"; }}
      
      # Restart Dock
      ${macLib.mkDockRestart}
    '';
  };
}
```

### Common Issues & Solutions

**Issue 1**: Application not installed

- **Symptom**: App missing from Dock after build
- **Solution**: Install app before running `darwin-rebuild switch`
- **Prevention**: Document prerequisite in quickstart.md

**Issue 2**: Wrong Dock order

- **Symptom**: Apps appear but not in expected sequence
- **Solution**: Verify position numbers are sequential and correct
- **Prevention**: Use explicit positions in mkDockAddApp calls

**Issue 3**: Preferences not applied

- **Symptom**: Dock behavior doesn't match expected
- **Solution**: Run `defaults read com.apple.dock` to check values, restart Dock manually
- **Prevention**: Ensure mkDockRestart is called at end of activation script

### Testing Strategy

1. **Unit Testing**: Each helper function tested in spec 006
1. **Integration Testing**:
   - US1 independent test (T008): Dock items only
   - US2 independent test (T011): Dock preferences only
   - Combined test (T013): Both items and preferences
1. **Idempotency Testing**: Run `darwin-rebuild switch` twice, verify no errors
1. **Visual Testing**: Manual verification of Dock layout and behavior

______________________________________________________________________

## Success Criteria

**Definition of Done**:

- [x] All 14 tasks completed (checked off)
- [x] US1 acceptance criteria met (17 Dock items configured)
- [x] US2 acceptance criteria met (15 Dock preferences applied)
- [x] US1 independent tests pass (T008)
- [x] US2 independent tests pass (T011)
- [x] Final validation checklist complete (T013)
- [x] Documentation updated (T012)
- [x] Changes committed (T014)
- [x] No errors during `darwin-rebuild switch`
- [x] Idempotency validated (can rerun safely)

**Ready for Merge**: All checkboxes above checked, no blocking issues

______________________________________________________________________

## References

- **Feature Spec**: [spec.md](./spec.md)
- **Implementation Plan**: [plan.md](./plan.md)
- **Research**: [research.md](./research.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Quickstart Guide**: [quickstart.md](./quickstart.md)
- **Helper Library**: `modules/darwin/lib/mac.nix` (spec 006)
- **Target Module**: `modules/darwin/system/dock.nix`
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
