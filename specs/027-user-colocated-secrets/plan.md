# Implementation Plan: User Colocated Secrets

**Branch**: `027-user-colocated-secrets` | **Date**: 2025-12-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/027-user-colocated-secrets/spec.md`

## Summary

Simplify secrets management by colocating encrypted secrets (`secrets.age`) directly in user directories alongside their configuration (`default.nix`). Uses a single shared age keypair for all users, eliminating the need for a central `secrets.nix` registry or separate `secrets/` directory. Wrapper commands in justfile handle all agenix complexity including auto-initialization.

## Technical Context

**Language/Version**: Nix 2.19+ with flakes enabled, Bash (for justfile recipes)
**Primary Dependencies**: agenix (secret management), Home Manager, nix-darwin/NixOS
**Storage**: Age-encrypted JSON files (`user/{username}/secrets.age`)
**Testing**: `nix flake check`, manual verification of secret resolution
**Target Platform**: darwin (macOS), nixos (Linux) - any platform with Home Manager
**Project Type**: Configuration management (Nix expressions)
**Performance Goals**: N/A (build-time configuration)
**Constraints**: Secrets must decrypt at activation time, not evaluation time
**Scale/Scope**: 3 users (cdrokar, cdrolet, cdronix), expandable

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Declarative Configuration First | PASS | All secrets declared in Nix, resolved via agenix |
| II. Modularity and Reusability | PASS | Secrets colocated with user, no cross-dependencies |
| III. Documentation-Driven Development | PASS | Design documented in spec, trade-offs explained |
| IV. Purity and Reproducibility | PASS | Encrypted secrets are deterministic, same key = same output |
| V. Testing and Validation | PASS | `nix flake check` validates, manual test for decryption |
| VI. Cross-Platform Compatibility | PASS | agenix works on darwin and nixos |
| Directory Structure (II) | PASS | Follows `user/{username}/` pattern, no new top-level dirs |
| App-Centric Organization (II) | PASS | Secrets are user-centric, not app-centric |
| Version Control Discipline | PASS | Encrypted secrets safe to commit, private key excluded |
| Module Size \<200 lines | PASS | Wrapper logic minimal, user schema extension small |

**Gate Result**: PASS - All principles satisfied.

## Project Structure

### Documentation (this feature)

```text
specs/027-user-colocated-secrets/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: agenix integration patterns
├── data-model.md        # Phase 1: Secret file format, user schema
├── quickstart.md        # Phase 1: User guide for secrets
└── checklists/
    └── requirements.md  # Validation checklist
```

### Source Code (repository root)

```text
# New/Modified Files
public.age                           # NEW: Shared public key (repo root)
justfile                             # MODIFIED: Add secrets-* commands

user/
├── cdrokar/
│   ├── default.nix                  # MODIFIED: Add "<secret>" placeholders
│   └── secrets.age                  # NEW: Encrypted secrets (auto-created)
├── cdrolet/
│   ├── default.nix
│   └── secrets.age
├── cdronix/
│   ├── default.nix
│   └── secrets.age
└── shared/
    └── lib/
        └── secrets.nix              # NEW: Secret resolution helper

system/
├── shared/
│   └── lib/
│       └── user-schema.nix          # MODIFIED: Add freeformType support
├── darwin/
│   └── lib/
│       └── darwin.nix               # MODIFIED: Integrate agenix, secret resolution
└── nixos/
    └── lib/
        └── nixos.nix                # MODIFIED: Integrate agenix, secret resolution

# Removed (from spec 026 if implemented)
secrets/                             # REMOVED: No longer needed
```

**Structure Decision**: Secrets colocated in user directories. Single shared key at repo root. No separate secrets directory.

## Complexity Tracking

No constitution violations. Design is simpler than spec 026 (fewer files, no central registry).
