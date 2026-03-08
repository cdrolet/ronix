# Implementation Plan: App Category Wildcards

**Branch**: `037-app-category-wildcards` | **Date**: 2026-01-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/037-app-category-wildcards/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable users to install entire app categories using wildcard patterns (e.g., `"productivity/*"`, `"browser/*"`) in their `user.applications` array. The feature extends the existing discovery system (`resolveApplications`) to expand wildcard patterns at Nix evaluation time, respecting the hierarchical discovery order (system → families → shared) and automatically deduplicating results.

## Technical Context

**Language/Version**: Nix 2.19+ (flakes enabled)\
**Primary Dependencies**: nixpkgs lib (builtins.readDir, builtins.match, list functions), existing discovery.nix\
**Storage**: N/A (pure functional transformation at evaluation time)\
**Testing**: nix flake check, integration tests via test user configs\
**Target Platform**: Darwin (nix-darwin) and NixOS (cross-platform)\
**Project Type**: Configuration library extension (extends existing discovery system)\
**Performance Goals**: Wildcard resolution \<1 second for repos with up to 200 apps\
**Constraints**: Pure functions only (no side effects), deterministic results, backward compatible\
**Scale/Scope**: ~50 existing apps across 10 categories, support for up to 200 apps

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ Core Principles

- ✅ **I. Declarative Configuration First**: Wildcard expansion happens at Nix evaluation time (pure, declarative)
- ✅ **II. Modularity and Reusability**: Extends existing discovery.nix without modifying app modules
- ✅ **III. Documentation-Driven**: Will update CLAUDE.md with wildcard syntax documentation
- ✅ **IV. Purity and Reproducibility**: Pure functions, deterministic wildcard expansion, no network access
- ✅ **V. Testing and Validation**: Validates at `nix flake check` time, testable with example user configs
- ✅ **VI. Cross-Platform Compatibility**: Same wildcard syntax works on darwin and nixos

### ✅ Architectural Standards

- ✅ **Flakes as Entry Point**: No changes to flake inputs, extends existing outputs
- ✅ **Home Manager Integration**: Wildcards resolve before Home Manager sees the app list
- ✅ **Directory Structure**: No new directories, extends system/shared/lib/discovery.nix
- ✅ **Helper Libraries**: Wildcard expansion is a helper function in discovery.nix
- ✅ **Platform-Specific Code**: Platform-agnostic implementation (works on any platform)

### ✅ Development Standards

- ✅ **Specification Management**: This spec follows spec-driven process
- ✅ **Refactoring Discipline**: Extending existing pattern, not creating new one
- ✅ **No Backward Compatibility**: Feature is additive (existing configs without wildcards continue to work)
- ✅ **Version Control**: All changes committed with conventional commit messages
- ✅ **Code Organization**: Changes localized to system/shared/lib/discovery.nix
- ✅ **Nix Expression Style**: Will use alejandra formatting, explicit attribute names
- ✅ **Configuration Module Organization**: No app module changes (discovery system change only)

### ✅ Quality Assurance

- ✅ **Pre-Deployment Checks**: Will pass nix flake check, build verification on both platforms
- ✅ **Performance**: Wildcard expansion is O(n) where n = number of apps in category (acceptable for \<200 apps)
- ✅ **Security**: No new security concerns (pure evaluation-time transformation)

**GATE STATUS**: ✅ **PASSED** - No constitutional violations. Feature is a pure extension of existing discovery system following all architectural principles.

## Constitution Check (Post-Design Re-evaluation)

*Re-evaluated after Phase 1 design completion*

### ✅ Core Principles (Verified)

- ✅ **I. Declarative Configuration First**: Implementation uses pure Nix functions, no imperative steps
- ✅ **II. Modularity and Reusability**: All functions are independently composable, single responsibility
- ✅ **III. Documentation-Driven**: CLAUDE.md will be updated, all functions documented, quickstart.md created
- ✅ **IV. Purity and Reproducibility**: All functions pure, deterministic, no network access
- ✅ **V. Testing and Validation**: Test strategy defined, integration tests planned
- ✅ **VI. Cross-Platform Compatibility**: Same wildcard syntax works on all platforms

### ✅ Architectural Standards (Verified)

- ✅ **Helper Libraries**: All new functions in system/shared/lib/discovery.nix (proper location)
- ✅ **Code Organization**: Single file modification (\<200 lines of additions), focused changes
- ✅ **Platform-Specific Code**: No platform-specific code (pure cross-platform implementation)

### ✅ Development Standards (Verified)

- ✅ **Specification Management**: Full spec → plan → research → design workflow followed
- ✅ **No Backward Compatibility**: Feature is additive (existing configs work unchanged)
- ✅ **Version Control**: All changes in feature branch, conventional commits

### ✅ Quality Assurance (Verified)

- ✅ **Testing**: Unit tests and integration tests defined
- ✅ **Performance**: O(n\*m) complexity acceptable for \<200 apps, \<100ms overhead
- ✅ **Security**: No security concerns (pure evaluation-time transformation)

**FINAL GATE STATUS**: ✅ **PASSED** - Design maintains all constitutional principles. Implementation can proceed.

## Project Structure

### Documentation (this feature)

```text
specs/037-app-category-wildcards/
├── spec.md                        # Feature specification
├── plan.md                        # This file (/speckit.plan command output)
├── research.md                    # Phase 0 output (wildcard expansion patterns, Nix list manipulation)
├── data-model.md                  # Phase 1 output (wildcard pattern entity, resolved app list)
├── quickstart.md                  # Phase 1 output (user migration guide, examples)
├── contracts/                     # Phase 1 output (API contracts for extended discovery functions)
│   └── discovery-api.md           # Extended resolveApplications function signature
└── checklists/
    └── requirements.md            # Spec quality validation (completed)
```

### Source Code (repository root)

```text
system/shared/lib/
└── discovery.nix                  # MODIFIED: Add wildcard expansion functions
    ├── expandWildcards            # NEW: Expands "category/*" → list of app names
    ├── expandGlobalWildcard       # NEW: Expands "*" → all available apps
    ├── resolveApplications        # MODIFIED: Call expandWildcards before resolution
    └── (existing functions unchanged)

# No new files created - extending existing discovery system
```

**Structure Decision**: This feature extends the existing discovery library (`system/shared/lib/discovery.nix`) without creating new files or directories. The wildcard expansion logic is added as helper functions within the existing discovery module, maintaining the repository's helper library pattern. No app modules are modified - all changes are isolated to the discovery system.

## Complexity Tracking

> **No constitutional violations - this section is empty**

This feature has zero complexity violations:

- Extends existing discovery.nix (no new modules)
- Pure functional implementation (no side effects)
- Follows existing helper library pattern
- Backward compatible (additive feature)
- No new dependencies beyond Nix builtins
