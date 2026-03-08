# Implementation Plan: Refactor System Structure

**Branch**: `013-refactor-system-structure` | **Date**: 2025-01-27 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/013-refactor-system-structure/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Refactor the Darwin system structure to create a reusable template for future platform onboarding. Standardize profile configuration through a hostSpec structure, centralize system.stateVersion, consolidate discovery functions, implement auto-discovery for settings/apps, and clean up redundant Darwin library functions. This refactoring improves maintainability, reduces boilerplate, and establishes patterns for future NixOS integration.

## Technical Context

**Language/Version**: Nix (NixOS/nix-darwin modules), nix-darwin, Home Manager\
**Primary Dependencies**: nix-darwin, home-manager, nixpkgs (via flake inputs)\
**Storage**: N/A (declarative Nix configuration files)\
**Testing**: `nix flake check`, build verification via `nix build`, profile activation testing\
**Target Platform**: macOS (Darwin via nix-darwin), preparing for future NixOS support\
**Project Type**: Configuration repository (multi-platform Nix configuration)\
**Performance Goals**: N/A (configuration evaluation speed not critical, but should remain reasonable)\
**Constraints**:

- Must maintain backward compatibility (existing profiles must continue working)
- Must preserve flake.nix output structure for tooling compatibility (justfile commands)
- Must follow Constitution v2.0.4 (Platform-Agnostic Orchestration, User/System Split pattern)
- File size limit: 200 lines per module (existing standard)
  **Scale/Scope**:
- 2 existing Darwin profiles (home-macmini-m4, work)
- 3 users (cdrokar, cdrolet, cdrixus)
- ~13 settings modules in system/darwin/settings/
- ~9 app modules across system/shared/app/ subdirectories
- 2-4 Darwin library functions to review/refactor

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check

✅ **Modularity and Reusability (II)**:

- hostSpec structure improves reusability across profiles
- Auto-discovery maintains modularity while reducing maintenance
- Discovery functions consolidation improves code reuse

✅ **Documentation-Driven Development (III)**:

- All new modules must include header documentation
- Helper libraries must document purpose and usage
- No code changes without documentation

✅ **Cross-Platform Compatibility (VI)**:

- hostSpec structure designed to be cross-platform (usable for NixOS)
- Discovery functions in shared/lib are platform-agnostic
- System.stateVersion placement respects platform boundaries (Darwin-specific)

✅ **Flakes as Entry Point (I)**:

- Changes maintain flake.nix as primary entry point
- Output structure unchanged (backward compatibility)
- Discovery functions moved but behavior preserved

✅ **Helper Libraries (VI)**:

- Discovery functions moved to shared/lib (platform-agnostic)
- host.nix module follows helper library patterns
- Darwin lib cleanup maintains library standards

✅ **Configuration Module Organization**:

- Auto-discovery maintains topic-based organization
- Settings files remain single-responsibility
- No changes to file size limits or structure requirements

### Post-Design Check

*To be validated after Phase 1 design artifacts are complete*

## Project Structure

### Documentation (this feature)

```text
specs/013-refactor-system-structure/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── host-spec.md     # hostSpec structure contract
│   └── discovery-api.md # Discovery function API contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
system/
├── shared/
│   └── lib/
│       ├── discovery.nix      # Moved from flake.nix: discoverUsers, discoverProfiles, discoverAllProfilesPrefixed, discoverModules (new)
│       └── host.nix           # NEW: hostSpec processing module
│
├── darwin/
│   ├── lib/
│   │   ├── darwin.nix         # Modified: Add system.stateVersion = 5, import host.nix
│   │   ├── mac.nix            # REVIEW: Evaluate necessity, potentially remove
│   │   ├── dock.nix           # REVIEW: Check if redundant with nix-darwin
│   │   ├── power.nix          # REVIEW: Check if redundant with nix-darwin
│   │   └── system-defaults.nix # REVIEW: Check if redundant with nix-darwin
│   │
│   ├── profiles/
│   │   ├── home-macmini-m4/
│   │   │   └── default.nix    # Modified: Use hostSpec instead of manual config
│   │   └── work/
│   │       └── default.nix    # Modified: Use hostSpec instead of manual config
│   │
│   └── settings/
│       └── default.nix        # Modified: Auto-discovery instead of manual imports
│
flake.nix                      # Modified: Import discovery functions from system/shared/lib/discovery.nix
```

**Structure Decision**: This refactoring maintains the existing hierarchical structure (Constitution v2.0.4) while improving internal organization. Changes are:

1. **Discovery consolidation**: Move discovery functions from flake.nix to shared library
1. **hostSpec standardization**: Add new host.nix module in shared/lib (cross-platform ready)
1. **Auto-discovery**: Update defaults.nix files to use discovery.nix functions
1. **Darwin lib cleanup**: Review and potentially remove redundant/unnecessary functions
1. **State version centralization**: Move to darwin/lib/darwin.nix (platform-specific)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations identified. All changes align with Constitution principles.
