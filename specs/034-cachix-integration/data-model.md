# Data Model: Cachix Integration

**Feature**: 034-cachix-integration\
**Date**: 2025-12-31

## Overview

This document defines the data entities and relationships for Cachix binary cache integration. The model supports:

1. **System-wide read-only access** - Hardcoded read-only token for all users (no config needed)
1. **Per-user write access** - Optional write tokens via secrets (opt-in)
1. **Cachix-deploy agent** - System service for remote deployments

______________________________________________________________________

## Entities

### 1. System-Wide Cache Configuration

**Description**: Read-only cache access available to all users without configuration.

**Attributes**:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | String | Yes | `"default"` | Cache name |
| `url` | String | Auto-generated | `"https://default.cachix.org"` | Full cache URL |
| `publicKey` | String | Yes | - | Cache's public signing key for verification |
| `readOnlyToken` | String (hardcoded) | Yes | - | Read-only auth token (safe to hardcode) |
| `priority` | Integer | No | `10` | Substituter priority (lower = higher priority) |

**Validation Rules**:

- `name`: Alphanumeric + hyphens, 3-50 characters
- `publicKey`: Must match format `{name}.cachix.org-1:{base64-key}`
- `priority`: Range 1-100 (1 = highest, 100 = lowest)
- `readOnlyToken`: JWT format, scope: "cache" (read-only)

**Example**:

```nix
{
  name = "default";
  url = "https://default.cachix.org";
  publicKey = "default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=";
  readOnlyToken = "eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c";
  priority = 10;
}
```

______________________________________________________________________

### 2. User Cachix Configuration (Optional)

**Description**: Per-user Cachix settings for write access. Users without this configuration still benefit from system-wide read-only access.

**Attributes**:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `authToken` | String (secret) | No | `null` | Write auth token ("<secret>" placeholder) |
| `cacheName` | String | No | `"default"` | Cache name (can override to use different cache) |

**Validation Rules**:

- `authToken`: Must use `"<secret>"` placeholder pattern if set
- `cacheName`: Must match configured cache if overriding

**Behavior**:

- **authToken undefined**: User has read-only access (system default)
- **authToken = "<secret>"**: User has write access (can push via `just push-cache`)
- **cacheName undefined**: Defaults to "default"

**Example (Read-only - no config needed)**:

```nix
# User doesn't configure cachix at all
# Still gets read-only access to default.cachix.org
user = {
  name = "username";
  applications = ["*"];
  # No cachix field - uses system defaults
};
```

**Example (Write access)**:

```nix
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";  # Write token, resolved from secrets.age
    # cacheName defaults to "default"
  };
};
```

**Example (Custom cache)**:

```nix
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";
    cacheName = "my-custom-cache";  # Override to use different cache
  };
};
```

______________________________________________________________________

### 3. Cachix Deploy Agent Configuration

**Description**: System service configuration for remote deployment via Cachix.

**Attributes**:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `workspace` | String | Yes | `"default"` | Cachix workspace name |
| `agentToken` | String (secret) | Yes | - | Agent authentication token |
| `serviceUser` | String | Yes | Platform-dependent | User running the agent service |

**Validation Rules**:

- `workspace`: Alphanumeric + hyphens, 3-50 characters
- `agentToken`: JWT format, scope: "agent"
- `serviceUser`: Must be valid system user

**Platform-Specific Details**:

| Platform | Service Manager | Service User | Log Location |
|----------|----------------|--------------|--------------|
| Darwin | launchd | root | `/var/log/cachix-agent.log` |
| NixOS | systemd | root | journalctl |

**Example**:

```nix
{
  workspace = "default";
  agentToken = "<extracted-from-cdrolet-secrets>";  # From user/cdrolet/secrets.age
  serviceUser = "root";  # Darwin/NixOS
}
```

______________________________________________________________________

### 4. Netrc Entry

**Description**: Authentication credential for HTTP(S) cache access, generated at activation time for users with write access.

**Attributes**:

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `machine` | String | Yes | - | Cache hostname (e.g., "default.cachix.org") |
| `login` | String | Yes | `"cachix"` | Username (always "cachix" for Cachix) |
| `password` | String (secret) | Yes | - | Write auth token (decrypted from secrets.age) |

**File Format**:

```
machine default.cachix.org
  login cachix
  password eyJhbGciOiJIUzI1NiJ9...
```

**File Location**: `~/.config/nix/netrc`
**Permissions**: `600` (owner read/write only)

**Generation**: Created by home.activation script from `user.cachix.authToken` secret

**When Generated**:

- Only for users who have configured `user.cachix.authToken = "<secret>"`
- Not generated if user has no cachix configuration (read-only mode)

______________________________________________________________________

## Relationships

```
┌─────────────────────────────────┐
│   System Configuration          │
│  (system/shared/settings/)      │
│                                 │
│  - default.cachix.org (r/o)     │
│  - Read-only token (hardcoded)  │
│  - Public key                   │
└──────────────┬──────────────────┘
               │
               │ provides read-only access to ALL users
               ▼
┌─────────────────────────────────┐
│   User Configuration            │
│  (user/{name}/default.nix)      │
│                                 │
│  - user.cachix.authToken (opt)  │
│  - user.cachix.cacheName (opt)  │
└──────────────┬──────────────────┘
               │
               │ IF authToken configured
               ▼
┌─────────────────────────────────┐
│   Secrets Storage               │
│  (user/{name}/secrets.age)      │
│                                 │
│  - cachix.authToken (encrypted) │
│  - cachix.agentToken (cdrolet)  │
└──────────────┬──────────────────┘
               │
               │ decrypted at activation
               ▼
┌─────────────────────────────────┐
│   Runtime Netrc File            │
│  (~/.config/nix/netrc)          │
│                                 │
│  - machine default.cachix.org   │
│  - login cachix                 │
│  - password {write-token}       │
└──────────────┬──────────────────┘
               │
               │ used for push operations
               ▼
┌─────────────────────────────────┐
│   just push-cache               │
│                                 │
│  - Reads netrc for auth         │
│  - Pushes ./result to cache     │
└─────────────────────────────────┘


┌─────────────────────────────────┐
│   Cachix Deploy Agent           │
│  (system service)               │
│                                 │
│  - Workspace: default           │
│  - Token from cdrolet secrets   │
│  - Auto-start on boot           │
└─────────────────────────────────┘
               │
               │ receives deployments
               ▼
┌─────────────────────────────────┐
│   Cachix Dashboard              │
│                                 │
│  - Trigger remote deployments   │
│  - Monitor agent status         │
└─────────────────────────────────┘
```

______________________________________________________________________

## State Transitions

### User Cachix Configuration Lifecycle

```
┌──────────────────┐
│   Unconfigured   │
│   (read-only)    │
│                  │
│  Benefits:       │
│  ✓ Downloads     │
│  ✗ Pushes        │
└───────┬──────────┘
        │
        │ User adds cachix.authToken = "<secret>"
        ▼
┌──────────────────┐
│   Configured     │
│   (no secret)    │
│                  │
│  Benefits:       │
│  ✓ Downloads     │
│  ✗ Pushes (error)│
└───────┬──────────┘
        │
        │ User runs: just secrets-set username cachix.authToken "token"
        ▼
┌──────────────────┐
│   Secret Stored  │
│   (encrypted)    │
│                  │
│  Benefits:       │
│  ✓ Downloads     │
│  ⚠ Pushes (needs │
│    activation)   │
└───────┬──────────┘
        │
        │ User runs: just install username hostname
        │ Activation script generates netrc
        ▼
┌──────────────────┐
│   Active         │
│   (can push)     │
│                  │
│  Benefits:       │
│  ✓ Downloads     │
│  ✓ Pushes        │
└───────┬──────────┘
        │
        │ Token expires/rotates
        ▼
┌──────────────────┐
│   Needs Rotation │
│   (401 errors)   │
│                  │
│  Benefits:       │
│  ✓ Downloads     │
│  ✗ Pushes (401)  │
└───────┬──────────┘
        │
        │ User rotates: just secrets-set username cachix.authToken "new-token"
        │               just install username hostname
        └─────────┐
                  │
                  ▼
         ┌──────────────────┐
         │   Re-authenticated│
         │   (active)        │
         └──────────────────┘
```

### Cache Query Flow (With Read-Only Default)

```
┌───────────────┐
│  Nix requests │
│  package      │
└───────┬───────┘
        │
        ▼
┌───────────────────────────────┐
│  Query substituters in        │
│  priority order               │
└───────┬───────────────────────┘
        │
        ├─────────┬─────────────┬────────────┐
        ▼         ▼             ▼            ▼
    ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐
    │default  │ │cache.    │ │Other     │ │Build   │
    │(p=10)   │ │nixos.org │ │caches    │ │Locally │
    │         │ │(p=40)    │ │          │ │        │
    │READ-ONLY│ │          │ │          │ │        │
    └───┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘
        │            │             │            │
        │ Found?     │ Found?      │ Found?     │ None
        ▼            ▼             ▼            ▼
    ┌──────────────────────────────────────────────┐
    │  Return package (from cache or build)        │
    └──────────────────────────────────────────────┘
```

**Key insight**: All users query default.cachix.org first (priority 10), using read-only token automatically.

______________________________________________________________________

## Data Constraints

### Integrity Constraints

1. **Public Key Verification**: Every cache MUST have a corresponding public key in `trusted-public-keys`
1. **Read-Only Default**: System MUST provide read-only access without user configuration
1. **Optional Write**: User write access is optional, read-only is always available
1. **Priority Uniqueness**: Cache priorities can overlap (handled by Nix query order)
1. **Secret Encryption**: Write tokens MUST be encrypted in secrets.age (never plaintext)
1. **Agent Token Storage**: Agent token stored in one user's secrets (cdrolet by convention)

### Business Rules

1. **Fallback Behavior**: System always includes cache.nixos.org as ultimate fallback
1. **Token Expiry**: Tokens don't auto-expire but become invalid when revoked on Cachix
1. **Cache Priority**: Lower number = higher priority (1 = highest, 100 = lowest)
1. **User Isolation**: Each user's write token is encrypted with their own age key
1. **Read-Only Safety**: Read-only token can be hardcoded (limited scope, no write access)
1. **Push Strategy**: Darwin uses `just push-cache` (manual), not post-build-hook
1. **Agent Per-System**: One agent per system (uses one user's token)

______________________________________________________________________

## Example Configurations

### Minimal (Read-Only - No User Config)

```nix
# User config - NO cachix field
user = {
  name = "username";
  applications = ["*"];
};

# System automatically provides:
# - Read-only access to default.cachix.org
# - Priority 10 (checked before cache.nixos.org)
# - No secrets needed
# - No netrc file generated

# User benefits:
# ✓ Downloads from cache
# ✗ Cannot push (no write token)
```

### Read-Only User (Explicit Config)

```nix
# User config - cachix configured but no secret
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    # authToken not configured
    cacheName = "default";  # Explicit (optional)
  };
};

# Behavior: Same as minimal
# ✓ Downloads from cache (read-only)
# ✗ Cannot push (no write token)
```

### Write Access User

```nix
# User config
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";  # Write token
    # cacheName defaults to "default"
  };
};

# Secrets
just secrets-set username cachix.authToken "eyJhbGc..."

# Generated netrc (~/.config/nix/netrc):
# machine default.cachix.org
#   login cachix
#   password eyJhbGc...

# User benefits:
# ✓ Downloads from cache (read-only or write token)
# ✓ Can push via: just push-cache
```

### Custom Cache User

```nix
# User config
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";
    cacheName = "my-org-cache";  # Override to different cache
  };
};

# Secrets
just secrets-set username cachix.authToken "write-token-here"

# Generated netrc:
# machine my-org-cache.cachix.org
#   login cachix
#   password write-token-here

# User benefits:
# ✓ Downloads from default.cachix.org (read-only, system default)
# ✓ Downloads from my-org-cache.cachix.org (write token)
# ✓ Can push to my-org-cache: cachix push my-org-cache ./result
```

### Cachix Deploy Agent (System-Level)

```nix
# Stored in user/cdrolet/secrets.age:
{
  "cachix": {
    "agentToken": "eyJhbGciOiJIUzI1NiJ9..."
  }
}

# System service configuration:
# - Workspace: default
# - Token: Extracted from cdrolet's secrets at service start
# - Auto-restart: Yes
# - Platform: launchd (darwin) or systemd (nixos)

# Usage:
# 1. Service starts on boot
# 2. Connects to Cachix workspace "default"
# 3. Receives deployment commands from dashboard
# 4. Applies configuration changes remotely
```

______________________________________________________________________

## Schema Validation

### User Configuration Schema

```nix
user.cachix = {
  # Optional: Write auth token (use "<secret>" placeholder)
  authToken = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Write access token for Cachix cache";
  };
  
  # Optional: Cache name (defaults to "default")
  cacheName = mkOption {
    type = types.str;
    default = "default";
    description = "Cachix cache name";
  };
};
```

### Secret Storage Schema (Write Access)

```json
{
  "cachix": {
    "authToken": "eyJhbGciOiJIUzI1NiJ9..."
  }
}
```

### Secret Storage Schema (Agent Token - cdrolet)

```json
{
  "cachix": {
    "authToken": "eyJhbGc...",  // Write token (optional)
    "agentToken": "eyJhbGc..."  // Agent token (required for agent service)
  }
}
```

______________________________________________________________________

## Migration Considerations

### Adding Cachix to Existing Configuration

1. **Phase 1**: Add system-wide read-only access (no user changes needed)

   - All users immediately benefit from cache downloads
   - No secrets required
   - Zero configuration burden

1. **Phase 2**: Users opt-in to write access (optional)

   - Add `user.cachix.authToken = "<secret>"`
   - Set secret: `just secrets-set username cachix.authToken "token"`
   - Rebuild: `just install username hostname`

1. **Phase 3**: Enable cachix-deploy agent (optional)

   - Add `cachix.agentToken` to cdrolet's secrets
   - Deploy agent service (launchd/systemd)

**Backward Compatibility**: Configuration without cachix continues to work (uses cache.nixos.org only). Adding system-wide read-only access is non-breaking.

### Token Rotation

**Write Token Rotation (Per-User)**:

```bash
# Step 1: Generate new token at https://app.cachix.org/personal-auth-tokens
# Step 2: Update secret
just secrets-set username cachix.authToken "new-token-here"
# Step 3: Rebuild
just install username hostname
```

**Agent Token Rotation (System-Wide)**:

```bash
# Step 1: Generate new agent token at https://app.cachix.org/workspace/default/agents
# Step 2: Update cdrolet's secret
just secrets-set cdrolet cachix.agentToken "new-agent-token"
# Step 3: Restart agent service
# Darwin: sudo launchctl kickstart -k system/cachix-deploy-agent
# NixOS: sudo systemctl restart cachix-deploy-agent
```

Old token becomes invalid, new token active after activation/restart.

______________________________________________________________________

## Cache Details (Reference)

**Cache Name**: default\
**URL**: https://default.cachix.org\
**Public Key**: `default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=`\
**Read-Only Token**: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzBhM2MxOS1jZmIwLTQ2MDItYjIwMy0zYzUwMjg0Y2E2MjgiLCJzY29wZXMiOiJjYWNoZSJ9.rpYn3jkuZ3yoDzy4UbJF6f5nBQX91KylKnZyEXcJK9c`\
**Read-Write Token**: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiI0ODhkNjViNy1hMTE2LTQzNDYtYTMwNS1kYTAyZmFlN2FhZWIiLCJzY29wZXMiOiJjYWNoZSJ9.uAtsEJmBmRmt1mZErn5wo2mNWGJ7ognHSUAWstxAHHg` (per-user secret)\
**Agent Token**: `eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIzMzVlYWFkMC0yMTBjLTQxNjQtOWE5My04NjQ0Y2NmZDk5ZjgiLCJzY29wZXMiOiJhZ2VudCJ9.PCwuiCMPSb-cVpVzGCyglME6bBpHZ_DURaQe43okL8g` (cdrolet secret)\
**Agent Workspace**: default
