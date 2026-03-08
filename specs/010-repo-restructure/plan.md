# Implementation Plan: Repository Restructure - User/System Split

**Branch**: `010-repo-restructure` | **Date**: 2025-10-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-repo-restructure/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

This feature implements a major repository restructure introducing a user/system split architecture with app-centric configuration organization. The primary requirement is to reorganize the entire nix-config repository from the current flat `modules/`, `home/`, `profiles/` structure into a hierarchical `user/` and `system/` structure where each application is self-contained in a single module bundling package, configuration, aliases, and file associations. This enables multi-user persona management (cdrokar, cdrolet, cdrixus), profile-based installation via justfile (`just install <user> <profile>`), and centralized secrets management with agenix. The technical approach uses Nix's module system with explicit dependency declarations, hierarchical profiles (platform+context > platform > family > shared), and helper libraries for cross-platform abstractions.

## Technical Context

**Language/Version**: Nix 2.19+, Bash 5.x (for helper library scripts)\
**Primary Dependencies**:

- nix-darwin (macOS system configuration)
- nixpkgs (package management)
- Home Manager (user environment management)
- agenix (age-based secret encryption)
- just (command runner for installation)

**Storage**: Git repository with encrypted secrets (.age files), no database\
**Testing**:

- `nix flake check` (syntax/build validation)
- `darwin-rebuild build` / `nixos-rebuild build` (platform testing)
- Manual end-to-end testing per phase

**Target Platform**: macOS (nix-darwin), NixOS, Kali Linux (Home Manager only)\
**Project Type**: Nix configuration repository (infrastructure-as-code)\
**Performance Goals**:

- First build: \<10 minutes for typical profile (20-30 apps)
- Incremental rebuild: \<2 minutes for single app change
- Installation command: \<30 seconds to validate and start build

**Constraints**:

- Must maintain backward compatibility during migration phases
- Project not in production (allows clean migration)
- Git-based rollback required at each phase
- Constitution amendment required (MAJOR version 2.0.0)

**Scale/Scope**:

- 3 user personas (cdrokar, cdrolet, cdrixus)
- ~40-50 applications across all platforms
- 5 system profiles (darwin/home, darwin/work, nixos-gnome-desktop-1, etc.)
- 3 platform families (shared, darwin, nixos/kali linux)
- 41 functional requirements
- 6-8 week migration timeline

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

✅ **I. Declarative Configuration First**: All changes are declarative Nix expressions. No imperative steps required.

✅ **II. Modularity and Reusability**: CONSTITUTIONAL VIOLATION - REQUIRES AMENDMENT

- **Violation**: This feature fundamentally changes the required directory structure from the constitution's mandated layout
- **Current Constitution (v1.7.0)**: Requires `hosts/`, `modules/`, `home/`, `profiles/`, `overlays/`, `secrets/`
- **New Structure**: Introduces `user/`, `system/` with hierarchical `{app,settings,lib}/` organization
- **Amendment Required**: MAJOR version bump to 2.0.0
- **Justification**: New structure improves modularity with:
  - App-centric organization (single file per app vs scattered configs)
  - Clear user/system separation (multi-user persona management)
  - Hierarchical profiles (platform+context > platform > family > shared)
  - Better scalability for 40-50 apps across 3 platforms
- **Migration Plan**: Phase 0 includes constitution amendment with 1 week approval period
- **Status**: ⚠️ AMENDMENT IN PROGRESS (Phase 0)

✅ **III. Documentation-Driven Development**: All modules will include purpose, options, examples, dependencies per spec

✅ **IV. Purity and Reproducibility**: No network access during build, all dependencies via flake.lock

✅ **V. Testing and Validation**: Each phase includes `nix flake check`, build verification, rollback procedures

✅ **VI. Cross-Platform Compatibility**: Supports macOS (darwin), NixOS, Kali (Home Manager). Uses `pkgs.stdenv.isDarwin`/`isLinux`

### Architectural Standards Compliance

✅ **Flakes as Entry Point**: Uses flake.nix, all dependencies in flake.lock

✅ **Home Manager Integration**: User configs managed via Home Manager in `user/` directory

⚠️ **Directory Structure Standard**: REQUIRES CONSTITUTIONAL AMENDMENT (see above)

✅ **Module Organization Pattern**: Follows topic-based pattern with:

- Top-level orchestrators (`system/{platform}/app/`, `system/shared/app/`)
- Topic modules \<200 lines each
- Clear naming, header documentation, mkDefault for overrides

✅ **Activation Scripts and Helper Libraries**: Uses helper libraries:

- `system/shared/lib/file-associations.nix` (mkFileAssociation)
- `user/shared/lib/home.nix` (Home Manager bootstrap)
- Platform-specific helpers for installation

### Development Standards Compliance

✅ **Specification Management**: Following specification-driven process via /speckit workflow

✅ **Version Control Discipline**: All changes committed, conventional commits, sops-nix for secrets (migrating to agenix)

✅ **Code Organization**: Hierarchical structure, max 3-4 levels, descriptive names

✅ **Nix Expression Style**: Will use alejandra formatting, explicit attrs, lib.mkOption with types

✅ **Platform-Specific Code**: Uses lib.mkIf with platform detection, documented requirements

### Quality Assurance Compliance

✅ **Pre-Deployment Checks**: Each phase requires `nix flake check`, build verification, platform testing, rollback plan

✅ **Performance and Resource Constraints**: Build closures monitored, performance benchmarking in Phase 5

✅ **Security Requirements**: agenix for secrets, age encryption, no unencrypted secrets committed

### Governance Compliance

⚠️ **Constitution Authority & Amendment Process**:

- **Amendment Required**: Yes - MAJOR version 2.0.0 (directory structure change)
- **Documentation**: This plan.md and spec.md provide rationale
- **Review Period**: 1 week minimum per constitution (Phase 0)
- **Migration Plan**: Documented in spec.md (6-8 weeks, 5 phases, git rollback)
- **Status**: AMENDMENT PENDING APPROVAL

### Gate Summary

**BLOCKERS**:

- ⚠️ Constitution amendment must be approved before proceeding past Phase 0

**WARNINGS**:

- Directory structure violates current constitution v1.7.0
- Requires MAJOR version bump (2.0.0)
- 1 week approval period mandatory

**ACTION REQUIRED**:

1. Complete Phase 0: Update constitution with new directory structure
1. Submit amendment with this plan as rationale
1. Wait 1 week for approval per constitution governance
1. Proceed with Phase 1+ after approval

## Project Structure

### Documentation (this feature)

```text
specs/010-repo-restructure/
├── spec.md              # Feature specification
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── justfile-api.md  # Justfile command interface
│   └── flake-outputs.md # Flake output schema
├── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
└── checklists/
    └── requirements.md  # Specification quality checklist
```

### Source Code (repository root)

**NEW STRUCTURE** (after migration):

```text
nix-config/
├── flake.nix              # Updated with new outputs
├── flake.lock
├── justfile               # NEW: Installation command interface
│
├── user/                  # NEW: User-specific configurations
│   ├── cdrokar/
│   │   └── default.nix    # User's app selections
│   ├── cdrolet/
│   │   └── default.nix
│   ├── cdrixus/
│   │   └── default.nix
│   └── shared/
│       ├── lib/
│       │   └── home.nix   # Home Manager bootstrap module
│       └── profiles/      # Shared user profiles (if needed)
│
├── system/                # NEW: System-wide configurations
│   ├── shared/            # Universal cross-platform
│   │   ├── app/           # Apps that work on ANY platform
│   │   │   ├── dev/
│   │   │   │   └── git.nix
│   │   │   ├── editor/
│   │   │   │   └── helix.nix
│   │   │   └── shell/
│   │   │       └── zsh.nix
│   │   ├── settings/      # Cross-platform settings
│   │   ├── lib/
│   │   │   └── file-associations.nix  # mkFileAssociation helper
│   │   └── profiles/      # Cross-platform families
│   │       ├── linux/
│   │       │   ├── app/
│   │       │   ├── settings/
│   │       │   └── lib/
│   │       └── linux-gnome/
│   │           ├── app/
│   │           ├── settings/
│   │           └── lib/
│   │
│   ├── darwin/            # macOS-specific
│   │   ├── app/
│   │   │   └── aerospace.nix
│   │   ├── settings/
│   │   │   └── default.nix
│   │   ├── lib/
│   │   │   └── mac.nix
│   │   └── profiles/
│   │       ├── home/
│   │       │   └── default.nix
│   │       └── work/
│   │           └── default.nix
│   │
│   └── nixos/             # NixOS-specific
│       ├── app/
│       ├── settings/
│       ├── lib/
│       └── profiles/
│           ├── gnome-desktop-1/
│           ├── kde-desktop-1/
│           └── server-1/
│
├── secrets/               # NEW: Centralized secrets (agenix)
│   ├── users/
│   │   ├── cdrokar/
│   │   ├── cdrolet/
│   │   └── cdrixus/
│   ├── system/
│   │   ├── darwin/
│   │   └── nixos/
│   ├── shared/
│   └── secrets.nix        # Single source of truth for age keys
│
└── [OLD STRUCTURE - to be removed in Phase 5]
    ├── hosts/
    ├── modules/
    ├── home/
    ├── profiles/
    └── overlays/
```

**Structure Decision**: This is a Nix configuration repository (infrastructure-as-code), not a traditional software project. The structure follows a hierarchical organization pattern with:

- User/system separation at top level
- Hierarchical profiles: `system/{platform}/profiles/{context}/` and `system/shared/profiles/{family}/`
- Each level has `{app,settings,lib}/` subdirectories
- App-centric modules (single file per application)
- Centralized secrets management

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Directory Structure Change (Constitution v1.7.0) | Current flat structure doesn't scale for 40-50 apps across 3 users and 3 platforms. App configs scattered across `modules/`, `home/`, `profiles/` making it hard to see what an app includes. | Keeping current structure would require: 1) Continue scattering app configs (package in modules/, aliases in home/, settings in profiles/), 2) No clear user/system separation for multi-user personas, 3) Profile explosion (need work-macOS, home-macOS, work-NixOS combos instead of composable layers), 4) Can't reuse linux-specific configs across NixOS and Kali without duplication |
