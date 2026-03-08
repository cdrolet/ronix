# Contract: Git Library Interface

**Feature**: 032-user-git-repos\
**Module**: `system/shared/lib/git.nix`\
**Status**: Partially exists (reusing from Feature 030)

## Overview

This document defines the interface contract for the git repository cloning library. This library provides pure Nix functions for repository name extraction and bash script generation for cloning/updating repositories.

## Function Contracts

### 1. repoName

**Purpose**: Extract repository name from a git URL.

**Signature**:

```nix
repoName :: String -> String
```

**Input**:

- `url` (String): Git repository URL in SSH or HTTPS format

**Output**:

- (String): Repository name without .git extension

**Behavior**:

1. Remove `.git` suffix if present
1. Split URL by `/` separator
1. Return last segment

**Examples**:

| Input | Output |
|-------|--------|
| `"git@github.com:user/my-repo.git"` | `"my-repo"` |
| `"https://github.com/user/my-repo.git"` | `"my-repo"` |
| `"https://github.com/user/my-repo"` | `"my-repo"` |
| `"git@gitlab.com:org/sub/project.git"` | `"project"` |

**Edge Cases**:

- URL without `.git`: Works (just takes last segment)
- URL with no slashes: Returns entire URL (edge case, rare)
- Empty string: Returns empty string (caller should validate)

**Guarantees**:

- Pure function (no side effects)
- Deterministic (same input → same output)
- No external dependencies

**Implementation Status**: ✅ EXISTS (from Feature 030)

______________________________________________________________________

### 2. mkRepoCloneScript

**Purpose**: Generate bash script fragment for cloning/updating multiple repositories.

**Signature**:

```nix
mkRepoCloneScript :: { pkgs, repos, targetDir } -> String
```

**Input**:

- `pkgs` (nixpkgs): Package set for git binary path
- `repos` (List of String): List of git repository URLs
- `targetDir` (String): Parent directory to clone into

**Output**:

- (String): Bash script that clones/updates all repositories

**Behavior**:
For each repository URL:

1. Extract repository name using `repoName`
1. Construct local path: `${targetDir}/${repoName}`
1. If directory exists: `git pull` (update)
1. If directory doesn't exist: `git clone` (initial clone)
1. Suppress output with `--quiet`, errors to `/dev/null`
1. Continue on failure (use `|| true`)

**Generated Script Structure**:

```bash
# For each repo in repos:
if [ -d "${targetDir}/${repoName}" ]; then
  echo "Updating repository: ${repoName}"
  cd "${targetDir}/${repoName}" && ${pkgs.git}/bin/git pull --quiet 2>/dev/null || true
else
  echo "Cloning repository: ${repoName}"
  ${pkgs.git}/bin/git clone --quiet "${url}" "${targetDir}/${repoName}" 2>/dev/null || true
fi
```

**Guarantees**:

- Non-blocking: Failures don't stop subsequent clones
- Idempotent: Safe to run multiple times
- Informative: Prints operation being performed
- Silent errors: Doesn't spam activation log with git errors

**Limitations**:

- No local change detection (always attempts pull on existing repos)
- No authentication configuration (relies on environment variables)
- No branch/tag selection (uses default branch)

**Implementation Status**: ✅ EXISTS (from Feature 030)

**Note**: This contract needs enhancement for Feature 032 to support:

- Custom paths per repository (not all in same targetDir)
- Local change detection before pull
- Better error reporting

______________________________________________________________________

### 3. normalizeRepo (NEW)

**Purpose**: Convert flexible repository specification to consistent internal format.

**Signature**:

```nix
normalizeRepo :: (String | { url :: String, path :: String? }) -> { url :: String, path :: String? }
```

**Input**:

- (String): Simple repository URL, OR
- (AttrSet): Detailed specification with `url` and optional `path`

**Output**:

- (AttrSet): `{ url = "..."; path = null | "..."; }`

**Behavior**:

1. If input is string: `{ url = input; path = null; }`
1. If input is attrset: `{ url = input.url; path = input.path or null; }`
1. If input is neither: Throw type error

**Examples**:

| Input | Output |
|-------|--------|
| `"git@github.com:user/repo.git"` | `{ url = "git@github.com:user/repo.git"; path = null; }` |
| `{ url = "https://..."; }` | `{ url = "https://..."; path = null; }` |
| `{ url = "https://..."; path = "~/work"; }` | `{ url = "https://..."; path = "~/work"; }` |

**Guarantees**:

- Type safety: Throws on invalid input
- Consistent output: Always returns `{ url, path }` structure
- Pure function: No side effects

**Implementation Status**: ❌ NEW (to be implemented in Feature 032)

______________________________________________________________________

### 4. resolveRepoPath (NEW)

**Purpose**: Determine final clone destination for a repository.

**Signature**:

```nix
resolveRepoPath :: { url :: String, path :: String? } -> String? -> String
```

**Input**:

- `repo` (AttrSet): Normalized repository specification
- `rootPath` (String | Null): Section-level default path

**Output**:

- (String): Resolved clone destination path

**Behavior** (precedence order):

1. If `repo.path != null`: Return `repo.path`
1. Else if `rootPath != null`: Return `"${rootPath}/${repoName repo.url}"`
1. Else: Return `"$HOME/${repoName repo.url}"`

**Examples**:

| repo.path | rootPath | repo.url | Output |
|-----------|----------|----------|--------|
| `"~/work"` | `"~/projects"` | `"git@...repo.git"` | `"~/work"` |
| `null` | `"~/projects"` | `"git@...repo.git"` | `"~/projects/repo"` |
| `null` | `null` | `"git@...repo.git"` | `"$HOME/repo"` |
| `"/opt/code"` | `"~/projects"` | `"git@...repo.git"` | `"/opt/code"` |

**Guarantees**:

- Deterministic: Same inputs → same output
- Well-defined precedence: Individual > section > default
- Path flexibility: Supports absolute, relative, tilde-expansion

**Implementation Status**: ❌ NEW (to be implemented in Feature 032)

______________________________________________________________________

### 5. mkRepoCloneScriptWithPaths (NEW)

**Purpose**: Enhanced version of `mkRepoCloneScript` supporting custom paths and local change detection.

**Signature**:

```nix
mkRepoCloneScriptWithPaths :: { pkgs, repos :: List { url, path }, checkLocal :: Bool } -> String
```

**Input**:

- `pkgs` (nixpkgs): Package set for git binary
- `repos` (List of AttrSet): List of `{ url, path }` specifications (normalized)
- `checkLocal` (Bool): If true, check for local changes before pull

**Output**:

- (String): Bash script for cloning/updating with custom paths

**Behavior**:
For each repository:

1. Use `repo.path` as clone destination
1. Create parent directories with `mkdir -p "$(dirname "${repo.path}")"`
1. If directory exists:
   - If `checkLocal`: Check `git status --porcelain`
   - If local changes: Skip pull, print warning
   - If clean: Attempt `git pull`
1. If directory doesn't exist: `git clone`
1. Non-blocking failures: Use `|| echo "Warning: ..."`

**Generated Script Structure**:

```bash
# Create parent directory
mkdir -p "$(dirname "${resolvedPath}")"

if [ -d "${resolvedPath}" ]; then
  cd "${resolvedPath}"
  
  # Check for local changes (if checkLocal=true)
  if [ -n "$(git status --porcelain)" ]; then
    echo "Skipping update for ${repoName}: local changes detected"
  else
    echo "Updating repository: ${repoName}"
    git pull --quiet 2>/dev/null || echo "Warning: Failed to update ${repoName}"
  fi
else
  echo "Cloning repository: ${repoName} to ${resolvedPath}"
  git clone --quiet "${url}" "${resolvedPath}" 2>/dev/null || echo "Warning: Failed to clone ${repoName}"
fi
```

**Guarantees**:

- Custom paths: Each repo can have different destination
- Local safety: Preserves uncommitted changes when `checkLocal=true`
- Informative errors: Warns about failures without breaking activation
- Parent directory creation: Ensures path exists before clone

**Implementation Status**: ❌ NEW (to be implemented in Feature 032)

## Module Exports

The `system/shared/lib/git.nix` module MUST export these functions:

```nix
{
  # Existing (Feature 030)
  inherit repoName;
  inherit mkRepoCloneScript;
  
  # New (Feature 032)
  inherit normalizeRepo;
  inherit resolveRepoPath;
  inherit mkRepoCloneScriptWithPaths;
}
```

## Usage Example

```nix
# In system/shared/settings/git-repos.nix
let
  gitLib = import ../../lib/git.nix { inherit lib; };
  
  # User configuration
  userRepos = config.user.repositories.repos;
  rootPath = config.user.repositories.rootPath;
  
  # Normalize all repository specifications
  normalized = map gitLib.normalizeRepo userRepos;
  
  # Resolve paths
  withPaths = map (repo: {
    url = repo.url;
    path = gitLib.resolveRepoPath repo rootPath;
  }) normalized;
  
in {
  home.activation.cloneUserRepos = lib.mkIf hasGit (
    lib.hm.dag.entryAfter ["writeBoundary" "agenixInstall"] ''
      ${gitLib.mkRepoCloneScriptWithPaths {
        inherit pkgs;
        repos = withPaths;
        checkLocal = true;  # Preserve local changes
      }}
    ''
  );
}
```

## Backward Compatibility

Feature 032 enhancements MUST NOT break Feature 030 (font repository cloning):

- ✅ `repoName` signature unchanged
- ✅ `mkRepoCloneScript` signature unchanged
- ✅ New functions are additive (don't modify existing)
- ✅ Font cloning continues using original `mkRepoCloneScript`

## Testing Requirements

Each function MUST be testable in isolation:

1. **Unit tests**: Pure functions with known inputs/outputs
1. **Integration tests**: Full activation script generation
1. **Edge case tests**: Empty lists, null paths, invalid URLs

**Test Strategy**:

- Nix evaluation tests: Verify correct output for various inputs
- Activation script tests: Manual testing on darwin and nixos
- Error handling tests: Verify graceful degradation

## Error Handling Contract

All library functions MUST follow these error handling rules:

1. **Type errors**: Throw at evaluation time with clear message
1. **Logic errors**: Return sensible default or throw with explanation
1. **Runtime errors**: Handled by activation script (bash), not Nix functions

**Examples**:

```nix
# Type error (evaluation time)
normalizeRepo 123  # Throws: "Invalid repository specification: must be string or attrset"

# Logic preserved (evaluation time)
repoName ""  # Returns: "" (empty string, caller validates)

# Runtime error (activation time, bash handles)
git clone <invalid-url>  # Script continues, prints warning
```

## Version Compatibility

**Library Version**: 2.0 (Feature 032)

- Adds: `normalizeRepo`, `resolveRepoPath`, `mkRepoCloneScriptWithPaths`
- Maintains: All Feature 030 functions unchanged

**Breaking Changes**: None - purely additive

**Migration**: Feature 030 (fonts) continues using v1.0 interface
