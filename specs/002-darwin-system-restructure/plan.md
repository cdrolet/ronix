# Implementation Plan: Darwin System Defaults Restructuring and Migration

**Branch**: `002-darwin-system-restructure` | **Date**: 2025-10-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-darwin-system-restructure/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Restructure the monolithic `modules/darwin/defaults.nix` into a modular system folder with topic-specific files (dock.nix, finder.nix, trackpad.nix, etc.). Migrate additional macOS system defaults from the dotfiles repository's `scripts/sh/darwin/system.sh` to the appropriate Nix files. The restructured defaults.nix becomes an import-only orchestration file, with migrated system.sh settings taking precedence. Settings that cannot be migrated are documented in `unresolved-migration.md`, and deprecated settings are skipped with post-migration reporting.

**Note**: Documentation of the darwin system structure, constitution updates, and establishment of cross-platform organizational patterns are covered separately in spec 003-nix-config-documentation.

## Technical Context

**Language/Version**: Nix 2.19+, Bash 5.x (for script analysis)
**Primary Dependencies**: nix-darwin, nixpkgs (darwin-specific modules)
**Storage**: File system (Nix expressions in .nix files)
**Testing**: `darwin-rebuild build` for syntax/build validation, `darwin-rebuild switch --dry-run` for preview, `defaults read` for runtime verification
**Target Platform**: macOS (nix-darwin managed systems)
**Project Type**: Configuration management (declarative system configuration)
**Performance Goals**: Configuration apply time \<5 minutes for full system rebuild, instant for incremental changes
**Constraints**: Must maintain 100% functional compatibility with existing configuration during restructuring, zero breaking changes for existing hosts
**Scale/Scope**: ~100-150 system default settings across 8+ topic files, migration of ~150+ settings from system.sh, affects all darwin hosts in the repository

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Declarative Configuration First

**Status**: ✅ PASS

- All restructured configuration remains fully declarative in Nix
- No imperative steps introduced
- Migration from bash scripts to Nix expressions enhances declarative purity

### Principle II: Modularity and Reusability

**Status**: ✅ PASS

- Restructuring into topic-specific modules (dock.nix, finder.nix, etc.) enhances modularity
- Follows Blueprint pattern with configurations in `modules/darwin/system/`
- Each topic module has single, well-defined purpose

### Principle III: Documentation-Driven Development

**Status**: ✅ PASS (with requirements)

- MUST document each topic-specific module with purpose, options, examples
- MUST create `unresolved-migration.md` documenting settings that cannot be migrated
- MUST generate post-migration report for deprecated settings

### Principle IV: Purity and Reproducibility

**Status**: ✅ PASS

- All configurations remain pure Nix expressions
- No network access or impure operations introduced
- Settings migrated from bash maintain deterministic behavior

### Principle V: Testing and Validation

**Status**: ✅ PASS (with requirements)

- MUST validate with `nix flake check` and `darwin-rebuild build`
- MUST test on darwin hosts before and after restructuring
- MUST verify all settings apply correctly with `defaults read`
- Rollback documented (git revert to previous commit)

### Principle VI: Cross-Platform Compatibility

**Status**: ✅ PASS

- Changes are darwin-specific, do not affect NixOS or other platforms
- Establishes pattern that CAN be applied to other platforms
- Uses platform-appropriate tools (nix-darwin for macOS)

### Architectural Standards: Flakes as Entry Point

**Status**: ✅ PASS

- No changes to flake.nix required
- Changes are within existing module structure

### Architectural Standards: Directory Structure

**Status**: ✅ PASS

- Follows Blueprint pattern: `modules/darwin/system/` for system defaults
- Aligns with constitution's required directory layout
- New structure: `modules/darwin/system/{default.nix,dock.nix,finder.nix,...}`

### Code Organization Standards

**Status**: ✅ PASS (with requirement)

- Topic-specific files SHOULD remain under 200 lines each
- If any file exceeds 200 lines, MUST refactor into sub-modules

**Overall Gate Status**: ✅ **PASS** - No constitutional violations. All principles satisfied with documented requirements.

______________________________________________________________________

## Post-Design Constitution Re-Check

*Re-evaluated after Phase 1 design (research.md, data-model.md, quickstart.md)*

### Design Artifacts Review

**research.md**: ✅ Complies

- Documents technology decisions (nix-darwin, typed options vs CustomUserPreferences)
- Provides rationale for choices
- Identifies risks and mitigations
- No constitutional concerns

**data-model.md**: ✅ Complies

- Defines modular structure (TopicModule, SystemSetting, SystemAggregator)
- Establishes clear entity relationships
- Provides validation rules
- Supports ≤200 line module requirement

**quickstart.md**: ✅ Complies

- Documents testing procedures
- Provides validation checklists
- Includes rollback procedures
- Supports Principle V (Testing and Validation)

### Principle Re-Validation

All principles remain satisfied:

- ✅ Declarative Configuration First: Design maintains pure Nix expressions
- ✅ Modularity and Reusability: Topic-based modules well-defined
- ✅ Documentation-Driven Development: All artifacts properly documented
- ✅ Purity and Reproducibility: No impure operations introduced in design
- ✅ Testing and Validation: Comprehensive testing strategy in quickstart.md
- ✅ Cross-Platform Compatibility: Darwin-specific, doesn't affect other platforms
- ✅ Architectural Standards: Follows Blueprint pattern, proper directory structure

**Final Gate Status**: ✅ **PASS** - Design phase complete, all constitutional requirements satisfied. Ready for `/speckit.tasks`.

## Project Structure

### Documentation (this feature)

```text
specs/002-darwin-system-restructure/
├── spec.md              # Feature specification
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── unresolved-migration.md  # Settings that cannot be migrated
├── deprecated-settings.md   # Post-migration report of skipped settings
├── checklists/
│   └── requirements.md  # Specification quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
modules/darwin/
├── default.nix          # Darwin module aggregator (unchanged)
├── defaults.nix         # BECOMES import-only orchestration file
└── system/              # NEW: Topic-specific system defaults
    ├── default.nix      # Import all topic modules
    ├── dock.nix         # Dock settings
    ├── finder.nix       # Finder settings (including Finder-specific shortcuts)
    ├── trackpad.nix     # Trackpad/mouse settings
    ├── keyboard.nix     # System-wide keyboard settings only
    ├── screen.nix       # Screen/display settings
    ├── security.nix     # Security & privacy settings
    ├── network.nix      # Network settings
    ├── power.nix        # Battery/power settings
    ├── ui.nix           # UI/visual effects/menu bar
    ├── accessibility.nix # Accessibility settings
    ├── applications.nix # Application-specific defaults (Safari, Mail, etc.)
    └── system.nix       # General system settings


```

**Structure Decision**: Configuration management structure following nix-darwin Blueprint pattern. All system defaults moved from monolithic `defaults.nix` to topic-specific modules under `modules/darwin/system/`. The original `defaults.nix` becomes an import-only file that references `system/default.nix`.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

**No violations detected.** This section is not applicable for this feature as all constitutional gates pass.
