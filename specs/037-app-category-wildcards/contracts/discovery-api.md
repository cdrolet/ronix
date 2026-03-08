# API Contract: Discovery System Extensions

**Feature**: 037-app-category-wildcards\
**Date**: 2026-01-03\
**Module**: `system/shared/lib/discovery.nix`

## Overview

This contract defines the new and modified functions in the discovery system to support wildcard expansion. All functions maintain purity and determinism.

## New Functions

### `isWildcard`

**Purpose**: Detect if a string is a wildcard pattern

**Signature**:

```nix
isWildcard :: String → Bool
```

**Parameters**:

- `str` (String): Pattern to check

**Returns**: `true` if pattern is a wildcard, `false` otherwise

**Behavior**:

- Returns `true` for `"category/*"` patterns
- Returns `true` for `"*"` global wildcard
- Returns `false` for explicit app names

**Examples**:

```nix
isWildcard "browser/*"    # → true
isWildcard "*"            # → true
isWildcard "git"          # → false
isWildcard "dev/lang/*"   # → true (but will error on multi-level later)
```

**Error Conditions**: None (pure predicate function)

**Implementation**:

```nix
isWildcard = str:
  (builtins.match "(.+)/\\*" str) != null  # Matches "category/*"
  || str == "*";                           # Matches "*"
```

______________________________________________________________________

### `extractCategory`

**Purpose**: Extract category name from a wildcard pattern

**Signature**:

```nix
extractCategory :: String → String?
```

**Parameters**:

- `str` (String): Wildcard pattern

**Returns**: Category name or `null`

**Behavior**:

- For `"category/*"`: returns `"category"`
- For `"*"`: returns `null` (global wildcard has no category)
- For explicit app names: returns `null`

**Examples**:

```nix
extractCategory "browser/*"   # → "browser"
extractCategory "dev/*"       # → "dev"
extractCategory "*"           # → null
extractCategory "git"         # → null
```

**Error Conditions**: None

**Implementation**:

```nix
extractCategory = str: let
  match = builtins.match "(.+)/\\*" str;
in
  if match != null
  then builtins.head match
  else null;
```

______________________________________________________________________

### `expandWildcards`

**Purpose**: Expand wildcard patterns to list of app names

**Signature**:

```nix
expandWildcards :: {
  patterns :: [String],
  system :: String?,
  families :: [String],
  basePath :: Path
} → [String]
```

**Parameters**:

- `patterns` ([String]): List of app patterns (wildcards + explicit names)
- `system` (String?): Optional system name ("darwin", "nixos")
- `families` ([String]): Optional family names (["linux", "gnome"])
- `basePath` (Path): Repository root path

**Returns**: Deduplicated list of app names

**Behavior**:

1. Build hierarchical search paths from system/families
1. For each pattern:
   - If `"*"`: expand to all apps in all search paths
   - If `"category/*"`: expand to all apps in category across search paths
   - If explicit name: keep as-is
1. Flatten nested results
1. Deduplicate (preserves first occurrence)

**Examples**:

```nix
expandWildcards {
  patterns = ["browser/*", "git", "dev/*"];
  system = "darwin";
  families = [];
  basePath = ./.;
}
# → ["zen", "brave", "firefox", "git", "uv", "spec-kit", "helix"]

expandWildcards {
  patterns = ["*"];
  system = null;
  families = [];
  basePath = ./.;
}
# → All app names from system/shared/app/
```

**Error Conditions**:

- Multi-level wildcards: Throws error
- Invalid pattern syntax: Throws error

**Warnings**:

- Empty category: Emits warning but continues

**Implementation** (high-level):

```nix
expandWildcards = { patterns, system ? null, families ? [], basePath }: let
  searchPaths = buildWildcardSearchPaths { inherit system families basePath; };
  
  expanded = lib.flatten (map (pattern:
    if pattern == "*"
    then expandGlobalWildcard searchPaths
    else if isWildcard pattern
    then expandCategoryWildcard pattern searchPaths
    else [pattern]
  ) patterns);
in
  lib.unique expanded;
```

______________________________________________________________________

### `expandCategoryWildcard`

**Purpose**: Expand a single category wildcard to app names

**Signature**:

```nix
expandCategoryWildcard :: String → [Path] → [String]
```

**Parameters**:

- `pattern` (String): Category wildcard pattern (`"category/*"`)
- `searchPaths` ([Path]): Hierarchical search paths

**Returns**: List of app names found in category

**Behavior**:

1. Extract category name from pattern
1. For each search path, look for `{searchPath}/{category}/`
1. List all .nix files in category directory
1. Return flattened list of app names

**Examples**:

```nix
expandCategoryWildcard "browser/*" [
  ./system/darwin/app
  ./system/shared/app
]
# → ["zen", "brave", "firefox"] (from system/shared/app/browser/)

expandCategoryWildcard "nonexistent/*" [./system/shared/app]
# → [] (with warning)
```

**Error Conditions**:

- Multi-level pattern: Throws error

**Warnings**:

- Empty category: "Wildcard 'category/\*' matched zero apps"

**Implementation**:

```nix
expandCategoryWildcard = pattern: searchPaths: let
  category = extractCategory pattern;
  
  # Validate not multi-level
  _ = if builtins.match ".*/.*/*" pattern != null
      then throw "Multi-level wildcards not supported: ${pattern}"
      else true;
  
  # Search each path
  appsInPaths = lib.flatten (map (basePath:
    listAppsInCategorySafe (basePath + "/${category}")
  ) searchPaths);
  
  # Warn if empty
  _ = if appsInPaths == []
      then lib.warn "Wildcard '${pattern}' matched zero apps" true
      else true;
in
  appsInPaths;
```

______________________________________________________________________

### `expandGlobalWildcard`

**Purpose**: Expand global wildcard to all available apps

**Signature**:

```nix
expandGlobalWildcard :: [Path] → [String]
```

**Parameters**:

- `searchPaths` ([Path]): Hierarchical search paths

**Returns**: List of all app names across all search paths

**Behavior**:

1. For each search path, discover all app names
1. Flatten results
1. Return all apps (deduplication happens in caller)

**Examples**:

```nix
expandGlobalWildcard [
  ./system/darwin/app
  ./system/shared/app
]
# → All app names from both directories
```

**Error Conditions**: None

**Implementation**:

```nix
expandGlobalWildcard = searchPaths:
  lib.flatten (map (basePath:
    if builtins.pathExists basePath
    then discoverApplicationNames basePath
    else []
  ) searchPaths);
```

______________________________________________________________________

### `buildWildcardSearchPaths`

**Purpose**: Build hierarchical search paths for wildcard expansion

**Signature**:

```nix
buildWildcardSearchPaths :: {
  system :: String?,
  families :: [String],
  basePath :: Path
} → [Path]
```

**Parameters**:

- `system` (String?): Optional system name
- `families` ([String]): Optional family names
- `basePath` (Path): Repository root

**Returns**: Ordered list of search paths (highest priority first)

**Behavior**:

- Constructs paths in order: system → families → shared
- Filters out non-existent paths

**Examples**:

```nix
buildWildcardSearchPaths {
  system = "darwin";
  families = [];
  basePath = ./.;
}
# → [
#     ./system/darwin/app
#     ./system/shared/app
#   ]

buildWildcardSearchPaths {
  system = "nixos";
  families = ["linux", "gnome"];
  basePath = ./.;
}
# → [
#     ./system/nixos/app
#     ./system/shared/family/gnome/app
#     ./system/shared/family/linux/app
#     ./system/shared/app
#   ]
```

**Implementation**:

```nix
buildWildcardSearchPaths = { system ? null, families ? [], basePath }: let
  systemPath = basePath + "/system/${system}/app";
  familyPaths = map (f: basePath + "/system/shared/family/${f}/app") families;
  sharedPath = basePath + "/system/shared/app";
in
  (lib.optional (system != null && builtins.pathExists systemPath) systemPath)
  ++ familyPaths
  ++ [sharedPath];
```

______________________________________________________________________

### `listAppsInCategorySafe`

**Purpose**: List all app names in a category directory (with safety checks)

**Signature**:

```nix
listAppsInCategorySafe :: Path → [String]
```

**Parameters**:

- `categoryPath` (Path): Path to category directory

**Returns**: List of app names, empty list if directory doesn't exist

**Behavior**:

1. Check if path exists
1. If exists: list all .nix files (excluding default.nix)
1. Recursively search subdirectories
1. Return app names (filenames without .nix)

**Examples**:

```nix
listAppsInCategorySafe ./system/shared/app/browser
# → ["zen", "brave", "firefox"]

listAppsInCategorySafe ./nonexistent
# → []
```

**Implementation**:

```nix
listAppsInCategorySafe = categoryPath:
  if !builtins.pathExists categoryPath
  then []
  else listAppsInCategory categoryPath;

listAppsInCategory = dir: let
  entries = builtins.readDir dir;
  nixFiles = lib.filterAttrs (n: t:
    t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix"
  ) entries;
  appNames = map (n: lib.removeSuffix ".nix" n) (builtins.attrNames nixFiles);
  
  subdirs = lib.filterAttrs (n: t: t == "directory") entries;
  subdirApps = lib.flatten (lib.mapAttrsToList (name: _:
    listAppsInCategory (dir + "/${name}")
  ) subdirs);
in
  appNames ++ subdirApps;
```

______________________________________________________________________

## Modified Functions

### `resolveApplications`

**Modified**: Integrated wildcard expansion before hierarchical resolution

**Signature**: (Unchanged)

```nix
resolveApplications :: {
  apps :: [String],
  callerPath :: Path,
  basePath :: Path,
  system :: String?,
  families :: [String]
} → [Path]
```

**New Behavior**:

1. **Expand wildcards first** (new step)
1. Resolve each expanded app name (existing logic)
1. Filter nulls (existing logic)

**Code Changes**:

```nix
resolveApplications = { apps, callerPath, basePath, system ? null, families ? [], ... }: let
  # NEW: Expand wildcards
  expandedApps = expandWildcards {
    patterns = apps;
    inherit system families basePath;
  };
  
  # EXISTING: Detect context, build registry, resolve each app
  context = detectContext callerPath basePath;
  registry = buildAppRegistry basePath;
  
  resolved = builtins.map (appName:
    if system != null
    then discoverWithHierarchy { itemName = appName; itemType = "app"; inherit system families basePath; }
    else resolveApp appName searchPaths basePath
  ) expandedApps;  # Changed from `apps` to `expandedApps`
  
  filtered = lib.filter (x: x != null) resolved;
in
  filtered;
```

**Backward Compatibility**: ✅ Fully backward compatible

- Explicit app names pass through unchanged
- Existing configs without wildcards work identically

______________________________________________________________________

## Validation Functions

### `validateWildcardPattern`

**Purpose**: Validate wildcard pattern syntax

**Signature**:

```nix
validateWildcardPattern :: String → Bool (or throws)
```

**Validation Rules**:

1. Not empty
1. Not multi-level (`"*/*/*"`)
1. Valid category name (if category wildcard)

**Error Messages**:

```nix
# Empty pattern
"error: Empty wildcard pattern not allowed"

# Multi-level wildcard
"error: Multi-level wildcards not supported: 'dev/lang/*'
Wildcard patterns must be single-level: 'category/*' or '*'"

# Invalid characters
"error: Invalid characters in wildcard pattern: 'cat!gory/*'
Pattern must contain only alphanumeric, hyphens, and forward slash"
```

______________________________________________________________________

## Export Updates

**Added to discovery.nix exports**:

```nix
{
  # ... existing exports
  
  # NEW: Wildcard expansion functions
  inherit
    isWildcard
    extractCategory
    expandWildcards
    expandCategoryWildcard
    expandGlobalWildcard
    buildWildcardSearchPaths
    listAppsInCategorySafe
    ;
  
  # MODIFIED: resolveApplications (now handles wildcards)
  inherit resolveApplications;
}
```

______________________________________________________________________

## Testing Contract

### Unit Test Cases

```nix
# Test isWildcard
assert isWildcard "browser/*" == true;
assert isWildcard "*" == true;
assert isWildcard "git" == false;

# Test extractCategory
assert extractCategory "dev/*" == "dev";
assert extractCategory "*" == null;

# Test expandWildcards
let result = expandWildcards {
  patterns = ["browser/*", "git"];
  system = null;
  families = [];
  basePath = ./.;
};
in assert lib.elem "git" result && lib.elem "zen" result;

# Test deduplication
let result = expandWildcards {
  patterns = ["browser/*", "zen"];  # "zen" is in browser/
  system = null;
  families = [];
  basePath = ./.;
};
in assert (lib.count (x: x == "zen") result) == 1;  # Only one "zen"
```

### Integration Test Cases

1. **Basic wildcard**: User with `["browser/*"]` gets all browsers
1. **Global wildcard**: User with `["*"]` gets all apps
1. **Mixed patterns**: User with `["browser/*", "git", "dev/*"]` gets combined list
1. **Deduplication**: User with `["browser/*", "zen"]` doesn't get duplicate zen
1. **Empty category**: User with `["nonexistent/*"]` gets warning but continues

______________________________________________________________________

## Performance Contract

**Guarantees**:

- Wildcard expansion completes in \<100ms for 200 apps
- Pure evaluation (no side effects)
- Deterministic results (same input → same output)
- Memory efficient (uses lazy evaluation)

**Complexity**:

- `expandWildcards`: O(n\*m) where n=patterns, m=apps per category
- `listAppsInCategory`: O(n) where n=files in directory
- `lib.unique`: O(n²) but fast for \<200 items

______________________________________________________________________

## Summary

**New Functions**: 7 (isWildcard, extractCategory, expandWildcards, expandCategoryWildcard, expandGlobalWildcard, buildWildcardSearchPaths, listAppsInCategorySafe)

**Modified Functions**: 1 (resolveApplications)

**Breaking Changes**: None (fully backward compatible)

**Testing Requirements**: Unit tests for new functions, integration tests for user configs
