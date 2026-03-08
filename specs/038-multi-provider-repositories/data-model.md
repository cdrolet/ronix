# Data Model: Multi-Provider Repository Support

**Feature**: 038-multi-provider-repositories\
**Created**: 2026-01-04\
**References**: [spec.md](./spec.md), [research.md](./research.md)

## Entity: Repository

Represents a remote data source to be synchronized locally during user activation.

### Fields

| Field | Type | Required | Description | Validation |
|-------|------|----------|-------------|------------|
| `url` | String | ✓ | Source URL/location (auto-detects provider) | Must be valid URL or path |
| `provider` | String | ✗ | Explicit provider type (overrides auto-detection) | Must be: "git", "s3", "proton-drive", or custom |
| `path` | String | ✗ | Local destination path | Defaults to `$HOME/{repo-name}` |
| `rootPath` | String | ✗ | Section-level root path (applies to all repos in section) | Valid directory path |
| `auth` | String | ✗ | Secret key name for authentication | References agenix secret |
| `options` | AttrSet | ✗ | Provider-specific options | Flexible attribute set |

### Provider-Specific Options

**Git** (`options` for provider="git"):

- `branch`: String - Branch to checkout (default: repository default branch)
- `depth`: Int - Shallow clone depth (default: full clone)
- `submodules`: Bool - Include submodules (default: false)

**S3** (`options` for provider="s3"):

- `region`: String - AWS region (default: auto-detect from URL)
- `endpoint`: String - Custom S3 endpoint (for S3-compatible services)
- `syncDelete`: Bool - Delete local files not in S3 (default: false)

**Proton Drive** (`options` for provider="proton-drive"):

- `shareToken`: String - Share link token
- `expirationWarning`: Bool - Warn on expiring links (default: true)

### Path Resolution Precedence

1. **Individual `path`** (highest priority): If specified, use exactly as-is
1. **Section `rootPath` + repository name**: If `rootPath` set, join with auto-detected repo name
1. **`$HOME` + repository name** (default): Fallback to home directory

**Repository Name Extraction**:

- **Git**: Last path segment, removing `.git` suffix if present
  - `https://github.com/user/repo.git` → `repo`
  - `git@github.com:user/my-project` → `my-project`
- **S3**: Bucket name (first path segment after `s3://`)
  - `s3://my-bucket/path` → `my-bucket`
- **Proton Drive**: Share token (extracted from URL)
  - `https://drive.proton.me/urls/ABC123` → `proton-drive-ABC123`

### State Transitions

```
┌─────────────┐
│ Configured  │ (Repository in user.repositories list)
└──────┬──────┘
       │
       │ Activation starts
       ▼
┌─────────────┐
│ Validating  │ (Provider detection, URL validation, auth check)
└──────┬──────┘
       │
       ├─── Invalid ──→ ┌──────────┐
       │                │ Skipped  │ (Error logged, continue)
       │                └──────────┘
       │
       │ Valid
       ▼
┌─────────────┐
│  Syncing    │ (Provider handler processes)
└──────┬──────┘
       │
       ├─── Success ──→ ┌────────────┐
       │                │ Synced     │ (Files on disk)
       │                └────────────┘
       │
       └─── Failure ──→ ┌────────────┐
                        │ Failed     │ (Error logged, continue)
                        └────────────┘
```

**State Properties**:

- **Configured**: Declared in user config, not yet processed
- **Validating**: Provider detected, fields checked, auth verified
- **Skipped**: Validation failed, repository ignored (doesn't block others)
- **Syncing**: Provider handler actively syncing files
- **Synced**: Successfully synchronized, files exist locally
- **Failed**: Sync failed (network, auth, tool), error logged (doesn't block others)

### Validation Rules

**URL Validation**:

- MUST be non-empty string
- MUST match known provider pattern OR have explicit `provider` field
- Git: Valid git URL format (SSH, HTTPS, git://, file://, or absolute path)
- S3: Valid S3 URI (`s3://`) or AWS S3 URL pattern
- Proton Drive: Valid share link format

**Provider Validation**:

- If explicit `provider` specified, MUST be recognized type
- If URL cannot be auto-detected, explicit `provider` is REQUIRED
- Explicit `provider` overrides auto-detection (with warning if mismatch)

**Path Validation**:

- Individual `path` or section `rootPath` MUST be valid directory path
- MUST NOT specify same local path for multiple repositories (warn, not error)
- Relative paths resolved from `$HOME`

**Auth Validation**:

- If `auth` specified, MUST reference existing agenix secret
- Secret format validated at activation time (provider-specific)

**Options Validation**:

- Unknown options logged as warnings (not errors)
- Provider-specific options validated by handler
- Type mismatches (e.g., string instead of int) cause validation failure

## Entity: ProviderHandler

Represents the logic that knows how to synchronize a specific provider type.

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `providerType` | String | Unique identifier (e.g., "git", "s3", "proton-drive") |
| `detectPatterns` | List | URL patterns that identify this provider |
| `requiredTool` | String | CLI tool required (e.g., "git", "aws-cli", "rclone") |
| `syncFunction` | Function | Nix function that generates sync script |
| `validateRepo` | Function | Validates repository config for this provider |

### Provider Detection Patterns

**Git Detection Patterns** (in priority order):

1. Protocol prefix: `git@`, `ssh://`, `git://`, `file://`, absolute path `/`
1. Hostname: `github.com`, `gitlab.com`, `bitbucket.org`, `*.gitlab.io`
1. Path suffix: `.git` (weak signal, not definitive)

**S3 Detection Patterns**:

1. Protocol prefix: `s3://` (definitive)
1. Hostname: `.s3.amazonaws.com`, `.s3-*.amazonaws.com`, `.digitaloceanspaces.com`, `.s3.wasabisys.com`, `.s3.backblazeb2.com`

**Proton Drive Detection Patterns**:

1. Hostname + path: `drive.proton.me/urls/*`

### Relationships

```
┌──────────────┐
│  Repository  │
│  (user cfg)  │
└──────┬───────┘
       │
       │ 1. Provider detection
       ▼
┌──────────────┐
│   Provider   │
│  Detection   │ (Auto-detect from URL patterns)
│   Library    │
└──────┬───────┘
       │
       │ 2. Route to handler
       ▼
┌──────────────┐
│   Provider   │
│   Handler    │ (git/s3/proton-drive specific)
│  (settings)  │
└──────┬───────┘
       │
       │ 3. Sync execution
       ▼
┌──────────────┐
│  Local Path  │
│  (filesystem)│
└──────────────┘
```

**Data Flow**:

1. User declares repository in `user.repositories` list
1. Provider detection library analyzes URL, determines provider type
1. Appropriate provider handler filters and claims repository
1. Handler generates sync script (git clone/pull, s3 sync, rclone sync)
1. Script executes during home.activation, files written to local path

## Schema Integration

### user-schema.nix

```nix
repositories = {
  # Section-level configuration (applies to all repos in list)
  rootPath = mkOption {
    type = types.nullOr types.str;
    default = null;
    description = "Root path for all repositories (joined with repo name)";
  };
  
  repos = mkOption {
    type = types.listOf (types.submodule {
      options = {
        url = mkOption {
          type = types.str;
          description = "Repository URL (provider auto-detected)";
        };
        
        provider = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Explicit provider type (overrides auto-detection)";
        };
        
        path = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Local destination path (overrides rootPath)";
        };
        
        auth = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Secret key name for authentication";
        };
        
        options = mkOption {
          type = types.attrs;
          default = {};
          description = "Provider-specific options";
        };
      };
    });
    default = [];
    description = "List of repositories to sync";
  };
};
```

### Example User Configuration

```nix
user = {
  repositories = {
    # Optional: Set root path for all repos
    rootPath = "~/projects";
    
    repos = [
      # Git repository (auto-detected from URL)
      {
        url = "https://github.com/nixos/nixpkgs";
        # path defaults to ~/projects/nixpkgs
      }
      
      # Git with SSH (auto-detected)
      {
        url = "git@github.com:user/private-repo.git";
        auth = "git"; # References user.sshKeys.git secret
        options = {
          branch = "develop";
          submodules = true;
        };
      }
      
      # S3 bucket (auto-detected from s3:// prefix)
      {
        url = "s3://my-backup-bucket/documents";
        path = "~/backups/s3-docs"; # Override rootPath
        auth = "aws"; # References AWS credentials
        options = {
          region = "us-west-2";
          syncDelete = false;
        };
      }
      
      # Proton Drive (auto-detected from URL pattern)
      {
        url = "https://drive.proton.me/urls/ABC123XYZ";
        auth = "proton"; # References Proton credentials
      }
      
      # Custom MinIO server (requires explicit provider)
      {
        url = "https://minio.example.com/my-bucket";
        provider = "s3"; # Explicit override
        auth = "minio";
        options = {
          endpoint = "https://minio.example.com";
        };
      }
    ];
  };
};
```

## Error Handling

### Validation Errors (Evaluation Time)

| Error | Cause | Behavior |
|-------|-------|----------|
| `EmptyURL` | `url` field is empty | Nix evaluation error (fails build) |
| `UnknownProvider` | Cannot detect provider, no explicit override | Nix evaluation error with helpful message |
| `InvalidProviderType` | Explicit `provider` not recognized | Nix evaluation error |
| `MissingAuth` | Provider requires auth, `auth` not specified | Warning (may fail at activation) |
| `InvalidPath` | Path is malformed | Nix evaluation error |

### Runtime Errors (Activation Time)

| Error | Cause | Behavior |
|-------|-------|----------|
| `ToolNotFound` | Provider tool not in PATH | Skip repository, log error, continue |
| `AuthFailure` | Invalid credentials or missing secret | Skip repository, log error, continue |
| `NetworkFailure` | Cannot reach remote URL | Skip repository, log error, continue |
| `DiskFull` | Insufficient disk space | Skip repository, log error, continue |
| `PartialSync` | Sync failed mid-operation | Log error, partial files may exist, continue |

**Isolation Guarantee**: Failed repository sync MUST NOT block other repositories from syncing.

## Backward Compatibility

### Migration from Feature 032 (git-repos)

**Old Schema** (git-specific):

```nix
repositories = {
  rootPath = "~/projects";
  repos = [
    { url = "https://github.com/user/repo"; }
  ];
};
```

**New Schema** (provider-agnostic):

```nix
repositories = {
  rootPath = "~/projects";
  repos = [
    { url = "https://github.com/user/repo"; } # Works identically
  ];
};
```

**Compatibility**:

- ✅ Existing git repository configurations work without modification
- ✅ URL auto-detects to git provider
- ✅ Field names unchanged (`url`, `path`, `rootPath`, `auth`)
- ✅ Git-specific options continue to work (passed through to git handler)

**Breaking Changes**: None - schema is backward compatible.
