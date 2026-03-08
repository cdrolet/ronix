# Implementation Plan: App Exclusion Patterns

**Branch**: `043-app-exclusion-patterns` | **Date**: 2026-02-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/043-app-exclusion-patterns/spec.md`

## Summary

Add exclusion pattern support (`"!"` prefix) to the `user.applications` array, allowing users to subtract specific apps or entire categories from wildcard results. The implementation extends the existing wildcard expansion in `resolveApplications` (Feature 037) by adding a post-expansion filtering step. Processing order: expand wildcards → collect exclusions → expand exclusion wildcards → remove excluded apps → add explicit includes.

## Technical Context

**Language/Version**: Nix 2.19+ (flakes enabled)\
**Primary Dependencies**: nixpkgs lib (builtins.readDir, builtins.match, list functions), existing discovery.nix (Feature 037)\
**Storage**: N/A (pure functional transformation at evaluation time)\
**Testing**: `nix flake check`, `just build <user> <host>`\
**Target Platform**: Cross-platform (darwin, nixos)\
**Project Type**: Single Nix configuration repository\
**Performance Goals**: Exclusion filtering adds negligible overhead to existing wildcard expansion\
**Constraints**: Must integrate into existing `resolveApplications` function without breaking current behavior\
**Scale/Scope**: ~50 apps across 3 users, 2 hosts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | Exclusions declared in pure Nix expressions |
| II. Modularity and Reusability | PASS | Change confined to single file (discovery.nix), \<200 lines added |
| III. Documentation-Driven Development | PASS | CLAUDE.md and spec updated |
| IV. Purity and Reproducibility | PASS | Pure function, deterministic, no side effects |
| V. Testing and Validation | PASS | Testable via `nix flake check` and `just build` |
| VI. Cross-Platform Compatibility | PASS | Platform-agnostic — operates on app name strings |
| Module Size \<200 lines | PASS | Adding ~40 lines to discovery.nix (well under limit) |
| App-Centric Organization | PASS | No new files, extends existing discovery system |
| Pure Data Pattern | PASS | User configs remain pure data — just new string syntax |
| No Backward Compatibility needed | PASS | Existing configs without `!` work identically |
| Context Validation | N/A | No home-manager options involved — pure list transformation |

**Pre-design gate**: PASS — no violations. Proceed to Phase 0.

### Post-Design Re-evaluation

All gates remain PASS after Phase 1 design:

- No new files created (only discovery.nix modified)
- ~40 lines of new functions, well within 200-line module limit
- Function signature unchanged — zero caller impact
- Pure string operations — fully platform-agnostic
- All design artifacts produced (research.md, data-model.md, contracts/, quickstart.md)

**Post-design gate**: PASS — no new violations.

## Project Structure

### Documentation (this feature)

```text
specs/043-app-exclusion-patterns/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (files modified)

```text
system/shared/lib/
└── discovery.nix        # Add exclusion detection, expansion, and filtering functions
```

**Structure Decision**: No new files. All changes are additions to `discovery.nix` within the existing Feature 037 wildcard section. The change is a pure extension of the wildcard expansion pipeline in `resolveApplications`.

## Complexity Tracking

> No violations — table not needed.
