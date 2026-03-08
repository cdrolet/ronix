# Implementation Plan: Multi-Provider Repository Support

**Branch**: `038-multi-provider-repositories` | **Date**: 2026-01-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/038-multi-provider-repositories/spec.md`

## Summary

Extend the existing user.repositories schema (Feature 032) to support multiple remote repository providers beyond git, including S3 buckets, Proton Drive, and custom providers. The system will automatically detect provider type from URL patterns with optional explicit override. Each provider handler (git, s3, proton-drive) filters and processes only its relevant repositories, enabling extensible multi-provider sync during user activation.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled\
**Primary Dependencies**: Home Manager, agenix (secrets), provider-specific tools (git, aws-cli/s3cmd, proton-drive-cli)\
**Storage**: Local filesystem (repositories synced to user-specified paths)\
**Testing**: Nix flake check, manual activation testing with multiple providers\
**Target Platform**: Cross-platform (darwin, nixos, any Home Manager-compatible system)\
**Project Type**: Nix configuration repository (declarative system management)\
**Performance Goals**: Handle 10+ repositories from mixed providers in single activation\
**Constraints**: Provider handlers must be idempotent, failures isolated per-provider\
**Scale/Scope**: Support 3+ provider types initially (git, s3, proton-drive), extensible architecture for future providers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles

- ✅ **Declarative Configuration First**: Repository schema defined in user-schema.nix, activation via home-manager
- ✅ **Modularity and Reusability**:
  - Schema in `user/shared/lib/user-schema.nix` (user-level)
  - Provider handlers as independent settings modules (e.g., `system/shared/settings/git-repos.nix`)
  - Each handler self-contained, filters by provider type
- ✅ **Documentation-Driven**: Spec, plan, research, data-model, contracts all documented
- ✅ **Purity and Reproducibility**: Repository URLs pinned in user config, sync tools from nixpkgs
- ✅ **Testing and Validation**: Flake check validates schema, manual testing per provider
- ✅ **Cross-Platform Compatibility**: Schema and handlers work across darwin/nixos

### Architectural Standards

- ✅ **Flakes as Entry Point**: No changes to flake structure
- ✅ **Home Manager Integration**: Repositories synced via home.activation scripts
- ✅ **Directory Structure**:
  - Schema: `user/shared/lib/user-schema.nix`
  - Handlers: `system/shared/settings/{provider}-repos.nix`
  - Helper libs: `system/shared/lib/` (provider detection, validation)

### Development Standards

- ✅ **Context Validation**: All settings modules MUST use `lib.optionalAttrs ((options ? home) && conditions)` for home-manager-specific code
- ✅ **Specification Management**: Full spec → plan → research → implementation workflow
- ✅ **No Backward Compatibility Required**: Can modify schema (single-user project)
- ✅ **Module Size**: Each provider handler \<200 lines (git-repos currently ~180 lines)
- ✅ **Version Control**: All changes committed with conventional commit format

### Quality Assurance

- ✅ **Pre-Deployment Checks**: `nix flake check` must pass, test on target platform
- ✅ **Security**: Credentials via agenix secrets, no plaintext auth

**Gate Status**: ✅ PASSED - No constitutional violations, ready for Phase 0 research

## Project Structure

### Documentation (this feature)

```text
specs/038-multi-provider-repositories/
├── plan.md              # This file
├── research.md          # Phase 0: Provider detection patterns, tool integration
├── data-model.md        # Phase 1: Repository schema, provider types
├── quickstart.md        # Phase 1: User guide for configuring multi-provider repos
├── contracts/           # Phase 1: Schema contracts
│   └── repository-schema.nix  # Repository type definition
└── tasks.md             # Phase 2: Implementation task breakdown
```

### Source Code (repository root)

```text
user/shared/lib/
└── user-schema.nix           # [MODIFY] Add provider-agnostic repositories option

system/shared/lib/
├── provider-detection.nix    # [NEW] Auto-detect provider from URL patterns
└── repository-validation.nix # [NEW] Validate repository configuration

system/shared/settings/
├── git-repos.nix             # [MODIFY] Filter by provider=git, refactor as handler
├── s3-repos.nix              # [NEW] S3 bucket sync handler
└── proton-drive-repos.nix    # [NEW] Proton Drive sync handler

# No changes to flake.nix, discovery system, or platform-specific code
```

**Structure Decision**: Extends existing nix-config repository structure. Schema lives in `user/shared/lib/` (user-level config), provider handlers in `system/shared/settings/` (activation logic), helper libraries in `system/shared/lib/` (shared utilities). Follows constitutional placement rules for user/system split.

## Complexity Tracking

> **No violations - table not needed**

All constitutional requirements satisfied:

- Module size \<200 lines per handler
- Context validation for all home-manager code
- Declarative schema in user-schema.nix
- Independent, self-contained provider handlers
- Cross-platform compatible architecture
