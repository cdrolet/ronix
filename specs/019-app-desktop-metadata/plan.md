# Implementation Plan: Application Desktop Metadata

**Branch**: `019-app-desktop-metadata` | **Date**: 2025-11-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/019-app-desktop-metadata/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Enable application configuration files to declare desktop integration metadata including platform-specific installation paths, file type associations, and autostart behavior. The system will validate metadata constraints (requiring desktop paths when associations/autostart are declared) and allow each platform to process metadata using native mechanisms (Darwin launch agents, NixOS systemd, XDG desktop entries).

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: nixpkgs lib (for validation functions), nix-darwin, Home Manager, platform-specific desktop integration APIs\
**Storage**: Declarative Nix configuration files (.nix expressions)\
**Testing**: `nix flake check` for syntax validation, platform-specific activation tests for file associations and autostart\
**Target Platform**: Multi-platform (darwin, nixos, and any platform supporting Home Manager)\
**Project Type**: Configuration management (Nix-based declarative system)\
**Performance Goals**: Evaluation time impact < 1 second per application with desktop metadata, activation time < 5 seconds for all desktop integrations\
**Constraints**: Must remain backward compatible (apps without metadata continue working), validation at evaluation time, platform-specific processing isolated to platform libs\
**Scale/Scope**: ~40-50 applications across repository, 3 user personas, 2+ platforms (darwin, nixos)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

**I. Declarative Configuration First**: ✅ PASS

- Desktop metadata declared in Nix expressions (.nix files)
- No imperative configuration steps
- All state reproducible from configuration files

**II. Modularity and Reusability**: ✅ PASS

- Desktop metadata is optional addition to existing app modules
- Self-contained: each app declares its own metadata
- Reusable: metadata structure applies to any application
- Dependencies explicit: platforms process metadata independently
- Module size: Validation and processing logic will be in helper libraries (\<200 lines each)

**III. Documentation-Driven Development**: ✅ PASS

- Specification created (spec.md)
- Implementation plan in progress (plan.md)
- Will document metadata schema in quickstart.md
- Will update user documentation in docs/

**IV. Purity and Reproducibility**: ✅ PASS

- No network access during evaluation
- Desktop paths are static declarations
- File associations and autostart are deterministic
- Platform processing uses native declarative mechanisms

**V. Testing and Validation**: ✅ PASS

- Validation at evaluation time (`nix flake check`)
- Platform-specific activation tests planned
- Backward compatibility test: apps without metadata continue working
- Rollback via nix-darwin/NixOS generations

**VI. Cross-Platform Compatibility**: ✅ PASS

- Platform-agnostic schema in shared app files
- Platform-specific paths isolated by platform name
- Each platform processes metadata using native mechanisms
- Platform libs remain independent (darwin doesn't load nixos code)

### Architectural Standards Compliance

**Flakes as Entry Point**: ✅ PASS

- No changes to flake.nix required
- Works within existing flake structure

**Home Manager Integration**: ✅ PASS

- Desktop integration processed through Home Manager
- User environment configurations affected
- Maintains declarative user environment management

**Directory Structure Standard**: ✅ PASS

- Application configs remain in `platform/shared/app/` and `platform/{platform}/app/`
- Helper libraries in `platform/shared/lib/` and `platform/{platform}/lib/`
- No new directories required
- Follows app-centric organization (metadata within app files)

### Development Standards Compliance

**Specification Management**: ✅ PASS

- Following specification-driven process
- spec.md created, plan.md in progress
- Will create user documentation in docs/

**Code Organization**: ✅ PASS

- Uses existing hierarchical structure
- Helper libraries for validation and processing
- Each component under 200 lines

**Configuration Module Organization**: ✅ PASS

- Desktop metadata within existing app modules
- Single responsibility maintained
- Clear naming (desktop metadata section)
- Will use `lib.mkDefault` for overridability

**Helper Libraries and Activation Scripts**: ✅ PASS

- Validation logic in shared helper library (platform-agnostic)
- Platform-specific processing in platform libs
- Unidirectional dependency: platform lib → shared lib
- Declarative approach preferred (file associations via native APIs)

### Quality Assurance Compliance

**Pre-Deployment Checks**: ✅ PASS

- Will pass `nix flake check`
- Platform testing planned (darwin and nixos)
- Backward compatibility verified (apps without metadata)
- Rollback via system generations

**Performance and Resource Constraints**: ✅ PASS

- Minimal evaluation overhead (simple attribute lookups)
- No significant closure size impact (metadata is configuration only)
- Activation time minimal (native platform APIs)

**Security Requirements**: ✅ PASS

- No new security surface (uses existing platform mechanisms)
- No secrets in desktop metadata
- Platform security features unaffected

### Gate Result: ✅ ALL GATES PASSED

No constitutional violations. Feature aligns with all core principles, architectural standards, development standards, and quality assurance requirements. Proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/019-app-desktop-metadata/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── desktop-metadata-schema.nix  # Nix type definitions and validation contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
platform/
├── shared/
│   ├── app/
│   │   └── {category}/
│   │       └── {app}.nix         # Enhanced with desktop metadata (optional)
│   └── lib/
│       └── desktop-metadata.nix  # NEW: Validation and schema functions
│
├── darwin/
│   ├── app/
│   │   └── {category}/
│   │       └── {app}.nix         # Enhanced with desktop metadata (optional)
│   └── lib/
│       └── darwin.nix            # MODIFIED: Process desktop metadata for darwin
│
└── nixos/
    ├── app/
    │   └── {category}/
    │       └── {app}.nix         # Enhanced with desktop metadata (optional)
    └── lib/
        └── nixos.nix             # MODIFIED: Process desktop metadata for nixos

docs/
└── features/
    └── 019-app-desktop-metadata.md  # NEW: User documentation
```

**Structure Decision**: This is a Nix configuration management project following the User/System Split architecture. The feature enhances existing application configuration files with optional desktop metadata and adds validation/processing logic to shared and platform-specific libraries. No new directories are required - the feature integrates into the existing hierarchical structure defined by Constitution v2.0.0.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - All constitutional gates passed. No violations to justify.

## Post-Design Constitution Re-Check

*Re-evaluating constitutional compliance after design phase completion*

### Design Artifacts Review

**Generated Artifacts**:

- ✅ research.md: Platform mechanisms research (darwin, nixos)
- ✅ data-model.md: Desktop metadata schema and validation
- ✅ contracts/desktop-metadata-schema.nix: Type definitions and validation functions
- ✅ quickstart.md: User guide for adding desktop metadata

### Architecture Validation

**Module Size Compliance**: ✅ PASS

- Validation library (desktop-metadata-schema.nix): ~300 lines (includes extensive comments and examples)
- Core validation functions: \<100 lines
- Each platform processing: \<50 lines (isolated to platform libs)
- Individual app enhancements: \<20 lines per app

**Dependency Flow**: ✅ PASS

- Shared validation lib (platform/shared/lib/desktop-metadata.nix)
- Platform libs use shared validation (platform/{platform}/lib/)
- Apps declare metadata (no processing logic)
- Unidirectional: platform lib → shared lib

**Platform Isolation**: ✅ PASS

- Schema validation in shared lib (platform-agnostic)
- Platform-specific processing in platform libs
- Each platform uses native mechanisms independently
- No cross-platform dependencies

**Backward Compatibility**: ✅ PASS

- Desktop metadata is completely optional
- Apps without metadata continue functioning
- No changes to existing apps required
- Gradual adoption supported

### Design Decisions Alignment

**Declarative First**: ✅ PASS

- All metadata in Nix expressions
- No imperative steps
- Platform libs use declarative Home Manager options

**Modularity**: ✅ PASS

- Self-contained validation library
- Platform processing isolated
- App metadata independent
- Helper functions reusable

**Documentation**: ✅ PASS

- Comprehensive quickstart guide
- Data model documented
- Schema with inline documentation
- Error messages actionable

**Testing**: ✅ PASS

- Evaluation-time validation (nix flake check)
- Platform-specific activation tests
- Backward compatibility verification
- Rollback via system generations

### Gate Result: ✅ ALL GATES PASSED (POST-DESIGN)

Design phase completed with full constitutional compliance. All artifacts align with:

- Core principles (declarative, modular, documented, pure, testable, cross-platform)
- Architectural standards (flakes, Home Manager, directory structure)
- Development standards (specification-driven, well-organized, helper libraries)
- Quality assurance (validation, performance, security)

**Recommendation**: Proceed to `/speckit.tasks` to generate implementation task breakdown.
