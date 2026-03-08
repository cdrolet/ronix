# Implementation Plan: Segregate Settings Directories

**Branch**: `039-segregate-settings-directories` | **Date**: 2026-01-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/039-segregate-settings-directories/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Eliminate fragile `options ? home` guards by segregating settings into `system/` and `user/` subdirectories. System-level discovery only loads from `settings/system/`, home-manager discovery only loads from `settings/user/`, preventing context mismatch errors and enabling clean automatic discovery without manual guards.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nix-darwin, Home Manager, nixpkgs (via flake inputs)\
**Storage**: File system (Nix expressions in .nix files, directory scanning)\
**Testing**: `nix flake check` (syntax validation), `nix build` (build verification)\
**Target Platform**: macOS (darwin), NixOS (nixos), cross-platform (via Home Manager)\
**Project Type**: Configuration management (nix-config repository)\
**Performance Goals**: Instant module discovery (< 1s), zero build errors from context mismatches\
**Constraints**:

- Module size < 200 lines (constitution requirement)
- No backward compatibility (clean breaks permitted)
- Pure data pattern for user/host configs (no imports in config files)
- Hierarchical discovery (system → families → shared)\
  **Scale/Scope**:
- ~40-50 settings modules across 3 platforms (darwin, nixos, shared)
- ~20-30 system-level settings (NixOS services, display managers, boot, etc.)
- ~10-20 user-level settings (dconf, shell aliases, file associations, etc.)
- 3 users, 2-3 hosts per platform
- GNOME family with 10+ settings modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

✅ **I. Declarative Configuration First**: Settings remain declarative Nix expressions, only directory structure changes

✅ **II. Modularity and Reusability**: Improves modularity by enforcing clean context separation, no change to app-centric organization

✅ **III. Documentation-Driven Development**: Will update CLAUDE.md and create docs/features/039-segregate-settings-directories.md

✅ **IV. Purity and Reproducibility**: No impact on purity, purely structural refactoring

✅ **V. Testing and Validation**: Will validate with `nix flake check` and build tests for both contexts

✅ **VI. Cross-Platform Compatibility**: Enhances cross-platform by clarifying system vs user boundaries

### Architectural Standards Compliance

✅ **Flakes as Entry Point**: No changes to flake.nix structure

✅ **Home Manager Integration**: Improves integration by clean context separation

✅ **Directory Structure Standard**: Modifies settings directories to add `system/` and `user/` subdirectories:

- `system/darwin/settings/` → `system/darwin/settings/{system,user}/`
- `system/nixos/settings/` → `system/nixos/settings/{system,user}/`
- `system/shared/family/gnome/settings/` → `system/shared/family/gnome/settings/{system,user}/`
- Constitution allows this as improvement to existing structure

### Development Standards Compliance

✅ **Context Validation**: **DIRECTLY ADDRESSES** Constitution v2.3.0 requirement - eliminates need for manual `options ? home` guards by structural separation

✅ **Specification Management**: Following spec-driven process with this plan

✅ **Refactoring Discipline**: This IS a refactoring - segregating settings replaces fragile guard pattern

✅ **No Backward Compatibility**: Clean break permitted - will update all imports and discovery logic

✅ **Configuration Module Organization**: Settings remain topic-based, organization improves with clearer context separation

✅ **Helper Libraries and Activation Scripts**: Discovery system will be enhanced to support subdirectory filtering

### Constitutional Gates: **ALL PASS** ✅

This feature directly addresses a constitutional requirement (Context Validation v2.3.0) by eliminating the fragile guard pattern through structural separation. No violations or exceptions needed.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This feature modifies the settings directory structure across all platforms and families:

```text
system/
├── darwin/
│   └── settings/
│       ├── system/           # NEW: System-level darwin settings
│       │   ├── default.nix   # Auto-discovery (imports all .nix in system/)
│       │   ├── dock.nix      # System dock configuration
│       │   └── defaults.nix  # macOS system defaults
│       └── user/             # NEW: User-level darwin settings
│           ├── default.nix   # Auto-discovery (imports all .nix in user/)
│           └── aliases.nix   # Shell aliases
│
├── nixos/
│   └── settings/
│       ├── system/           # NEW: System-level nixos settings
│       │   ├── default.nix   # Auto-discovery
│       │   ├── security.nix  # Firewall, sudo, polkit
│       │   ├── network.nix   # NetworkManager, DNS
│       │   ├── boot.nix      # Boot loader configuration
│       │   └── system.nix    # Nix settings, GC
│       └── user/             # NEW: User-level nixos settings
│           ├── default.nix   # Auto-discovery
│           └── locale.nix    # User locale preferences
│
└── shared/
    ├── family/
    │   ├── gnome/
    │   │   └── settings/
    │   │       ├── system/           # NEW: GNOME system-level settings
    │   │       │   ├── default.nix   # Auto-discovery
    │   │       │   ├── desktop/
    │   │       │   │   ├── gnome-core.nix      # GNOME Shell, GDM
    │   │       │   │   ├── gnome-optional.nix  # Optional components
    │   │       │   │   └── gnome-exclude.nix   # Exclude packages
    │   │       │   └── wayland.nix   # Wayland display server
    │   │       └── user/             # NEW: GNOME user-level settings
    │   │           ├── default.nix   # Auto-discovery
    │   │           ├── ui.nix        # Dark mode, fonts (dconf)
    │   │           ├── keyboard.nix  # Window shortcuts
    │   │           ├── power.nix     # Screen timeout
    │   │           ├── dock.nix      # Dock favorites
    │   │           └── shortcuts.nix # Global shortcuts
    │   └── linux/
    │       └── settings/
    │           ├── system/           # NEW: Linux system-level settings
    │           │   └── default.nix   # Auto-discovery
    │           └── user/             # NEW: Linux user-level settings
    │               ├── default.nix   # Auto-discovery
    │               └── keyboard.nix  # Mac-style modifier remapping
    │
    ├── settings/
    │   ├── system/           # NEW: Shared system-level settings (if any)
    │   │   └── default.nix   # Auto-discovery
    │   └── user/             # NEW: Shared user-level settings
    │       ├── default.nix   # Auto-discovery
    │       └── password.nix  # MOVED: User password activation
    │
    └── lib/
        └── discovery.nix     # MODIFIED: Add subdirectory filtering

user/
└── shared/
    └── lib/
        └── home.nix          # MODIFIED: Update imports for new structure
```

**Key Changes**:

1. **New subdirectories**: Every `settings/` directory gets `system/` and `user/` subdirectories
1. **Auto-discovery per context**: Each subdirectory has its own `default.nix` for auto-discovery
1. **Setting migrations**: Existing settings move to appropriate subdirectory based on their purpose
1. **Discovery enhancements**: `discovery.nix` gains context-aware subdirectory filtering
1. **Guard elimination**: Settings lose `options ? home` guards as they're now structurally separated

**Structure Decision**: Settings directory segregation pattern - each settings location gets `system/` and `user/` subdirectories with independent auto-discovery. This mirrors the existing hierarchical structure while adding context-based filtering at the directory level.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No constitutional violations - this feature directly addresses a constitutional requirement (Context Validation v2.3.0).

______________________________________________________________________

## Phase 0: Research Summary

**Status**: ✅ Complete\
**Artifacts**: [research.md](./research.md)

**Key Findings**:

1. **Current Discovery Mechanism**:

   - `discoverModules` scans entire settings directories recursively
   - Context handled by manual `lib.optionalAttrs (options ? home)` guards in each file
   - Guards are fragile and frequently forgotten

1. **Import Locations**:

   - System settings: Imported before home-manager (no `home` option)
   - User settings: Imported during home-manager activation (has `home` option)
   - Two-stage build process (Feature 036)

1. **Solution Design**:

   - Add `discoverModulesInContext` function to discovery.nix
   - Create `system/` and `user/` subdirectories in all settings locations
   - Each subdirectory gets own `default.nix` with auto-discovery
   - Platform libraries import appropriate subdirectory based on build stage

1. **Settings Categorization** (51 files audited):

   - System-level: Services, boot, network, desktop environment installation (~30 files)
   - User-level: Preferences, dconf, GTK themes, aliases, fonts (~20 files)
   - Some settings need splitting (locale, keyboard)

1. **Migration Strategy**:

   - 5 phases: Structure → Move → Update Discovery → Remove Guards → Cleanup
   - Verification at each phase with `nix flake check` and builds

**Technical Decisions**:

- Subdirectory naming: `system/` and `user/` (clear, self-documenting)
- Discovery design: New `discoverModulesInContext` function (backward compatible)
- Two `default.nix` per settings directory (maintains auto-discovery pattern)

**Risks Identified**:

- Breaking builds during migration (mitigate with incremental phases)
- Miscategorizing settings (mitigate with clear criteria and testing)

**No Blockers** - Ready to proceed to Phase 1 (Design)
