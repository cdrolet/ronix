# FINAL ARCHITECTURE: Per-User Cachix with Read-Only Default

**Date**: 2025-12-31\
**Final Decision**: Per-user configuration with system-wide read-only default

## Architecture Evolution

This document tracks the architecture decisions through multiple iterations:

### Iteration 1: Pure Per-User (Initial)

- Per-user cache configuration
- Each user could configure their own cache
- All authentication via per-user secrets

**Reason for change**: User provided actual credentials and mentioned users are same persona

### Iteration 2: System-Wide (First Pivot)

- Single cache for all users (cdrolet.cachix.org)
- Tokens stored in one user's secrets (cdrolet)
- System-wide configuration

**Reason for change**: User said "Users are not necessarily the same personas" and "I don't want to use cdrolet secrets for all users"

### Iteration 3: Back to Per-User (Second Pivot)

- Per-user cache configuration restored
- Cache name changed to "default" (not cdrolet)
- Per-user encrypted secrets

**Reason for change**: User said "leave the user cachix entry" and "maybe user without configured secret should use the read only token by default?"

### Iteration 4: FINAL - Per-User with Read-Only Default (Current)

**System-Wide Read-Only**:

- Cache: default.cachix.org
- Read-only token: Hardcoded (safe, limited scope)
- All users benefit automatically (no configuration needed)
- Public key: default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=

**Per-User Write Access** (Optional):

- user.cachix.authToken = "<secret>" (opt-in)
- user.cachix.cacheName = "default" (or override to custom cache)
- Netrc generated at activation time from per-user secrets
- Enables: `just build-and-push` (build + automatic push)

**Push Strategy**:

- Darwin: Build-and-push via `just build-and-push` (post-build-hook can't access user secrets)
- NixOS: Build-and-push via `just build-and-push` (consistent across platforms)
- Decision: Use `just build-and-push` on all platforms (one-command workflow)

**Cachix-Deploy Agent**:

- System service (launchd/systemd)
- Token stored in cdrolet's secrets (by convention)
- Workspace: "default"
- Auto-start on boot

## Final Architecture Summary

### System Level (All Users)

**What**: Read-only access to default.cachix.org\
**How**: Hardcoded configuration in `system/shared/settings/cachix.nix`\
**Why**: Everyone benefits without configuration burden\
**Security**: Read-only token is safe to hardcode (limited scope)

```nix
# system/shared/settings/cachix.nix
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

# Read-only auth (option 1: system netrc)
environment.etc."nix/netrc".text = ''
  machine default.cachix.org
    login cachix
    password eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
'';
nix.settings.netrc-file = "/etc/nix/netrc";
```

### User Level (Opt-In Write Access)

**What**: Ability to push builds to cache\
**How**: Per-user configuration + secrets\
**Why**: Security isolation, opt-in model\
**Security**: Write tokens encrypted with per-user age keys

```nix
# user/{username}/default.nix
user = {
  name = "username";
  
  # Optional: Only configure if user wants to push builds
  cachix = {
    authToken = "<secret>";  # Write token
    # cacheName defaults to "default"
  };
};
```

```bash
# Setup
just secrets-set username cachix.authToken "eyJhbGc..."
just install username hostname

# Usage
just build-and-push username hostname  # Builds and pushes in one command
```

### Agent Level (System Service)

**What**: Remote deployment capability\
**How**: System service reading token from one user's secrets\
**Why**: Enables GitOps-style deployments\
**Security**: Agent token in cdrolet's secrets (by convention)

```nix
# Stored in user/cdrolet/secrets.age
{
  "cachix": {
    "agentToken": "eyJhbGc..."
  }
}
```

```nix
# system/darwin/settings/cachix-agent.nix (launchd)
# OR
# system/nixos/settings/cachix-agent.nix (systemd)

# Wrapper script extracts token with jq, runs agent
```

## Key Technical Decisions

### Decision 1: Read-Only Token Hardcoded

**Why**: Safe (limited scope), no secrets management overhead, benefits everyone\
**Alternative**: Store in system-level secrets (adds complexity for no benefit)

### Decision 2: Per-User Write Tokens

**Why**: Security isolation (Feature 031 principle), users are independent personas\
**Alternative**: Share one write token system-wide (breaks security model)

### Decision 3: Build-and-Push via `just build-and-push`

**Why**: Post-build-hook runs as nix-daemon (root), can't access user secrets\
**Alternative**: Post-build-hook with system token (breaks per-user model)

### Decision 4: Cache Name "default"

**Why**: Avoids confusion with user named "cdrolet"\
**Alternative**: Use "cdrolet" cache (confusing naming)

### Decision 5: Agent Token in cdrolet's Secrets

**Why**: Needs one user's secrets, cdrolet is system owner by convention\
**Alternative**: System-level secrets (not implemented yet)

## Files Updated with Final Architecture

✅ **spec.md**: Final architecture (read-only default + per-user write)\
✅ **research.md**: Read-only default strategy, just recipe push, agent setup\
✅ **data-model.md**: Entities for system-wide + per-user + agent\
✅ **contracts/user-config.nix**: User API (optional authToken)\
✅ **contracts/system-config.nix**: System API (hardcoded read-only)\
✅ **quickstart.md**: Usage guide (read-only, write access, agent)\
✅ **plan.md**: Implementation plan (final technical approach)\
✅ **REVISED.md**: This file (architecture evolution notes)

## Migration Path

### Phase 1: System-Wide Read-Only (Non-Breaking)

- Add `system/shared/settings/cachix.nix`
- All users immediately benefit
- No user configuration changes needed

### Phase 2: Per-User Write Access (Opt-In)

- Users who want to push add `user.cachix.authToken`
- Set secret: `just secrets-set username cachix.authToken "token"`
- Rebuild: `just install username hostname`

### Phase 3: Agent Service (Optional)

- Add agent token to cdrolet's secrets
- Deploy agent service (platform-specific)
- Enable remote deployments

## Constitution Compliance (Final)

✅ **I. Declarative Configuration**: System + user configs in Nix\
✅ **II. Modularity**: Separate modules for system/user/agent\
✅ **III. Documentation**: All docs updated for final architecture\
✅ **IV. Purity**: Tokens encrypted, read-only hardcoded (safe)\
✅ **V. Testing**: Build validation, push test, agent status check\
✅ **VI. Cross-Platform**: Works on darwin, nixos, any Nix platform

## Next Steps

1. ✅ All planning documents updated
1. ⏳ Run `/speckit.tasks` to generate implementation tasks
1. ⏳ Implement system-wide read-only
1. ⏳ Implement per-user write access
1. ⏳ Implement agent service
1. ⏳ Update CLAUDE.md documentation
1. ⏳ Test all use cases

## Summary of Architecture Changes

| Aspect | Iteration 1 | Iteration 2 | Iteration 3 | **Final (Iteration 4)** |
|--------|-------------|-------------|-------------|-------------------------|
| **Cache name** | Per-user choice | cdrolet | Per-user choice | **default** |
| **Read access** | Per-user config | System-wide | Per-user config | **System-wide (hardcoded)** |
| **Write access** | Per-user secrets | System-wide (cdrolet) | Per-user secrets | **Per-user secrets (optional)** |
| **Token storage** | Per-user | cdrolet only | Per-user | **System read-only (hardcoded) + per-user write (secrets)** |
| **Push method** | Manual | Post-build-hook | Manual | **Build-and-push (just build-and-push)** |
| **Agent** | Not included | System service | System service | **System service (cdrolet token)** |
| **Complexity** | Medium | Low | Medium | **Low-Medium (best of both)** |

**Final Architecture Benefits**:

- ✅ Everyone benefits from cache (no config needed)
- ✅ Security isolation for write access (per-user secrets)
- ✅ Simple for read-only users (majority)
- ✅ Flexible for power users (opt-in write)
- ✅ Remote deployments enabled (agent)
- ✅ Consistent across platforms (manual push)
