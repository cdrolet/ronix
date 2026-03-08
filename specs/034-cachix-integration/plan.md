# Implementation Plan: Cachix Integration

**Branch**: `034-cachix-integration` | **Date**: 2025-12-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/034-cachix-integration/spec.md`

## Summary

Integrate Cachix binary cache into nix-config with:

1. **System-wide read-only access** - All users benefit from default.cachix.org (no config needed)
1. **Optional per-user write access** - Users can opt into pushing builds via secrets
1. **Cachix-deploy agent** - Remote deployment service (system-level)

Uses Nix's native substituter configuration with hardcoded read-only token (safe) and agenix-encrypted write tokens (per-user).

## Technical Context

**Language/Version**: Nix 2.19+, Bash (justfile recipes)\
**Primary Dependencies**: Cachix (optional CLI for pushing), nixpkgs, nix-darwin/NixOS, Home Manager, agenix\
**Storage**:

- Read-only token: Hardcoded in system settings (safe, limited scope)
- Write tokens: `user/{name}/secrets.age` (agenix-encrypted, per-user)
- Agent token: `user/cdrolet/secrets.age` (by convention)

**Testing**: Build validation (`nix flake check`), cache fetch verification, push test\
**Target Platform**: Cross-platform (darwin, nixos, any Nix platform)\
**Project Type**: Infrastructure configuration (Nix flake enhancement)\
**Performance Goals**: Reduce build times by 50-90% when packages available in cache\
**Constraints**:

- Must work with existing user/system architecture
- Maintain declarative config pattern
- Support per-user security isolation (Feature 031)
- Darwin post-build-hook can't access user secrets (manual push instead)

**Scale/Scope**: All users automatically benefit (read-only), 3 users can opt into write access

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Core Principles Compliance

✅ **I. Declarative Configuration First**: Cachix configuration via Nix expressions (nix.settings.substituters)\
✅ **II. Modularity and Reusability**: Cache config as reusable modules (system-level + opt-in user-level)\
✅ **III. Documentation-Driven**: Will document in CLAUDE.md with setup examples\
✅ **IV. Purity and Reproducibility**: Cachix URLs/keys declared explicitly, tokens via agenix\
✅ **V. Testing and Validation**: Build validation ensures cache config doesn't break builds\
✅ **VI. Cross-Platform Compatibility**: Cachix works on all Nix platforms (darwin, nixos, linux)

### Architectural Standards Compliance

✅ **Flakes as Entry Point**: Configuration via flake.nix inputs and module system\
✅ **Home Manager Integration**: Per-user write access via Home Manager activation scripts\
✅ **Directory Structure**:

- System-wide: `system/shared/settings/cachix.nix` (read-only default)
- Per-user: `user/{name}/default.nix` (optional write access)
- Secrets: `user/{name}/secrets.age` (write tokens)
- Helper: `user/shared/lib/secrets.nix` (existing mkActivationScript)

### Development Standards Compliance

✅ **Specification Management**: This spec + plan.md + research.md workflow\
✅ **No Backward Compatibility**: Clean implementation, read-only default is non-breaking\
✅ **Version Control**: Git workflow with feature branch `034-cachix-integration`

### Quality Assurance Compliance

✅ **Pre-Deployment Checks**: `nix flake check`, build verification, push test\
✅ **Security**:

- Read-only token hardcoded (safe, limited scope)
- Write tokens encrypted via agenix (per-user keys)
- Never committed plaintext

### Module Organization Compliance

✅ **Single Responsibility**: Cachix module handles only cache configuration\
✅ **Size Limit**: Expected \<150 lines (system config + user integration)\
✅ **Clear Naming**: `cachix.nix` clearly indicates purpose\
✅ **Default Values**: System provides read-only default, users opt into write

**GATE STATUS**: ✅ PASS - No constitutional violations

## Project Structure

### Documentation (this feature)

```text
specs/034-cachix-integration/
├── spec.md              # Feature specification (✅ completed)
├── plan.md              # This file (✅ completed)
├── research.md          # Research findings (✅ completed)
├── data-model.md        # Data model (✅ completed)
├── quickstart.md        # User guide (✅ completed)
├── contracts/
│   ├── user-config.nix  # User API contract (✅ completed)
│   └── system-config.nix # System API contract (✅ completed)
└── REVISED.md           # Architecture revision notes (outdated)
```

### Source Code (to be implemented)

```text
user/
├── {name}/
│   ├── default.nix          # Add user.cachix (optional for write access)
│   └── secrets.age          # cachix.authToken (write), cachix.agentToken (cdrolet only)
└── shared/
    └── lib/
        └── secrets.nix      # Existing mkActivationScript helper (reused)

system/
├── shared/
│   └── settings/
│       └── cachix.nix       # System-wide read-only + per-user write integration
├── darwin/
│   └── settings/
│       └── cachix-agent.nix # Darwin agent service (optional, launchd)
└── nixos/
    └── settings/
        └── cachix-agent.nix # NixOS agent service (optional, systemd)

justfile                     # Add push-cache recipe

CLAUDE.md                    # Documentation section for Cachix setup
```

**Structure Decision**:

- System provides read-only default (hardcoded token in `system/shared/settings/cachix.nix`)
- Users opt into write access (per-user netrc via Home Manager activation)
- Agent service is platform-specific (launchd/systemd)
- Reuse existing secrets.nix helper (Feature 031 pattern)

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. Cachix integration follows existing patterns without constitutional exceptions.

## Phase 0: Research & Unknowns ✅

**Research Tasks** (completed):

1. ✅ **Cachix Configuration Methods**:

   - Decision: Use nix.settings.substituters + nix.settings.trusted-public-keys
   - System-wide read-only via hardcoded token
   - Per-user write via netrc file (activation-time generation)

1. ✅ **Authentication Architecture**:

   - Read-only: Hardcoded token (safe, limited scope)
   - Write access: Per-user netrc from secrets.age
   - Pattern: Reuse Feature 031 mkActivationScript

1. ✅ **Push Strategy by Platform**:

   - Darwin: Build-and-push via `just build-and-push` (post-build-hook can't access user secrets)
   - NixOS: Build-and-push via `just build-and-push` (consistent across platforms)
   - Decision: Use `just build-and-push` on all platforms (one-command workflow)

1. ✅ **Cachix-Deploy Agent**:

   - System service (launchd/systemd)
   - Wrapper script extracts token from user secrets (jq)
   - Token stored in cdrolet's secrets by convention

**Output**: ✅ `research.md` complete with all decisions documented

## Phase 1: Design & Contracts ✅

**Prerequisites**: ✅ `research.md` complete

### Data Model ✅ (`data-model.md`)

**Entities**:

1. **System-Wide Cache Configuration**: Read-only access for all users

   - Cache: default.cachix.org
   - Public key: default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=
   - Read-only token: eyJhbGc... (hardcoded)
   - Priority: 10

1. **User Cachix Configuration** (Optional): Write access

   - user.cachix.authToken (secret placeholder)
   - user.cachix.cacheName (default: "default")
   - Stored in user/{name}/secrets.age

1. **Cachix Deploy Agent**: System service

   - Workspace: "default"
   - Token: From cdrolet's secrets
   - Platform: launchd (darwin) or systemd (nixos)

1. **Netrc Entry**: Runtime authentication

   - Generated at activation time
   - Location: ~/.config/nix/netrc
   - Permissions: 600

### API Contracts ✅ (`contracts/`)

**User Configuration API** (`user-config.nix`):

```nix
user.cachix = {
  authToken = "<secret>";  # Optional write token
  cacheName = "default";   # Optional override
};
```

**System Configuration API** (`system-config.nix`):

```nix
nix.settings = {
  substituters = [
    "https://default.cachix.org?priority=10"
    "https://cache.nixos.org?priority=40"
  ];
  
  trusted-public-keys = [
    "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];
};
```

### Quickstart ✅ (`quickstart.md`)

User guide with:

1. ✅ Use Case 1: Read-only access (no configuration)
1. ✅ Use Case 2: Write access (push builds)
1. ✅ Use Case 3: Custom cache name
1. ✅ Use Case 4: Cachix-deploy agent
1. ✅ Troubleshooting section
1. ✅ Configuration decision tree

### Agent Context Update ⏳

Run `.specify/scripts/bash/update-agent-context.sh claude` to add to CLAUDE.md:

- Cachix (binary cache service)
- nix.settings.substituters (Nix cache configuration)
- nix.settings.trusted-public-keys (signature verification)
- Cachix-deploy agent (remote deployments)
- just build-and-push (build + automatic push recipe)

**Output**: ✅ data-model.md, contracts/, quickstart.md complete | ⏳ CLAUDE.md update pending

## Phase 2: Task Breakdown ⏳

**Prerequisites**: Phase 1 complete ✅

**Next Step**: Run `/speckit.tasks` command to generate implementation tasks.

Tasks will include:

1. Implement system-wide read-only configuration
1. Implement per-user write access (netrc generation)
1. Add build-and-push recipe to justfile
1. Implement cachix-deploy agent (darwin/nixos)
1. Update CLAUDE.md documentation
1. Test read-only access
1. Test write access + build-and-push
1. Test agent service

## Implementation Notes

### Key Design Decisions

1. **Read-Only Default**:

   - Hardcoded token in system settings (safe, limited scope)
   - No secrets management needed
   - All users benefit automatically

1. **Per-User Write Access**:

   - Optional via user.cachix.authToken
   - Stored encrypted in secrets.age
   - Netrc generated at activation time

1. **Push Strategy**:

   - Darwin/NixOS: `just build-and-push` (post-build-hook can't access user secrets)
   - One-command workflow for build + push
   - Works on all platforms consistently

1. **Agent Service**:

   - System-level (one per machine)
   - Token from cdrolet's secrets by convention
   - Wrapper script extracts token with jq

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Cachix service downtime | Builds slow | Nix falls back to local builds automatically |
| Token expiration | Push fails | Clear error messages, documented rotation process |
| Cache misconfiguration | Builds fail | Build-time validation warnings |
| Read-only token leak | Limited exposure | Token has read-only scope only |
| Post-build-hook complexity | Implementation burden | Use manual push instead (simpler) |

### Dependencies

- ✅ Existing agenix setup (Feature 031)
- ✅ User/system module architecture (Feature 021)
- ✅ secrets.mkActivationScript helper (Feature 031)
- ✅ Discovery system for auto-importing settings

### Cache Details (Reference)

**Cache**: default.cachix.org\
**Public Key**: default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=\
**Read-Only Token** (hardcoded): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c\
**Read-Write Token** (per-user secret): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI0ODhkNjViNy1hMTE2LTQzNDYtYTMwNS1kYTAyZmFlN2FhZWIiLCJzY29wZXMiOiJjYWNoZSJ9.uAtsEJmBmRmt1mZErn5wo2mNWGJ7ognHSUAWstxAHHg\
**Agent Token** (cdrolet secret): eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzVlYWFkMC0yMTBjLTQxNjQtOWE5My04NjQ0Y2NmZDk5ZjgiLCJzY29wZXMiOiJhZ2VudCJ9.PCwuiCMPSb-cVpVzGCyglME6bBpHZ_DURaQe43okL8g\
**Workspace**: default\
**Priority**: 10 (higher than cache.nixos.org)

### Performance Expectations

| Scenario | Without Cache | With Cache | Improvement |
|----------|---------------|------------|-------------|
| Fresh install | 30-60 minutes | 5-10 minutes | **80-90%** |
| Package update | 10-20 minutes | 2-5 minutes | **70-80%** |
| Config change only | 1-2 minutes | 30-60 seconds | **50%** |

**Note**: First user to build pushes, others benefit from cache.
