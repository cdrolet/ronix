# Discovery API Contract

**Feature**: 017-platform-agnostic-discovery\
**Date**: 2025-11-15\
**Status**: Phase 1 - Design

## Overview

This document defines the complete API contract for the platform-agnostic discovery system. All functions are pure Nix functions operating at evaluation time.

______________________________________________________________________

## Public API

These functions are exported and intended for use by user configs, profiles, and flake.nix.

### mkApplicationsModule

**Purpose**: Create a module that imports applications by name (convenience wrapper)

**Signature**:

```nix
mkApplicationsModule :: {
  lib :: Lib
  applications :: [AppName] | ["*"]
  user :: String (optional)
  platform :: Platform (optional)
  profile :: String (optional)
} → Module
```

**Parameters**:

- `lib` (required): nixpkgs lib for Nix functions
- `applications` (required): List of app names to import, or `["*"]` for all apps
- `user` (optional): User name (for context, not currently used)
- `platform` (optional): Platform override (auto-detected if not provided)
- `profile` (optional): Profile name (for context, not currently used)

**Returns**: Nix module with `imports` set to resolved app paths

**Behavior**:

- Auto-detects context from caller path
- Resolves all app names to paths
- **User configs**: Skip apps not available in current platform (graceful)
- **Profiles**: Error on missing apps (strict)
- Validates all apps exist somewhere in repository

**Example Usage**:

```nix
# User config: import all available apps
{ userContext, lib, ... }: {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "*" ];
    })
  ];
}

# User config: import specific apps (cross-platform safe)
{ userContext, lib, ... }: {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "git" "zsh" "aerospace" ];  # aerospace skipped on non-darwin
    })
  ];
}

# Profile: import specific apps (strict)
{ lib, ... }: {
  imports = [
    (discovery.mkApplicationsModule {
      inherit lib;
      applications = [ "git" "zsh" ];
    })
  ];
}
```

**Error Conditions**:

- App doesn't exist anywhere: Throw error with suggestions
- Explicit platform prefix to non-existent platform: Throw error
- Profile missing required app: Throw error

______________________________________________________________________

### discoverUsers

**Purpose**: Discover all users in the repository

**Signature**:

```nix
discoverUsers :: → [String]
```

**Parameters**: None (uses relative path from discovery.nix location)

**Returns**: List of user names (directory names in user/ with default.nix)

**Behavior**:

- Scans `user/` directory
- Filters for directories containing `default.nix`
- Excludes `shared` directory
- Returns sorted list of names

**Example Usage**:

```nix
# In flake.nix
let
  discovery = import ./platform/shared/lib/discovery.nix { inherit lib; };
  validUsers = discovery.discoverUsers;
in {
  # validUsers = ["cdrokar" "cdrolet" "cdrixus"]
}
```

**Error Conditions**: None (returns empty list if no users found)

______________________________________________________________________

### discoverProfiles

**Purpose**: Discover all profiles for a specific platform

**Signature**:

```nix
discoverProfiles :: Platform → [String]
```

**Parameters**:

- `platform` (required): Platform name (e.g., "darwin", "nixos")

**Returns**: List of profile names (directory names in platform/{platform}/profiles/ with default.nix)

**Behavior**:

- Scans `platform/{platform}/profiles/` directory
- Filters for directories containing `default.nix`
- Returns sorted list of names

**Example Usage**:

```nix
# In flake.nix
let
  discovery = import ./platform/shared/lib/discovery.nix { inherit lib; };
  darwinProfiles = discovery.discoverProfiles "darwin";
in {
  # darwinProfiles = ["home" "work"]
}
```

**Error Conditions**:

- Platform directory doesn't exist: Returns empty list
- No profiles directory: Returns empty list

______________________________________________________________________

## Internal API

These functions are used internally by the discovery system but not directly exposed to users.

### discoverPlatforms

**Purpose**: Discover all platforms in the repository

**Signature**:

```nix
discoverPlatforms :: Path → [Platform]
```

**Parameters**:

- `basePath` (required): Repository root path

**Returns**: List of platform names (directory names in platform/ excluding "shared")

**Behavior**:

- Scans `platform/` directory
- Filters for directories (excludes "shared")
- Returns sorted list of platform names

**Example**:

```nix
Input: /repo
Output: ["darwin" "nixos"]
```

______________________________________________________________________

### buildAppRegistry

**Purpose**: Build complete index of all apps across all platforms

**Signature**:

```nix
buildAppRegistry :: Path → AppRegistry
```

**Parameters**:

- `basePath` (required): Repository root path

**Returns**:

```nix
{
  platforms :: [Platform]
  apps :: {
    "${platform}" :: [AppName]
    shared :: [AppName]
  }
  index :: {
    "${appName}" :: [Platform | "shared"]
  }
}
```

**Behavior**:

- Discovers all platforms
- Scans each platform's app/ directory
- Scans shared/app/ directory
- Builds index mapping app names to platforms

**Example**:

```nix
Input: /repo
Output: {
  platforms = ["darwin" "nixos"];
  apps = {
    darwin = ["aerospace" "borders"];
    nixos = ["i3" "polybar"];
    shared = ["git" "zsh"];
  };
  index = {
    aerospace = ["darwin"];
    borders = ["darwin"];
    i3 = ["nixos"];
    polybar = ["nixos"];
    git = ["shared"];
    zsh = ["shared"];
  };
}
```

______________________________________________________________________

### detectContext

**Purpose**: Detect caller context (platform, type) from caller path

**Signature**:

```nix
detectContext :: Path → Path → Context
```

**Parameters**:

- `callerPath` (required): Path of calling module
- `basePath` (required): Repository root path

**Returns**:

```nix
{
  callerPath :: Path
  callerType :: CallerType  # "{platform}-profile" | "user-config" | "unknown"
  platform :: Platform | null
  basePath :: Path
}
```

**Behavior**:

- Converts paths to strings for pattern matching
- Extracts platform from path pattern `/platform/{platform}/`
- Determines caller type from path patterns
- Returns context object

**Example**:

```nix
Input: (/repo/platform/darwin/profiles/home/default.nix, /repo)
Output: {
  callerPath = /repo/platform/darwin/profiles/home/default.nix;
  callerType = "darwin-profile";
  platform = "darwin";
  basePath = /repo;
}

Input: (/repo/user/cdrokar/default.nix, /repo)
Output: {
  callerPath = /repo/user/cdrokar/default.nix;
  callerType = "user-config";
  platform = null;
  basePath = /repo;
}
```

______________________________________________________________________

### buildSearchPaths

**Purpose**: Build prioritized search paths based on context

**Signature**:

```nix
buildSearchPaths :: Context → Path → [Path]
```

**Parameters**:

- `context` (required): Context from detectContext
- `basePath` (required): Repository root path

**Returns**: Ordered list of paths to search (highest priority first)

**Behavior**:

- Platform-specific context: [platform/app, shared/app]
- User config context: [shared/app] (platform-agnostic)
- Unknown context: [shared/app] (fallback)
- Only includes paths that exist on filesystem

**Example**:

```nix
Input: (Context { platform = "darwin" }, /repo)
Output: [/repo/platform/darwin/app, /repo/platform/shared/app]

Input: (Context { platform = null }, /repo)
Output: [/repo/platform/shared/app]
```

______________________________________________________________________

### resolveApp

**Purpose**: Resolve single app name to absolute path

**Signature**:

```nix
resolveApp :: AppName → [Path] → Path → AppPath | null
```

**Parameters**:

- `appName` (required): App name to resolve (simple or prefixed)
- `searchPaths` (required): Ordered list of paths to search
- `basePath` (required): Repository root path

**Returns**: Absolute path to app module, or null if not found

**Behavior**:

- Parses app name (extract prefix if present)
- If prefixed: search only in specified location
- If simple: search in order through searchPaths
- Tries both `{name}.nix` and `{name}/default.nix`
- Returns first match found, or null

**Example**:

```nix
Input: ("git", [/repo/platform/darwin/app, /repo/platform/shared/app], /repo)
Output: /repo/platform/shared/app/dev/git.nix

Input: ("aerospace", [/repo/platform/shared/app], /repo)
Output: null

Input: ("darwin/aerospace", [/repo/platform/shared/app], /repo)
Output: /repo/platform/darwin/app/aerospace.nix (absolute path, ignores search paths)
```

______________________________________________________________________

### resolveApplications

**Purpose**: Resolve list of app names to paths

**Signature**:

```nix
resolveApplications :: {
  apps :: [AppName]
  callerPath :: Path
  basePath :: Path
} → [AppPath]
```

**Parameters**:

- `apps` (required): List of app names to resolve
- `callerPath` (required): Path of calling module
- `basePath` (required): Repository root path

**Returns**: List of resolved app paths (may be shorter than input if graceful degradation)

**Behavior**:

1. Detect context from caller path
1. Build search paths from context
1. Build app registry for validation
1. For each app name:
   a. Resolve to path
   b. If null: check registry
   c. If in registry but different platform:
   - User config: skip (graceful)
   - Profile: error (strict)
     d. If not in registry: error
1. Return all resolved paths

**Example**:

```nix
Input: {
  apps = ["git" "aerospace" "zsh"];
  callerPath = /repo/user/cdrokar/default.nix;
  basePath = /repo;
}
Output: [
  /repo/platform/shared/app/dev/git.nix
  /repo/platform/shared/app/shell/zsh.nix
]
# Note: aerospace skipped (darwin-only, user config is platform-agnostic)
```

______________________________________________________________________

### findAppInPath

**Purpose**: Find app in specific directory path (recursive search)

**Signature**:

```nix
findAppInPath :: AppName → Path → AppPath | null
```

**Parameters**:

- `appName` (required): Simple app name (no prefix)
- `searchPath` (required): Directory to search

**Returns**: Absolute path to app module, or null if not found

**Behavior**:

- Recursively searches directory tree
- Tries `{appName}.nix` in current dir
- Tries `{appName}/default.nix` in current dir
- Recursively searches subdirectories
- Returns first match found (depth-first search)

**Example**:

```nix
Input: ("git", /repo/platform/shared/app)
Output: /repo/platform/shared/app/dev/git.nix

Input: ("aerospace", /repo/platform/shared/app)
Output: null
```

______________________________________________________________________

### discoverApplicationNames

**Purpose**: Discover all app names in a directory tree

**Signature**:

```nix
discoverApplicationNames :: Path → [AppName]
```

**Parameters**:

- `basePath` (required): Directory to scan (e.g., platform/darwin/app)

**Returns**: List of app names (file names without .nix, no paths)

**Behavior**:

- Uses discoverModules to get all .nix files
- Converts file paths to app names (strips directories and .nix)
- Returns unique sorted list

**Example**:

```nix
Input: /repo/platform/darwin/app
Files: [aerospace.nix, borders.nix]
Output: ["aerospace" "borders"]

Input: /repo/platform/shared/app
Files: [dev/git.nix, shell/zsh.nix, shell/starship.nix]
Output: ["git" "starship" "zsh"]
```

______________________________________________________________________

### discoverModules

**Purpose**: Recursively discover all .nix files in directory tree

**Signature**:

```nix
discoverModules :: Path → [String]
```

**Parameters**:

- `basePath` (required): Directory to scan

**Returns**: List of relative file paths (e.g., ["dock.nix", "dev/git.nix"])

**Behavior**:

- Scans directory recursively
- Includes all .nix files except default.nix
- Returns paths relative to basePath

**Example**:

```nix
Input: /repo/platform/darwin/app
Files:
  - aerospace.nix
  - borders.nix
Output: ["aerospace.nix" "borders.nix"]

Input: /repo/platform/shared/app
Files:
  - dev/git.nix
  - editor/helix.nix
  - shell/zsh.nix
  - shell/starship.nix
Output: ["dev/git.nix" "editor/helix.nix" "shell/starship.nix" "shell/zsh.nix"]
```

______________________________________________________________________

### discoverApplications

**Purpose**: Discover all applications available for caller context

**Signature**:

```nix
discoverApplications :: {
  callerPath :: Path
  basePath :: Path
} → [AppName]
```

**Parameters**:

- `callerPath` (required): Path of calling module
- `basePath` (required): Repository root path

**Returns**: List of all app names available in caller's context

**Behavior**:

- Detects context
- Builds search paths
- Discovers apps from all search paths
- Returns unique sorted list

**Example**:

```nix
Input: {
  callerPath = /repo/user/cdrokar/default.nix;
  basePath = /repo;
}
Output: ["git" "zsh" "helix" "starship" "bat"]  # shared apps only

Input: {
  callerPath = /repo/platform/darwin/profiles/home/default.nix;
  basePath = /repo;
}
Output: ["aerospace" "borders" "git" "zsh" "helix" "starship" "bat"]  # darwin + shared
```

______________________________________________________________________

## Error Handling

### Error Types

#### 1. App Not Found (Does Not Exist Anywhere)

**Trigger**: Requested app doesn't exist in any platform or shared

**Message Format**:

```
error: Application 'aerospc' not found in any platform

Did you mean one of these?
  - aerospace (in darwin)
  - aerc (in shared)

All available apps:
  - Platform darwin: aerospace, borders
  - Platform shared: git, zsh, helix, bat, starship

Called from: user/cdrokar/default.nix
```

**Recovery**: User must fix app name or remove from list

______________________________________________________________________

#### 2. App Not Available in Current Platform

**Trigger**: App exists but not in current platform's search paths

**Behavior**:

- **User config**: Skip app (graceful degradation), no error
- **Profile**: Throw error (strict validation)

**Message Format** (profile only):

```
error: Application 'aerospace' not found in platform 'nixos'

Available in other platforms:
  - darwin: platform/darwin/app/aerospace.nix

Searched in current context:
  - platform/nixos/app/**/aerospace.nix
  - platform/shared/app/**/aerospace.nix

Called from: platform/nixos/profiles/server/default.nix

Tip: This app is platform-specific. Remove it from this profile's application list.
```

**Recovery**:

- User config: Automatic (app skipped)
- Profile: Remove app or make profile platform-specific

______________________________________________________________________

#### 3. Platform Not Found

**Trigger**: Explicit platform prefix references non-existent platform

**Message Format**:

```
error: Platform 'kali' not found in application reference 'kali/tool'

Available platforms:
  - darwin
  - nixos
  - shared

Called from: user/cdrokar/default.nix

Tip: Check platform directory exists: platform/kali/
```

**Recovery**: User must fix platform name or remove platform prefix

______________________________________________________________________

#### 4. Invalid App Name

**Trigger**: App name contains invalid characters or patterns

**Message Format**:

```
error: Invalid application name '../../../etc/passwd'

App names must:
  - Contain only alphanumeric, dash, underscore, slash
  - Not start with .. or /
  - Be relative paths only

Called from: user/cdrokar/default.nix
```

**Recovery**: User must provide valid app name

______________________________________________________________________

## Validation Rules

### Input Validation

All public API functions validate inputs:

1. **App names**: No path traversal (`..`), no absolute paths, valid characters only
1. **Platforms**: Must be valid directory names, no special characters
1. **Paths**: Must be absolute when required, must exist when specified

### Output Validation

All internal functions validate outputs:

1. **Resolved paths**: Must exist on filesystem before returning
1. **Lists**: Must not contain duplicates (use `lib.unique`)
1. **Registry**: Must be internally consistent (all indexed apps exist in apps.\*)

______________________________________________________________________

## Performance Guarantees

### Evaluation Time

| Operation | Max Time | Notes |
|-----------|----------|-------|
| `discoverUsers` | \<10ms | Small directory scan |
| `discoverProfiles` | \<10ms | Small directory scan |
| `buildAppRegistry` | \<100ms | Scans all platforms |
| `resolveApp` | \<20ms | Recursive search in 2-3 dirs |
| `mkApplicationsModule` | \<200ms | Full resolution for ~10 apps |

**Total for typical user config**: \<250ms

### Caching

Nix automatically caches:

- `builtins.readDir` results (within single evaluation)
- Function results (pure functions, memoized implicitly)

No explicit caching needed.

______________________________________________________________________

## Backward Compatibility

### Breaking Changes

None - this is an internal refactor. Public API remains unchanged:

```nix
# Still works
mkApplicationsModule { inherit lib; applications = ["git"]; }

# Still works
discoverUsers

# Still works
discoverProfiles "darwin"
```

### Migration Guide

No migration needed - existing code continues to work without changes.

______________________________________________________________________

## Testing Contract

### Unit Test Cases

1. **discoverPlatforms**:

   - Empty platform/ directory → []
   - Only shared/ → []
   - darwin/, nixos/, shared/ → ["darwin", "nixos"]

1. **detectContext**:

   - Darwin profile path → { platform = "darwin"; callerType = "darwin-profile" }
   - User config path → { platform = null; callerType = "user-config" }
   - Unknown path → { platform = null; callerType = "unknown" }

1. **resolveApp**:

   - Simple name in shared → shared path
   - Simple name in platform → platform path
   - Prefixed name → forced path
   - Not found → null

1. **mkApplicationsModule**:

   - ["\*"] → imports all available apps
   - ["git"] → imports git
   - ["nonexistent"] → error with suggestions
   - ["aerospace"] in user config on nixos → empty imports (graceful)

### Integration Test Cases

1. **User config with mixed platform apps**:

   - Build on darwin → all apps resolved
   - Build on nixos → platform-specific apps skipped
   - No errors in either case

1. **Profile with platform-specific apps**:

   - Build on correct platform → all apps resolved
   - Build on wrong platform → error (profiles are strict)

1. **Performance**:

   - 50-app config evaluates in \<1 second
   - Registry build happens once per evaluation

______________________________________________________________________

## Summary

This API contract defines:

1. **Public API**: 3 functions for external use (mkApplicationsModule, discoverUsers, discoverProfiles)
1. **Internal API**: 10 functions for implementation details
1. **Error handling**: 4 error types with helpful messages
1. **Validation**: Input/output validation rules
1. **Performance**: Evaluation time guarantees
1. **Testing**: Unit and integration test cases

The API is platform-agnostic, efficient, and provides excellent developer experience through helpful error messages.
