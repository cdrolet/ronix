# Research: Cachix Integration

**Feature**: 034-cachix-integration\
**Date**: 2025-12-31\
**Research Phase**: Phase 0 - Technical Foundation

## Overview

This document consolidates research findings for implementing Cachix binary cache integration into the nix-config repository. Research focused on five key areas:

1. **Cachix configuration methods** - How to configure binary caches in Nix
1. **Authentication approaches** - Secure token storage and usage
1. **Read-only default strategy** - System-wide read access without configuration
1. **Push strategies by platform** - How to share builds (darwin vs nixos)
1. **Cachix-deploy agent** - Remote deployment service integration

______________________________________________________________________

## 1. Cachix Configuration Methods

### Decision: Use `nix.settings` for Declarative Configuration

**Rationale:**

- `nix.settings` is the modern, declarative approach for NixOS and nix-darwin
- Automatically generates `/etc/nix/nix.conf` from declarative configuration
- Integrates seamlessly with flakes and Home Manager
- Matches repository's declarative-first philosophy (Constitution Principle I)

**Alternatives Considered:**

| Method | Pros | Cons | Decision |
|--------|------|------|----------|
| **nix.settings** (chosen) | ✅ Declarative<br>✅ Flake-compatible<br>✅ Home Manager support | - | ✅ **SELECTED** |
| Direct nix.conf editing | ✅ Quick for testing | ❌ Not declarative<br>❌ Conflicts with module system | ❌ Rejected |
| nixConfig in flake.nix | ✅ Project-level hints | ❌ Interactive prompts<br>❌ Not automatic | ❌ Rejected |
| cachix use command | ✅ CLI convenience | ❌ Not reproducible<br>❌ Conflicts with declarations | ❌ Rejected |

### Implementation Approach

**Public Cache Configuration:**

```nix
# system/shared/settings/cachix.nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org/"           # Official (default)
    "https://nix-community.cachix.org"   # Community cache
  ];
  
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
};
```

**Private Cache Configuration (Read-Only Default):**

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://default.cachix.org"  # Read-only access for all users
  ];
  
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
  ];
  
  # Read-only token hardcoded (no secret needed)
  extra-substituters = ["https://default.cachix.org"];
  extra-trusted-public-keys = ["default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="];
};
```

______________________________________________________________________

## 2. Authentication Architecture

### Decision: Hybrid Read-Only Default + Per-User Write

**Rationale:**

- Everyone benefits from cache without configuration (read-only default)
- Users opt into write access independently (per-user secrets)
- netrc is Nix's native authentication mechanism for HTTP substituters
- Integrates with existing agenix setup (Feature 031 per-user secrets)
- Aligns with repository's activation script pattern

**Authentication Methods Comparison:**

| Method | Use Case | Integration | Decision |
|--------|----------|-------------|----------|
| **Hardcoded read-only token** | System-wide reads | ✅ No secrets needed | ✅ **SELECTED for reads** |
| **netrc file (per-user)** | Write access | ✅ Perfect for agenix + activation | ✅ **SELECTED for writes** |
| Environment variable | CI/CD, temp sessions | ⚠️ Not persistent | ⚠️ Secondary option |
| access-tokens setting | Newer Nix versions | ⚠️ Requires Nix 2.24+ | ❌ Too new |

### Read-Only Default Strategy

**System-Wide Configuration:**

```nix
# Hardcoded read-only token (no secret management needed)
nix.settings = {
  substituters = ["https://default.cachix.org"];
  trusted-public-keys = ["default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="];
};

# Option 1: Environment variable (works for downloads)
nix.settings.extra-sandbox-paths = [
  "/etc/nix/cachix-env"
];

environment.etc."nix/cachix-env".text = ''
  export CACHIX_AUTH_TOKEN="eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c"
'';

# Option 2: System-wide netrc (simpler)
environment.etc."nix/netrc".text = ''
  machine default.cachix.org
    login cachix
    password eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c
'';

nix.settings.netrc-file = "/etc/nix/netrc";
```

**Benefits:**

- ✅ All users benefit from cache without any configuration
- ✅ No per-user secrets needed for reads
- ✅ Read-only token safe to hardcode (limited scope)
- ✅ Clean separation: system provides reads, users opt into writes

### Per-User Write Access (Optional)

**Netrc File Format:**

```
machine default.cachix.org
  login cachix
  password YOUR_WRITE_TOKEN_HERE
```

**Location:** `~/.config/nix/netrc` (user-level, generated at activation)

**Permissions:** `600` (owner read/write only)

### Token Storage Pattern

Following Feature 031 (per-user secrets):

1. **User configuration:**

   ```nix
   user.cachix = {
     authToken = "<secret>";  # Read-write token placeholder
     cacheName = "default";   # Optional, defaults to "default"
   };
   ```

1. **Encrypted storage:**

   ```bash
   just secrets-set username cachix.authToken "eyJhbGc..."
   ```

   Stored in `user/{username}/secrets.age` as JSON:

   ```json
   {
     "email": "user@example.com",
     "cachix": {
       "authToken": "eyJhbGciOiJIUzI1NiJ9..."
     }
   }
   ```

1. **Activation script resolution:**

   ```nix
   home.activation.applyCachixAuth = secrets.mkActivationScript {
     inherit config pkgs lib;
     name = "cachix";
     fields = {
       "cachix.authToken" = ''
         mkdir -p ~/.config/nix
         echo "machine ${cacheName}.cachix.org login cachix password $CACHIX_AUTHTOKEN" > ~/.config/nix/netrc
         chmod 600 ~/.config/nix/netrc
       '';
     };
   };
   ```

**Why This Pattern:**

- ✅ Matches existing git.nix, gh.nix secret handling
- ✅ Secrets never in Nix store (activation-time resolution)
- ✅ Per-user encryption keys (security isolation)
- ✅ Standard netrc format (works with nix and cachix CLI)
- ✅ Optional - users without config still get read-only access

______________________________________________________________________

## 3. Push Strategies by Platform

### Challenge: Darwin post-build-hook runs as nix-daemon (root)

**Key Finding:** Post-build-hook does NOT have access to current user config. It runs in nix-daemon context as root, not in a user's context.

**Environment variables available:**

- `$OUT_PATHS`: Store paths of build outputs
- `$DRV_PATH`: Derivation file path
- No user-specific context or configuration

### Push Strategy Decision Matrix

| Platform | Strategy | Rationale |
|----------|----------|-----------|
| **Darwin** | Build-and-push via `just build-and-push` | Post-build-hook can't access user secrets cleanly |
| **NixOS** | Build-and-push via `just build-and-push` | Consistent with darwin, simpler than post-build-hook |

### Darwin: Build-and-Push Command

**Implementation:**

```bash
# justfile
build-and-push user="" host="":
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Build first (reuses existing build recipe logic)
    just build {{user}} {{host}}
    
    # Check if user has write access configured
    if [ ! -f ~/.config/nix/netrc ]; then
        echo ""
        echo "Build complete! (read-only mode - no push)"
        echo "To enable push, configure: just secrets-set <user> cachix.authToken '<token>'"
        exit 0
    fi
    
    # Push build result to cache
    if [ -L ./result ]; then
        echo ""
        echo "Pushing build to cache..."
        cachix push default ./result
        echo "Push complete!"
    else
        echo "Warning: No ./result symlink found, skipping push"
    fi
```

**Usage:**

```bash
# Build and push in one command (if write access configured)
just build-and-push username hostname

# Or just build without push
just build username hostname
```

**Benefits:**

- ✅ One command for build + push workflow
- ✅ Works with per-user secrets (reads user's netrc)
- ✅ Consistent with repo's just-based workflow
- ✅ Graceful degradation (builds without push if no auth)
- ✅ No fighting with daemon architecture
- ✅ Users choose: `build` (no push) or `build-and-push` (with push)

### NixOS: Optional Post-Build-Hook

**Implementation:**

```nix
# system/nixos/settings/cachix.nix
nix.settings.post-build-hook = pkgs.writeShellScript "cachix-push" ''
  set -eu
  set -f # disable globbing
  
  # Use system-level netrc with write token
  export HOME=/var/lib/cachix-pusher
  
  # Push all build outputs
  ${pkgs.cachix}/bin/cachix push default $OUT_PATHS
'';

# Create system user with netrc
users.users.cachix-pusher = {
  isSystemUser = true;
  home = "/var/lib/cachix-pusher";
};

# Generate netrc from one user's secret (cdrolet by convention)
# This requires system-level secret extraction - complex
```

**Challenges:**

- Requires extracting secret at system level (not user level)
- Breaks per-user secret model
- Complex implementation

**Recommendation:** Skip post-build-hook on NixOS initially. Build-and-push via just recipe works on all platforms and is simpler.

______________________________________________________________________

## 4. Cachix-Deploy Agent Integration

### Decision: System Service with User Secret Token

**Architecture:**

- Service runs system-wide (launchd on darwin, systemd on nixos)
- Token stored in one user's secrets (cdrolet by convention)
- Wrapper script extracts token from secrets.age JSON

### Implementation Pattern

**Wrapper Script:**

```bash
#!/usr/bin/env bash
# Extract agent token from user secrets

USER_SECRETS="/Users/cdrolet/secrets.age"  # Darwin
# USER_SECRETS="/home/cdrolet/secrets.age"  # NixOS

if [ ! -f "$USER_SECRETS" ]; then
    echo "Error: Secrets file not found: $USER_SECRETS"
    exit 1
fi

# Decrypt and extract token
AGENT_TOKEN=$(${pkgs.age}/bin/age -d -i ~/.config/agenix/key.txt "$USER_SECRETS" 2>/dev/null | \
              ${pkgs.jq}/bin/jq -r '.cachix.agentToken // empty')

if [ -z "$AGENT_TOKEN" ]; then
    echo "Error: cachix.agentToken not found in secrets"
    exit 1
fi

# Run agent with token
export CACHIX_AGENT_TOKEN="$AGENT_TOKEN"
exec ${pkgs.cachix}/bin/cachix deploy agent default
```

### Darwin: launchd Service

```nix
# system/darwin/settings/cachix-agent.nix
launchd.daemons.cachix-deploy-agent = {
  serviceConfig = {
    ProgramArguments = [
      "${pkgs.bash}/bin/bash"
      "${./cachix-agent-wrapper.sh}"
    ];
    
    RunAtLoad = true;
    KeepAlive = true;
    StandardOutPath = "/var/log/cachix-agent.log";
    StandardErrorPath = "/var/log/cachix-agent.log";
  };
};
```

### NixOS: systemd Service

```nix
# system/nixos/settings/cachix-agent.nix
systemd.services.cachix-deploy-agent = {
  description = "Cachix Deploy Agent";
  wantedBy = [ "multi-user.target" ];
  after = [ "network-online.target" ];
  
  serviceConfig = {
    ExecStart = "${pkgs.bash}/bin/bash ${./cachix-agent-wrapper.sh}";
    Restart = "always";
    RestartSec = "10s";
  };
};
```

**Benefits:**

- ✅ Works on both platforms (unified approach)
- ✅ Uses existing per-user secrets infrastructure
- ✅ Auto-starts on boot
- ✅ Auto-restarts on failure

**Agent Details:**

- Workspace: "default"
- Token scope: "agent"
- Token stored in: `user/cdrolet/secrets.age` → `cachix.agentToken`
- Documentation: https://docs.cachix.org/deploy/running-an-agent/

______________________________________________________________________

## 5. Substituter Priority and Fallback

### Priority Mechanics

**Explicit Priority via URL Parameter:**

```nix
substituters = [
  "https://default.cachix.org?priority=10"   # Higher priority (lower number)
  "https://cache.nixos.org?priority=40"      # Default priority
];
```

**Priority Ranges:**

- `1-9`: Highest priority (organizational caches)
- `10-30`: High priority (project caches) ← **default.cachix.org uses 10**
- `40`: Default (cache.nixos.org)
- `50+`: Lower priority (experimental/unreliable caches)

**Order Matters:**

- When priorities are equal, left-to-right query order
- First successful response wins

### Fallback Behavior

1. **Cache unavailable:** Nix tries next substituter in list
1. **No cache has package:** Nix builds from source
1. **Negative caching:** Nix remembers cache misses (can cause confusion)

**Clear negative cache:**

```bash
rm -rf ~/.cache/nix
```

### Verification Methods

```bash
# Method 1: Watch build logs
nix build .#darwinConfigurations.user-host.system --print-build-logs
# Look for: "copying path '/nix/store/xxx' from 'https://...'"

# Method 2: Check nix.conf
cat /etc/nix/nix.conf | grep substituters

# Method 3: Verbose logging
nix build .#something --verbose
# Look for: "querying https://..." messages

# Method 4: Test specific cache
nix-store -r /nix/store/xxx \
  --option substituters https://default.cachix.org \
  --option trusted-public-keys "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs="
```

______________________________________________________________________

## 6. Integration with Repository Architecture

### Recommended Structure

Following the User/System Split pattern (Constitution v2.0.0):

```
system/
  shared/
    settings/
      cachix.nix          # System-wide read-only + per-user write logic
  darwin/
    settings/
      cachix-agent.nix    # Darwin agent service (optional)
  nixos/
    settings/
      cachix-agent.nix    # NixOS agent service (optional)

user/
  {name}/
    default.nix           # Optional: user.cachix.authToken = "<secret>"
    secrets.age           # Optional: cachix.authToken write token

user/shared/lib/
  secrets.nix             # Existing mkActivationScript helper (Feature 031)

justfile                  # Add push-cache recipe
```

### Configuration Layers

**Layer 1: System-Wide Read-Only** (`system/shared/settings/cachix.nix`)

- Hardcoded read-only token for default.cachix.org
- Public cache substituters
- Base trusted-public-keys
- All users benefit without configuration

**Layer 2: Per-User Write Access** (same module, optional)

- Reads `config.user.cachix` (if defined)
- Generates user netrc via activation script
- Enables push via `just push-cache`

**Layer 3: Agent Service** (platform-specific, optional)

- Darwin: `system/darwin/settings/cachix-agent.nix`
- NixOS: `system/nixos/settings/cachix-agent.nix`
- Reads token from one user's secrets (cdrolet)

### Module Auto-Discovery

Modules automatically imported by `system/shared/settings/default.nix`:

```nix
{ config, lib, pkgs, ... }:
let
  discovery = import ../lib/discovery.nix {inherit lib;};
in {
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

No manual imports needed - follows existing discovery pattern.

______________________________________________________________________

## 7. Performance and Security

### Performance Optimization

**Recommended Priority Strategy:**

```nix
substituters = [
  # Organization cache (fastest, most reliable)
  "https://default.cachix.org?priority=10"
  
  # Community caches
  "https://nix-community.cachix.org?priority=20"
  
  # Official cache (default priority 40)
  "https://cache.nixos.org"
];
```

**Expected Build Time Improvements:**

- Packages in cache: 50-90% faster (download vs compile)
- Large dependencies (LLVM, GHC, etc.): 95%+ faster
- Incremental rebuilds: Minimal improvement (already fast)

### Security Considerations

**Token Security:**

- ✅ Read-only token hardcoded (limited scope, safe)
- ✅ Write tokens stored encrypted in `secrets.age` (agenix)
- ✅ Write tokens decrypted only at activation time
- ✅ netrc file has 600 permissions (user-only read)
- ✅ Per-user encryption keys (security isolation)
- ✅ Never committed to git in plaintext

**Public Key Verification:**

- All substituters require trusted-public-keys
- Nix verifies package signatures before installation
- Prevents cache poisoning attacks

**Token Rotation:**

```bash
# Rotate user's Cachix write token
just secrets-set username cachix.authToken "new-token"
just install username hostname

# Rotate agent token (stored in cdrolet's secrets)
just secrets-set cdrolet cachix.agentToken "new-token"
# Restart agent service
```

______________________________________________________________________

## Key Decisions Summary

### Configuration Approach

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Config method** | nix.settings | Declarative, flake-compatible |
| **Read-only auth** | Hardcoded token | No secrets needed, everyone benefits |
| **Write auth** | Per-user netrc | Optional, preserves security isolation |
| **Token storage** | agenix secrets.age | Per-user encryption (Feature 031) |
| **Resolution** | Activation script | Matches existing pattern (git.nix, gh.nix) |
| **Module location** | system/shared/settings/ | Cross-platform, auto-discovered |
| **Push strategy** | just build-and-push | Works with per-user secrets, one-command workflow |
| **Agent** | System service | Uses one user's token (cdrolet) |

### Implementation Pattern

| Component | Implementation | File |
|-----------|----------------|------|
| Read-only access | Hardcoded in nix.settings | system/shared/settings/cachix.nix |
| Write access config | config.user.cachix | user/{name}/default.nix (optional) |
| Write token | "<secret>" placeholder | user/{name}/default.nix (optional) |
| Token storage | Encrypted JSON | user/{name}/secrets.age (optional) |
| netrc generation | Activation script | system/shared/settings/cachix.nix |
| Secret helper | mkActivationScript | user/shared/lib/secrets.nix (existing) |
| Push helper | just build-and-push | justfile |
| Agent service (darwin) | launchd daemon | system/darwin/settings/cachix-agent.nix |
| Agent service (nixos) | systemd service | system/nixos/settings/cachix-agent.nix |

______________________________________________________________________

## Open Questions (All Resolved)

### Q1: Should we use netrc-file setting or generate netrc manually? ✅

**Answer**: Generate netrc via activation script. The `nix.settings.netrc-file` setting requires trusted-user privileges and is less flexible than dynamic generation at activation time.

### Q2: System-level vs user-level cache configuration? ✅

**Answer**: Hybrid approach:

- System-level read-only for all users (hardcoded token)
- User-level write access (per-user secrets, optional)

### Q3: Support cachix CLI or just nix commands? ✅

**Answer**: Support both:

- Primary: nix commands (works automatically with netrc for reads)
- Secondary: cachix CLI (for `just push-cache`)

### Q4: How to handle darwin push with per-user secrets? ✅

**Answer**: Manual push via `just push-cache`. Post-build-hook runs as nix-daemon (root) and can't access user secrets cleanly.

### Q5: What about users without cachix configured? ✅

**Answer**: They get read-only access automatically (system default). Write access is opt-in.

______________________________________________________________________

## Research Sources

- [Cachix Documentation - Getting Started](https://docs.cachix.org/getting-started)
- [Cachix FAQ](https://docs.cachix.org/faq)
- [Cachix Deploy - Running an Agent](https://docs.cachix.org/deploy/running-an-agent/)
- [Binary Cache - NixOS Wiki](https://nixos.wiki/wiki/Binary_Cache)
- [Nix Reference Manual - nix.conf](https://nix.dev/manual/nix/2.24/command-ref/conf-file.html)
- [Nix Reference Manual - post-build-hook](https://nix.dev/manual/nix/2.24/command-ref/conf-file.html#conf-post-build-hook)
- [Agenix - NixOS Wiki](https://nixos.wiki/wiki/Agenix)
- [GitHub - ryantm/agenix](https://github.com/ryantm/agenix)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Add Binary Cache - Nix.dev](https://nix.dev/guides/recipes/add-binary-cache.html)
- [NixOS Discourse - Cachix in flake-based config](https://discourse.nixos.org/t/how-to-set-up-cachix-in-flake-based-nixos-config/31781)

## Next Steps (Phase 1 - Design)

1. ✅ Update spec.md with final architecture
1. ✅ Update research.md with read-only default and just recipe approach
1. Update data-model.md defining cachix configuration structure
1. Update contracts/ with user configuration schema
1. Update quickstart.md with usage examples
1. Update plan.md with final technical approach
1. Re-evaluate Constitution Check with concrete design
