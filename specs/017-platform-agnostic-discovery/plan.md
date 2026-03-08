# Implementation Plan: Platform-Agnostic Discovery System

**Branch**: `017-platform-agnostic-discovery` | **Date**: 2025-11-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/017-platform-agnostic-discovery/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Redesign the discovery system to be truly platform-agnostic by:

1. **Scanning the complete repository tree** from flake.nix root instead of hardcoding platform names (darwin/nixos)
1. **Filtering by context** - collect all apps, then filter to platform-compatible ones (shared + current platform)
1. **Graceful degradation** - apps not available for current platform are skipped, not errored
1. **Validation** - all referenced apps must exist somewhere in the tree, even if not in current platform context

This eliminates the constitutional violation where discovery.nix expects specific platforms (darwin/nixos) and allows users to reference platform-specific apps without being locked to that platform.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nixpkgs lib (builtins.readDir, builtins.pathExists, lib.filter\*)\
**Storage**: N/A (pure Nix functions operating on filesystem at evaluation time)\
**Testing**: `nix flake check` for syntax validation, build tests for integration\
**Target Platform**: Platform-agnostic (darwin, nixos, nix-on-droid, standalone home-manager)\
**Project Type**: Library (Nix discovery functions)\
**Performance Goals**: Fast evaluation time (\<1s for typical 50-app repository)\
**Constraints**:

- Must work at Nix evaluation time (no IFD - Import From Derivation)
- Pure functions only (no side effects)
- Must not hardcode platform names except "shared"
- Filesystem scanning limited to `builtins.readDir` and `builtins.pathExists`

**Scale/Scope**:

- 3-5 users per repository
- 40-60 apps across all platforms
- 2-4 platforms per repository
- 3-5 profiles per platform

**Current Issues**:

1. `detectContext` hardcodes "/system/darwin/" and "/system/nixos/" paths (line 117-126)
1. `buildSearchPaths` hardcodes "darwin" and "nixos" platform names (line 131-143)
1. User configs using platform-specific apps throw errors when built for different platform
1. Violates Constitution v2.2.0 Core Principle VI (platform-agnostic requirement)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principle VI: Cross-Platform Compatibility (NON-NEGOTIABLE)

**Requirement**: Platform-agnostic design - functions and structure can be applied to any platform supporting Home Manager and Nix packages. Platform configurations in `platform/` serve as examples, not exhaustive list.

**Current Violation**: ❌ FAIL

- `detectContext` hardcodes darwin/nixos checks (lines 117-126)
- `buildSearchPaths` hardcodes darwin/nixos paths (lines 131-143)
- Violates "no specific platforms expected" principle

**After Redesign**: ✅ PASS (expected)

- Generic tree scanning from repository root
- Dynamic platform detection via filesystem structure
- No hardcoded platform names except "shared"

### Architectural Standard: Directory Structure

**Requirement**: Follow canonical `platform/{platform}/` structure with `platform/shared/` for cross-platform code.

**Current Status**: ✅ PASS

- Existing structure already compliant
- Discovery system operates within defined structure
- No structural changes required

### Development Standard: Module Size \<200 lines

**Requirement**: Configuration modules must be under 200 lines.

**Current Status**: ⚠️ WARNING - discovery.nix at 242 lines

- Recently reduced from 334 lines (feature 015-refactor-discovery)
- Redesign may add complexity initially
- Must monitor and refactor if approaching limit

**Mitigation**: Break into sub-modules if exceeds 250 lines after redesign:

- `discovery/core.nix` - generic tree scanning
- `discovery/app-resolution.nix` - application-specific logic
- `discovery.nix` - public API aggregator

### Development Standard: Refactoring Discipline

**Requirement**: Remove old pattern functions instead of fixing them during refactors.

**Current Status**: ✅ PASS

- This is a redesign, not a fix
- Will remove hardcoded platform logic entirely
- New pattern replaces old pattern cleanly

### Summary

**GATE STATUS**: ⚠️ CONDITIONAL PASS

- **Blocker**: Current implementation violates Core Principle VI (platform-agnostic)
- **Justification for Proceeding**: This feature exists to fix the violation
- **Risk**: Module size approaching limit (242/200 lines)
- **Mitigation**: Monitor size, split into sub-modules if needed (>250 lines)

**Decision**: Proceed to Phase 0 research. Re-evaluate module size after Phase 1 design.

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

```text
platform/shared/lib/
├── discovery.nix              # Main discovery library (MODIFIED)
└── discovery/                 # Sub-modules if size exceeds 250 lines
    ├── core.nix               # Generic tree scanning functions
    ├── app-resolution.nix     # Application resolution logic
    └── context.nix            # Context detection utilities

platform/darwin/lib/
└── darwin.nix                 # Darwin platform lib (unchanged)

platform/nixos/lib/
└── nixos.nix                  # NixOS platform lib (unchanged)

user/cdrokar/
└── default.nix                # User config with mixed platform apps (unchanged)

flake.nix                      # Entry point (unchanged)
```

**Structure Decision**:

- Primary changes in `platform/shared/lib/discovery.nix`
- May split into sub-modules if approaching 250 lines
- No changes to user configs, platform libs, or flake.nix structure
- Maintains existing directory hierarchy

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - No constitutional violations that require justification. The current module size warning (242/200 lines) has a mitigation plan (split into sub-modules if exceeds 250 lines).
