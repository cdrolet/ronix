# Feature 032: User Git Repository Configuration

**Status**: Implemented\
**Version**: 1.0\
**Date**: 2025-12-30

## Overview

Automatically clone and update git repositories during system activation. Configure repositories in your user config, and they'll be cloned to your preferred locations whenever you activate your system.

## Quick Start

### Basic Example

```nix
# user/yourname/default.nix
{...}: {
  user = {
    name = "yourname";
    applications = ["git"];  # Required
    
    repositories = {
      repos = [
        "https://github.com/nixos/nixpkgs.git"
      ];
    };
  };
}
```

**Result**: Repository cloned to `~/nixpkgs`

### With Organization

```nix
user.repositories = {
  rootPath = "~/projects";
  repos = [
    "https://github.com/neovim/neovim.git"    # → ~/projects/neovim
    "https://github.com/rust-lang/rust.git"   # → ~/projects/rust
  ];
};
```

### With Custom Paths

```nix
user.repositories = {
  rootPath = "~/projects";
  repos = [
    "https://github.com/user/default.git"  # → ~/projects/default (uses rootPath)
    
    {
      url = "git@github.com:user/work.git";
      path = "~/work/project";  # → ~/work/project (custom path)
    }
  ];
};
```

## Configuration Reference

### user.repositories

Top-level configuration section for git repositories.

**Type**: `null | { rootPath?, repos }`\
**Default**: `null`

#### rootPath

Default parent directory for all repositories without individual paths.

**Type**: `null | string (path)`\
**Default**: `null` (repositories clone to home folder)\
**Example**: `"~/projects"`

Supports:

- Tilde expansion: `~/code`
- Relative paths: `./local`
- Absolute paths: `/opt/repos`

#### repos

List of repositories to clone.

**Type**: `list of (string | { url, path? })`\
**Default**: `[]`

Each entry can be:

1. **Simple URL** (string): Uses rootPath or home folder

   ```nix
   "https://github.com/user/repo.git"
   ```

1. **Detailed spec** ({ url, path }): Custom clone location

   ```nix
   {
     url = "git@github.com:user/repo.git";
     path = "~/custom/location";
   }
   ```

## Path Resolution

The system uses three-tier precedence for clone destinations:

1. **Individual repo.path** (if specified) → Highest priority
1. **Section rootPath** (if specified) → Medium priority
1. **Home folder** (`$HOME`) → Default

**Examples**:

| repo.path | rootPath | URL | Clone Path |
|-----------|----------|-----|-----------|
| Not set | Not set | `...repo.git` | `~/repo` |
| Not set | `~/code` | `...repo.git` | `~/code/repo` |
| `~/work` | `~/code` | `...repo.git` | `~/work` (overrides) |
| `/opt/sys` | `~/code` | `...repo.git` | `/opt/sys` (absolute) |

## Private Repositories (SSH)

### Setup SSH Key

```bash
# Add your SSH key to secrets
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"
```

### Configure User

```nix
user = {
  applications = ["git"];
  sshKeys.git = "<secret>";  # Reference the secret
  
  repositories.repos = [
    "git@github.com:yourorg/private.git"
  ];
};
```

### What Happens

1. Activation deploys SSH key to `~/.ssh/id_git`
1. Repository cloning uses SSH authentication automatically
1. Private repos clone successfully

## Repository Updates

Existing repositories are automatically updated during subsequent activations.

### Update Behavior

**Clean repositories** (no local changes):

- `git pull` updates to latest
- Success message printed

**Repositories with local changes**:

- Update skipped
- Warning message: "Skipping update for {name}: local changes detected"
- Your work is preserved

**Deleted repositories**:

- Re-cloned from remote
- Fresh copy created

### Example

```bash
# First activation: Clone repos
just install yourname hostname

# Make changes in remote
# (Someone pushes new commits)

# Second activation: Update repos
just install yourname hostname
# → Clean repos updated automatically

# Work on a repo locally
cd ~/projects/myrepo
echo "testing" >> README.md

# Third activation
just install yourname hostname
# → "Skipping update for myrepo: local changes detected"
```

## Activation Timing

Repositories are cloned during Home Manager activation, not during build:

**Activation Order**:

1. System packages installed (including git)
1. Files written (`writeBoundary`)
1. Secrets deployed (`agenixInstall`)
1. **Repositories cloned** ← Happens here
1. Other activation scripts

**Why This Matters**:

- Git must be installed first
- SSH credentials must be available
- Network access required during activation

## Requirements

### Must Have

- `git` in `user.applications` list
- Network connectivity during activation

### Optional

- `sshKeys.git` secret for private repositories
- Disk space for repositories

### Graceful Degradation

If git not in applications list:

- Repository cloning skipped silently
- No activation failure
- Other features work normally

## Examples

### Developer Workflow

```nix
user.repositories = {
  rootPath = "~/code";
  repos = [
    # Open source
    "https://github.com/neovim/neovim.git"
    
    # Your projects
    "git@github.com:yourname/portfolio.git"
    
    # Work (separate location)
    {
      url = "git@github.com:company/app.git";
      path = "~/work/main-app";
    }
  ];
};
```

### Dotfiles Management

```nix
user.repositories.repos = [
  {
    url = "git@github.com:yourname/dotfiles.git";
    path = "~/.dotfiles";
  }
];
```

### Multi-Machine Sync

```nix
# Same config works on all machines
user.repositories = {
  rootPath = "~/sync";
  repos = [
    "git@github.com:yourname/notes.git"
    "git@github.com:yourname/scripts.git"
  ];
};
```

## Troubleshooting

### Repository Not Cloning

**Symptom**: Warning during activation: "Failed to clone repo-name"

**Solutions**:

1. **Check network**: `ping github.com`
1. **Verify URL**: `git ls-remote <url>`
1. **Test SSH** (private repos): `ssh -T git@github.com`
1. **Verify git installed**: Ensure `"git"` in `user.applications`

### SSH Authentication Fails

**Error**: "Permission denied (publickey)"

**Solutions**:

```bash
# 1. Verify SSH key configured
just secrets-list

# 2. Re-add SSH key if needed
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"

# 3. Test SSH connection
ssh -T git@github.com
```

### Path Conflicts

**Error**: "Failed to clone: path exists and is not a directory"

**Solution**: Remove conflicting file

```bash
# Check what's at the path
ls -la ~/projects/repo-name

# Remove or rename if it's a file
mv ~/projects/repo-name ~/projects/repo-name.old

# Re-activate
just install yourname hostname
```

### Want to Update Despite Local Changes

**Scenario**: Discard local changes and pull latest

**Solution**:

```bash
cd ~/repo
git reset --hard HEAD  # Discard changes
# Then activate to pull updates
just install yourname hostname
```

## Limitations

### Current Limitations

- **No branch selection**: Always clones default branch
- **No sparse checkout**: Clones full repository
- **Sequential cloning**: Repos cloned one at a time
- **No automatic cleanup**: Removed repos stay on disk

### Workarounds

**Branch selection**: Manually checkout after clone

```bash
cd ~/repo && git checkout develop
```

**Sparse checkout**: Configure manually after clone

**Large repos**: Consider shallow clone manually if needed

## Technical Details

### Files Modified

- `system/shared/lib/git.nix` - Library functions
- `system/shared/settings/git-repos.nix` - Activation module

### Activation Script

Located in: `home.activation.cloneUserRepos`

**DAG Position**: `entryAfter ["writeBoundary" "agenixInstall"]`

**Conditional**: Only runs if `git` in applications and repos configured

### Related Features

- **Feature 030**: Font repository cloning (similar pattern)
- **Feature 027**: Activation-time secrets (SSH key deployment)
- **Feature 031**: Per-user secrets (SSH key storage)

## See Also

- [Quickstart Guide](../../specs/032-user-git-repos/quickstart.md) - Detailed examples
- [Specification](../../specs/032-user-git-repos/spec.md) - Full requirements
- [Implementation Plan](../../specs/032-user-git-repos/plan.md) - Technical details
