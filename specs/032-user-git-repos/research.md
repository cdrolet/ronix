# Research: User Git Repository Configuration

**Feature**: 032-user-git-repos\
**Date**: 2025-12-30\
**Status**: Complete

## Overview

This document captures research findings and design decisions for implementing user-configurable git repository cloning during Home Manager activation.

## Key Decisions

### 1. Repository Configuration Data Structure

**Decision**: Use a flexible attribute set structure supporting both simple URLs and detailed repository specifications.

**Rationale**:

- **Simple case**: Users can specify just a URL string for quick configuration
- **Advanced case**: Users can provide `{ url = "..."; path = "..."; }` for custom paths
- **Section-level settings**: Optional `rootPath` applies to all repos without individual paths
- **Backward compatible**: Easy to extend with additional fields (branch, tag, recursive, etc.) in the future

**Structure**:

```nix
user.repositories = {
  rootPath = "~/projects";  # Optional: default parent directory
  repos = [
    "git@github.com:user/simple-repo.git"              # Simple URL
    { url = "https://github.com/user/custom.git"; }    # Explicit but no custom path
    { url = "git@github.com:user/work.git"; path = "~/work/project"; }  # Custom path
  ];
};
```

**Alternatives Considered**:

- **Flat list of URLs only**: Too rigid, no custom path support
- **Only detailed specifications**: Too verbose for simple cases
- **Separate arrays** (`urls`, `customRepos`): Confusing, duplicates configuration

### 2. Path Resolution Algorithm

**Decision**: Three-tier precedence with explicit resolution order.

**Resolution Order**:

1. **Individual repository `path`**: If specified, use exactly as-is
1. **Section `rootPath`**: If no individual path, use `${rootPath}/${repoName}`
1. **Home folder default**: If neither specified, use `${HOME}/${repoName}`

**Path Handling**:

- **Absolute paths** (`/path/to/dir`): Used exactly as specified
- **Relative paths** (`~/projects`, `./local`): Resolved from `$HOME`
- **Tilde expansion**: Handled by bash during activation (not Nix evaluation)

**Rationale**:

- Clear precedence eliminates ambiguity
- Supports both organized project directories and one-off placements
- Follows principle of least surprise (most specific wins)
- Consistent with Feature 030 (font repos) pattern

**Implementation**:

```nix
resolveRepoPath = repo: rootPath:
  if repo ? path && repo.path != null then
    repo.path  # Individual path takes precedence
  else if rootPath != null then
    "${rootPath}/${gitLib.repoName repo.url}"  # Section root
  else
    "$HOME/${gitLib.repoName repo.url}";  # Default to home
```

### 3. Activation Timing and Dependencies

**Decision**: Use `lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"]` for activation ordering.

**Rationale**:

- **After writeBoundary**: Ensures all file writes complete before cloning
- **After agenixInstall**: SSH credentials must be deployed before private repo cloning
- **Conditional on git**: Only run if `git` is in `user.applications` list
- **Non-blocking failures**: Repository cloning failures don't break entire activation

**Proven Pattern**: Feature 030 (font repos) uses identical ordering for SSH-authenticated git cloning

**Activation Guard**:

```nix
home.activation.cloneUserRepos = lib.mkIf (hasGit && hasRepos) (
  lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
    # Activation script here
  ''
);
```

### 4. Authentication Strategy

**Decision**: Reuse existing SSH key management from Feature 031 (per-user secrets).

**SSH Key Handling**:

- **Private repos**: Require `user.sshKeys.git` configured in secrets
- **Public repos**: Work without authentication
- **Mixed repos**: SSH key applied via `GIT_SSH_COMMAND` for all clones (no-op for HTTPS)
- **Key deployment**: Handled by existing SSH app activation (Feature 027)

**Environment Variable**:

```bash
export GIT_SSH_COMMAND='ssh -i $HOME/.ssh/id_git -o StrictHostKeyChecking=accept-new -o BatchMode=yes'
```

**Rationale**:

- No new authentication mechanism needed
- Consistent with font repository pattern
- Users already understand `sshKeys.*` secret pattern
- `accept-new` prevents interactive prompts during activation
- `BatchMode=yes` ensures non-interactive operation

**Alternatives Considered**:

- **Dedicated git SSH key**: Could use `sshKeys.repositories` but adds configuration burden
- **Reuse `sshKeys.personal`**: Less clear intent, mixing concerns
- **Per-repo authentication**: Too complex for typical use cases

### 5. Update Strategy for Existing Repositories

**Decision**: Safe update using `git fetch` + status check, preserving local changes.

**Update Logic**:

```bash
if [ -d "${localPath}" ]; then
  cd "${localPath}"
  
  # Check for local changes
  if [ -n "$(git status --porcelain)" ]; then
    echo "Skipping update for ${name}: local changes detected"
  else
    git pull --quiet 2>/dev/null || echo "Warning: Failed to update ${name}"
  fi
else
  git clone --quiet "${url}" "${localPath}" 2>/dev/null || echo "Warning: Failed to clone ${name}"
fi
```

**Rationale**:

- **Preserve local work**: Never overwrite uncommitted changes
- **Non-destructive**: User maintains control over repository state
- **Informative**: Warns about local changes without blocking
- **Graceful degradation**: Network failures don't break activation

**Alternatives Considered**:

- **Always pull**: Risk losing local changes (unacceptable)
- **Stash + pull + pop**: Complex, risk of merge conflicts, unexpected behavior
- **Never update**: Repositories become stale over time
- **`git fetch` only**: Safer but less useful (requires manual merge)

**Trade-off**: Chosen approach balances safety (never lose work) with automation (update when safe).

### 6. Repository Name Extraction

**Decision**: Reuse existing `gitLib.repoName` function from `system/shared/lib/git.nix`.

**Existing Implementation**:

```nix
repoName = url: let
  withoutGit = lib.removeSuffix ".git" url;
  parts = lib.splitString "/" withoutGit;
in lib.last parts;
```

**Supported Formats**:

- `git@github.com:user/repo.git` → `repo`
- `https://github.com/user/repo.git` → `repo`
- `https://github.com/user/repo` → `repo`

**Rationale**:

- Already implemented and tested (Feature 030)
- Handles both SSH and HTTPS formats
- No duplication of logic

### 7. Error Handling and User Feedback

**Decision**: Non-blocking errors with clear user feedback during activation.

**Error Scenarios**:

1. **Missing git**: Silently skip (conditional activation)
1. **Missing SSH key**: Warn but continue with public repos
1. **Network failure**: Warn per repository, continue with others
1. **Invalid URL**: Git clone failure warning, continue
1. **Path conflicts**: Error if path is a file, not directory

**Feedback Pattern**:

```bash
echo "Cloning repository: ${name}"
${pkgs.git}/bin/git clone --quiet "${url}" "${localPath}" 2>/dev/null || {
  echo "Warning: Failed to clone ${name} from ${url}"
  echo "  Check network connection and repository URL"
}
```

**Rationale**:

- Activation should not fail due to repository issues
- Users see actionable error messages
- Failed repos don't block successful clones
- Matches existing activation script error handling patterns

### 8. Normalization of Repository Specifications

**Decision**: Normalize all repository specifications to a consistent internal format during evaluation.

**Normalization Function**:

```nix
normalizeRepo = repo:
  if builtins.isString repo then
    { url = repo; path = null; }
  else if builtins.isAttrs repo then
    { url = repo.url; path = repo.path or null; }
  else
    throw "Invalid repository specification: must be string or { url, path }";
```

**Rationale**:

- **Uniform processing**: Single code path for path resolution and cloning
- **Type safety**: Validation at evaluation time, not activation time
- **Clear errors**: User sees configuration errors during build, not activation
- **Extensibility**: Easy to add fields (branch, tag, depth) in future

**Alternatives Considered**:

- **Handle both formats in activation script**: More complex bash logic
- **Require consistent format**: Less user-friendly
- **Multiple code paths**: Duplication, higher maintenance burden

## Best Practices Applied

### From Feature 030 (Font Repositories)

**Proven Patterns**:

- ✅ Activation timing: `entryAfter ["writeBoundary" "agenixInstall"]`
- ✅ SSH authentication: `GIT_SSH_COMMAND` environment variable
- ✅ Conditional execution: `lib.mkIf (hasRequiredApp && hasConfig)`
- ✅ Directory creation: `mkdir -p` before cloning
- ✅ Quiet operation: `--quiet` flag, errors to `/dev/null`, user-friendly echo

**Reused Functions**:

- ✅ `gitLib.mkRepoCloneScript`: Generate bash clone/update logic
- ✅ `gitLib.repoName`: Extract repository name from URL
- ✅ `secrets.isSecret`: Check for SSH key secrets

### From Feature 027 (Activation-Time Secrets)

**Pattern Applied**:

- ✅ Secret detection: Check `user.sshKeys.git` for `"<secret>"`
- ✅ Activation guard: Only run if secret exists and agenix deployed it
- ✅ Non-blocking: SSH key absence doesn't fail activation (skip private repos)

### From Feature 031 (Per-User Secrets)

**Integration**:

- ✅ Per-user SSH keys: `user/{username}/secrets.age` contains `sshKeys.git`
- ✅ Key deployment: SSH app handles `~/.ssh/id_git` creation
- ✅ Justfile commands: `just secrets-set cdrokar sshKeys.git "$(cat ~/.ssh/id_ed25519)"`

## Technical Constraints

### 1. Git Availability

**Constraint**: Git must be installed before repository cloning activation runs.

**Solution**: Conditional activation based on `lib.elem "git" config.user.applications`

**Validation**: Build fails if repositories configured but git not in applications list? NO - silently skip for flexibility.

### 2. Network Dependency

**Constraint**: Repository cloning requires network access during activation.

**Mitigation**:

- Non-blocking failures (activation succeeds even if clones fail)
- User can manually retry: `git clone` after activation
- Future enhancement: Offline mode with local git bundles

### 3. Home Manager Activation Ordering

**Constraint**: Home Manager DAG (Directed Acyclic Graph) determines activation order.

**Dependencies**:

- **AFTER**: `writeBoundary` (file writes complete)
- **AFTER**: `agenixInstall` (SSH keys deployed)
- **BEFORE**: None (repository cloning is terminal operation)

**Verification**: No circular dependencies, order is well-defined.

### 4. Path Expansion

**Constraint**: Nix cannot expand `~` (tilde) - it's a shell construct.

**Solution**:

- Store paths as strings with `~` in Nix
- Let bash handle expansion during activation
- Document that paths are bash-expanded, not Nix-evaluated

**Example**:

```nix
# In Nix config
rootPath = "~/projects";

# In activation script (bash expands ~)
mkdir -p ~/projects  # Becomes /Users/username/projects
```

## Integration Points

### 1. User Configuration Schema

**Location**: `user/{username}/default.nix`

**New Section**:

```nix
user.repositories = {
  rootPath = "~/projects";  # Optional
  repos = [
    "git@github.com:user/repo1.git"
    { url = "https://github.com/user/repo2.git"; path = "~/custom/location"; }
  ];
};
```

**Validation**: Type checking at evaluation time via Home Manager options.

### 2. Secrets Integration

**Location**: `user/{username}/secrets.age`

**New Field**:

```json
{
  "sshKeys": {
    "git": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
  }
}
```

**Management**:

```bash
just secrets-set cdrokar sshKeys.git "$(cat ~/.ssh/id_ed25519)"
```

### 3. Settings Module Registration

**Location**: Auto-discovered via `system/shared/settings/default.nix`

**Discovery**: Just add `git-repos.nix` to `system/shared/settings/`, auto-imported.

## Open Questions

None. All design decisions resolved through research and existing pattern analysis.

## References

- **Feature 030**: Font repository cloning (activation pattern)
- **Feature 027**: Activation-time secret resolution
- **Feature 031**: Per-user secrets with SSH keys
- **Existing Code**: `system/shared/lib/git.nix` (reusable git helpers)
- **Home Manager**: DAG activation documentation
- **Nix Manual**: String interpolation, path handling
