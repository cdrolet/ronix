# Implementation Plan: User Git Repository Configuration

**Branch**: `032-user-git-repos` | **Date**: 2025-12-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/032-user-git-repos/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Users can configure git repositories in their user configuration to be automatically cloned during home-manager activation. Repositories support flexible path configuration (individual, section root, or home folder default) and are cloned/updated after git installation and credential deployment. The feature builds on existing patterns from Feature 030 (font repository cloning) and Feature 027 (activation-time secret resolution).

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled, Bash (for activation scripts)\
**Primary Dependencies**: Home Manager, git (from user applications), agenix (for SSH credentials)\
**Storage**: Local filesystem (cloned repositories), age-encrypted secrets (user/{username}/secrets.age)\
**Testing**: `nix flake check` (syntax), `just build <user> <host>` (build verification), manual activation testing\
**Target Platform**: Cross-platform (darwin, nixos, any Home Manager-compatible platform)\
**Project Type**: Nix configuration repository with hierarchical user/system structure\
**Performance Goals**: Clone/update 3-5 small repositories in < 5 minutes during activation\
**Constraints**: Activation ordering (must run after git installation and credential deployment)\
**Scale/Scope**: Support multiple repositories per user, both SSH and HTTPS authentication, hierarchical path resolution

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Initial Check**: ✅ PASSED (before Phase 0)\
**Final Check**: ✅ PASSED (after Phase 1)

### ✅ Core Principles

- **I. Declarative Configuration First**: Repository configuration declared in user config, cloning performed via activation scripts
- **II. Modularity and Reusability**:
  - Git repository library in `system/shared/lib/git.nix` (reusable across features)
  - User config remains pure data (repositories array in user.repositories section)
  - Cross-platform compatibility (works on darwin, nixos, any Home Manager platform)
- **III. Documentation-Driven Development**: Will document in `docs/features/032-user-git-repos.md` after implementation
- **IV. Purity and Reproducibility**: Git cloning happens at activation time (not build), deterministic based on configuration
- **V. Testing and Validation**: `nix flake check`, build verification, activation testing required
- **VI. Cross-Platform Compatibility**: Platform-agnostic design using Home Manager activation, works on any platform

### ✅ Architectural Standards

- **Flakes as Entry Point**: Uses existing flake.nix, no changes needed
- **Home Manager Integration**: Leverages `home.activation` for repository cloning (same pattern as fonts)
- **Directory Structure Standard**: Follows user/system split:
  - User config: `user/{username}/default.nix` (repositories configuration)
  - Shared library: `system/shared/lib/git.nix` (repository cloning helpers - already exists)
  - Secrets: `user/{username}/secrets.age` (SSH keys for private repos)

### ✅ Development Standards

- **Specification Management**: Specification created, plan in progress
- **Version Control Discipline**: Using feature branch `032-user-git-repos`
- **Code Organization**: Max 200 lines per module, hierarchical structure
- **Configuration Module Organization**: Single responsibility, clear naming, header documentation
- **Helper Libraries**: Reuse existing `system/shared/lib/git.nix` for repository cloning logic

### ✅ Quality Assurance

- **Pre-Deployment Checks**: `nix flake check`, build verification, platform testing
- **Performance**: Repository cloning during activation (not build), reasonable time constraints
- **Security**: SSH credentials from agenix, no plaintext secrets

### 📋 Notes

- **Existing Patterns**: Feature 030 (font repository cloning) provides proven activation pattern
- **Activation Ordering**: Must use `lib.hm.dag.entryAfter` to ensure git and credentials are available
- **Reusable Library**: `system/shared/lib/git.nix` already exists with `mkRepoCloneScript` function

## Project Structure

### Documentation (this feature)

```text
specs/032-user-git-repos/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (in progress)
├── research.md          # Phase 0 output (next)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# User Configuration
user/{username}/
├── default.nix          # Add repositories section:
│                        # user.repositories = {
│                        #   rootPath = "~/projects";  # Optional
│                        #   repos = [
│                        #     { url = "..."; path = "..."; }  # Optional path
│                        #     "git@github.com:..."            # Simple URL
│                        #   ];
│                        # };
└── secrets.age          # SSH keys for private repos (if needed)

# Shared Libraries (cross-platform)
system/shared/lib/
├── git.nix              # EXISTING: Repository cloning helpers
│                        # - repoName: Extract repo name from URL
│                        # - mkRepoCloneScript: Generate clone/update bash script
└── discovery.nix        # Existing discovery system

# Settings Module (new activation integration)
system/shared/settings/
└── git-repos.nix        # NEW: Home Manager activation for repository cloning
                         # Reads user.repositories config
                         # Uses git.nix helpers for cloning
                         # Handles path resolution (individual > section root > home)
                         # Runs after git installation and credential deployment
```

**Structure Decision**:

This feature extends the existing user/system split architecture:

1. **User Configuration** (`user/{username}/default.nix`): Pure data declaring repositories
1. **Shared Library** (`system/shared/lib/git.nix`): Reusable git cloning functions (already exists)
1. **Settings Module** (`system/shared/settings/git-repos.nix`): Home Manager activation integration

The structure follows Feature 030 (font repos) pattern: user config + shared library + activation module.

## Complexity Tracking

> **No constitutional violations - section not needed**

All constitutional requirements are met:

- Uses existing modular structure
- Reuses existing git library
- Follows activation script best practices
- Platform-agnostic design
- Single responsibility modules
