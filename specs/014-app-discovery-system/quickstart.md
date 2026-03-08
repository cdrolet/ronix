# Quickstart: App Discovery System

**For**: Developers implementing or using the app discovery system\
**Time**: 5 minutes

______________________________________________________________________

## TL;DR

**Problem**: Manual app imports are fragile and cumbersome\
**Solution**: Specify apps by name, system auto-discovers paths\
**Benefit**: No more broken paths, easier maintenance

______________________________________________________________________

## Quick Example

### Before (Manual Imports)

```nix
# user/cdrokar/default.nix
imports = [
  ../../system/shared/app/dev/git.nix
  ../../system/shared/app/shell/zsh.nix
  ../../system/darwin/app/aerospace.nix
];
```

### After (Auto-Discovery)

```nix
# user/cdrokar/default.nix
imports = [ ../shared/lib/applications.nix ];

applications = [
  "git"
  "zsh"
  "aerospace"
];
```

______________________________________________________________________

## How to Use

### Step 1: Import the module

```nix
{ config, lib, ... }:
{
  imports = [
    ../shared/lib/applications.nix  # For user configs
    # OR
    ../../shared/lib/applications.nix  # For profiles
  ];
}
```

### Step 2: List your apps

```nix
{
  applications = [
    # Shared apps
    "git"
    "zsh"
    "starship"
    "helix"
    
    # Platform-specific apps (auto-detected)
    "aerospace"  # Found in darwin/app/ when on Darwin
    "borders"    # Found in darwin/app/ when on Darwin
  ];
}
```

### Step 3: Build!

```bash
nix build .#darwinConfigurations.user-profile.system
# Apps automatically discovered and imported ✓
```

______________________________________________________________________

## Common Patterns

### Simple Names (Recommended)

```nix
applications = [
  "git"      # Finds system/shared/app/dev/git.nix
  "zsh"      # Finds system/shared/app/shell/zsh.nix
  "helix"    # Finds system/shared/app/editor/helix.nix
];
```

### Disambiguation with Paths

```nix
applications = [
  "darwin/aerospace"   # Specifically from darwin/app/
  "shared/app/dev/git" # Specifically from shared/app/dev/
];
```

### Mixed Approach

```nix
applications = [
  "git"                # Auto-discover
  "darwin/aerospace"   # Disambiguate
];
```

______________________________________________________________________

## Key Concepts

### Search Priority

**From User Config**:

1. `system/shared/app/` first (cross-platform)
1. `system/darwin/app/` second (platform-specific)

**From Darwin Profile**:

1. `system/darwin/app/` first (platform-specific)
1. `system/shared/app/` second (cross-platform)

**Rule**: Closer = Higher Priority

### Error Messages

When app not found, you get helpful errors:

```
error: Application 'aerospacee' not found

Searched locations:
  - system/darwin/app/aerospacee.nix (not found)
  - system/shared/app/**/aerospacee.nix (not found)

Did you mean:
  - aerospace (system/darwin/app/aerospace.nix)
```

______________________________________________________________________

## Migration Guide

### Convert Existing Config

**Before**:

```nix
{
  imports = [
    ../shared/lib/home-manager.nix
    ../../system/shared/app/dev/git.nix
    ../../system/shared/app/shell/zsh.nix
    ../../system/shared/app/shell/starship.nix
    ../../system/shared/app/editor/helix.nix
    ../../system/darwin/app/aerospace.nix
    ../../system/darwin/app/borders.nix
  ];
}
```

**After**:

```nix
{
  imports = [
    ../shared/lib/home-manager.nix
    ../shared/lib/applications.nix  # New!
  ];
  
  applications = [  # New!
    "git"
    "zsh"
    "starship"
    "helix"
    "aerospace"
    "borders"
  ];
}
```

### Incremental Migration

You can use both approaches simultaneously:

```nix
{
  imports = [
    ../shared/lib/applications.nix
    # Keep some manual imports during transition
    ../../system/shared/app/experimental/new-tool.nix
  ];
  
  applications = [
    "git"
    "zsh"
    # ... other auto-discovered apps
  ];
}
```

______________________________________________________________________

## Troubleshooting

### App Not Found

**Error**: `Application 'myapp' not found`

**Solutions**:

1. Check spelling: `"myapp"` vs `"my-app"`
1. Check if app exists: `ls system/shared/app/**/myapp.nix`
1. Use full path: `"system/shared/app/dev/myapp"`
1. Check error suggestions (fuzzy matches shown)

### Ambiguous Match

**Error**: Multiple apps with same name

**Solution**: Use partial path for disambiguation:

```nix
applications = [
  "darwin/aerospace"  # Not shared/aerospace
];
```

### Build Time Slow

**Issue**: Discovery adds build time

**Solutions**:

1. Check number of apps (100+ may be slow)
1. Use partial paths to skip recursive search
1. Report performance issue (caching may help)

______________________________________________________________________

## Best Practices

### ✅ Do

- Use simple names when possible: `"git"` not `"system/shared/app/dev/git"`
- Group related apps in lists for readability
- Comment unusual or platform-specific apps
- Use partial paths only for disambiguation

### ❌ Don't

- Don't use absolute paths: `/nix/store/...`
- Don't include `.nix` extension (optional, but unnecessary)
- Don't use wildcards (not supported yet)
- Don't worry about duplicates (system handles it)

______________________________________________________________________

## Examples

### Minimal User Config

```nix
# user/minimal/default.nix
{ config, lib, ... }:
{
  imports = [
    ../shared/lib/home-manager.nix
    ../shared/lib/applications.nix
  ];
  
  applications = [ "git" "zsh" "helix" ];
  
  user.name = "minimal";
  user.email = "user@example.com";
}
```

### Full Developer Config

```nix
# user/developer/default.nix
{ config, lib, ... }:
{
  imports = [
    ../shared/lib/home-manager.nix
    ../shared/lib/applications.nix
  ];
  
  applications = [
    # Development
    "git"
    "sdkman"
    
    # Shell
    "zsh"
    "starship"
    "bat"
    "atuin"
    "ghostty"
    
    # Editor
    "helix"
    
    # Window Management (Darwin)
    "aerospace"
    "borders"
  ];
  
  user.name = "developer";
  user.email = "dev@example.com";
  user.fullName = "Developer Name";
}
```

### Darwin Profile with Platform Apps

```nix
# system/darwin/profiles/workstation/default.nix
{ config, lib, ... }:
{
  imports = [
    ../../../shared/lib/host.nix
    ../../../shared/lib/applications.nix
    ../../settings/default.nix
  ];
  
  host = {
    name = "workstation";
    display = "Workstation";
    platform = "aarch64-darwin";
  };
  
  # Platform-specific apps for this profile
  applications = [
    "aerospace"
    "borders"
  ];
}
```

______________________________________________________________________

## Next Steps

1. **Read the spec**: [spec.md](./spec.md) for complete details
1. **Check data model**: [data-model.md](./data-model.md) for structures
1. **Review plan**: [plan.md](./plan.md) for implementation phases
1. **Try it out**: Migrate one user config as proof of concept

______________________________________________________________________

## FAQ

**Q: Can I still use manual imports?**\
A: Yes! 100% backward compatible. Both work together.

**Q: What if the app moves to a different folder?**\
A: No problem! Discovery finds it automatically. No config changes needed.

**Q: Does this work with NixOS?**\
A: Yes! Same pattern, same API. Works everywhere.

**Q: What about performance?**\
A: Discovery is fast (uses native Nix functions). No noticeable impact.

**Q: Can I mix both approaches?**\
A: Yes! Use applications list for most apps, manual imports for special cases.

**Q: What if two apps have the same name?**\
A: Use partial path to disambiguate: `"darwin/myapp"` vs `"shared/myapp"`

______________________________________________________________________

## Support

- **Spec Issues**: Check [spec.md](./spec.md) for detailed behavior
- **Implementation**: See [plan.md](./plan.md) for technical details
- **Bugs**: Report with error message and config snippet
