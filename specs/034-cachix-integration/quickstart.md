# Quickstart: Cachix Integration

**Feature**: 034-cachix-integration\
**Date**: 2025-12-31

## Overview

This guide shows how to use Cachix binary caching in your nix-config. All users automatically benefit from read-only cache access. Users who want to push builds can optionally configure write access.

**Key Concepts**:

- **Read-only access**: Automatic for all users (no configuration needed)
- **Write access**: Optional, via per-user secrets (for users who push builds)
- **Cache name**: "default" (default.cachix.org)

______________________________________________________________________

## Prerequisites

- Nix-config repository set up with Feature 031 (per-user secrets)
- User configuration in `user/{name}/default.nix`
- For write access: Cachix account at https://app.cachix.org

______________________________________________________________________

## Use Case 1: Read-Only Access (No Configuration)

**Scenario**: Download pre-built packages to speed up builds.

**Configuration**: **NONE NEEDED!** All users automatically get read-only access to default.cachix.org.

**Verify it's working:**

```bash
# Build something
just build username hostname

# Watch for cache downloads in the logs:
# "copying path '/nix/store/xxx' from 'https://default.cachix.org'"

# Or check nix.conf:
cat /etc/nix/nix.conf | grep substituters
# Should include: https://default.cachix.org?priority=10
```

**Benefits**:

- ✅ Faster builds (download vs compile)
- ✅ No configuration required
- ✅ No secrets needed
- ✅ Works for all users automatically

**Limitations**:

- ❌ Cannot push builds to cache (read-only)

______________________________________________________________________

## Use Case 2: Write Access (Push Builds to Cache)

**Scenario**: Push your builds to the cache so other machines/users can reuse them.

### Step 1: Get Write Token

1. Visit https://app.cachix.org/personal-auth-tokens
1. Create a **write token** (scope: "cache", read-write)
1. Copy the token (starts with `eyJhbGc...`)

### Step 2: Configure User

Edit `user/{username}/default.nix`:

```nix
{ ... }:
{
  user = {
    name = "username";
    email = "<secret>";
    applications = [ "*" ];
    
    # Add Cachix write access configuration
    cachix = {
      authToken = "<secret>";  # Write token (from secrets.age)
      # cacheName defaults to "default"
    };
  };
}
```

### Step 3: Add Secret Token

```bash
# Store the write token in encrypted secrets
just secrets-set username cachix.authToken "eyJhbGc..."
```

This stores the token in `user/{username}/secrets.age` as:

```json
{
  "cachix": {
    "authToken": "eyJhbGc..."
  }
}
```

### Step 4: Rebuild

```bash
just install username hostname
```

This generates `~/.config/nix/netrc` with your write token at activation time.

### Step 5: Build and Push to Cache

```bash
# Build and automatically push to cache (one command)
just build-and-push username hostname

# Or build without pushing
just build username hostname
```

**Verify**:

```bash
# Check netrc file was created
cat ~/.config/nix/netrc
# Should show: machine default.cachix.org login cachix password eyJhbGc...

# Check cache contents at https://app.cachix.org/cache/default
# You should see newly pushed derivations
```

**Benefits**:

- ✅ Faster builds (download from cache)
- ✅ Can push builds to share with other machines/users
- ✅ One-command workflow: `just build-and-push`

______________________________________________________________________

## Use Case 3: Custom Cache Name

**Scenario**: Use a different Cachix cache instead of "default".

### Configuration

```nix
user = {
  name = "username";
  applications = [ "*" ];
  
  cachix = {
    authToken = "<secret>";
    cacheName = "my-org-cache";  # Override to different cache
  };
};
```

### Setup

```bash
# Store write token for your custom cache
just secrets-set username cachix.authToken "your-org-cache-write-token"

# Rebuild
just install username hostname
```

### Build and Push to Custom Cache

```bash
# Build and push (uses cacheName from config)
just build-and-push username hostname

# Note: build-and-push uses default cache unless you modify the justfile recipe
# For custom caches, you may need to manually specify:
cachix push my-org-cache ./result
```

**Benefits**:

- ✅ Read from default.cachix.org (system default, read-only)
- ✅ Read from my-org-cache.cachix.org (your write token)
- ✅ Can push to my-org-cache

______________________________________________________________________

## Use Case 4: Cachix Deploy Agent (Remote Deployments)

**Scenario**: Enable remote deployments via Cachix dashboard/CI.

**Note**: Agent configuration is system-level (one agent per machine), implemented separately from user config.

### Prerequisites

1. Agent token from https://app.cachix.org/workspace/default/agents
1. Store in one user's secrets (cdrolet by convention):

```bash
just secrets-set cdrolet cachix.agentToken "eyJhbGc..."
```

### Verify Agent Status

```bash
# Darwin
sudo launchctl list | grep cachix-deploy-agent

# NixOS
systemctl status cachix-deploy-agent
```

### Usage

1. Trigger deployment from Cachix dashboard
1. Agent receives deployment command
1. System applies configuration remotely

______________________________________________________________________

## Troubleshooting

### Problem: Not using cache (building locally)

**Debug steps**:

1. **Check substituters configuration**:

   ```bash
   cat /etc/nix/nix.conf | grep substituters
   # Should include: https://default.cachix.org?priority=10
   ```

1. **Check for negative caching**:

   ```bash
   # Clear negative cache
   rm -rf ~/.cache/nix
   ```

1. **Verify cache has the package**:

   - Visit https://app.cachix.org/cache/default
   - Search for the derivation hash
   - If not found, cache doesn't have it yet (build will be local)

______________________________________________________________________

### Problem: "401 Unauthorized" when pushing

**Cause**: No write token configured, or token expired/revoked.

**Solution**:

```bash
# Check if netrc exists
cat ~/.config/nix/netrc
# If missing: you didn't configure user.cachix.authToken

# If exists but still 401: token is invalid
# Get a new write token from https://app.cachix.org/personal-auth-tokens
just secrets-set username cachix.authToken "new-write-token"
just install username hostname
```

______________________________________________________________________

### Problem: "No ./result symlink found"

**Cause**: The build didn't create a result symlink (rare).

**Solution**:

```bash
# Use build-and-push which handles this automatically
just build-and-push username hostname

# If build succeeds but no result, this is expected for some configurations
```

______________________________________________________________________

### Problem: Want read-only access back after configuring write

**Solution**: Just remove the `cachix` config from your user file or comment it out:

```nix
user = {
  name = "username";
  
  # cachix = {
  #   authToken = "<secret>";
  # };
};
```

Rebuild, and you're back to read-only (system default).

______________________________________________________________________

## Configuration Decision Tree

```
Do you want to push builds to cache?
│
├─ NO  → Don't configure anything! (read-only access automatic)
│        Use: just build username hostname
│
└─ YES → Configure user.cachix.authToken = "<secret>"
         Use: just build-and-push username hostname
         │
         ├─ Using default.cachix.org?
         │  │
         │  └─ YES → Just add authToken (cacheName defaults to "default")
         │
         └─ Using custom cache?
            │
            └─ YES → Add authToken + cacheName = "my-cache"
```

______________________________________________________________________

## Quick Reference

### Commands

```bash
# Setup write access
just secrets-set username cachix.authToken "token"
just install username hostname

# Build only (read-only)
just build username hostname

# Build and push (write access)
just build-and-push username hostname

# Check configuration
cat ~/.config/nix/netrc           # User netrc (write token)
cat /etc/nix/nix.conf              # System config (read-only)
```

### Configuration Templates

**Read-Only (No Config)**:

```nix
# user/{username}/default.nix
user = {
  name = "username";
  applications = ["*"];
  # No cachix config - automatically gets read-only access
};
```

**Write Access (Default Cache)**:

```nix
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";  # Write token
    # cacheName defaults to "default"
  };
};
```

**Write Access (Custom Cache)**:

```nix
user = {
  name = "username";
  applications = ["*"];
  
  cachix = {
    authToken = "<secret>";
    cacheName = "my-org-cache";  # Override cache name
  };
};
```

______________________________________________________________________

## Expected Build Time Improvements

With default.cachix.org configured:

| Scenario | Without Cache | With Cache | Improvement |
|----------|---------------|------------|-------------|
| Fresh install | 30-60 minutes | 5-10 minutes | **80-90%** |
| Package update | 10-20 minutes | 2-5 minutes | **70-80%** |
| Config change only | 1-2 minutes | 30-60 seconds | **50%** |

**Note**: Improvements vary based on what's in the cache. First user to build pushes, others benefit.

______________________________________________________________________

## Next Steps

### For Read-Only Users (Most Users)

1. ✅ **Done!** You're already benefiting from cache
1. Verify: `cat /etc/nix/nix.conf | grep default.cachix.org`

### For Users Who Push Builds

1. **Get write token**: Visit https://app.cachix.org/personal-auth-tokens
1. **Configure user**: Add `user.cachix.authToken = "<secret>"`
1. **Store secret**: `just secrets-set username cachix.authToken "token"`
1. **Rebuild**: `just install username hostname`
1. **Test push**: `just build-and-push username hostname`

### For System Administrators

1. **Enable agent** (optional): Configure cachix-deploy agent for remote deployments
1. **Monitor cache**: Visit https://app.cachix.org/cache/default to see usage
1. **Manage tokens**: Rotate tokens periodically for security

**Documentation**: See `CLAUDE.md` for full Cachix integration details after implementation.
