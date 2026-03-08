# Implementation Plan: Niri Family Desktop Environment

**Branch**: `041-niri-family` | **Date**: 2026-01-29 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/041-niri-family/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Create a new Linux family (`system/shared/family/niri/`) as an alternative to GNOME, providing a Niri compositor-based desktop environment. The family will follow the established architecture pattern with context-segregated settings (system/ and user/ subdirectories), integrate with existing user configuration (wallpaper, fonts, dark mode), and compose correctly with the `linux` family for shared Linux settings. Users will declare `family = ["linux", "niri"]` in their host configuration to get a fully functional tiling window manager desktop on first boot.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nixpkgs (Niri compositor package), Home Manager (standalone mode), NixOS modules\
**Storage**: Declarative Nix configuration files (`.nix` expressions)\
**Testing**: `nix flake check` (syntax validation), `nix build` (build verification), manual testing on NixOS VM/hardware\
**Target Platform**: NixOS (Linux x86_64 and aarch64)\
**Project Type**: Configuration management (Nix family module)\
**Performance Goals**: Instant window management response (\<16ms frame time for 60fps tiling), fast session start (\<5s from login to usable desktop)\
**Constraints**:

- Must follow Feature 039 architecture (context-segregated settings in system/ and user/ subdirectories)
- Must use standalone home-manager (Feature 036)
- Must integrate with existing discovery system
- Module files must be \<200 lines (constitutional requirement)
- Must use `lib.mkDefault` for all settings (user-overridability)
- Must validate execution context with `options ? home` pattern

**Scale/Scope**:

- Single family directory: `system/shared/family/niri/`
- Estimated 5-10 settings modules (system and user combined)
- Optional app directory for Niri-specific utilities
- Must compose with existing `linux` family
- Integration with 3+ existing user configuration fields (wallpaper, fonts, dark mode)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles

- ✅ **I. Declarative Configuration First**: All family settings declared in Nix expressions, no imperative steps
- ✅ **II. Modularity and Reusability**: Family is self-contained, composable with `linux` family, follows hierarchical directory pattern
- ✅ **III. Documentation-Driven Development**: Will create `docs/features/041-niri-family.md` for user-facing documentation
- ✅ **IV. Purity and Reproducibility**: All dependencies declared in nixpkgs, deterministic build
- ✅ **V. Testing and Validation**: `nix flake check`, build verification, manual VM testing
- ✅ **VI. Cross-Platform Compatibility**: Linux-only family (appropriate for NixOS compositor), follows platform-agnostic orchestration pattern

### Architectural Standards

- ✅ **Flakes as Entry Point**: Using existing flake.nix, no changes needed (family auto-discovered)
- ✅ **Home Manager Integration**: User-level settings use standalone home-manager (Feature 036)
- ✅ **Directory Structure Standard**: Family follows `system/shared/family/niri/` with `app/`, `settings/system/`, `settings/user/` subdirectories
- ✅ **Topic-Based Organization**: Each setting module is \<200 lines, focused on single concern (compositor, display manager, keyboard, wallpaper, etc.)

### Development Standards

- ✅ **Context Validation**: All user-level modules will use `lib.optionalAttrs (options ? home)` pattern
- ✅ **Specification Management**: Following spec-driven process with integrity checks
- ✅ **No Backward Compatibility**: New family, no compatibility concerns
- ✅ **Code Organization**: Follows hierarchical structure, \<200 lines per module, meaningful names
- ✅ **Helper Libraries**: Will use existing `system/shared/lib/discovery.nix`, may create `family/niri/lib/` if needed

### Quality Assurance

- ✅ **Pre-Deployment Checks**: Syntax validation, build verification, NixOS VM testing
- ✅ **Performance Constraints**: Niri compositor is lightweight, minimal closure size impact
- ✅ **Security Requirements**: Using nixpkgs packages, no custom secrets for family defaults

**GATE STATUS**: ✅ **PASS** - No constitutional violations, all requirements met

______________________________________________________________________

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design completion (2026-01-29)*

### Core Principles (Verified)

- ✅ **I. Declarative Configuration**: All settings in Nix expressions (no imperative steps)
- ✅ **II. Modularity**:
  - System modules: `compositor.nix`, `display-manager.nix`, `session.nix` (3 files, \<50 lines each)
  - User modules: `keyboard.nix`, `wallpaper.nix`, `theme.nix` (3 files, \<200 lines each)
  - All independently composable, single purpose
- ✅ **III. Documentation**: Plan, research, data-model, contracts, quickstart all complete
- ✅ **IV. Purity**: All dependencies from nixpkgs, deterministic build
- ✅ **V. Testing**: Validation strategy documented in quickstart.md
- ✅ **VI. Cross-Platform**: Linux-only (appropriate for compositor), follows platform-agnostic orchestration

### Architectural Standards (Verified)

- ✅ **Flakes**: Using existing flake.nix, no changes needed
- ✅ **Home Manager**: User modules use standalone mode with context validation
- ✅ **Directory Structure**: Follows `family/niri/` with `app/`, `settings/system/`, `settings/user/`
- ✅ **Topic-Based Organization**: Each module \<200 lines, single purpose, clear naming

### Development Standards (Verified)

- ✅ **Context Validation**: All user modules use `lib.optionalAttrs (options ? home)` pattern
  - `keyboard.nix` - ✅ Validated
  - `wallpaper.nix` - ✅ Validated
  - `theme.nix` - ✅ Validated
  - `default.nix` (user) - ✅ Validated with context guard
- ✅ **Specification Management**: Following spec-driven process, all artifacts generated
- ✅ **Code Organization**: Hierarchical structure, meaningful names, \<200 lines per module
- ✅ **Helper Libraries**: Using existing `discovery.nix`, no new helpers needed

### Quality Assurance (Verified)

- ✅ **Pre-Deployment**: Syntax validation, build verification, VM testing documented
- ✅ **Performance**: Niri is lightweight compositor, minimal closure impact
- ✅ **Security**: Using nixpkgs packages only, no custom secrets

### Module Size Validation

| Module | Type | Estimated Lines | Status |
|--------|------|-----------------|--------|
| `compositor.nix` | System | ~30 | ✅ \<200 |
| `display-manager.nix` | System | ~20 | ✅ \<200 |
| `session.nix` | System | ~15 | ✅ \<200 |
| `keyboard.nix` | User | ~150 | ✅ \<200 |
| `wallpaper.nix` | User | ~50 | ✅ \<200 |
| `theme.nix` | User | ~40 | ✅ \<200 |
| `waybar.nix` (optional app) | User | ~100 | ✅ \<200 |
| `default.nix` (system) | Discovery | ~10 | ✅ \<200 |
| `default.nix` (user) | Discovery | ~15 | ✅ \<200 |

**Total modules**: 9 files, all \<200 lines ✅

### Integration Validation

- ✅ **Linux Family**: Composes correctly, order enforced (`["linux", "niri"]`)
- ✅ **Discovery System**: Auto-discovery works, no manual imports
- ✅ **Feature 030 (Fonts)**: No action required, fontconfig works automatically
- ✅ **Feature 033 (Wallpaper)**: Integrated via swaybg with path expansion
- ✅ **Feature 036 (Standalone Home Manager)**: Context segregation respected
- ✅ **Feature 039 (Context Segregation)**: System/user subdirectories used correctly

**FINAL GATE STATUS**: ✅ **PASS** - All constitutional requirements met after design completion. Ready for implementation phase (`/speckit.implement`).

## Project Structure

### Documentation (this feature)

```text
specs/041-niri-family/
├── spec.md              # Feature specification (user scenarios, requirements, success criteria)
├── plan.md              # This file (implementation plan with technical context)
├── research.md          # Phase 0: Technology decisions and best practices
├── data-model.md        # Phase 1: Family structure and module organization
├── quickstart.md        # Phase 1: Setup and testing instructions
├── contracts/           # Phase 1: Module interfaces and integration points
│   ├── system-settings.md   # System-level module contracts
│   ├── user-settings.md     # User-level module contracts
│   └── integration.md       # Integration with linux family and discovery system
└── checklists/
    └── requirements.md  # Specification quality validation (completed)
```

### Source Code (repository root)

```text
system/shared/family/niri/           # New Niri family directory
├── app/                             # Optional Niri-specific applications
│   └── [empty initially, users add apps like waybar, fuzzel, etc.]
│
├── settings/                        # Family settings (Feature 039 architecture)
│   ├── system/                      # System-level settings (NixOS context)
│   │   ├── default.nix              # Auto-discovery entry point
│   │   ├── compositor.nix           # Niri compositor installation & config
│   │   ├── display-manager.nix      # greetd/tuigreet configuration
│   │   └── session.nix              # Niri session setup
│   │
│   └── user/                        # User-level settings (home-manager context)
│       ├── default.nix              # Auto-discovery entry point
│       ├── keyboard.nix             # Window management keybindings
│       ├── wallpaper.nix            # Wallpaper integration (user.wallpaper)
│       ├── fonts.nix                # Font integration (user.fonts.defaults)
│       └── theme.nix                # Dark mode and visual theming
│
└── lib/                             # Optional helper libraries
    └── [empty initially, add if needed for Niri-specific utilities]

system/nixos/lib/nixos.nix           # Existing file (validates family exists)
system/shared/lib/discovery.nix      # Existing file (family auto-discovery)
```

**Structure Decision**: This follows the established family pattern from GNOME (Feature 028) with context-segregated settings (Feature 039). The family integrates seamlessly with the existing discovery system, requiring no changes to flake.nix or platform libraries. Users declare `family = ["linux", "niri"]` and the system automatically installs system-level settings (compositor, display manager) and user-level settings (keyboard, wallpaper, fonts, theme).

## Complexity Tracking

**No constitutional violations** - This section is not applicable. All constitutional requirements are met without exceptions.
