# Quickstart: User Git Repository Configuration

**Feature**: 032-user-git-repos\
**For**: End users configuring repository auto-cloning\
**Last Updated**: 2025-12-30

## Overview

This feature automatically clones and updates git repositories during system activation. Configure repositories in your user config, and they'll be cloned to your preferred locations whenever you activate your system.

## Basic Setup

### 1. Add Git to Your Applications

```nix
# user/yourname/default.nix
{...}: {
  user = {
    name = "yourname";
    applications = [
      "git"  # Required for repository cloning
      # ... other apps
    ];
  };
}
```

### 2. Configure Repositories

**Simple Example** (clone to home folder):

```nix
# user/yourname/default.nix
{...}: {
  user = {
    name = "yourname";
    applications = ["git"];
    
    # Add repositories section
    repositories = {
      repos = [
        "https://github.com/user/my-project.git"
        "https://github.com/user/dotfiles.git"
      ];
    };
  };
}
```

**Result**: Repositories cloned to `~/my-project` and `~/dotfiles`

### 3. Activate Your System

```bash
just install yourname your-host
```

**What Happens**:

1. System builds with your configuration
1. Activation runs after git is installed
1. Repositories are cloned to configured paths
1. Success messages printed for each repo

## Advanced Configuration

### Organize Repositories in a Directory

```nix
user.repositories = {
  rootPath = "~/projects";  # All repos clone here by default
  repos = [
    "https://github.com/user/project-a.git"  # → ~/projects/project-a
    "https://github.com/user/project-b.git"  # → ~/projects/project-b
  ];
};
```

### Custom Paths for Specific Repositories

```nix
user.repositories = {
  rootPath = "~/projects";  # Default for most repos
  repos = [
    "https://github.com/user/project-a.git"  # → ~/projects/project-a (uses rootPath)
    
    # Custom path overrides rootPath
    {
      url = "git@github.com:work/important.git";
      path = "~/work/important";  # → ~/work/important (ignores rootPath)
    }
    
    # Absolute path
    {
      url = "https://github.com/user/config.git";
      path = "/opt/configs/my-config";  # → /opt/configs/my-config
    }
  ];
};
```

### Private Repositories with SSH

**Step 1**: Configure SSH key in secrets

```bash
# Set up your SSH key for git
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"
```

**Step 2**: Reference secret in user config

```nix
user = {
  name = "yourname";
  sshKeys.git = "<secret>";  # Will be resolved from secrets.age
  
  repositories = {
    repos = [
      "git@github.com:yourorg/private-repo.git"  # SSH authentication
    ];
  };
};
```

**Step 3**: Activate (SSH key deployed automatically)

```bash
just install yourname your-host
```

### Mixed Public and Private Repositories

```nix
user.repositories = {
  rootPath = "~/code";
  repos = [
    # Public repos (HTTPS, no auth needed)
    "https://github.com/open-source/tool.git"
    
    # Private repos (SSH, uses sshKeys.git)
    "git@github.com:yourorg/private-project.git"
    
    # Works together seamlessly
    {
      url = "git@gitlab.com:company/secret.git";
      path = "~/work/secret";
    }
  ];
};
```

## Path Resolution Examples

The system uses a three-tier precedence for determining where to clone repositories:

| repo.path | rootPath | Repository URL | Final Clone Path |
|-----------|----------|----------------|------------------|
| Not set | Not set | `https://github.com/user/repo.git` | `~/repo` |
| Not set | `~/projects` | `https://github.com/user/repo.git` | `~/projects/repo` |
| `~/custom` | `~/projects` | `https://github.com/user/repo.git` | `~/custom` (overrides rootPath) |
| `/opt/code` | `~/projects` | `https://github.com/user/repo.git` | `/opt/code` (absolute path) |

**Rule**: Individual repo.path > rootPath > home folder

## Common Workflows

### Initial Setup (First Time)

```bash
# 1. Configure repositories in user config
vim user/yourname/default.nix

# 2. For private repos, set up SSH key
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"

# 3. Build and activate
just install yourname your-host

# 4. Verify repositories were cloned
ls ~/projects  # or wherever you configured them
```

### Adding New Repositories

```nix
# Add to your repos list
user.repositories.repos = [
  # Existing repos...
  "https://github.com/user/new-project.git"  # Add this
];
```

```bash
# Activate to clone new repository
just install yourname your-host
```

**Result**: New repository cloned, existing ones updated (if clean)

### Updating Repositories

Repositories are automatically updated during activation **if they have no local changes**:

```bash
# Regular activation updates all clean repos
just install yourname your-host
```

**What Happens**:

- Clean repositories: `git pull` updates to latest
- Repositories with uncommitted changes: Skipped with message
- New repositories: Cloned fresh

### Working with Local Changes

```bash
# Make changes to a cloned repository
cd ~/projects/my-repo
echo "testing" >> README.md
# (Don't commit yet)

# Activate your system
just install yourname your-host
```

**Output**:

```
Skipping update for my-repo: local changes detected
```

**Your work is safe**: Local changes are never overwritten.

## Troubleshooting

### Repository Not Cloning

**Symptom**: Warning during activation: "Failed to clone repo-name"

**Possible Causes**:

1. **Network Issue**: Check internet connection

   ```bash
   ping github.com
   ```

1. **Invalid URL**: Verify repository URL is correct

   ```bash
   git ls-remote https://github.com/user/repo.git
   ```

1. **Authentication Failure** (private repos): Check SSH key

   ```bash
   # Verify SSH key exists
   ls -la ~/.ssh/id_git

   # Test SSH authentication
   ssh -T git@github.com
   ```

1. **Git Not Installed**: Ensure git in applications list

   ```nix
   user.applications = ["git"];  # Must include git
   ```

### SSH Authentication Fails

**Error**: "Permission denied (publickey)"

**Solution**:

```bash
# 1. Verify SSH key is configured
just secrets-show-pubkey yourname

# 2. Re-set SSH key if needed
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"

# 3. Verify key deployed after activation
ls -la ~/.ssh/id_git
cat ~/.ssh/id_git  # Should show your private key

# 4. Test SSH connection
ssh -T git@github.com
```

### Path Already Exists as a File

**Error**: "Failed to clone: path exists and is not a directory"

**Solution**: Remove or rename the conflicting file

```bash
# Check what's at the path
ls -la ~/projects/repo-name

# If it's a file, remove or rename it
mv ~/projects/repo-name ~/projects/repo-name.old

# Re-activate
just install yourname your-host
```

### Repository Has Local Changes But I Want to Update

**Scenario**: You want to discard local changes and pull latest

**Solution**: Commit or discard changes before activation

```bash
# Option 1: Commit your changes
cd ~/projects/my-repo
git add -A
git commit -m "Local changes"

# Option 2: Discard changes
git reset --hard HEAD

# Then activate to pull updates
just install yourname your-host
```

## Best Practices

### 1. Use SSH for Private Repositories

```nix
# ✅ Good: SSH for private repos
repos = [
  "git@github.com:yourorg/private.git"
];

# ❌ Avoid: HTTPS requires manual credential management
repos = [
  "https://github.com/yourorg/private.git"  # Will prompt for password
];
```

### 2. Organize with Root Path

```nix
# ✅ Good: Organized structure
repositories = {
  rootPath = "~/code";
  repos = [...];  # All go in ~/code/
};

# ❌ Avoid: Cluttering home folder
repositories = {
  repos = [...];  # All go in ~/
};
```

### 3. Use Custom Paths for Special Cases

```nix
# ✅ Good: Work repos separate from personal
repositories = {
  rootPath = "~/personal";
  repos = [
    "https://github.com/user/hobby.git"  # → ~/personal/hobby
    {
      url = "git@work.com:company/project.git";
      path = "~/work/project";  # → ~/work/project
    }
  ];
};
```

### 4. Set Up SSH Key Before First Activation

```bash
# ✅ Good: Set up secrets first
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"
just install yourname your-host

# ❌ Avoid: Activating without SSH key for private repos
# (Will fail with authentication errors)
```

## Examples by Use Case

### Developer Workflow

```nix
user.repositories = {
  rootPath = "~/code";
  repos = [
    # Open source projects
    "https://github.com/neovim/neovim.git"
    "https://github.com/rust-lang/rust.git"
    
    # Your projects
    "git@github.com:yourname/portfolio.git"
    "git@github.com:yourname/blog.git"
    
    # Work projects (separate location)
    {
      url = "git@github.com:company/main-app.git";
      path = "~/work/main-app";
    }
  ];
};
```

### Dotfiles Management

```nix
user.repositories = {
  repos = [
    {
      url = "git@github.com:yourname/dotfiles.git";
      path = "~/.dotfiles";  # Hidden directory in home
    }
  ];
};
```

### Multi-Machine Sync

```nix
# Same config works on all machines
user.repositories = {
  rootPath = "~/sync";  # Consistent path across machines
  repos = [
    "git@github.com:yourname/notes.git"
    "git@github.com:yourname/scripts.git"
  ];
};
```

## Feature Limitations

### Current Limitations

1. **No Branch Selection**: Always clones default branch

   - Workaround: Manually checkout desired branch after clone

1. **No Sparse Checkout**: Clones full repository

   - Workaround: Use shallow clone manually if needed

1. **No Submodule Init**: Submodules not automatically initialized

   - Workaround: Run `git submodule update --init` after clone

1. **Sequential Cloning**: Repositories cloned one at a time

   - Impact: Large number of repos may take time

1. **No Automatic Cleanup**: Removed repos stay on disk

   - Workaround: Manually delete unwanted repositories

### Planned Enhancements

These features are not yet implemented but may be added in the future:

- Parallel repository cloning
- Branch/tag selection per repository
- Shallow clone support (depth=1)
- Post-clone hook scripts
- Update strategy configuration (rebase vs merge)
- Automatic cleanup of removed repositories

## Quick Reference

### Configuration Template

```nix
{...}: {
  user = {
    name = "yourname";
    applications = ["git"];  # Required
    
    # Optional: SSH key for private repos
    sshKeys.git = "<secret>";
    
    # Repository configuration
    repositories = {
      rootPath = "~/projects";  # Optional: default parent directory
      repos = [
        # Simple URL (uses rootPath or home)
        "https://github.com/user/public.git"
        
        # With custom path
        {
          url = "git@github.com:user/private.git";
          path = "~/custom/location";
        }
      ];
    };
  };
}
```

### Common Commands

```bash
# Set up SSH key for private repos
just secrets-set yourname sshKeys.git "$(cat ~/.ssh/id_ed25519)"

# Build and activate (clones/updates repos)
just install yourname your-host

# Check secrets are configured
just secrets-list

# Show your public key
just secrets-show-pubkey yourname
```

### Path Resolution Cheat Sheet

```
Priority 1: repo.path (if specified)
    ↓
Priority 2: rootPath + repo-name (if rootPath specified)
    ↓
Priority 3: $HOME + repo-name (default)
```

## Getting Help

If you encounter issues:

1. Check activation log for error messages
1. Verify git is in your applications list
1. Test SSH authentication: `ssh -T git@github.com`
1. Verify repository URL: `git ls-remote <url>`
1. Check network connectivity
1. Review this troubleshooting guide

For feature requests or bugs, see the project's issue tracker.
