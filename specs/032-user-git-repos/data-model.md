# Data Model: User Git Repository Configuration

**Feature**: 032-user-git-repos\
**Date**: 2025-12-30

## Overview

This document defines the data structures for user-configurable git repository cloning. The model supports flexible path configuration, authentication via SSH keys, and integration with the existing user configuration system.

## Core Entities

### 1. RepositoryConfiguration

**Description**: Top-level configuration section for git repositories in user config.

**Location**: `user.repositories` in `user/{username}/default.nix`

**Attributes**:

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `rootPath` | String (path) | No | `null` | Default parent directory for all repositories without individual paths. Supports tilde expansion (`~/projects`). |
| `repos` | List\<Repository | String> | Yes | `[]` | List of repositories to clone. Can be simple URL strings or detailed repository specifications. |

**Example**:

```nix
user.repositories = {
  rootPath = "~/projects";
  repos = [
    "git@github.com:user/simple-repo.git"
    { url = "https://github.com/user/work.git"; path = "~/work"; }
  ];
};
```

**Validation Rules**:

- If `repos` is empty, activation is skipped (no error)
- `rootPath` must be a valid path string if specified
- Each element in `repos` must be either a String or a Repository attribute set

### 2. Repository

**Description**: Specification for a single git repository to clone.

**Normalized Form** (internal):

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `url` | String (git URL) | Yes | - | Git repository URL. Supports SSH (`git@github.com:user/repo.git`) and HTTPS (`https://github.com/user/repo.git`) formats. |
| `path` | String (path) | Null | No | `null` | Custom clone destination. If `null`, uses `rootPath` or home folder. Supports absolute (`/path/to/dir`) and relative (`~/local`) paths. |

**User Input Forms**:

1. **Simple URL** (string):

   ```nix
   "git@github.com:user/repo.git"
   ```

   Normalized to: `{ url = "git@github.com:user/repo.git"; path = null; }`

1. **Detailed Specification** (attribute set):

   ```nix
   { url = "https://github.com/user/repo.git"; path = "~/custom"; }
   ```

   Normalized to: `{ url = "https://github.com/user/repo.git"; path = "~/custom"; }`

**Validation Rules**:

- `url` must be a non-empty string
- `url` must be a valid git URL format (validated by git at clone time)
- `path` must be a valid path string if specified
- If `path` points to an existing file (not directory), clone fails with error

### 3. ResolvedPath

**Description**: Computed destination path for a repository after applying resolution rules.

**Resolution Algorithm**:

```
resolveRepoPath(repo, rootPath):
  if repo.path != null:
    return repo.path                      # Priority 1: Individual path
  else if rootPath != null:
    return rootPath + "/" + repoName(repo.url)  # Priority 2: Section root
  else:
    return "$HOME" + "/" + repoName(repo.url)   # Priority 3: Home folder
```

**Path Types**:

- **Absolute**: `/usr/local/repos/project` - used exactly as-is
- **Tilde-relative**: `~/projects/work` - expanded by bash to `$HOME/projects/work`
- **Current-relative**: `./local/repo` - resolved from `$HOME` (activation runs from home)

**Examples**:

| repo.path | rootPath | repoName | Resolved Path |
|-----------|----------|----------|---------------|
| `"~/work"` | `"~/projects"` | `"my-repo"` | `~/work` |
| `null` | `"~/projects"` | `"my-repo"` | `~/projects/my-repo` |
| `null` | `null` | `"my-repo"` | `$HOME/my-repo` |
| `"/opt/repos"` | `"~/projects"` | `"my-repo"` | `/opt/repos` |

### 4. SSHAuthentication

**Description**: SSH key configuration for private repository access.

**Location**: `user.sshKeys.git` in `user/{username}/secrets.age`

**Secret Format** (JSON):

```json
{
  "sshKeys": {
    "git": "-----BEGIN OPENSSH PRIVATE KEY-----\nbase64encodedkey...\n-----END OPENSSH PRIVATE KEY-----"
  }
}
```

**Deployment**:

- Secret resolved by `system/shared/app/security/ssh.nix` activation
- Key written to `~/.ssh/id_git` (mode 600)
- Used via `GIT_SSH_COMMAND` environment variable during cloning

**Validation Rules**:

- If `sshKeys.git` == `"<secret>"`, key must exist in `secrets.age`
- If key not configured, SSH repository cloning will fail (HTTPS still works)
- Key must be valid OpenSSH private key format (validated by ssh at clone time)

## Data Flow

### 1. Configuration → Normalization

**Input**: User configuration in `user/{username}/default.nix`

```nix
user.repositories = {
  rootPath = "~/projects";
  repos = [
    "git@github.com:user/simple.git"
    { url = "https://github.com/user/custom.git"; path = "~/work"; }
  ];
};
```

**Process**: Normalization function converts all repos to consistent format

```nix
normalizedRepos = map (repo: 
  if builtins.isString repo then { url = repo; path = null; }
  else { url = repo.url; path = repo.path or null; }
) config.user.repositories.repos;
```

**Output**: Uniform list of repository attribute sets

```nix
[
  { url = "git@github.com:user/simple.git"; path = null; }
  { url = "https://github.com/user/custom.git"; path = "~/work"; }
]
```

### 2. Normalization → Path Resolution

**Input**: Normalized repositories + section rootPath

**Process**: Apply resolution algorithm to each repository

```nix
resolvedPaths = map (repo: 
  resolveRepoPath repo config.user.repositories.rootPath
) normalizedRepos;
```

**Output**: List of resolved destination paths

```nix
[
  "~/projects/simple"     # Used rootPath
  "~/work"                # Used individual path
]
```

### 3. Path Resolution → Activation Script

**Input**: Repositories with resolved paths

**Process**: Generate bash script for cloning

```bash
mkdir -p ~/projects
git clone --quiet git@github.com:user/simple.git ~/projects/simple

mkdir -p ~/work
git clone --quiet https://github.com/user/custom.git ~/work
```

**Output**: Home Manager activation entry

## State Transitions

### Repository Lifecycle

```
[Configured] → [Normalizing] → [Path Resolved] → [Cloning] → [Cloned]
                                                     ↓
                                                [Clone Failed]
                                                     ↓
                                              [User Notified]

[Cloned] → [Checking Updates] → [Has Changes] → [Skipped]
              ↓
         [No Changes] → [Pulling] → [Updated]
                            ↓
                      [Pull Failed]
                            ↓
                      [User Warned]
```

**States**:

1. **Configured**: User added repository to config
1. **Normalizing**: Converting to internal format
1. **Path Resolved**: Destination path determined
1. **Cloning**: Git clone operation in progress
1. **Cloned**: Repository successfully cloned
1. **Clone Failed**: Network error, auth failure, or invalid URL
1. **User Notified**: Warning printed to activation log
1. **Checking Updates**: Existing repository found, checking for changes
1. **Has Changes**: Local uncommitted changes detected
1. **Skipped**: Update skipped to preserve local work
1. **No Changes**: Clean working directory
1. **Pulling**: Git pull operation in progress
1. **Updated**: Repository updated successfully
1. **Pull Failed**: Network error during update
1. **User Warned**: Warning printed to activation log

## Invariants

### Data Integrity

1. **URL Uniqueness**: Not enforced - users can configure same repo multiple times with different paths
1. **Path Conflicts**: Same path can't be used by multiple repos (last clone wins, not validated)
1. **Repository Name Extraction**: Always succeeds (uses last path segment)
1. **Normalization**: Every repository specification can be normalized to `{ url, path }`

### Activation Guarantees

1. **Idempotency**: Running activation multiple times produces same result
1. **Non-Destructive**: Local changes never overwritten or lost
1. **Partial Success**: Some repositories can fail without breaking activation
1. **Order Independence**: Repository clone order doesn't affect outcome (except path conflicts)

### Secret Dependencies

1. **SSH Key Availability**: If `sshKeys.git` is secret, agenix must deploy before cloning
1. **Public Repos**: Work without SSH key configuration
1. **Mixed Authentication**: HTTPS and SSH repos can coexist in same configuration

## Validation Rules Summary

### Evaluation Time (Nix)

- ✅ `repos` must be a list
- ✅ Each repo must be string or attribute set with `url`
- ✅ `rootPath` must be string if specified
- ✅ All values must be of correct type (type checking via Home Manager options)

### Activation Time (Bash)

- ⚠️ Repository URL must be accessible (network validation)
- ⚠️ SSH key must be valid if private repo (authentication validation)
- ⚠️ Clone path must not be an existing file (filesystem validation)
- ⚠️ Parent directories must be writable (permission validation)

**Note**: Activation-time validation failures are non-blocking warnings, not errors.

## Extension Points

### Future Enhancements

The data model supports these future extensions without breaking changes:

1. **Branch/Tag Selection**:

   ```nix
   { url = "..."; path = "..."; branch = "develop"; }
   ```

1. **Shallow Clones**:

   ```nix
   { url = "..."; path = "..."; depth = 1; }
   ```

1. **Submodule Control**:

   ```nix
   { url = "..."; path = "..."; recursive = true; }
   ```

1. **Post-Clone Hooks**:

   ```nix
   { url = "..."; path = "..."; postClone = "npm install"; }
   ```

1. **Update Strategy**:

   ```nix
   { url = "..."; path = "..."; updateStrategy = "rebase"; }  # vs "merge"
   ```

All extensions are additive - existing configurations remain valid.

## Relationship to Other Features

### Feature 030 (Font Repository Cloning)

**Shared**:

- `gitLib.repoName`: Extract repository name from URL
- `gitLib.mkRepoCloneScript`: Generate clone/update bash script
- SSH authentication pattern via `GIT_SSH_COMMAND`
- Activation timing after `agenixInstall`

**Differences**:

- Fonts have no path configuration (fixed `~/.local/share/fonts/private/`)
- Fonts require `sshKeys.fonts`, repos use `sshKeys.git`
- Fonts symlink files after clone (macOS), repos don't post-process

### Feature 027 (Activation-Time Secrets)

**Integration**:

- Secret detection: `secrets.isSecret config.user.sshKeys.git`
- Activation guard: Only run if git available and SSH key deployed
- Non-blocking: Missing SSH key doesn't fail activation

### Feature 031 (Per-User Secrets)

**Integration**:

- SSH key storage: `user/{username}/secrets.age` contains `sshKeys.git`
- Per-user encryption: Each user has own keypair
- Secret management: `just secrets-set username sshKeys.git "..."`

## Type Definitions (Nix Options)

### Home Manager Option Schema

```nix
{
  user.repositories = lib.mkOption {
    type = types.submodule {
      options = {
        rootPath = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Default parent directory for repositories without individual paths.";
        };
        
        repos = lib.mkOption {
          type = types.listOf (types.either types.str (types.submodule {
            options = {
              url = lib.mkOption {
                type = types.str;
                description = "Git repository URL (SSH or HTTPS).";
              };
              
              path = lib.mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Custom clone destination. Overrides rootPath.";
              };
            };
          }));
          default = [];
          description = "List of repositories to clone. Can be URLs or { url, path } specifications.";
        };
      };
    };
    default = {};
    description = "Git repository configuration for automatic cloning during activation.";
  };
}
```

**Type Safety**: Home Manager validates this schema at evaluation time, catching configuration errors before activation.
