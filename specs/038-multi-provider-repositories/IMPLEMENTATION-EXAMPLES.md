# Implementation Examples: Multi-Provider Repository Support

**Feature**: 038-multi-provider-repositories\
**Date**: 2026-01-04\
**Purpose**: Concrete examples of URL detection, configuration, and provider handler implementation

## Configuration Examples

### User Configuration with Multiple Providers

```nix
# user/alice/default.nix
{ ... }:

{
  user = {
    name = "alice";
    email = "alice@example.com";
    applications = ["git" "*"];
    
    # Repository configuration with multiple providers
    repositories = {
      rootPath = "~/projects";  # Default for git repos
      
      repos = [
        # Git repositories (auto-detected)
        "git@github.com:alice/dotfiles.git"
        "https://github.com/alice/blog"
        
        # Git with custom path (explicit)
        {
          url = "git@github.com:alice/private-work.git";
          path = "~/work/projects/private";
        }
        
        # S3 data sync (auto-detected via s3:// URI)
        {
          url = "s3://my-backups/documents";
          path = "~/backups/documents";
          options.sync = "update";  # Download updates
        }
        
        # DigitalOcean Spaces (auto-detected via hostname)
        {
          url = "https://my-space.nyc3.digitaloceanspaces.com/media";
          path = "~/cloud-sync/media";
        }
        
        # Proton Drive (requires explicit provider)
        {
          url = "https://drive.proton.me/urls/share-token-12345";
          path = "~/proton-shared";
          provider = "proton-drive";
        }
        
        # Ambiguous custom server (requires explicit provider)
        {
          url = "https://internal-git.company.com/alice/project";
          provider = "git";
          path = "~/work/internal-projects";
        }
        
        # MinIO self-hosted (requires explicit provider)
        {
          url = "http://minio.internal:9000/alice-backup/documents";
          provider = "s3";
          path = "~/minio-backup";
        }
      ];
    };
    
    # SSH credentials for private git repos
    sshKeys = {
      git = "<secret>";  # Deploy SSH key for git operations
      s3 = "<secret>";   # AWS credentials for S3 sync
    };
  };
}
```

### Secrets Configuration for Multi-Provider

```json
// user/alice/secrets.age (encrypted JSON)
{
  "email": "alice@example.com",
  "sshKeys": {
    "git": "-----BEGIN OPENSSH PRIVATE KEY-----\nAAAC3NzaC...\n-----END OPENSSH PRIVATE KEY-----",
    "s3": "AKIAIOSFODNN7EXAMPLE:wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }
}
```

### Justfile Commands for Repository Management

```bash
# List all configured repositories (with providers)
just repos-list

# Sync all repositories
just repos-sync

# Sync only git repositories
just repos-sync git

# Sync only S3 buckets
just repos-sync s3

# Resync a specific repository
just repos-resync alice/projects/dotfiles

# Show repository status
just repos-status
```

## Provider Detection Examples

### Detection Flowchart with Examples

```
Input URLs and Detection Results:

1. "git@github.com:user/repo.git"
   → Protocol prefix "git@" detected
   → Provider: GIT ✓

2. "https://github.com/user/repo"
   → No protocol match, check hostname
   → Contains "github.com"
   → Provider: GIT ✓

3. "s3://my-bucket/documents"
   → Protocol prefix "s3://" detected
   → Provider: S3 ✓

4. "https://my-bucket.s3.amazonaws.com/files"
   → No protocol match, check hostname
   → Contains "s3.amazonaws.com"
   → Provider: S3 ✓

5. "https://my-space.nyc3.digitaloceanspaces.com/media"
   → No protocol match, check hostname
   → Contains ".digitaloceanspaces.com"
   → Provider: S3 ✓

6. "https://drive.proton.me/urls/abc123"
   → No protocol match, check hostname
   → Contains "drive.proton.me/urls"
   → Provider: PROTON_DRIVE ✓

7. "https://internal-server.company.com/project"
   → No protocol match, check hostname
   → No known git/S3 pattern
   → Provider: UNKNOWN ✗
   → Error: "Require explicit provider field"

8. "http://minio.internal:9000/bucket"
   → No protocol match, check hostname
   → No known pattern
   → Provider: UNKNOWN (could be MinIO/S3-compatible) ✗
   → User must specify: provider = "s3"
```

### Nix Implementation: Detection in Action

```nix
# system/shared/lib/provider-detection.nix
# Detection logic that runs during nix flake evaluation

let
  examples = {
    # Test cases demonstrating detection
    gitSSH = {
      url = "git@github.com:alice/repo.git";
      expected = "git";
      detected = detectProvider url;  # → "git" ✓
    };
    
    gitHTTPS = {
      url = "https://gitlab.com/org/project";
      expected = "git";
      detected = detectProvider url;  # → "git" ✓
    };
    
    s3URI = {
      url = "s3://my-bucket/data";
      expected = "s3";
      detected = detectProvider url;  # → "s3" ✓
    };
    
    s3AWS = {
      url = "https://bucket.s3.us-west-2.amazonaws.com/key";
      expected = "s3";
      detected = detectProvider url;  # → "s3" ✓
    };
    
    digitalOcean = {
      url = "https://space.nyc3.digitaloceanspaces.com/path";
      expected = "s3";
      detected = detectProvider url;  # → "s3" ✓
    };
    
    protonDrive = {
      url = "https://drive.proton.me/urls/share-token";
      expected = "proton-drive";
      detected = detectProvider url;  # → "proton-drive" ✓
    };
    
    ambiguous = {
      url = "https://internal.company.com/files";
      expected = "unknown";
      detected = detectProvider url;  # → null (requires explicit provider)
    };
  };
in
{
  # Tests can be run via: nix eval ".#test.providerDetection"
  inherit examples;
}
```

## Provider Handler Implementation Examples

### Git Provider Handler

```nix
# system/shared/settings/git-repos.nix (Feature 032 refactored for Feature 038)

{ config, lib, pkgs, options, ... }:
let
  providerLib = import ../lib/provider-detection.nix {inherit lib;};
  secrets = import ../../../user/shared/lib/secrets.nix {inherit lib pkgs;};
  gitLib = import ../lib/git.nix {inherit lib;};

  reposCfg = config.user.repositories or null;
  hasRepos = reposCfg != null && reposCfg.repos != [];
  
  # Filter only git repositories
  gitRepos = 
    if hasRepos then
      builtins.filter (repo: 
        let
          normalized = gitLib.normalizeRepo repo;
          provider = normalized.provider or null;
          detected = if provider == null then providerLib.detectProvider normalized.url else provider;
        in
        detected == "git"
      ) reposCfg.repos
    else [];
  
  normalizedGitRepos = map gitLib.normalizeRepo gitRepos;
  
  reposWithPaths = map (repo: {
    url = repo.url;
    path = gitLib.resolveRepoPath repo (reposCfg.rootPath or null);
  }) normalizedGitRepos;
  
  hasGit = lib.elem "git" config.user.applications;
  hasGitKey = secrets.isSecret (config.user.sshKeys.git or "");

in {
  # Only activate in home-manager context
  config = lib.optionalAttrs ((options ? home) && (lib ? hm)) {
    home.activation.gitRepos = lib.mkIf (hasGit && gitRepos != []) (
      lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
        # Git-specific repository cloning
        
        # Setup SSH authentication if configured
        ${lib.optionalString hasGitKey ''
          if [ -f "$HOME/.ssh/id_git" ]; then
            export GIT_SSH_COMMAND='ssh -i $HOME/.ssh/id_git -o StrictHostKeyChecking=accept-new -o BatchMode=yes'
          fi
        ''}

        # Clone/update repositories
        ${gitLib.mkRepoCloneScriptWithPaths {
          inherit pkgs;
          repos = reposWithPaths;
          checkLocal = true;
        }}
      ''
    );
  };
}
```

### S3 Provider Handler

```nix
# system/shared/settings/s3-repos.nix (NEW - Feature 038)

{ config, lib, pkgs, options, ... }:
let
  providerLib = import ../lib/provider-detection.nix {inherit lib;};
  secrets = import ../../../user/shared/lib/secrets.nix {inherit lib pkgs;};

  reposCfg = config.user.repositories or null;
  hasRepos = reposCfg != null && reposCfg.repos != [];
  
  # Filter only S3 repositories
  s3Repos = 
    if hasRepos then
      builtins.filter (repo:
        let
          normalized = 
            if builtins.isString repo then { url = repo; path = null; provider = null; }
            else repo // { provider = repo.provider or null; };
          provider = normalized.provider;
          detected = if provider == null then providerLib.detectProvider normalized.url else provider;
        in
        detected == "s3"
      ) reposCfg.repos
    else [];
  
  hasS3Tools = lib.all (x: pkgs ? ${x}) ["awscli2" "s3cmd"];
  hasS3Creds = secrets.isSecret (config.user.sshKeys.s3 or "");

in {
  # Only activate in home-manager context with S3 support
  config = lib.optionalAttrs ((options ? home) && (lib ? hm)) {
    home.activation.s3Repos = lib.mkIf (hasS3Tools && hasS3Creds && s3Repos != []) (
      lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
        # S3 bucket synchronization
        
        # Setup AWS credentials if configured
        ${lib.optionalString hasS3Creds ''
          if [ -f "$HOME/.aws/credentials" ]; then
            export AWS_SHARED_CREDENTIALS_FILE="$HOME/.aws/credentials"
          fi
        ''}

        # Sync each S3 repository
        ${lib.concatMapStringsSep "\n" (repo:
          let
            repoPath = repo.path or ".";
            repoUrl = repo.url;
            syncOption = (repo.options or {}).sync or "update";
            excludePatterns = (repo.options or {}).exclude or [];
          in ''
          mkdir -p "${repoPath}"
          echo "Syncing S3 repository: ${repoUrl}"
          
          ${if syncOption == "update" || syncOption == "always-update" then ''
          # Download updates from S3
          ${pkgs.awscli2}/bin/aws s3 sync "${repoUrl}" "${repoPath}" \
            --delete \
            ${lib.concatMapStringsSep " " (pattern: "--exclude '${pattern}'") excludePatterns} \
            2>/dev/null || echo "Warning: Failed to sync ${repoUrl}"
          '' else if syncOption == "clone-once" then ''
          # Only sync if local directory is empty
          if [ -z "$(ls -A "${repoPath}" 2>/dev/null)" ]; then
            ${pkgs.awscli2}/bin/aws s3 sync "${repoUrl}" "${repoPath}" \
              ${lib.concatMapStringsSep " " (pattern: "--exclude '${pattern}'") excludePatterns} \
              2>/dev/null || echo "Warning: Failed to sync ${repoUrl}"
          fi
          '' else ''
          echo "Warning: Unknown sync strategy '${syncOption}' for ${repoUrl}"
          ''}
        ) s3Repos}
      ''
    );
  };
}
```

### Proton Drive Provider Handler

```nix
# system/shared/settings/proton-drive-repos.nix (NEW - Feature 038)

{ config, lib, pkgs, options, ... }:
let
  providerLib = import ../lib/provider-detection.nix {inherit lib;};
  secrets = import ../../../user/shared/lib/secrets.nix {inherit lib pkgs;};

  reposCfg = config.user.repositories or null;
  hasRepos = reposCfg != null && reposCfg.repos != [];
  
  # Filter only Proton Drive repositories
  protonDriveRepos = 
    if hasRepos then
      builtins.filter (repo:
        let
          normalized = 
            if builtins.isString repo then { url = repo; path = null; provider = null; }
            else repo // { provider = repo.provider or null; };
          provider = normalized.provider;
          detected = if provider == null then providerLib.detectProvider normalized.url else provider;
        in
        detected == "proton-drive"
      ) reposCfg.repos
    else [];
  
  # Check for rclone with proton-drive backend support
  hasRclone = pkgs ? rclone;
  hasProtonCreds = secrets.isSecret (config.user.sshKeys.protonDrive or "");

in {
  # Only activate in home-manager context with Proton Drive support
  config = lib.optionalAttrs ((options ? home) && (lib ? hm)) {
    home.activation.protonDriveRepos = lib.mkIf (hasRclone && protonDriveRepos != []) (
      lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
        # Proton Drive synchronization via rclone
        
        # Create rclone config for Proton Drive if credentials provided
        ${lib.optionalString hasProtonCreds ''
          mkdir -p "$HOME/.config/rclone"
          # Note: Proton Drive credentials configured via rclone interactive setup
          # or environment variables set by agenix
        ''}

        # Sync each Proton Drive folder
        ${lib.concatMapStringsSep "\n" (repo:
          let
            repoPath = repo.path or ".";
            repoUrl = repo.url;  # Can be share link or folder ID
          in ''
          mkdir -p "${repoPath}"
          echo "Syncing Proton Drive folder: ${repoUrl}"
          
          # Use rclone to sync from Proton Drive
          ${pkgs.rclone}/bin/rclone sync "proton-drive:${repoUrl}" "${repoPath}" \
            --log-level INFO \
            2>/dev/null || echo "Warning: Failed to sync Proton Drive folder"
        ) protonDriveRepos}
      ''
    );
  };
}
```

## Configuration Schema Examples

### User Schema Update

```nix
# user/shared/lib/user-schema.nix (Feature 038 additions)

user.repositories = lib.mkOption {
  type = lib.types.nullOr (lib.types.submodule {
    options = {
      rootPath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default parent directory for repositories without individual paths";
      };

      repos = lib.mkOption {
        type = lib.types.listOf (lib.types.either lib.types.str (lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Repository URL/URI (git, S3, Proton Drive, etc.)";
              example = "git@github.com:user/repo.git";
            };

            path = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Custom clone/sync destination path";
            };

            provider = lib.mkOption {
              type = lib.types.nullOr (lib.types.enum ["git" "s3" "proton-drive"]);
              default = null;
              description = "Explicit provider type (auto-detected if null)";
            };

            options = lib.mkOption {
              type = lib.types.attrs;
              default = {};
              description = "Provider-specific options (branch for git, sync for S3, etc.)";
            };
          };
        }));
        default = [];
        description = "List of repositories from multiple providers to clone/sync";
      };
    };
  });
  default = null;
};
```

## Activation Script Integration

### Complete Activation Example

```bash
# During home-manager activation, these scripts run in sequence:

# Stage 1: writeBoundary (all file writes)
# - Deploy configuration files
# - Create directories
# → Ensures filesystem is stable

# Stage 2: agenixInstall (SECRET DEPLOYMENT)
# - Decrypt and deploy SSH keys ($HOME/.ssh/id_git, $HOME/.ssh/id_proton, etc.)
# - Deploy AWS credentials ($HOME/.aws/credentials)
# → Ensures credentials available for repository access

# Stage 3: gitRepos activation (after writeBoundary and agenixInstall)
# - Set GIT_SSH_COMMAND with SSH key path
# - Clone/update all git repositories
# - Preserve local changes when updating

# Stage 4: s3Repos activation (after writeBoundary and agenixInstall)
# - Set AWS_SHARED_CREDENTIALS_FILE environment variable
# - Sync all S3 buckets (only if credentials available)
# - Apply exclude patterns

# Stage 5: protonDriveRepos activation (after writeBoundary and agenixInstall)
# - Configure rclone for Proton Drive (if credentials available)
# - Sync all Proton Drive folders via rclone
# - Non-blocking failures per repository

# All stages are idempotent and can be re-run safely
```

## Error Messages and User Guidance

### Example 1: Auto-Detection Failure

```
Error during evaluation (nix flake check):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cannot auto-detect repository provider

  URL: https://internal-git.company.com/alice/project
  
  The URL does not match any known provider patterns.
  
  Please specify the provider explicitly:
  
    {
      url = "https://internal-git.company.com/alice/project";
      provider = "git";  # one of: "git" | "s3" | "proton-drive"
      path = "~/work/projects";
    }
  
  Common URL patterns:
  ✓ Git SSH:     git@github.com:owner/repo.git
  ✓ Git HTTPS:   https://github.com/owner/repo.git
  ✓ S3 URI:      s3://bucket-name/path
  ✓ S3 AWS:      https://bucket.s3.amazonaws.com/path
  ✓ Proton:      https://drive.proton.me/urls/share-token
```

### Example 2: Invalid S3 Bucket Name

```
Error during evaluation (nix flake check):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Invalid S3 URI format

  URL: s3://My-Bucket/data  ← Uppercase not allowed
  
  S3 bucket names must:
  - Start with lowercase letter or number
  - Contain only lowercase letters, numbers, and hyphens
  - Be between 3 and 63 characters
  - Not contain consecutive hyphens
  
  Suggestion: s3://my-bucket/data
```

### Example 3: Runtime Sync Failure

```
During home-manager activation:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cloning repository: dotfiles
✓ Repository cloned successfully to ~/projects/dotfiles

Updating repository: blog
✓ Repository updated to latest commit

Syncing S3 repository: s3://my-backups/documents
✗ Warning: Failed to sync s3://my-backups/documents
  Check AWS credentials and bucket permissions

Syncing Proton Drive folder: shared-folder
✓ Folder synced successfully to ~/proton-shared

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Summary: 4 repositories processed, 3 succeeded, 1 failed
Failed repositories can be manually retried after fixing the issue.
```

## Testing and Validation

### Nix Flake Check Validation

```bash
# Validate all repository configurations during flake check
$ nix flake check

# Provider detection for each URL
✓ git@github.com:alice/repo.git → git
✓ https://github.com/alice/blog → git
✓ s3://my-bucket/data → s3
✓ https://drive.proton.me/urls/token → proton-drive
✓ https://internal.company.com/files → Requires explicit provider
✓ http://minio.local:9000/bucket → Requires explicit provider (could be S3)

# Overall result
Flake configuration valid, ready to activate.
```

### Manual Testing Commands

```bash
# Test git repository cloning
just repos-sync git

# Test S3 bucket sync
just repos-sync s3

# Test Proton Drive sync
just repos-sync proton-drive

# Test all repositories
just repos-sync

# Check repository status
just repos-status

# Show which provider handles each repository
just repos-list --verbose
```

## Summary of Provider-Specific Behaviors

| Feature | Git | S3 | Proton Drive |
|---------|-----|----|----|
| **URL Format** | ssh://, git@, https://, file:// | s3://, https://*.s3.* | https://drive.proton.me/urls/\* |
| **Auto-Detection** | Yes (strong patterns) | Yes (s3:// or AWS domains) | Yes (proton.me domain) |
| **Requires Explicit Provider** | No (unless ambiguous) | No (unless custom S3-compat) | No (unless share link format) |
| **Authentication** | SSH keys (agenix) | AWS credentials or tokens | Proton Drive credentials |
| **Sync Strategy** | Clone/pull | Always-sync / Clone-once | Always-sync |
| **Activation Ordering** | After git installation | After AWS CLI | After rclone |
| **Idempotent** | Yes (checks for local changes) | Yes (--delete flag) | Yes (rclone handles) |
| **Tools Required** | git | aws-cli2 / s3cmd | rclone |
| **Failure Blocking** | No (per-repo) | No (per-bucket) | No (per-folder) |
