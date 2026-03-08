# Implementation Plan: Host/Family Architecture Refactoring

**Branch**: `021-host-family-refactor` | **Date**: 2025-12-02 | **Spec**: [spec.md](./spec.md)\
**Input**: Feature specification from `/specs/021-host-family-refactor/spec.md`

## Summary

Refactor the family system into a host/family architecture where:

- **Hosts** (formerly familys) become pure data configurations in `platform/{name}/host/`
- **Familys** (formerly N/A) provide reusable configuration bundles in `platform/shared/family/`
- Platform libraries automatically load host data, resolve familys, and generate imports
- Applications and settings follow hierarchical search: platform → family → shared

This mirrors the successful pure data pattern from feature 020 (user configurations) and extends it to system-level configuration.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**:

- nixpkgs (via flake inputs)
- nix-darwin (macOS system management)
- Home Manager (user environment)
- Discovery system (`platform/shared/lib/discovery.nix`)

**Storage**: File system (Nix expressions in .nix files, directory scanning)\
**Testing**: `nix flake check`, `nix build`, manual verification\
**Target Platform**: Multi-platform (darwin, nixos, extensible)\
**Project Type**: Configuration management repository (not traditional source code)\
**Performance Goals**: Build time unchanged or improved\
**Constraints**:

- Must maintain Nix module system purity (no config in imports)
- Cannot break existing user configurations (feature 020)
- Must follow constitutional requirement of \<200 lines per module
- Directory renames must preserve git history

**Scale/Scope**:

- Currently 2 darwin familys to migrate
- Discovery system needs hierarchical search extension
- Platform libraries need host data loading logic
- Documentation and justfile updates across repository

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles

✅ **I. Declarative Configuration First**: Hosts as pure data maintains declarative approach\
✅ **II. Modularity and Reusability**: Familys enable reusability across hosts\
✅ **III. Documentation-Driven Development**: Spec created, docs will be updated\
✅ **IV. Purity and Reproducibility**: Pure data pattern maintains purity\
✅ **V. Testing and Validation**: `nix flake check` will validate all changes\
✅ **VI. Cross-Platform Compatibility**: Architecture supports any platform

### Architectural Standards

✅ **Flakes as Entry Point**: No changes to flake structure\
✅ **Home Manager Integration**: User configs unchanged\
✅ **Directory Structure Standard**: Extends existing structure with host/family

**Proposed Directory Changes**:

```
platform/
├── {name}/
│   ├── familys/ → host/     # RENAME: familys become hosts
│   ├── app/                   # Unchanged
│   ├── settings/              # Unchanged
│   └── lib/                   # Enhanced with host loading
└── shared/
    ├── family/                # NEW: Cross-platform familys
    │   ├── work/
    │   │   ├── app/
    │   │   │   └── default.nix
    │   │   └── settings/
    │   │       └── default.nix
    │   ├── home/
    │   └── gaming/
    ├── app/                   # Unchanged
    ├── settings/              # Unchanged
    └── lib/                   # Enhanced with hierarchical discovery
```

### Development Standards

✅ **Specification Management**: Following spec-driven process\
✅ **Refactoring Discipline**: This IS a refactoring - will remove old family pattern\
✅ **Implementation Blockers**: Will document in UNRESOLVED.md if blocked\
✅ **Version Control Discipline**: All changes will be committed with conventional commits\
✅ **Code Organization**: Following hierarchical structure\
✅ **Nix Expression Style**: Will use alejandra formatting\
✅ **Configuration Module Organization**: \<200 lines per module\
✅ **Platform-Specific Code**: Platform libs handle platform-specific logic

### Quality Assurance

✅ **Pre-Deployment Checks**: Will run `nix flake check` and build tests\
✅ **Performance and Resource Constraints**: Build time will be monitored\
✅ **Security Requirements**: No security changes in this refactoring

### Compliance Summary

**All gates PASS** - No constitutional violations. This feature:

- Extends existing architecture patterns
- Maintains all core principles
- Follows established development standards
- Mirrors successful feature 020 pattern

**No complexity justification required.**

## Project Structure

### Documentation (this feature)

```text
specs/021-host-family-refactor/
├── spec.md              # Feature specification (✅ completed)
├── plan.md              # This file (in progress)
├── research.md          # Phase 0 output (pending)
├── data-model.md        # Phase 1 output (pending)
├── quickstart.md        # Phase 1 output (pending)
├── contracts/           # Phase 1 output (pending)
│   ├── host-schema.nix  # Host configuration schema
│   └── family-schema.nix # Family structure schema
├── checklists/
│   └── requirements.md  # Quality checklist (✅ completed)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Repository Structure (Current vs Proposed)

**Current**:

```text
platform/
├── darwin/
│   ├── familys/                    # Familys with imports
│   │   ├── home-macmini-m4/
│   │   │   └── default.nix          # Has imports, host module, settings
│   │   └── work/
│   │       └── default.nix
│   ├── app/
│   ├── settings/
│   └── lib/
│       └── darwin.nix               # Platform lib
└── shared/
    ├── app/
    ├── settings/
    └── lib/
        ├── discovery.nix
        └── host.nix                 # Host options module
```

**Proposed**:

```text
platform/
├── darwin/
│   ├── host/                        # RENAMED from familys/
│   │   ├── home-macmini-m4/
│   │   │   └── default.nix          # Pure data (no imports)
│   │   └── work/
│   │       └── default.nix          # Pure data (no imports)
│   ├── app/
│   ├── settings/
│   └── lib/
│       └── darwin.nix               # Enhanced: loads hosts, resolves familys
└── shared/
    ├── family/                      # NEW directory
    │   ├── work/
    │   │   ├── app/
    │   │   │   └── default.nix      # Auto-installed if exists
    │   │   └── settings/
    │   │       └── default.nix      # Auto-installed if exists
    │   ├── home/
    │   └── gaming/
    ├── app/
    ├── settings/
    └── lib/
        ├── discovery.nix            # Enhanced: hierarchical search
        └── host.nix                 # Removed (no longer needed)
```

**Structure Decision**: Configuration management repository with no traditional source code. Pure Nix expressions organized hierarchically. Hosts and familys are pure data, platform libraries contain orchestration logic.

## Phase 0: Research & Technical Decisions

### Research Tasks

**Research Task 1: Hierarchical Discovery Pattern**

- **Question**: How should discovery system be extended for platform → family → shared search?
- **Approach**: Study feature 020 implementation, design hierarchical resolver
- **Output**: Design for `discoverWithHierarchy` function in discovery.nix

**Research Task 2: Family Resolution Strategy**

- **Question**: How should platform libs resolve family references efficiently?
- **Approach**: Analyze path construction patterns, determine caching needs
- **Output**: Design for family path resolution and validation

**Research Task 3: Settings vs Applications Resolution**

- **Question**: Why do settings prohibit "\*" but applications allow it?
- **Approach**: Review darwin/settings/default.nix pattern, analyze use cases
- **Output**: Clarify design rationale and validation requirements

**Research Task 4: Migration Path**

- **Question**: Can familys be migrated to hosts without breaking existing builds?
- **Approach**: Test pure data transformation on existing familys
- **Output**: Step-by-step migration procedure

**Research Task 5: Default Auto-Installation**

- **Question**: How should automatic installation of family defaults work?
- **Approach**: Design conditional import logic based on pathExists
- **Output**: Implementation pattern for auto-installing defaults

### Technologies & Patterns

**Existing Technologies** (no new additions):

- Nix 2.19+ with flakes
- nixpkgs lib functions (builtins.readDir, builtins.pathExists, lib.filter\*)
- Platform libraries (darwin.nix pattern)
- Discovery system (app resolution)

**Patterns to Apply**:

- Pure data pattern (from feature 020)
- Pre-evaluation extraction (from feature 020)
- Directory-based discovery (existing)
- Hierarchical search with fallbacks

### Best Practices

**Nix Module System**:

- Cannot reference config in imports (infinite recursion)
- Can import files and access attributes before module evaluation
- Module evaluation happens AFTER all imports are collected

**Discovery Patterns**:

- Use `builtins.readDir` for directory scanning
- Use `builtins.pathExists` for conditional logic
- Filter and map for path resolution

**Git History Preservation**:

- Use `git mv platform/darwin/familys platform/darwin/host` for renames
- Single atomic commit for directory rename
- Separate commits for content changes

## Phase 1: Design Artifacts

### Data Model

**File**: `data-model.md`

**Entities**:

1. **Host Configuration** (pure data)

   - Fields: name, optional family, applications[], settings[]
   - Location: `platform/{platform}/host/{name}/default.nix`
   - Validation: No imports allowed

1. **Family** (reusable bundle)

   - Optional files: `app/default.nix`, `settings/default.nix`
   - Subdirectories: `app/{name}.nix`, `settings/{name}.nix`
   - Location: `platform/shared/family/{name}/`

1. **Application** (unchanged from feature 020)

   - Hierarchical search: platform → family → shared
   - Wildcard "\*" supported

1. **Setting** (system configuration)

   - Hierarchical search: platform → family → shared
   - Special "default" keyword imports all platform settings
   - Wildcard "\*" NOT supported

### Contracts

**File**: `contracts/host-schema.nix`

```nix
# Schema for host configuration (pure data)
{
  host = {
    name = "string";           # Required
    family = ["string"];        # Optional, references platform/shared/family/{name}
    applications = ["string"]; # Array of app names or ["*"]
    settings = ["string"];     # Array of setting names or ["default"], NOT ["*"]
  };
}
```

**File**: `contracts/family-schema.nix`

```nix
# Schema for family structure
platform/shared/family/{name}/
├── app/
│   ├── default.nix         # Optional, auto-installed if exists
│   ├── {appname}.nix       # Individual apps
│   └── {category}/
│       └── {appname}.nix
└── settings/
    ├── default.nix         # Optional, auto-installed if exists
    └── {setting}.nix       # Individual settings
```

### Quick Start

**File**: `quickstart.md`

Example showing:

1. Creating a new host (pure data)
1. Creating a new family
1. Referencing family from host
1. Migration example (old family → new host)

## Complexity Tracking

> No violations - all gates passed. No complexity justification needed.

## Notes

### Key Decisions

1. **Pure Data Pattern**: Following feature 020 success, hosts are pure data with platform libs handling all imports
1. **Hierarchical Search**: platform → family → shared provides intuitive override behavior
1. **Settings vs Apps**: Settings use "default" keyword instead of "\*" to match existing darwin/settings/default.nix pattern
1. **Auto-Installation**: Family defaults (app/default.nix, settings/default.nix) auto-install when family referenced
1. **Git History**: Use `git mv` to preserve history for directory renames

### Dependencies

- Feature 020 (pure data user configs) - provides proven pattern to follow
- Discovery system - needs hierarchical search extension
- Platform libraries - need host loading and family resolution logic
- Constitution v2.2.0 - directory structure guidelines

### Risks

1. **Breaking Changes**: Directory rename could break external references

   - Mitigation: This is a feature branch, test thoroughly before merge

1. **Discovery Complexity**: Hierarchical search adds logic complexity

   - Mitigation: Follow feature 020 patterns, comprehensive testing

1. **Migration Effort**: All familys must be converted to hosts

   - Mitigation: Only 2 darwin familys currently, manageable scope

1. **Family Confusion**: Users might confuse family with family/host

   - Mitigation: Clear documentation, examples in quickstart.md

### Next Steps

1. Complete Phase 0: Generate research.md with all decisions documented
1. Complete Phase 1: Generate data-model.md, contracts/, quickstart.md
1. Run agent context update script
1. Proceed to Phase 2: Generate tasks.md with `/speckit.tasks`
