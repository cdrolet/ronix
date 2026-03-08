# Quickstart: Platform-Agnostic Discovery System

**Feature**: 017-platform-agnostic-discovery\
**Audience**: Developers working on nix-config\
**Date**: 2025-11-15

## What Changed

The discovery system has been redesigned to be truly platform-agnostic:

- ✅ **No hardcoded platform names** - discovers platforms dynamically from filesystem
- ✅ **Graceful degradation** - user configs skip unavailable apps instead of erroring
- ✅ **Better validation** - helpful errors when apps truly don't exist
- ✅ **Cross-platform configs** - users can reference platform-specific apps safely

## Quick Examples

### User Config: Import All Apps

```nix
# user/cdrokar/default.nix
{ config, pkgs, lib, userContext, ... }:

{
  imports =
    let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      ../shared/lib/home-manager.nix
      
      # Import ALL available apps for current platform
      (discovery.mkApplicationsModule {
        inherit lib;
        applications = [ "*" ];
      })
    ];

  user = {
    name = "cdrokar";
    email = "cdrokar@pm.me";
    fullName = "Charles Drokar";
  };
}
```

**Behavior**:

- On darwin: Imports all darwin + shared apps (aerospace, borders, git, zsh, ...)
- On nixos: Imports all nixos + shared apps (i3, polybar, git, zsh, ...)
- No errors, works seamlessly across platforms

______________________________________________________________________

### User Config: Specific Apps (Cross-Platform Safe)

```nix
# user/cdrokar/default.nix
{ config, pkgs, lib, userContext, ... }:

{
  imports =
    let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      ../shared/lib/home-manager.nix
      
      # Import specific apps - platform-specific ones are skipped gracefully
      (discovery.mkApplicationsModule {
        inherit lib;
        applications = [
          # Cross-platform apps (always imported)
          "git"
          "zsh"
          "helix"
          "starship"
          
          # Platform-specific apps (imported only when available)
          "aerospace"  # darwin only - skipped on nixos
          "borders"    # darwin only - skipped on nixos
          "i3"         # nixos only - skipped on darwin
        ];
      })
    ];

  user = {
    name = "cdrokar";
    email = "cdrokar@pm.me";
    fullName = "Charles Drokar";
  };
}
```

**Behavior**:

- On darwin: Imports git, zsh, helix, starship, aerospace, borders (skips i3)
- On nixos: Imports git, zsh, helix, starship, i3 (skips aerospace, borders)
- **No errors** - platform-specific apps are gracefully skipped when not available

______________________________________________________________________

### Profile: Platform-Specific Apps

```nix
# platform/darwin/profiles/home/default.nix
{ config, pkgs, lib, ... }:

let
  discovery = import ../../../shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    ../../settings/default.nix
    
    # Import darwin-specific apps (strict validation)
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [
        "aerospace"   # darwin window manager
        "borders"     # darwin window borders
        "git"         # shared app
        "zsh"         # shared app
      ];
    })
  ];
}
```

**Behavior**:

- On darwin: All apps imported successfully
- On nixos: **ERROR** - profiles are strict, missing apps cause build failure
- Profiles should only list apps available on their platform

______________________________________________________________________

### Explicit Platform Prefix (Advanced)

```nix
# Force specific platform version of an app
(discovery.mkApplicationsModule {
  inherit lib;
  applications = [
    "git"           # Auto-resolves: darwin/git if exists, else shared/git
    "shared/git"    # Force shared version
    "darwin/git"    # Force darwin version (errors on other platforms)
  ];
})
```

**When to use**:

- Disambiguate when same app exists in platform and shared
- Force specific version for testing
- Document platform dependency explicitly

______________________________________________________________________

## Common Scenarios

### Scenario 1: Adding a New Platform-Specific App

**Problem**: I want to add a macOS-only app to my user config without breaking Linux builds.

**Solution**:

```nix
# In your user config
applications = [
  "git"        # Works everywhere
  "zsh"        # Works everywhere
  "aerospace"  # macOS only - automatically skipped on other platforms
];
```

**What happens**:

1. Discovery system scans all platforms and finds aerospace in darwin
1. On darwin builds: aerospace is imported
1. On non-darwin builds: aerospace is skipped (no error)
1. Your config works across all platforms

______________________________________________________________________

### Scenario 2: App Name Typo

**Problem**: I typo'd an app name and got a cryptic error.

**Before** (old system):

```
error: File not found: /nix/store/.../platform/shared/app/aerospc.nix
```

**After** (new system):

```
error: Application 'aerospc' not found in any platform

Did you mean one of these?
  - aerospace (in darwin)
  - aerc (in shared)

All available apps:
  - Platform darwin: aerospace, borders
  - Platform shared: git, zsh, helix, bat, starship, aerc

Called from: user/cdrokar/default.nix
```

**Solution**: Fix typo based on helpful suggestions.

______________________________________________________________________

### Scenario 3: Listing All Available Apps

**Problem**: What apps can I use in my config?

**Solution 1**: Import all and explore

```nix
applications = [ "*" ];  # Imports everything available
```

**Solution 2**: Check the filesystem

```bash
# List shared apps (work on all platforms)
ls platform/shared/app/**/*.nix

# List darwin-specific apps
ls platform/darwin/app/**/*.nix

# List nixos-specific apps
ls platform/nixos/app/**/*.nix
```

**Solution 3**: Read the error message when you reference a non-existent app (it lists all available apps)

______________________________________________________________________

### Scenario 4: Adding a New Platform

**Problem**: I want to add support for nix-on-droid.

**Steps**:

1. Create directory structure:

   ```bash
   mkdir -p platform/nix-on-droid/{app,settings,lib,profiles/mobile}
   ```

1. Add platform lib (copy from darwin.nix as template):

   ```bash
   cp platform/darwin/lib/darwin.nix platform/nix-on-droid/lib/nix-on-droid.nix
   # Edit to customize for nix-on-droid
   ```

1. Add to flake.nix:

   ```nix
   nixOnDroidOutputs =
     if builtins.pathExists ./platform/nix-on-droid/lib/nix-on-droid.nix
     then (import ./platform/nix-on-droid/lib/nix-on-droid.nix {
       inherit inputs lib nixpkgs validUsers discoverProfiles;
     }).outputs
     else {};
   ```

1. Add apps to `platform/nix-on-droid/app/`

**That's it!** Discovery system automatically:

- Finds the new platform
- Scans its apps
- Includes them in validation
- Makes them available to configs

No changes needed to discovery.nix or user configs.

______________________________________________________________________

## Migration from Old System

### No Changes Required

The new system is **100% backward compatible**. Your existing configs work without modification:

```nix
# This still works exactly as before
(discovery.mkApplicationsModule {
  inherit lib;
  applications = [ "git" "zsh" "helix" ];
})
```

### Recommended Changes (Optional)

**Old pattern** (manual platform filtering):

```nix
{ config, pkgs, lib, userContext, ... }:

{
  imports = [
    ../../platform/shared/app/dev/git.nix
    ../../platform/shared/app/shell/zsh.nix
  ] ++ (lib.optionals pkgs.stdenv.isDarwin [
    ../../platform/darwin/app/aerospace.nix
    ../../platform/darwin/app/borders.nix
  ]);
}
```

**New pattern** (automatic filtering):

```nix
{ config, pkgs, lib, userContext, ... }:

let
  discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [
        "git"
        "zsh"
        "aerospace"  # Automatically filtered
        "borders"    # Automatically filtered
      ];
    })
  ];
}
```

**Benefits**:

- Cleaner, more declarative
- No manual `lib.optionals` or `pkgs.stdenv.isDarwin` checks
- Works for any platform, not just darwin/linux
- Better error messages

______________________________________________________________________

## Testing Your Changes

### Test 1: User Config on Multiple Platforms

```bash
# Test darwin build
just build cdrokar home-macmini-m4

# Test would-be nixos build (when available)
# just build cdrokar nixos-desktop

# Both should succeed
```

### Test 2: Verify App Resolution

```bash
# Check which apps are available
nix eval .#validUsers
nix eval .#validProfiles

# Test resolution (will show error if app doesn't exist)
nix eval --expr '
  let
    lib = (import <nixpkgs> {}).lib;
    discovery = import ./platform/shared/lib/discovery.nix { inherit lib; };
  in
    discovery.discoverApplications {
      callerPath = ./user/cdrokar/default.nix;
      basePath = ./.;
    }
'
```

### Test 3: Error Messages

```bash
# Intentionally typo an app name to see helpful error
# Edit user/cdrokar/default.nix, add "aerospc" to applications list

nix flake check
# Should show: "Did you mean: aerospace?"
```

______________________________________________________________________

## Troubleshooting

### Problem: App not found, but I know it exists

**Check 1**: Verify file exists

```bash
ls -la platform/darwin/app/aerospace.nix
ls -la platform/shared/app/dev/git.nix
```

**Check 2**: Verify it's in an app/ directory

```
✅ platform/darwin/app/aerospace.nix
❌ platform/darwin/aerospace.nix  (wrong location)
```

**Check 3**: Check for typos

```nix
"aerospace"  # ✅ correct
"aero-space" # ❌ typo
"Aerospace"  # ❌ case sensitive
```

______________________________________________________________________

### Problem: Platform not found

**Error**: `Platform 'kali' not found`

**Cause**: Directory doesn't exist or isn't structured correctly

**Fix**: Verify directory structure

```bash
ls -la platform/kali/        # Should exist
ls -la platform/kali/app/    # Should exist
```

______________________________________________________________________

### Problem: Builds work on darwin but fail on nixos

**Likely cause**: Profile includes darwin-only apps

**Fix**: Make profile platform-specific or remove platform-specific apps

```nix
# Option 1: Separate profiles per platform
# platform/darwin/profiles/home/default.nix - can use darwin apps
# platform/nixos/profiles/home/default.nix - can use nixos apps

# Option 2: Only use shared apps in profiles
applications = [
  "git"      # ✅ shared
  "zsh"      # ✅ shared
  # "aerospace"  # ❌ darwin only - remove or move to platform-specific profile
];
```

______________________________________________________________________

## Performance Notes

### Evaluation Time

- **Small configs** (< 10 apps): No noticeable difference
- **Medium configs** (10-30 apps): +50-100ms
- **Large configs** (30+ apps): +100-200ms

**Why**: Dynamic platform discovery requires scanning filesystem, but Nix caches results within evaluation.

**Optimization**: If evaluation time becomes an issue (>2s), the discovery system can be split into sub-modules with caching layer.

______________________________________________________________________

### Build Time

No impact - discovery happens at evaluation time, not build time.

______________________________________________________________________

## Advanced Usage

### Custom Search Paths (Future)

Not yet implemented, but could be added:

```nix
(discovery.mkApplicationsModule {
  inherit lib;
  applications = [ "git" ];
  searchPaths = [ ./custom/apps ./platform/shared/app ];  # Override search paths
})
```

### App Dependencies (Future)

Not yet implemented, but data model supports:

```nix
# In app module
{ ... }: {
  meta.dependencies = [ "git" "zsh" ];  # Auto-import dependencies
}
```

### App Metadata (Future)

Not yet implemented, but could provide introspection:

```nix
discovery.getAppInfo "git"
# → { name = "git"; platform = "shared"; path = /path/to/git.nix; }
```

______________________________________________________________________

## Summary

**Key takeaways**:

1. ✅ User configs can safely reference platform-specific apps (graceful skipping)
1. ✅ Better error messages with suggestions
1. ✅ No hardcoded platform names - supports any future platform
1. ✅ 100% backward compatible - no migration needed
1. ✅ Profiles remain strict (must list only available apps)

**Best practices**:

- User configs: Use `["*"]` or list all apps you want (cross-platform safe)
- Profiles: Only list apps available on that platform
- Use explicit prefixes (`darwin/app`) only when needed for disambiguation
- Check error messages - they're designed to be helpful

**Next steps**:

- Use the new system in your configs (optional, it's already active)
- Add new apps to any platform
- Add new platforms as needed
