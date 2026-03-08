# Quickstart Guide: App Category Wildcards

**Feature**: 037-app-category-wildcards\
**Date**: 2026-01-03\
**Audience**: nix-config users

## What's New

You can now install entire categories of applications using wildcard patterns in your `user.applications` array instead of listing each app individually.

**Before** (explicit listing):

```nix
applications = [
  "zen"
  "brave"
  "firefox"
  # ... 20 more browsers
];
```

**After** (category wildcard):

```nix
applications = [
  "browser/*"  # Installs all browsers automatically
];
```

## Quick Examples

### Install All Apps in a Category

```nix
{
  user = {
    name = "myuser";
    applications = [
      "browser/*"      # All browsers (zen, brave, firefox, etc.)
      "productivity/*" # All productivity apps (obsidian, bitwarden, etc.)
      "dev/*"          # All development tools (git, uv, helix, etc.)
    ];
  };
}
```

### Mix Wildcards and Explicit Apps

```nix
applications = [
  "browser/*"  # All browsers
  "git"        # Plus git from dev category
  "obsidian"   # Plus obsidian from productivity
];
```

### Install Everything

```nix
applications = ["*"];  # Install ALL available apps (use with caution!)
```

## Wildcard Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `"category/*"` | All apps in category | `"browser/*"` → zen, brave, firefox |
| `"*"` | All apps everywhere | `"*"` → every app in the repo |
| `"app-name"` | Specific app (unchanged) | `"git"` → just git |

**Note**: Only single-level wildcards are supported. Multi-level like `"dev/lang/*"` will error.

## Migration Guide

### Scenario 1: Many Apps from Same Category

**Before**:

```nix
applications = [
  "zen"
  "brave"
  "firefox"
  "safari"
];
```

**After**:

```nix
applications = ["browser/*"];
```

**Benefit**: Auto-includes new browsers added to the repo later.

______________________________________________________________________

### Scenario 2: Mostly One Category, Plus a Few Others

**Before**:

```nix
applications = [
  # Development tools
  "git"
  "uv"
  "spec-kit"
  "helix"
  "zed"
  "cursor"
  # ... 10 more dev tools
  
  # Other
  "zen"
  "obsidian"
];
```

**After**:

```nix
applications = [
  "dev/*"      # All dev tools
  "zen"        # Specific browser
  "obsidian"   # Specific productivity app
];
```

______________________________________________________________________

### Scenario 3: Power User (All Apps)

**Before**:

```nix
applications = [
  # ... 50+ explicit app names
];
```

**After**:

```nix
applications = ["*"];
```

**Warning**: This installs EVERYTHING. Make sure you want all apps!

______________________________________________________________________

### Scenario 4: Cross-Platform User

**Before** (manual platform checks):

```nix
applications = 
  if isDarwin then [
    "zen" "brave" "mail" # darwin-specific
  ] else [
    "zen" "brave" "geary"  # nixos-specific
  ];
```

**After** (platform-agnostic wildcards):

```nix
applications = [
  "browser/*"      # Gets platform-appropriate browsers
  "productivity/*" # Gets mail on darwin, geary on nixos
];
```

**Benefit**: Same config works on both platforms - wildcards discover platform-specific apps automatically.

## Available Categories

Run this command to see all categories:

```bash
ls -1 system/shared/app/
```

Common categories:

- `browser/` - Web browsers (zen, brave, firefox)
- `dev/` - Development tools (git, uv, spec-kit, helix)
- `productivity/` - Productivity apps (obsidian, bitwarden, libreoffice)
- `communication/` - Chat apps (discord, slack, telegram, element)
- `design/` - Design tools (inkscape, blender, gimp, figma)
- `games/` - Games and chess apps (arena, lichess)
- `media/` - Media apps (qobuz, qbittorrent)
- `security/` - Security tools (bitwarden, proton-vpn)
- `containers/` - Container tools (docker, podman, colima)
- `utility/` - Utilities (caligula)

Platform-specific categories (use wildcards for cross-platform):

- `system/darwin/app/...` - macOS-only apps
- `system/nixos/app/...` - NixOS-only apps
- `system/shared/family/gnome/app/...` - GNOME-specific apps

## How It Works

### Wildcard Expansion Flow

```text
1. You write:
   applications = ["browser/*", "git"];

2. At build time, wildcard expands:
   "browser/*" → ["zen", "brave", "firefox"]
   
3. Combined with explicit apps:
   ["zen", "brave", "firefox", "git"]
   
4. Each app resolved to path:
   [
     ./system/shared/app/browser/zen.nix
     ./system/shared/app/browser/brave.nix
     ./system/shared/app/browser/firefox.nix
     ./system/shared/app/dev/git.nix
   ]
   
5. Home Manager imports all modules
```

### Hierarchical Search

Wildcards respect the platform hierarchy:

**Darwin** (no families):

```text
"browser/*" searches:
  1. system/darwin/app/browser/     (platform-specific)
  2. system/shared/app/browser/     (shared)
```

**NixOS with GNOME** (family = ["linux", "gnome"]):

```text
"browser/*" searches:
  1. system/nixos/app/browser/              (platform-specific)
  2. system/shared/family/gnome/app/browser/ (family-specific)
  3. system/shared/family/linux/app/browser/ (family-specific)
  4. system/shared/app/browser/             (shared)
```

**First match wins** - no duplicates across levels.

## Deduplication

If you specify the same app multiple ways, it's automatically deduplicated:

```nix
applications = [
  "browser/*"  # Includes "zen"
  "zen"        # Explicit zen
];

# Result: zen installed once (first occurrence kept)
```

## Error Handling

### Empty Category

```nix
applications = ["nonexistent/*"];
```

**Output**:

```
warning: Wildcard 'nonexistent/*' matched zero apps

Possible causes:
- Category directory doesn't exist
- Category is empty
- Typo in category name

Available categories:
  - browser
  - dev
  - productivity
  ...
```

**Behavior**: Continues without error (graceful degradation).

______________________________________________________________________

### Multi-Level Wildcard

```nix
applications = ["dev/lang/*"];  # Not supported
```

**Output**:

```
error: Multi-level wildcards not supported: 'dev/lang/*'

Wildcard patterns must be single-level:
  - Supported: "dev/*"
  - Not supported: "dev/lang/*"

Tip: Use "dev/*" to get all dev tools, or list specific apps
```

**Behavior**: Build fails immediately (prevents unexpected results).

______________________________________________________________________

### Typo in Category Name

```nix
applications = ["brwoser/*"];  # Typo: "brwoser" instead of "browser"
```

**Output**:

```
warning: Wildcard 'brwoser/*' matched zero apps

Did you mean: browser?

Available categories:
  - browser
  - dev
  - productivity
```

**Behavior**: Continues without installing apps from typo'd category.

## Best Practices

### 1. Use Wildcards for Categories You Want Complete

✅ **Good**:

```nix
applications = [
  "browser/*"  # I want all browsers
  "dev/*"      # I want all dev tools
];
```

❌ **Avoid**:

```nix
applications = [
  "browser/*"  # I only use zen
];
```

**Better**:

```nix
applications = ["zen"];
```

______________________________________________________________________

### 2. Mix Wildcards and Explicit Apps

✅ **Good**:

```nix
applications = [
  "dev/*"      # All dev tools
  "zen"        # Plus my favorite browser
  "obsidian"   # Plus note-taking app
];
```

______________________________________________________________________

### 3. Avoid Global Wildcard Unless You Mean It

⚠️ **Caution**:

```nix
applications = ["*"];  # Installs EVERYTHING (50+ apps!)
```

**When to use**:

- You're setting up a demo/test environment
- You genuinely want every available app
- You're experimenting with the repo

**When NOT to use**:

- Production user configs
- Systems with limited resources
- When you only need a subset of apps

______________________________________________________________________

### 4. Check What's Included

Before committing wildcard configs, check what apps will be installed:

```bash
# List apps in a category
ls -1 system/shared/app/browser/
# → zen.nix
# → brave.nix
# → firefox.nix

# List all apps
find system/shared/app -name "*.nix" -not -name "default.nix" | wc -l
# → 53 apps
```

______________________________________________________________________

### 5. Use Platform-Agnostic Wildcards for Multi-Platform Configs

If you use the same config on darwin and nixos:

✅ **Good**:

```nix
applications = [
  "browser/*"      # Gets appropriate browsers per platform
  "productivity/*" # Gets mail on darwin, geary on nixos
];
```

❌ **Avoid**:

```nix
applications =
  if isDarwin then ["mail"] else ["geary"];
```

## Troubleshooting

### Q: Why didn't my new app get installed?

**A**: Check that the app file exists in the category:

```bash
ls -1 system/shared/app/browser/
```

If it's not there, the wildcard won't include it. Add the app file first.

______________________________________________________________________

### Q: I have duplicate apps installed

**A**: This shouldn't happen - wildcards automatically deduplicate. If you see duplicates:

1. Check if app is listed explicitly AND via wildcard
1. Run `nix flake check` to verify config
1. File a bug if deduplication isn't working

______________________________________________________________________

### Q: Wildcard matched zero apps but the category exists

**A**: The category directory might be empty or only contain `default.nix`:

```bash
ls -1 system/shared/app/mycategory/
# → default.nix  (only default.nix - no apps)
```

Add actual app .nix files to the category.

______________________________________________________________________

### Q: Can I exclude specific apps from a wildcard?

**A**: Not yet. Exclusion patterns (`"browser/* !brave"`) are out of scope for this feature.

**Workaround**: Don't use wildcard for that category, list apps explicitly:

```nix
applications = [
  "zen"
  "firefox"
  # Intentionally excluding brave
];
```

______________________________________________________________________

### Q: How do I see what apps will be installed?

**A**: Run a dry-run build:

```bash
just build <user> <host>
# Check the output for imported app modules
```

Or inspect the evaluated config:

```bash
nix eval .#darwinConfigurations.<user>-<host>.config.home-manager.users.<user>.home.packages --json | jq 'length'
```

## Next Steps

1. **Update your user config** to use wildcards for categories you want complete
1. **Run** `just build <user> <host>` to verify
1. **Check** that expected apps are included
1. **Apply** with `just install <user> <host>`

## Examples by User Type

### Minimal User (Only Essentials)

```nix
applications = [
  "git"
  "zsh"
  "zen"
  "obsidian"
];
# No wildcards - explicit minimal set
```

______________________________________________________________________

### Developer

```nix
applications = [
  "dev/*"          # All dev tools
  "browser/*"      # All browsers (for testing)
  "containers/*"   # Docker, Podman, etc.
  "obsidian"       # Notes
];
```

______________________________________________________________________

### Power User

```nix
applications = [
  "dev/*"
  "browser/*"
  "productivity/*"
  "communication/*"
  "design/*"
  "games/*"
];
# Most categories via wildcard
```

______________________________________________________________________

### Ultimate Power User

```nix
applications = ["*"];
# Everything!
```

## Reference

- **Spec**: [spec.md](./spec.md)
- **Implementation Plan**: [plan.md](./plan.md)
- **Research**: [research.md](./research.md)
- **Data Model**: [data-model.md](./data-model.md)
- **API Contracts**: [contracts/discovery-api.md](./contracts/discovery-api.md)
