# Implementation Plan: Complete Dock Migration from Dotfiles

**Branch**: `007-007-complete-dock-migration` | **Date**: 2025-10-27 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `/specs/007-007-complete-dock-migration/spec.md`

## Summary

Replace the placeholder Dock configuration in `modules/darwin/system/dock.nix` with the actual configuration from dotfiles (`~/project/dotfiles/scripts/sh/darwin/system.sh`). Migrate all 17 Dock items (apps, spacers, folders) and 14 Dock preferences using helper library functions from spec 006. Use nix-darwin `system.defaults.dock.*` options where available, and activation scripts for remaining settings. This completes unresolved migration item #8 from spec 002.

## Technical Context

**Language/Version**: Nix 2.19+, Bash 5.x (for activation scripts)\
**Primary Dependencies**: nix-darwin, nixpkgs (dockutil package), helper library (spec 006)\
**Storage**: N/A (configuration only)\
**Testing**: Manual validation with `darwin-rebuild switch`, visual inspection of Dock\
**Target Platform**: macOS (Darwin) with nix-darwin\
**Project Type**: System configuration (Nix expressions)\
**Performance Goals**: Dock configuration completes \<10 seconds during `darwin-rebuild switch`\
**Constraints**: Must use helper library functions exclusively, no direct dockutil commands\
**Scale/Scope**: 1 module file (`dock.nix`), 17 Dock items, 14 Dock preferences

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Declarative Configuration First

- **Status**: PASS
- **Verification**: All Dock configuration declared in `dock.nix`, no manual steps required
- **Rationale**: Dock items via activation scripts, preferences via nix-darwin defaults

### ✅ Modularity and Reusability

- **Status**: PASS
- **Verification**: `dock.nix` is self-contained module, uses reusable helper library functions
- **Dependencies**: Explicitly declares dependency on `modules/darwin/lib/mac.nix`

### ✅ Documentation-Driven Development

- **Status**: PASS
- **Verification**: Feature spec complete, plan documents all decisions, comments in code
- **Deliverables**: This plan, research.md, data-model.md, quickstart.md, inline code comments

### ✅ Purity and Reproducibility

- **Status**: PASS
- **Verification**: Configuration is deterministic, idempotent helper functions ensure safe rerun
- **Testing**: Idempotency validated by running `darwin-rebuild switch` multiple times

### ✅ Activation Scripts and Helper Libraries (NON-NEGOTIABLE)

- **Status**: PASS
- **Verification**: Uses helper library functions from `modules/darwin/lib/mac.nix` (spec 006)
- **Pattern**:
  - Dock items: `mkDockClear`, `mkDockAddApp`, `mkDockAddSpacer`, `mkDockAddFolder`, `mkDockRestart`
  - Additional preferences: Activation script with `defaults write` commands
  - No code duplication, all logic in reusable helpers
- **Idempotency**: All functions check current state before modifying
- **Declarative style**: High-level function calls, not verbose inline commands

**Constitution Check Result**: ✅ ALL GATES PASSED

## Project Structure

### Documentation (this feature)

```text
specs/007-007-complete-dock-migration/
├── spec.md              # Feature specification (COMPLETE)
├── plan.md              # This file (IN PROGRESS)
├── research.md          # Phase 0 output (PENDING)
├── data-model.md        # Phase 1 output (PENDING)
├── quickstart.md        # Phase 1 output (PENDING)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
modules/darwin/
├── lib/
│   └── mac.nix                    # Helper library (spec 006, EXISTS)
└── system/
    ├── default.nix                # Imports dock.nix (EXISTS)
    └── dock.nix                   # TARGET FILE - will be completely rewritten
```

**Structure Decision**: Single configuration file approach. `dock.nix` contains both nix-darwin defaults declarations and activation script that uses helper library functions. No new files needed, complete replacement of existing `dock.nix`.

## Complexity Tracking

**No violations requiring justification** - All constitution checks passed.

______________________________________________________________________

## Phase 0: Research & Discovery

**Objective**: Resolve all technical unknowns about Dock configuration migration

### Research Tasks

#### R1: Map Dock Preferences to nix-darwin Options

**Question**: Which of the 14 Dock preferences from dotfiles have corresponding nix-darwin options?

**Investigation Required**:

- Review nix-darwin documentation for `system.defaults.dock.*` options
- Check nix-darwin source code for available dock settings
- Identify which settings require activation scripts

**Expected Output**: Mapping table in `research.md` showing:

- Settings available in nix-darwin (use defaults)
- Settings requiring activation scripts (use `defaults write`)
- Any deprecated or unavailable settings

#### R2: Verify Application Paths

**Question**: Do all application paths from dotfiles exist on target macOS system?

**Investigation Required**:

- Check if all apps in `dockItems` array are installed
- Verify system app paths (e.g., `/System/Applications/`)
- Determine if any paths need adjustment for Nix-installed apps

**Expected Output**: Validated application path list with corrections if needed

#### R3: Helper Library Function Review

**Question**: Confirm all required helper functions exist and work as expected

**Investigation Required**:

- Review `modules/darwin/lib/mac.nix` for required functions
- Verify function signatures match usage needs
- Test function output with sample inputs

**Expected Output**: Confirmed availability of:

- `mkDockClear`
- `mkDockAddApp { path, position }`
- `mkDockAddSpacer`
- `mkDockAddFolder { path, view, display }`
- `mkDockRestart`

#### R4: Folder View Options

**Question**: What are the valid options for `mkDockAddFolder` view and display parameters?

**Investigation Required**:

- Review dockutil documentation for folder options
- Check `mac.nix` function implementation
- Determine appropriate settings for Downloads folder

**Expected Output**: Valid values for:

- `view`: fan, grid, list, automatic
- `display`: folder, stack
- `sort`: name, dateadded, datemodified, datecreated, kind

### Research Deliverable

**File**: `research.md`\
**Content Structure**:

```markdown
# Research: Complete Dock Migration

## Decision 1: nix-darwin vs Activation Scripts Split
**Decision**: Use nix-darwin for 11 settings, activation scripts for 3 settings
**Rationale**: [mapping table]
**Alternatives**: All activation scripts (rejected: unnecessarily imperative)

## Decision 2: Application Paths
**Decision**: Use paths as-is from dotfiles
**Rationale**: [verification results]
**Alternatives**: N/A

## Decision 3: Folder Configuration
**Decision**: Downloads folder with fan view, stack display, dateadded sort
**Rationale**: Matches dotfiles behavior
**Alternatives**: N/A
```

______________________________________________________________________

## Phase 1: Design & Contracts

**Prerequisites**: `research.md` complete with all decisions documented

### Design Tasks

#### D1: Create Data Model

**Objective**: Document the structure of Dock configuration

**Deliverable**: `data-model.md` containing:

- Dock item entity (apps, spacers, folders)
- Dock preference entity (defaults settings)
- Relationships between items and order
- Validation rules (path exists, valid positions)

#### D2: Design Module Structure

**Objective**: Define the complete structure of new `dock.nix`

**Deliverable**: Outline in `data-model.md`:

```nix
{
  # Section 1: nix-darwin defaults
  system.defaults.dock = {
    # 11 settings from research mapping
  };

  # Section 2: Activation script with helper functions
  system.activationScripts.configureDock = {
    text = ''
      # Additional preferences (3 settings)
      # Dock items (17 items using helper functions)
    '';
  };
}
```

#### D3: Generate Quickstart Guide

**Objective**: Provide step-by-step instructions for applying configuration

**Deliverable**: `quickstart.md` with:

- Prerequisites (helper library, dockutil)
- Build command: `darwin-rebuild switch --flake .#<hostname>`
- Validation steps (check Dock visually, verify preferences)
- Troubleshooting common issues

#### D4: Update Agent Context

**Objective**: Add Dock configuration tech to CLAUDE.md

**Action**: Run update script:

```bash
.specify/scripts/bash/update-agent-context.sh claude
```

**Expected Changes**:

- Add "Dock configuration (dockutil, nix-darwin defaults)" to Active Technologies
- Update "Recent Changes" section with spec 007

### Design Deliverables

**Files**:

1. `data-model.md` - Entities, relationships, validation rules
1. `quickstart.md` - Usage instructions and validation
1. `CLAUDE.md` - Updated agent context

______________________________________________________________________

## Phase 2: Implementation Planning (OUT OF SCOPE)

**Note**: Phase 2 (task breakdown) is handled by `/speckit.tasks` command, not `/speckit.plan`.

The plan command stops after Phase 1 design artifacts are generated. Implementation tasks will be created separately.

______________________________________________________________________

## Key Decisions

### Decision 1: Complete Replacement Strategy

**Choice**: Delete all current `dock.nix` content and rewrite from scratch\
**Rationale**: Current content is placeholder/example, doesn't match user's actual workflow\
**Alternatives Considered**:

- Incremental update (rejected: current config has no value to preserve)
- Merge approach (rejected: introduces complexity, source of truth should be dotfiles)

### Decision 2: Two-Phase Configuration

**Choice**: nix-darwin defaults first, then activation script\
**Rationale**: Use built-in options where available, activation scripts only for gaps\
**Alternatives Considered**:

- All activation scripts (rejected: unnecessarily imperative)
- Complex custom module (rejected: overengineering)

### Decision 3: Helper Library Exclusive Usage

**Choice**: Use only helper library functions, no direct dockutil commands\
**Rationale**: Constitution requirement (NON-NEGOTIABLE), ensures idempotency and reusability\
**Alternatives Considered**: None (constitution requirement)

### Decision 4: Abandon Spotlight Indexing

**Choice**: Do not migrate unresolved item #6 (Spotlight Indexing Order)\
**Rationale**: User explicitly requested abandonment, complex structure, low value\
**Alternatives Considered**: None (user decision)

______________________________________________________________________

## Risk Mitigation

### Risk 1: Application Not Installed

**Impact**: dockutil fails silently, Dock item missing\
**Mitigation**: Document prerequisite of installing all apps before running config\
**Detection**: Visual inspection of Dock after `darwin-rebuild switch`

### Risk 2: nix-darwin Option Changes

**Impact**: Settings fail if nix-darwin removes/renames options\
**Mitigation**: Pin nix-darwin version in flake.lock, test before updates\
**Fallback**: Move affected settings to activation scripts

### Risk 3: Path Escaping Issues

**Impact**: Apps with spaces in path fail to add to Dock\
**Mitigation**: Helper library already handles escaping, verify with `Visual Studio Code.app`\
**Testing**: Include app with space in initial testing

______________________________________________________________________

## Success Metrics

1. **Functional Completeness**: All 17 Dock items appear in correct order
1. **Preference Accuracy**: All 14 Dock settings applied correctly
1. **Idempotency**: `darwin-rebuild switch` succeeds when run twice consecutively
1. **Documentation**: Spec 002's unresolved-migration.md updated (item #8 marked resolved)
1. **Code Quality**: No direct dockutil commands, helper functions used throughout

______________________________________________________________________

## Next Steps

1. **Generate Research** (Phase 0):

   - Map nix-darwin options to dotfiles settings
   - Verify application paths
   - Confirm helper library functions

1. **Generate Design Artifacts** (Phase 1):

   - Create `data-model.md` with entities and structure
   - Write `quickstart.md` with usage instructions
   - Update `CLAUDE.md` with new technology

1. **Execute Implementation** (Phase 2 - separate command):

   - Run `/speckit.tasks` to generate implementation tasks
   - Rewrite `dock.nix` with actual configuration
   - Test on development machine
   - Update spec 002 documentation

______________________________________________________________________

## References

- **Feature Spec**: [spec.md](./spec.md)
- **Parent Spec**: [002-darwin-system-restructure](../002-darwin-system-restructure/spec.md)
- **Dependency Spec**: [006-reusable-helper-library](../006-reusable-helper-library/spec.md)
- **Helper Library**: `modules/darwin/lib/mac.nix`
- **Target Module**: `modules/darwin/system/dock.nix`
- **Dotfiles Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- **Constitution**: `.specify/memory/constitution.md`
