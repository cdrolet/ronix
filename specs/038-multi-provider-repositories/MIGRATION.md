# Migration Guide: Feature 032 → Feature 038

**From**: Feature 032 (User Git Repository Configuration)\
**To**: Feature 038 (Multi-Provider Repository Support)\
**Status**: Backward Compatible - No Breaking Changes

## Summary

Feature 038 extends Feature 032's git-only repository support to a multi-provider system supporting git, S3, Proton Drive, and custom providers. The migration is **backward compatible** - existing git repository configurations continue to work without modification.

## What Changed

### Schema Location

**Before (Feature 032)**:

- Schema defined in `system/shared/settings/git-repos.nix`
- Options: `user.repositories.rootPath`, `user.repositories.repos`

**After (Feature 038)**:

- Schema defined in `user/shared/lib/user-schema.nix` (provider-agnostic)
- Option: `user.repositories` (flat list, no `rootPath` field)

### Repository Configuration Format

**Old Format (Feature 032)** - Still Works! ✓

```nix
user.repositories = {
  rootPath = "~/projects";  # Section-level path (REMOVED in 038)
  repos = [
    "git@github.com:user/repo1.git"  # Simple string
    {
      url = "https://github.com/user/repo2";
      path = "~/custom/location";
    }
  ];
};
```

**New Format (Feature 038)** - Recommended

```nix
user.repositories = [
  # Git repositories (auto-detected)
  {
    url = "git@github.com:user/repo1.git";
    # path defaults to ~/repositories/repo1
  }
  {
    url = "https://github.com/user/repo2";
    path = "~/custom/location";  # Override default
  }
  
  # New: S3 buckets
  {
    url = "s3://my-bucket/backups";
    auth = "tokens.s3";
    path = "~/backups";
  }
  
  # New: Proton Drive
  {
    url = "https://drive.proton.me/urls/ABC123";
    auth = "tokens.protonDrive";
  }
];
```

## Migration Steps

### Step 1: No Changes Required (Backward Compatible)

If you only use git repositories, **you don't need to change anything**. The new system automatically:

- Detects git provider from URLs
- Uses default paths: `~/repositories/<repo-name>`
- Maintains existing behavior

### Step 2: Optional - Modernize Configuration

If you want to use the new schema features:

**Before**:

```nix
user.repositories = {
  rootPath = "~/projects";
  repos = [
    "git@github.com:user/dotfiles.git"
    {
      url = "https://github.com/user/work-repo";
      path = "~/work/repo";
    }
  ];
};
```

**After**:

```nix
user.repositories = [
  {
    url = "git@github.com:user/dotfiles.git";
    path = "~/projects/dotfiles";  # Explicitly set (replaces rootPath)
  }
  {
    url = "https://github.com/user/work-repo";
    path = "~/work/repo";  # Same as before
  }
];
```

**Note**: The `rootPath` field is no longer supported. If you used it, explicitly set `path` for each repository.

### Step 3: Add Multi-Provider Repositories (Optional)

Once migrated, you can add S3, Proton Drive, or custom providers:

```nix
user.repositories = [
  # Existing git repos
  {
    url = "git@github.com:user/dotfiles.git";
  }
  
  # New: Add S3 bucket
  {
    url = "s3://my-backups/documents";
    auth = "tokens.s3";
    path = "~/backups/docs";
    options.region = "us-west-2";
  }
];
```

## Breaking Changes

### Removed: `rootPath` Field

**Impact**: Users who configured `user.repositories.rootPath` will need to set explicit paths.

**Before**:

```nix
user.repositories = {
  rootPath = "~/dev";
  repos = [
    "git@github.com:user/repo1.git"  # Cloned to ~/dev/repo1
    "git@github.com:user/repo2.git"  # Cloned to ~/dev/repo2
  ];
};
```

**After**:

```nix
user.repositories = [
  {
    url = "git@github.com:user/repo1.git";
    path = "~/dev/repo1";  # Explicit
  }
  {
    url = "git@github.com:user/repo2.git";
    path = "~/dev/repo2";  # Explicit
  }
];
```

**Or use default paths**:

```nix
user.repositories = [
  { url = "git@github.com:user/repo1.git"; }  # Defaults to ~/repositories/repo1
  { url = "git@github.com:user/repo2.git"; }  # Defaults to ~/repositories/repo2
];
```

## New Features Available

### 1. Automatic Provider Detection

No need to specify it's a git repository - the system auto-detects from URL:

```nix
user.repositories = [
  { url = "git@github.com:user/repo.git"; }  # Auto-detected: git
  { url = "s3://bucket/path"; }              # Auto-detected: s3
  { url = "https://drive.proton.me/urls/X"; } # Auto-detected: proton-drive
];
```

### 2. Explicit Provider Override

For ambiguous URLs:

```nix
user.repositories = [
  {
    url = "https://custom-server.com/data";
    provider = "s3";  # Force S3 (could be git or HTTP)
    options.endpoint = "https://custom-server.com";
  }
];
```

### 3. Provider-Specific Options

```nix
user.repositories = [
  # Git options
  {
    url = "https://github.com/large/monorepo";
    options = {
      depth = 1;        # Shallow clone
      branch = "main";  # Specific branch
      submodules = false;
    };
  }
  
  # S3 options
  {
    url = "s3://bucket/path";
    options = {
      region = "us-west-2";
      syncOptions = ["--delete"];
    };
  }
];
```

### 4. Authentication References

```nix
user.repositories = [
  {
    url = "git@github.com:user/private-repo.git";
    auth = "sshKeys.github";  # Uses user.sshKeys.github secret
  }
  {
    url = "s3://bucket/path";
    auth = "tokens.s3";  # Uses user.tokens.s3 secret
  }
];
```

## Validation

After migration, validate your configuration:

```bash
# Check Nix syntax
nix flake check

# Build configuration
just build myuser myhost

# Dry-run (darwin)
darwin-rebuild build --flake .#myuser-myhost
```

## Rollback

If you need to rollback to Feature 032:

```bash
git checkout <commit-before-038>
just install myuser myhost
```

Your user configuration remains compatible - the old schema will work again.

## Support

- **Documentation**: See [quickstart.md](quickstart.md) for examples
- **Schema Reference**: See [contracts/repository-schema.nix](contracts/repository-schema.nix)
- **Custom Providers**: See [Adding Custom Providers](quickstart.md#adding-custom-providers)

## Summary

✅ **Backward Compatible**: Existing git configs work without changes\
✅ **Optional Migration**: Modernize at your own pace\
⚠️ **Breaking**: `rootPath` removed - set explicit `path` if needed\
🚀 **New**: Multi-provider support (S3, Proton Drive, custom)\
🚀 **New**: Auto-detection from URLs\
🚀 **New**: Provider-specific options
