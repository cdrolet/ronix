# Data Model: Platform-Agnostic Discovery System

**Feature**: 017-platform-agnostic-discovery\
**Date**: 2025-11-15\
**Status**: Phase 1 - Design

## Overview

This document defines the data structures, types, and relationships for the platform-agnostic discovery system.

______________________________________________________________________

## Core Types

### Platform

**Definition**: A platform represents a specific operating system or environment that can run Nix configurations.

```nix
# Type: Platform
# Representation: String (platform name)
# Examples: "darwin", "nixos", "nix-on-droid", "kali"
# Special: "shared" is NOT a platform (it's cross-platform)
Platform :: String

# Constraints:
# - Must match directory name in platform/
# - Cannot be "shared"
# - Must be a valid filesystem name (no slashes, no special chars)
```

**Validation**:

```nix
isValidPlatform = name: 
  name != "shared" && 
  builtins.match "^[a-zA-Z0-9_-]+$" name != null;
```

**Discovery**:

```nix
# Discovered from filesystem: platform/{platform}/
discoverPlatforms :: Path → [Platform]
```

______________________________________________________________________

### AppName

**Definition**: An application name, optionally prefixed with platform or "shared".

```nix
# Type: AppName
# Representation: String
# Formats:
#   - Simple: "git"
#   - Prefixed: "shared/git"
#   - Platform-specific: "darwin/aerospace"
#   - Path-like: "dev/git"
AppName :: String

# Components (after parsing):
# - prefix: Platform | "shared" | null
# - name: String (actual app name)
```

**Parsing**:

```nix
parseAppName :: AppName → { prefix :: Platform | "shared" | null, name :: String }
parseAppName = appName: let
  parts = lib.splitString "/" appName;
  hasPrefix = builtins.length parts > 1;
in {
  prefix = if hasPrefix then builtins.head parts else null;
  name = if hasPrefix then lib.concatStringsSep "/" (builtins.tail parts) else appName;
};
```

**Examples**:

- `"git"` → `{ prefix = null; name = "git"; }`
- `"shared/git"` → `{ prefix = "shared"; name = "git"; }`
- `"darwin/aerospace"` → `{ prefix = "darwin"; name = "aerospace"; }`
- `"dev/git"` → `{ prefix = "dev"; name = "git"; }` (path-like, resolved via search)

______________________________________________________________________

### AppPath

**Definition**: Absolute filesystem path to an application module.

```nix
# Type: AppPath
# Representation: Path
# Formats:
#   - File: /path/to/platform/darwin/app/aerospace.nix
#   - Directory: /path/to/platform/shared/app/dev/git/default.nix
AppPath :: Path

# Constraints:
# - Must be absolute path
# - Must exist on filesystem
# - Must end in .nix or /default.nix
# - Must be within platform/{platform|shared}/app/ tree
```

**Validation**:

```nix
isValidAppPath = path:
  builtins.pathExists path &&
  (lib.hasSuffix ".nix" (toString path) ||
   lib.hasSuffix "/default.nix" (toString path));
```

______________________________________________________________________

### Context

**Definition**: Information about where discovery was called from, used to determine search paths.

```nix
# Type: Context
Context :: {
  callerPath :: Path           # Absolute path of calling module
  callerType :: CallerType     # Type of caller
  platform :: Platform | null  # Detected platform (null if not platform-specific)
  basePath :: Path             # Repository root path
}

# Type: CallerType
CallerType :: String
# Values:
#   - "{platform}-profile" (e.g., "darwin-profile", "nixos-profile")
#   - "user-config"
#   - "unknown"
```

**Detection**:

```nix
detectContext :: Path → Path → Context
# Extracts platform from caller path:
#   /path/to/platform/darwin/profiles/home → "darwin"
#   /path/to/user/cdrokar/default.nix → null
```

**Examples**:

```nix
# Darwin profile
{
  callerPath = /repo/platform/darwin/profiles/home/default.nix;
  callerType = "darwin-profile";
  platform = "darwin";
  basePath = /repo;
}

# User config
{
  callerPath = /repo/user/cdrokar/default.nix;
  callerType = "user-config";
  platform = null;  # User configs are platform-agnostic
  basePath = /repo;
}
```

______________________________________________________________________

### SearchPath

**Definition**: Ordered list of directories to search for applications.

```nix
# Type: SearchPath
SearchPath :: [Path]

# Priority order (higher priority first):
#   1. Current platform app directory (if known)
#   2. Shared app directory
```

**Construction**:

```nix
buildSearchPaths :: Context → Path → SearchPath
# Examples:
#   darwin-profile → [/repo/platform/darwin/app, /repo/platform/shared/app]
#   user-config → [/repo/platform/shared/app]
#   nixos-profile → [/repo/platform/nixos/app, /repo/platform/shared/app]
```

______________________________________________________________________

### AppResolution

**Definition**: Result of resolving an application name to a path.

```nix
# Type: AppResolution
AppResolution :: {
  name :: AppName               # Original app name requested
  path :: AppPath | null        # Resolved path (null if not found)
  platform :: Platform | "shared" | null  # Where app was found
  error :: String | null        # Error message if resolution failed
}
```

**States**:

1. **Success**: `{ name; path = /some/path.nix; platform = "darwin"; error = null; }`
1. **Not found in context**: `{ name; path = null; platform = null; error = "not in current platform"; }`
1. **Not found anywhere**: `{ name; path = null; platform = null; error = "does not exist"; }`

______________________________________________________________________

### AppRegistry

**Definition**: Complete map of all available applications across all platforms.

```nix
# Type: AppRegistry
AppRegistry :: {
  platforms :: [Platform]                    # All discovered platforms
  apps :: {
    "${platform}" :: [AppName]               # Apps per platform
    shared :: [AppName]                      # Cross-platform apps
  }
  index :: {
    "${appName}" :: [Platform | "shared"]    # Which platforms have this app
  }
}
```

**Construction**:

```nix
buildAppRegistry :: Path → AppRegistry
# Scans entire platform/ tree and builds index
```

**Example**:

```nix
{
  platforms = [ "darwin" "nixos" ];
  apps = {
    darwin = [ "aerospace" "borders" ];
    nixos = [ "i3" "polybar" ];
    shared = [ "git" "zsh" "helix" ];
  };
  index = {
    aerospace = [ "darwin" ];
    borders = [ "darwin" ];
    i3 = [ "nixos" ];
    polybar = [ "nixos" ];
    git = [ "shared" ];
    zsh = [ "shared" ];
    helix = [ "shared" ];
  };
}
```

**Usage**: Fast validation and helpful error messages

______________________________________________________________________

## Data Flows

### Flow 1: Application Resolution (User Config)

```
Input: [AppName] (e.g., ["git", "aerospace", "zsh"])
Context: user-config (platform = null)

1. detectContext(callerPath, basePath)
   → Context { platform = null, callerType = "user-config" }

2. buildSearchPaths(context, basePath)
   → [/repo/platform/shared/app]

3. buildAppRegistry(basePath)
   → AppRegistry { all platforms and apps }

4. For each appName:
   a. resolveApp(appName, searchPaths)
      → AppPath | null
   b. If null: validateAppExists(appName, registry)
      → Error if not exists anywhere
      → Warning if exists in other platform
   c. If found: return AppPath

5. Filter results: keep only found paths (graceful degradation)

Output: [AppPath] (e.g., [/repo/platform/shared/app/dev/git.nix, /repo/platform/shared/app/shell/zsh.nix])
```

**Key behavior**:

- `aerospace` not found in shared → check registry → exists in darwin → skip (not error)
- User gets `git` and `zsh`, `aerospace` is silently skipped

______________________________________________________________________

### Flow 2: Application Resolution (Platform Profile)

```
Input: [AppName] (e.g., ["git", "aerospace"])
Context: darwin-profile (platform = "darwin")

1. detectContext(callerPath, basePath)
   → Context { platform = "darwin", callerType = "darwin-profile" }

2. buildSearchPaths(context, basePath)
   → [/repo/platform/darwin/app, /repo/platform/shared/app]

3. For each appName:
   a. resolveApp(appName, searchPaths)
      → Try darwin/app first, then shared/app
   b. If not found: error (strict for profiles)

Output: [AppPath] (e.g., [/repo/platform/shared/app/dev/git.nix, /repo/platform/darwin/app/aerospace.nix])
```

**Key behavior**:

- `git` found in shared (darwin doesn't override)
- `aerospace` found in darwin
- If app not found: error (profiles should be complete)

______________________________________________________________________

### Flow 3: Platform Discovery

```
Input: basePath (e.g., /repo)

1. Read platform/ directory
   → { darwin = "directory"; nixos = "directory"; shared = "directory"; }

2. Filter directories (exclude "shared")
   → { darwin = "directory"; nixos = "directory"; }

3. Extract keys
   → ["darwin", "nixos"]

Output: [Platform]
```

**Usage**: Building app registry, validating platform references

______________________________________________________________________

## Validation Rules

### Rule 1: App Existence

**Constraint**: All requested apps must exist in at least one platform or shared.

```nix
validateAppExists :: AppName → AppRegistry → Bool
validateAppExists = appName: registry:
  builtins.hasAttr appName registry.index;
```

**Error if violated**:

```
error: Application 'aerospc' not found in any platform

Did you mean: aerospace, aerc?
```

______________________________________________________________________

### Rule 2: Platform Existence

**Constraint**: Explicit platform prefixes must refer to existing platforms.

```nix
validatePlatformExists :: Platform → AppRegistry → Bool
validatePlatformExists = platform: registry:
  lib.elem platform registry.platforms || platform == "shared";
```

**Error if violated**:

```
error: Platform 'kali' not found

Available platforms: darwin, nixos, shared
```

______________________________________________________________________

### Rule 3: Path Resolution

**Constraint**: Resolved paths must exist on filesystem.

```nix
validateResolution :: AppResolution → Bool
validateResolution = res:
  res.path == null || builtins.pathExists res.path;
```

**Error if violated**:

```
error: Internal error - resolved path does not exist: /repo/platform/darwin/app/missing.nix
```

______________________________________________________________________

## State Transitions

### App Resolution State Machine

```
               ┌─────────────┐
               │  Requested  │ (AppName)
               └──────┬──────┘
                      │
        ┌─────────────┴─────────────┐
        │  detectContext            │
        └─────────────┬─────────────┘
                      │
        ┌─────────────▼─────────────┐
        │  Search in SearchPaths    │
        └─────────────┬─────────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
    ┌─────▼─────┐          ┌─────▼─────┐
    │   Found   │          │ Not Found │
    └─────┬─────┘          └─────┬─────┘
          │                      │
    ┌─────▼─────┐      ┌─────────▼─────────┐
    │ Resolved  │      │ Check Registry    │
    └───────────┘      └─────────┬─────────┘
                                 │
                   ┌─────────────┴─────────────┐
                   │                           │
            ┌──────▼──────┐           ┌────────▼────────┐
            │ Exists in   │           │ Does not exist  │
            │ Other       │           │ anywhere        │
            │ Platform    │           └────────┬────────┘
            └──────┬──────┘                    │
                   │                           │
            ┌──────▼──────┐           ┌────────▼────────┐
            │ Skip (user) │           │  Error          │
            │ Error (prof)│           │                 │
            └─────────────┘           └─────────────────┘
```

**States**:

1. **Requested**: Initial state with AppName
1. **Searching**: Looking in SearchPaths
1. **Found**: Path resolved successfully
1. **Not Found**: Not in current search paths
1. **Exists Elsewhere**: Found in registry but different platform
1. **Does Not Exist**: Not in registry at all
1. **Resolved**: Final success state with AppPath
1. **Skipped**: Gracefully degraded (user config only)
1. **Error**: Terminal error state

______________________________________________________________________

## Relationships

```
┌──────────────┐
│  Repository  │
└───────┬──────┘
        │ contains
        │
        ├──────┐
        │      │
┌───────▼──┐  ┌▼─────────┐
│ Platform │  │  Shared  │
└───────┬──┘  └┬─────────┘
        │      │
        │ has  │ has
        │      │
     ┌──▼──────▼──┐
     │    Apps    │
     └──────┬─────┘
            │
            │ referenced by
            │
     ┌──────▼─────┐
     │   Users    │
     └──────┬─────┘
            │
            │ via
            │
     ┌──────▼─────┐
     │  Context   │
     └──────┬─────┘
            │
            │ uses
            │
     ┌──────▼─────┐
     │SearchPaths │
     └──────┬─────┘
            │
            │ to find
            │
     ┌──────▼─────┐
     │  AppPath   │
     └────────────┘
```

______________________________________________________________________

## Indexing Strategy

### Primary Index: AppRegistry.index

**Purpose**: Fast lookup of which platforms have which apps

**Structure**:

```nix
{
  "${appName}" = [Platform | "shared"];
}
```

**Usage**:

1. Validate app exists: `builtins.hasAttr appName index`
1. Find alternatives: `index.${similarName}`
1. Check platform availability: `lib.elem "darwin" index.${appName}`

**Maintenance**: Built once during evaluation, cached implicitly by Nix

______________________________________________________________________

### Secondary Index: AppRegistry.apps

**Purpose**: List all apps per platform (for error messages)

**Structure**:

```nix
{
  "${platform}" = [AppName];
  shared = [AppName];
}
```

**Usage**:

1. Show available apps: "Available in darwin: ${concatStringsSep ", " apps.darwin}"
1. Platform completeness check: `length apps.${platform} > 0`

______________________________________________________________________

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| `discoverPlatforms` | O(n) | n = entries in platform/ |
| `buildAppRegistry` | O(p * a) | p = platforms, a = avg apps per platform |
| `resolveApp` | O(s * d) | s = search paths, d = avg directory depth |
| `validateAppExists` | O(1) | Hash lookup in index |

**Total for typical config** (3 platforms, 50 apps, 10 user apps):

- Registry build: O(3 * 50) = O(150) - one-time cost
- Resolution: O(10 * 2 * 3) = O(60) - per user config
- **Estimated time**: \<100ms on modern hardware

### Space Complexity

| Structure | Size | Notes |
|-----------|------|-------|
| Platform list | O(p) | p = platforms (~5) |
| AppRegistry.apps | O(p * a) | p = platforms, a = apps per platform (~150) |
| AppRegistry.index | O(a_total) | a_total = total unique apps (~50) |

**Total for typical config**: ~5 KB in memory

- Negligible compared to Nix evaluation overhead
- No optimization needed

______________________________________________________________________

## Future Extensions

### Caching Layer (if needed)

```nix
# Memoize expensive operations
cachedBuildAppRegistry = lib.memoize buildAppRegistry;
```

**When to implement**: If evaluation time exceeds 2 seconds

### Multi-level Search Paths

```nix
# Support profile-specific app overrides
SearchPath :: {
  priority :: Int
  path :: Path
}[]
```

**When to implement**: If profiles need app customization

### App Metadata

```nix
AppInfo :: {
  name :: String
  path :: Path
  platform :: Platform | "shared"
  description :: String | null
  dependencies :: [AppName]
}
```

**When to implement**: If dependency resolution needed

______________________________________________________________________

## Summary

This data model provides:

1. **Clear types** for all entities (Platform, AppName, AppPath, Context, etc.)
1. **Validation rules** ensuring correctness
1. **Efficient indexing** for fast lookups
1. **State transitions** documenting resolution flow
1. **Performance characteristics** showing scalability

The design supports the platform-agnostic principle while maintaining type safety and performance.
