# Quickstart: Multi-Provider Repository Configuration

This guide shows how to configure repositories from multiple providers (Git, S3, Proton Drive) in your user configuration.

## Table of Contents

1. [Basic Concepts](#basic-concepts)
1. [Quick Examples](#quick-examples)
1. [Common Patterns](#common-patterns)
1. [Authentication Setup](#authentication-setup)
1. [Provider-Specific Options](#provider-specific-options)
1. [Troubleshooting](#troubleshooting)

## Basic Concepts

### What is user.repositories?

`user.repositories` is a list of repository configurations that automatically sync content from remote providers to your local machine. Each repository:

- **Auto-detects provider** from URL pattern (git, s3, proton-drive)
- **Resolves authentication** from your user secrets
- **Syncs content** to a local path
- **Runs at activation** (system rebuild/switch)

### Automatic Provider Detection

The system automatically detects the provider type from your URL:

| Pattern | Provider | Example |
|---------|----------|---------|
| `git@...` or `.git` | git | `git@github.com:user/repo.git` |
| GitHub/GitLab URLs | git | `https://github.com/user/repo` |
| `s3://...` | s3 | `s3://bucket-name/path` |
| `https://s3....` | s3 | `https://s3.amazonaws.com/bucket` |
| `drive.proton.me/urls/` | proton-drive | `https://drive.proton.me/urls/ABC123` |

If the URL is ambiguous, you can explicitly specify `provider = "git"` (or other type).

## Quick Examples

### Minimal Git Repository

```nix
user.repositories = [
  {
    url = "git@github.com:myuser/dotfiles.git";
  }
];
```

**Result**: Clones to `~/repositories/dotfiles/` using default SSH key.

### Git Repository with Custom Path

```nix
user.repositories = [
  {
    url = "https://github.com/myuser/notes";
    path = "~/Documents/notes";
    auth = "sshKeys.github";
  }
];
```

**Result**: Clones to `~/Documents/notes/` using GitHub SSH key from secrets.

### S3 Bucket Sync

```nix
user.repositories = [
  {
    url = "s3://my-backups/documents";
    path = "~/backups/docs";
    auth = "tokens.s3";
    options = {
      region = "us-west-2";
      syncOptions = [ "--delete" ];
    };
  }
];
```

**Result**: Syncs S3 bucket to `~/backups/docs/` using S3 credentials from secrets.

### Proton Drive Share

```nix
user.repositories = [
  {
    url = "https://drive.proton.me/urls/ABC123XYZ";
    path = "~/proton-documents";
    auth = "tokens.protonDrive";
  }
];
```

**Result**: Downloads Proton Drive share to `~/proton-documents/` using auth token.

### Multiple Repositories (Mixed Providers)

```nix
user.repositories = [
  # Git repositories
  {
    url = "git@github.com:work/private-repo.git";
    auth = "sshKeys.work";
  }
  {
    url = "https://gitlab.com/personal/config";
    path = "~/config-backup";
  }
  
  # S3 backup
  {
    url = "s3://my-backups/photos";
    path = "~/Pictures/backup";
    auth = "tokens.s3";
  }
  
  # Proton Drive
  {
    url = "https://drive.proton.me/urls/XYZ789";
    path = "~/secure-docs";
    auth = "tokens.protonDrive";
  }
];
```

## Common Patterns

### Pattern: Work vs Personal Git Repos

```nix
user.repositories = [
  # Work repositories (separate SSH key)
  {
    url = "git@github.com:company/backend.git";
    auth = "sshKeys.work";
    options.submodules = true;
  }
  {
    url = "git@github.com:company/frontend.git";
    auth = "sshKeys.work";
  }
  
  # Personal repositories (default SSH key)
  {
    url = "git@github.com:me/dotfiles.git";
  }
  {
    url = "git@github.com:me/scripts.git";
    path = "~/bin/scripts";
  }
];
```

### Pattern: Multi-Region S3 Backups

```nix
user.repositories = [
  {
    url = "s3://us-backup/data";
    path = "~/backups/us";
    auth = "tokens.s3";
    options.region = "us-east-1";
  }
  {
    url = "s3://eu-backup/data";
    path = "~/backups/eu";
    auth = "tokens.s3";
    options.region = "eu-west-1";
  }
];
```

### Pattern: Private Git Server (Custom Endpoint)

```nix
user.repositories = [
  {
    url = "https://git.company.internal/repo";
    provider = "git";  # Explicit override (ambiguous URL)
    auth = "sshKeys.company";
  }
];
```

### Pattern: S3-Compatible Services (MinIO, DigitalOcean Spaces, Hetzner)

```nix
user.repositories = [
  # MinIO (self-hosted)
  {
    url = "s3://my-bucket/files";
    provider = "s3";
    auth = "tokens.minio";
    options = {
      endpoint = "https://minio.example.com";
      region = "us-east-1";
    };
  }
  
  # Hetzner Object Storage
  {
    url = "https://my-bucket.fsn1.your-objectstorage.com/backups";
    auth = "tokens.hetzner";
    options = {
      region = "fsn1";  # Falkenstein datacenter
    };
  }
];
```

### Pattern: Shallow Git Clone (Save Space)

```nix
user.repositories = [
  {
    url = "https://github.com/large/monorepo";
    options = {
      depth = 1;  # Only latest commit
      branch = "main";
    };
  }
];
```

## Authentication Setup

### Step 1: Create Secrets

Use `just secrets-set` to add authentication credentials:

```bash
# GitHub SSH key
just secrets-set myuser sshKeys.github "$(cat ~/.ssh/id_ed25519_github)"

# GitLab SSH key
just secrets-set myuser sshKeys.gitlab "$(cat ~/.ssh/id_ed25519_gitlab)"

# AWS S3 credentials (JSON format)
just secrets-set myuser tokens.s3 '{"access_key":"AKIA...","secret_key":"..."}'

# Proton Drive token
just secrets-set myuser tokens.protonDrive "your-proton-drive-token"
```

### Step 2: Reference in Repository Config

```nix
user.repositories = [
  {
    url = "git@github.com:user/repo.git";
    auth = "sshKeys.github";  # References user.sshKeys.github secret
  }
  {
    url = "s3://bucket/path";
    auth = "tokens.s3";  # References user.tokens.s3 secret
  }
];
```

### Authentication Reference Format

Auth references use the format `"<secret-type>.<key-name>"`:

- `sshKeys.*` → SSH private keys
- `tokens.*` → API tokens, access keys, passwords

**Secret Resolution**:

```nix
auth = "sshKeys.github"
→ config.user.sshKeys.github
→ Decrypted from user/myuser/secrets.age
```

### Default Authentication

If `auth` is not specified:

- **Git**: Uses default SSH key (`~/.ssh/id_ed25519`)
- **S3**: Uses AWS environment credentials (`~/.aws/credentials`)
- **Proton Drive**: **Requires explicit auth** (no default)

## Provider-Specific Options

### Git Options

```nix
{
  url = "git@github.com:user/repo.git";
  options = {
    branch = "develop";        # Clone specific branch (default: default branch)
    depth = 1;                 # Shallow clone depth (default: full clone)
    submodules = true;         # Clone submodules (default: true)
    lfs = false;               # Enable Git LFS (default: false)
  };
}
```

### S3 Options

```nix
{
  url = "s3://bucket/path";
  options = {
    region = "us-west-2";      # AWS region (default: us-east-1)
    endpoint = "https://...";  # Custom S3 endpoint (for MinIO, etc.)
    profile = "work";          # AWS CLI profile name
    syncOptions = [            # Additional aws s3 sync flags
      "--delete"               # Delete files not in source
      "--exclude" "*.tmp"      # Exclude patterns
    ];
  };
}
```

### Proton Drive Options

```nix
{
  url = "https://drive.proton.me/urls/ABC123";
  options = {
    shareId = "specific-share-id";  # Override share ID from URL
    downloadOptions = [             # Additional download flags
      "--verify-checksum"
    ];
  };
}
```

## Troubleshooting

### Repository Not Syncing

**Check activation logs**:

```bash
# Rebuild and watch logs
just install myuser myhost
```

**Common issues**:

1. **Missing authentication**: Add secret with `just secrets-set`
1. **Wrong path**: Verify `path` exists or can be created
1. **Provider detection failed**: Add explicit `provider = "git"` field

### Authentication Errors

**Verify secret exists**:

```bash
just secrets-list
# Should show your user's secrets including sshKeys.*, tokens.*
```

**Check secret format**:

```bash
just secrets-edit myuser
# Verify JSON structure matches expected format
```

### Path Resolution Issues

**Path precedence** (first match wins):

1. Explicit `path = "~/custom/location"`
1. Provider default:
   - Git: `~/repositories/<repo-name>/`
   - S3: `~/sync/s3/<bucket-name>/`
   - Proton Drive: `~/sync/proton-drive/<share-name>/`

**Tilde expansion**: `~/` expands to your home directory

### Provider Auto-Detection Failed

**Symptoms**: Wrong provider detected, or "unknown provider" error

**Solution**: Add explicit provider field

```nix
{
  url = "https://ambiguous.com/resource";
  provider = "git";  # Force git provider
}
```

### Git Submodule Issues

**Disable submodules if causing errors**:

```nix
{
  url = "git@github.com:user/repo.git";
  options.submodules = false;
}
```

### S3 Region Mismatch

**Error**: "bucket is in region X, expected Y"

**Solution**: Specify correct region

```nix
{
  url = "s3://bucket/path";
  options.region = "us-west-2";  # Match bucket's actual region
}
```

### Large Repository Clone Times

**Use shallow clone**:

```nix
{
  url = "https://github.com/large/repo";
  options = {
    depth = 1;           # Only latest commit
    branch = "main";     # Specific branch
    submodules = false;  # Skip submodules
  };
}
```

## Adding Custom Providers

The system is extensible - you can add new providers without modifying core code.

### Step 1: Update Provider Detection

Edit `system/shared/lib/provider-detection.nix`:

```nix
# In detectProvider function, add your pattern:
else if lib.hasPrefix "rsync://" url
then "rsync"

# In knownProviders list:
knownProviders = ["git" "s3" "proton-drive" "rsync"];

# In getDefaultPath function:
else if provider == "rsync"
then "~/sync/rsync/${repoName}"

# In validateProviderUrl function:
else if provider == "rsync"
then {
  valid = true;
  error = null;
}
```

### Step 2: Create Provider Handler

Copy `system/shared/settings/custom-provider-template.nix` to `rsync-repos.nix`:

```nix
# Change "custom" to "rsync" throughout
# Implement your sync logic:
mkRsyncSyncScript = repo: ''
  echo "  Syncing via rsync: ${repo.url} -> ${resolvedPath}"
  mkdir -p "${resolvedPath}"
  
  ${pkgs.rsync}/bin/rsync -avz "${repo.url}" "${resolvedPath}" || \
    echo "  ✗ Rsync failed: ${repoName}"
'';
```

### Step 3: Use Your Provider

In your user configuration:

```nix
user.repositories = [
  {
    url = "rsync://server.example.com/data";
    provider = "rsync";  # Explicit provider
    path = "~/backups/rsync-data";
  }
];
```

### Step 4: Test

```bash
nix flake check  # Validate configuration
just build myuser myhost  # Build configuration
```

## Next Steps

- **Add more repositories**: Just append to the `user.repositories` list
- **Rotate secrets**: Use `just secrets-rotate-user myuser` to re-encrypt
- **View all secrets**: Use `just secrets-list` to audit configured secrets
- **Edit secrets**: Use `just secrets-edit myuser` for interactive editing
- **Add custom provider**: Follow the steps above to extend the system

For advanced configuration and provider implementation details, see:

- [Feature Specification](spec.md)
- [Data Model](data-model.md)
- [Repository Schema Contract](contracts/repository-schema.nix)
- [Custom Provider Template](../../system/shared/settings/custom-provider-template.nix)
