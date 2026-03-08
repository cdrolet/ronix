# Contract: Home Manager Activation Interface

**Feature**: 032-user-git-repos\
**Module**: `system/shared/settings/git-repos.nix`\
**Activation Entry**: `home.activation.cloneUserRepos`

## Overview

This document defines the contract for the Home Manager activation script that clones and updates user-configured git repositories. The activation integrates with the existing Home Manager DAG (Directed Acyclic Graph) to ensure proper ordering relative to other activation tasks.

## Activation Entry Specification

### Entry Name

`cloneUserRepos`

**Uniqueness**: Must not conflict with other activation entries in the system.

**Naming Convention**: Uses verb + noun pattern (`cloneUserRepos`) matching existing pattern (`applyGitSecrets`, `cloneFontRepos`).

### Activation Timing

**DAG Position**: `lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"]`

**Dependencies**:

- **AFTER `writeBoundary`**: Ensures all file writes (configs, scripts) are complete before cloning
- **AFTER `agenixInstall`**: SSH keys deployed and available at `~/.ssh/id_git`

**Rationale**:

- Git must be installed (handled by Home Manager's package installation phase before `writeBoundary`)
- SSH credentials must exist for private repository authentication
- Repositories are cloned to user-writable locations (no system-level changes)

**Comparison to Similar Features**:

- **Feature 030 (fonts)**: Also uses `entryAfter ["writeBoundary" "agenixInstall"]`
- **Feature 027 (git secrets)**: Uses `entryAfter ["agenixInstall"]` (no writeBoundary needed)

### Conditional Execution

The activation MUST only run when ALL conditions are met:

```nix
lib.mkIf (hasGit && hasRepos && (hasSSHKey || hasPublicRepos))
```

**Condition Breakdown**:

1. **hasGit** = `lib.elem "git" config.user.applications`

   - Ensures git package is installed
   - If false: Skip silently (user doesn't want git)

1. **hasRepos** = `config.user.repositories.repos != []`

   - Ensures repositories are configured
   - If false: Skip silently (nothing to clone)

1. **hasSSHKey** = `secrets.isSecret (config.user.sshKeys.git or "")`

   - Checks if SSH key configured for git
   - Used for private repositories

1. **hasPublicRepos** = Any repo with HTTPS URL (not starting with `git@`)

   - HTTPS repos work without SSH key
   - If no SSH key but has HTTPS repos: Still run

**Simplified Guard** (if all repos require SSH):

```nix
lib.mkIf (hasGit && hasRepos && hasSSHKey)
```

**Implementation Decision**: Use simplified guard initially, document that HTTPS repos work without `sshKeys.git` configured.

## Environment Setup

### SSH Authentication

**Environment Variable**: `GIT_SSH_COMMAND`

**Value**:

```bash
export GIT_SSH_COMMAND='ssh -i $HOME/.ssh/id_git -o StrictHostKeyChecking=accept-new -o BatchMode=yes'
```

**Components**:

- `-i $HOME/.ssh/id_git`: Use specific SSH key (deployed by `system/shared/app/security/ssh.nix`)
- `-o StrictHostKeyChecking=accept-new`: Accept new hosts without prompt (first-time clone)
- `-o BatchMode=yes`: Non-interactive mode (fail rather than prompt)

**Conditional Setup**:

```bash
if [ -f "$HOME/.ssh/id_git" ]; then
  export GIT_SSH_COMMAND='ssh -i $HOME/.ssh/id_git -o StrictHostKeyChecking=accept-new -o BatchMode=yes'
fi
```

**Behavior**:

- If SSH key exists: Applied to all git operations (SSH and HTTPS repos)
- If SSH key missing: SSH repos fail, HTTPS repos still work
- No harm applying to HTTPS repos (git ignores SSH settings for HTTPS)

### Working Directory

**Current Directory**: `$HOME` (Home Manager activation default)

**Path Resolution**:

- Relative paths resolved from `$HOME`
- Tilde (`~`) expanded by bash to `$HOME`
- Absolute paths used as-is

## Activation Script Structure

### Script Phases

```bash
# Phase 1: Environment Setup
export GIT_SSH_COMMAND='...'  # If SSH key exists

# Phase 2: Repository Processing
for each repository:
  # 2a. Path Resolution
  resolvedPath = <apply resolution algorithm>
  
  # 2b. Parent Directory Creation
  mkdir -p "$(dirname "${resolvedPath}")"
  
  # 2c. Clone or Update
  if [ -d "${resolvedPath}" ]; then
    # Update existing repository
    cd "${resolvedPath}"
    if [ -n "$(git status --porcelain)" ]; then
      echo "Skipping update for ${repoName}: local changes detected"
    else
      git pull --quiet 2>/dev/null || echo "Warning: Failed to update ${repoName}"
    fi
  else
    # Clone new repository
    git clone --quiet "${url}" "${resolvedPath}" 2>/dev/null || echo "Warning: Failed to clone ${repoName}"
  fi
```

### Error Handling

**Non-Blocking Failures**: Individual repository failures MUST NOT break activation.

**Pattern**:

```bash
git clone --quiet "${url}" "${resolvedPath}" 2>/dev/null || {
  echo "Warning: Failed to clone ${repoName} from ${url}"
  echo "  Check network connection, repository access, and SSH key configuration"
}
```

**Error Scenarios**:

| Scenario | Bash Exit Code | Activation Result | User Feedback |
|----------|----------------|-------------------|---------------|
| Network failure | `git clone` fails | Continue | Warning printed |
| Invalid URL | `git clone` fails | Continue | Warning printed |
| Auth failure (SSH) | `git clone` fails | Continue | Warning with SSH hint |
| Path is file | `mkdir -p` fails | Continue | Warning printed |
| Disk full | `git clone` fails | Continue | Warning printed |
| Local changes (update) | Skip pull | Continue | Info message |

**Success Indicators**:

```bash
# Clone success
echo "Cloned repository: ${repoName} to ${resolvedPath}"

# Update success  
echo "Updated repository: ${repoName}"

# Skip due to local changes
echo "Skipping update for ${repoName}: local changes detected"
```

### Output Verbosity

**Quiet Operation**: Suppress git's verbose output

```bash
git clone --quiet "${url}" "${resolvedPath}" 2>/dev/null
git pull --quiet 2>/dev/null
```

**Rationale**:

- Activation logs can be long; reduce noise
- Only show user-relevant messages (success, warnings, errors)
- Detailed git errors not actionable during activation

**User-Facing Messages**:

- ✅ "Cloning repository: ${repoName}"
- ✅ "Updated repository: ${repoName}"
- ⚠️ "Warning: Failed to clone ${repoName}"
- ⚠️ "Skipping update: local changes detected"

## Integration with Secrets

### SSH Key Deployment

**Dependency**: `system/shared/app/security/ssh.nix` deploys `sshKeys.git`

**Deployment Path**: `~/.ssh/id_git` (mode 600)

**Activation Check**:

```bash
if [ -f "$HOME/.ssh/id_git" ]; then
  # SSH key available, set up GIT_SSH_COMMAND
else
  # Skip SSH setup, HTTPS repos still work
fi
```

**Secret Configuration**:

```bash
# User sets up SSH key
just secrets-set cdrokar sshKeys.git "$(cat ~/.ssh/id_ed25519)"
```

**User Config**:

```nix
user.sshKeys.git = "<secret>";
```

### Secrets Validation

**No Validation in Activation**: Trust that if `~/.ssh/id_git` exists, it's valid.

**Error Handling**: If key is invalid, git will fail with auth error (caught by `|| echo` pattern).

## Performance Characteristics

### Expected Performance

**Small Repositories** (< 100 MB):

- Clone: < 10 seconds per repo
- Update: < 5 seconds per repo

**Target** (from success criteria):

- 3-5 small repositories: < 5 minutes total activation time

**Activation Impact**:

- Adds to total activation time (sequential operation)
- Network-bound (not CPU-bound)
- Disk I/O for large repos

### Optimization Strategies

**Future Enhancements** (out of scope for Feature 032):

- Parallel cloning: Use `xargs -P` for concurrent clones
- Shallow clones: `git clone --depth 1` for large repos
- Progress reporting: Show clone progress for large repos

**Current Approach**: Sequential cloning (simple, reliable)

## Idempotency Guarantee

The activation script MUST be idempotent (safe to run multiple times):

**Invariant**: Running activation N times produces same result as running once.

**Idempotent Operations**:

- ✅ `mkdir -p`: Creates if missing, no-op if exists
- ✅ `git clone`: Fails if directory exists (handled by `if`)
- ✅ `git pull`: Updates to latest, no-op if already up-to-date
- ✅ Local change check: Always preserves local work

**Non-Idempotent Scenarios** (safely handled):

- Repository removed from config but still on disk: Orphaned (not deleted)
- Repository URL changed: Old clone preserved, new URL cloned elsewhere (if path different)

## Testing Contract

### Manual Testing Requirements

1. **Clean State**: Test with no repositories cloned
1. **Update State**: Test with repositories already cloned
1. **Local Changes**: Test update with uncommitted changes
1. **SSH Repos**: Test private repository cloning
1. **HTTPS Repos**: Test public repository cloning
1. **Mixed Repos**: Test mix of SSH and HTTPS
1. **Path Resolution**: Test all three path resolution tiers
1. **Failures**: Test network failure, invalid URL, auth failure

### Expected Outcomes

| Test Case | Expected Behavior | Verification |
|-----------|-------------------|--------------|
| First activation | All repos cloned to correct paths | Check directories exist |
| Second activation (clean) | All repos updated to latest | Check git log shows new commits |
| Update with local changes | Skipped with message | Check local changes preserved |
| Missing SSH key | HTTPS works, SSH fails with warning | Check warning in log |
| Network failure | Warning printed, activation succeeds | Check activation exit code = 0 |
| Invalid URL | Warning printed, other repos cloned | Check successful repos exist |

## Version History

**Feature 032 (v1.0)**: Initial implementation

- User-configurable repositories
- Flexible path resolution
- SSH authentication support
- Local change detection
- Non-blocking error handling

**Future Enhancements**:

- Parallel cloning
- Branch/tag selection
- Shallow clone support
- Post-clone hooks
- Update strategy configuration (rebase vs merge)

## Related Activation Entries

**Dependencies** (must run before `cloneUserRepos`):

- `writeBoundary`: File writes complete
- `agenixInstall`: Secrets deployed

**Related Entries** (similar patterns):

- `clonePrivateFonts` (Feature 030): Font repository cloning
- `applyGitSecrets` (Feature 027): Git config secret resolution
- `applySshSecrets` (Feature 027): SSH key deployment

**Coordination**: No direct interaction, independent operations
