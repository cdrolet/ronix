# Cachix Integration User Guide

Complete guide for using Cachix binary cache in this nix-config repository.

**Feature Status**: ✅ Implemented (Feature 034)

______________________________________________________________________

## Table of Contents

1. [Overview](#overview)
1. [Quick Start](#quick-start)
1. [User Stories](#user-stories)
1. [Configuration Reference](#configuration-reference)
1. [Troubleshooting](#troubleshooting)
1. [Advanced Usage](#advanced-usage)

______________________________________________________________________

## Overview

### What is Cachix?

Cachix is a binary cache service for Nix that dramatically speeds up builds by downloading pre-built packages instead of compiling from source.

### What's Configured?

This repository provides two levels of Cachix integration:

1. **System-wide read-only access** (automatic, no configuration needed)

   - All users automatically download from `default.cachix.org`
   - Significantly faster builds

1. **Per-user write access** (optional, for developers)

   - Push your builds to the cache
   - Share pre-built packages with other users
   - One-command workflow: `just build-and-push`

______________________________________________________________________

## Quick Start

### For Regular Users (Read-Only Access)

**You don't need to do anything!** All users automatically benefit from read-only access to `default.cachix.org`.

```bash
# Just build normally - downloads from cache automatically
just build <user> <host>
```

That's it! Builds will be much faster when packages are already in the cache.

______________________________________________________________________

### For Developers (Write Access)

Want to push your builds to the cache? Follow these steps:

#### 1. Get a Write Token

Visit [Cachix Personal Auth Tokens](https://app.cachix.org/personal-auth-tokens) and create a token with **cache** scope.

#### 2. Store the Token

```bash
just secrets-set <your-username> cachix.authToken "your-token-here"
```

#### 3. Add Configuration

Edit your user config (`user/<username>/default.nix`):

```nix
{ ... }:
{
  user = {
    name = "username";
    email = "user@example.com";
    applications = ["*"];
    
    # Add this section
    cachix = {
      authToken = "<secret>";  # Placeholder for encrypted token
      # cacheName = "default";  # Optional, defaults to "default"
    };
  };
}
```

#### 4. Activate Configuration

```bash
just install <your-username> <host>
```

This generates `~/.config/nix/netrc` with your write token.

#### 5. Build and Push

```bash
# Build and push in one command
just build-and-push <your-username> <host>
```

Done! Your builds are now in the cache for everyone to use.

______________________________________________________________________

## User Stories

### User Story 1: Binary Cache Usage (Automatic)

**As a user, I want to automatically download pre-built packages from Cachix so that my builds are faster.**

✅ **Implemented** - All users automatically benefit from read-only access to `default.cachix.org`.

**Usage:**

```bash
# Just build normally
just build <user> <host>

# Packages automatically downloaded from cache when available
```

**Benefits:**

- ✅ No configuration required
- ✅ Automatic for all users
- ✅ Significantly faster builds
- ✅ Reduced CPU/battery usage

______________________________________________________________________

### User Story 2: Per-User Write Access (Optional)

**As a developer, I want to push my builds to Cachix so that other users can download my pre-built packages.**

✅ **Implemented** - Opt-in via `user.cachix.authToken` configuration.

**Setup:** See [For Developers](#for-developers-write-access) above.

**Usage:**

```bash
# Build and push in one command
just build-and-push <user> <host>
```

**Benefits:**

- ✅ Share pre-built packages with team
- ✅ Speed up CI/CD pipelines
- ✅ Reduce redundant compilation
- ✅ One-command workflow

______________________________________________________________________

### User Story 3: Build and Push (Developers)

**As a developer, I want a single command to build and push so that I don't have to run separate commands.**

✅ **Implemented** - `just build-and-push` command.

**Usage:**

```bash
# One command to build and push
just build-and-push <user> <host>

# Auto-detects if you have write access configured
# Pushes to cache if user.cachix.authToken is set
# Otherwise, just builds (with helpful setup instructions)
```

**Benefits:**

- ✅ Convenient one-step workflow
- ✅ Smart detection of write access
- ✅ Clear feedback and instructions
- ✅ No separate push command needed

______________________________________________________________________

## Configuration Reference

### User Configuration

Located in `user/<username>/default.nix`:

```nix
{ ... }:
{
  user = {
    name = "username";
    email = "user@example.com";
    applications = ["*"];
    
    # Optional: Cachix write access
    cachix = {
      # Write authentication token (required for push access)
      # MUST use "<secret>" placeholder
      # Actual token stored in user/<username>/secrets.age
      authToken = "<secret>";
      
      # Cache name (optional, defaults to "default")
      # Override to push to a different cache
      cacheName = "default";  # default.cachix.org
    };
  };
}
```

**Token Storage:**

```bash
# Store write token
just secrets-set <username> cachix.authToken "eyJhbGc..."

# Store agent token (cdrolet by convention)
just secrets-set cdrolet cachix.agentToken "eyJhbGc..."
```

**Secrets File Format** (`user/<username>/secrets.age`):

```json
{
  "email": "user@example.com",
  "cachix": {
    "authToken": "eyJhbGciOiJIUzI1NiJ9...",
    "agentToken": "eyJhbGciOiJIUzI1NiJ9..."
  }
}
```

______________________________________________________________________

### System Configuration

Located in `system/shared/settings/cachix.nix`:

**Read-Only Configuration** (automatic):

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

**Per-User Netrc** (generated at activation):

```
# ~/.config/nix/netrc (generated for users with write access)
machine default.cachix.org
  login cachix
  password <user-write-token>
```

______________________________________________________________________

## Troubleshooting

### Builds Not Using Cache

**Symptom:** Builds are compiling from source instead of downloading from cache.

**Check:**

```bash
# Verify substituters are configured
nix show-config | grep substituters

# Should show:
# substituters = https://default.cachix.org?priority=10 https://cache.nixos.org?priority=40
```

**Fix:**

```bash
# Rebuild configuration
just install <user> <host>
```

______________________________________________________________________

### Push Fails (Permission Denied)

**Symptom:** `just build-and-push` fails with authentication error.

**Check:**

1. **User config has authToken:**

   ```bash
   grep "cachix.*authToken" user/<username>/default.nix
   ```

1. **Token is stored in secrets:**

   ```bash
   just secrets-list
   # Should show: cachix.authToken: [encrypted]
   ```

1. **Netrc file exists:**

   ```bash
   cat ~/.config/nix/netrc
   # Should show: machine default.cachix.org ...
   ```

**Fix:**

```bash
# Store token
just secrets-set <username> cachix.authToken "your-token"

# Reactivate to regenerate netrc
just install <username> <host>
```

______________________________________________________________________

### Cachix Command Not Found

**Symptom:** `cachix: command not found` when running `just build-and-push`.

**Fix:**

```bash
# Install cachix
nix-env -iA nixpkgs.cachix

# Or add to user applications
# user/<username>/default.nix:
applications = ["cachix" ...];
```

______________________________________________________________________

## Advanced Usage

### Using a Different Cache

**User Configuration:**

```nix
cachix = {
  authToken = "<secret>";
  cacheName = "my-org-cache";  # Instead of "default"
};
```

**Benefits:**

- Private organization cache
- Multiple cache support
- Cache-per-project isolation

**Note:** Still gets read-only access to `default.cachix.org` system-wide.

______________________________________________________________________

### Manual Push (Custom Cache)

```bash
# Build first
just build <user> <host>

# Push to custom cache
cachix push my-org-cache ./result
```

______________________________________________________________________

## Cache Details

### Default Cache

- **Name:** `default`
- **URL:** https://default.cachix.org
- **Public Key:** `default.cachix.org-1:eB40iz5TB/dAn11vLeoaeYiICu+syfoHhNeUFZ53zcs=`
- **Priority:** 10 (higher than cache.nixos.org at 40)

### Token Types

| Token Type | Scope | Storage | Usage |
|-----------|-------|---------|-------|
| Read-Only | `cache` (read) | System netrc | Automatic downloads |
| Read-Write | `cache` (read+write) | User secrets | Push builds |

### Token Security

- ✅ Read-only token: Hardcoded in system config (safe, limited scope)
- ✅ Write tokens: Encrypted in `user/<name>/secrets.age` (per-user keys)
- ✅ All secrets: Age-encrypted with per-user keypairs (Feature 031)

______________________________________________________________________

## Resources

- [Cachix Documentation](https://docs.cachix.org/)
- [Cachix Deploy Documentation](https://docs.cachix.org/deploy/)
- [Cachix Dashboard](https://app.cachix.org/)
- [Personal Auth Tokens](https://app.cachix.org/personal-auth-tokens)
- [Workspace Agents](https://app.cachix.org/workspace/default/agents)
- [Feature 034 Specification](./spec.md)
- [Repository CLAUDE.md](../../CLAUDE.md)

______________________________________________________________________

## Support

**Issues:** Report at the repository issue tracker

**Questions:** Check [Troubleshooting](#troubleshooting) section first

**Contributing:** See repository CLAUDE.md for development guidelines
