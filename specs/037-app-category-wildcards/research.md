# Research: App Category Wildcards

**Feature**: 037-app-category-wildcards\
**Date**: 2026-01-03\
**Status**: Research Complete

## Overview

This document consolidates research findings for implementing wildcard pattern support in the user.applications array. The implementation extends the existing discovery system (`system/shared/lib/discovery.nix`) to expand patterns like `"productivity/*"` and `"*"` at Nix evaluation time.

## 1. Pattern Matching in Nix

### Decision

Use **`builtins.match`** with regex patterns to detect and parse wildcard strings.

### Rationale

- `builtins.match` is pure, deterministic, and available in all Nix versions
- Returns `null` for non-matches, or list of capture groups for matches
- Supports regex patterns for flexible matching

### Implementation Pattern

```nix
# Detect if string is a wildcard pattern
isWildcard = str:
  (builtins.match "(.+)/\\*" str) != null  # Matches "category/*"
  || str == "*";                           # Matches "*"

# Extract category name from "category/*" pattern
extractCategory = str: let
  match = builtins.match "(.+)/\\*" str;
in
  if match != null
  then builtins.head match  # Returns "category"
  else null;

# Examples:
# isWildcard "browser/*"     → true
# isWildcard "*"             → true
# isWildcard "git"           → false
# extractCategory "dev/*"     → "dev"
# extractCategory "*"         → null
```

### Alternatives Considered

- **`lib.hasInfix "/*"`**: Simpler but less precise (matches unintended strings like "foo/\*/bar")
- **`lib.hasSuffix "/*"`**: Works but doesn't extract category name
- **String splitting**: More complex, no advantage over regex

## 2. Directory Traversal

### Decision

Use **`builtins.readDir`** to list all .nix files in category directories, filtered by `lib.filterAttrs`.

### Rationale

- `builtins.readDir` is pure and deterministic (part of Nix's evaluation model)
- Returns attribute set: `{ "file.nix" = "regular"; "subdir" = "directory"; }`
- Already used extensively in existing discovery.nix
- No performance concerns for \<200 apps

### Implementation Pattern

```nix
# List all app names in a category directory
listAppsInCategory = categoryPath: let
  entries = builtins.readDir categoryPath;
  
  # Filter for .nix files (excluding default.nix)
  nixFiles = lib.filterAttrs (
    name: type:
      type == "regular"
      && lib.hasSuffix ".nix" name
      && name != "default.nix"
  ) entries;
  
  # Convert filenames to app names (remove .nix)
  appNames = map (name: lib.removeSuffix ".nix" name) (builtins.attrNames nixFiles);
  
  # Recursively search subdirectories
  subdirs = lib.filterAttrs (name: type: type == "directory") entries;
  subdirApps = lib.flatten (lib.mapAttrsToList (
    name: _: listAppsInCategory (categoryPath + "/${name}")
  ) subdirs);
in
  appNames ++ subdirApps;

# Handle missing directories gracefully
listAppsInCategorySafe = categoryPath:
  if builtins.pathExists categoryPath
  then listAppsInCategory categoryPath
  else [];
```

### Key Characteristics

- **Purity**: `builtins.readDir` always returns same result for same path
- **Determinism**: Directory order is deterministic (sorted alphabetically)
- **Performance**: O(n) where n = files in directory (acceptable for \<200 apps)
- **Error Handling**: Use `builtins.pathExists` to check before `readDir`

### Alternatives Considered

- **Manual file listing**: Not possible in pure Nix
- **Caching results**: Unnecessary complexity (evaluation is fast enough)

## 3. List Manipulation

### Decision

Use **`lib.unique`** for deduplication and **`lib.flatten`** for nested list flattening.

### Rationale

- Both functions are pure and well-tested in nixpkgs
- `lib.unique` preserves order (first occurrence kept)
- `lib.flatten` handles arbitrary nesting depth
- No need for custom implementations

### Implementation Pattern

```nix
# Deduplicate app list (removes duplicates, preserves order)
deduplicateApps = apps:
  lib.unique apps;

# Example:
# deduplicateApps ["git" "zsh" "git" "helix"]
# → ["git" "zsh" "helix"]

# Flatten nested lists from multiple wildcards
flattenAppLists = nestedLists:
  lib.flatten nestedLists;

# Example:
# flattenAppLists [["git" "zsh"] ["brave" "zen"] ["helix"]]
# → ["git" "zsh" "brave" "zen" "helix"]

# Combined pattern for wildcard expansion
resolveWildcards = patterns: searchPaths: let
  # Expand each pattern
  expanded = map (pattern:
    if isWildcard pattern
    then expandWildcard pattern searchPaths
    else [pattern]  # Explicit app name
  ) patterns;
  
  # Flatten and deduplicate
  flattened = lib.flatten expanded;
  deduplicated = lib.unique flattened;
in
  deduplicated;
```

### Performance Characteristics

- **`lib.unique`**: O(n²) naive implementation, but fast for \<200 items
- **`lib.flatten`**: O(n) where n = total elements
- **Combined**: Acceptable performance for typical use cases

### Alternatives Considered

- **Manual deduplication**: More complex, no performance gain
- **Set-based deduplication**: Not available in Nix stdlib

## 4. Hierarchical Discovery Integration

### Decision

**Expand wildcards BEFORE hierarchical resolution**, then pass expanded app names to existing `discoverWithHierarchy`.

### Rationale

- Separates concerns: wildcard expansion vs path resolution
- Reuses existing hierarchical search logic
- Maintains current deduplication behavior (first match wins)
- Simpler to test and reason about

### Integration Architecture

```text
User Config:
applications = ["browser/*", "git", "dev/*"];
                     ↓
           Wildcard Expansion
                     ↓
["brave", "zen", "firefox", "git", "uv", "spec-kit", ...]
                     ↓
    Hierarchical Resolution (existing)
                     ↓
[/path/to/brave.nix, /path/to/zen.nix, ...]
```

### Implementation Flow

```nix
resolveApplications = { apps, callerPath, basePath, system ? null, families ? [], ... }: let
  # STEP 1: Expand wildcards
  expandedApps = expandWildcards {
    patterns = apps;
    inherit system families basePath;
  };
  
  # STEP 2: Resolve each app using existing hierarchy search
  resolved = map (appName:
    if system != null
    then discoverWithHierarchy {
      itemName = appName;
      itemType = "app";
      inherit system families basePath;
    }
    else resolveApp appName searchPaths basePath
  ) expandedApps;
  
  # STEP 3: Filter nulls (apps not found)
  filtered = lib.filter (x: x != null) resolved;
in
  filtered;

# Wildcard expansion function
expandWildcards = { patterns, system ? null, families ? [], basePath }: let
  # Build hierarchical search paths
  searchPaths = buildWildcardSearchPaths { inherit system families basePath; };
  
  # Expand each pattern
  expanded = lib.flatten (map (pattern:
    if pattern == "*"
    then expandGlobalWildcard searchPaths
    else if isWildcard pattern
    then expandCategoryWildcard pattern searchPaths
    else [pattern]  # Keep explicit app names unchanged
  ) patterns);
in
  lib.unique expanded;  # Deduplicate

# Expand "category/*" wildcard
expandCategoryWildcard = pattern: searchPaths: let
  category = extractCategory pattern;
in
  lib.flatten (map (basePath:
    listAppsInCategorySafe (basePath + "/${category}")
  ) searchPaths);

# Expand "*" global wildcard
expandGlobalWildcard = searchPaths:
  lib.flatten (map (basePath:
    if builtins.pathExists basePath
    then discoverApplicationNames basePath
    else []
  ) searchPaths);

# Build search paths for wildcard expansion (respects hierarchy)
buildWildcardSearchPaths = { system ? null, families ? [], basePath }: let
  systemPath = basePath + "/system/${system}/app";
  familyPaths = map (f: basePath + "/system/shared/family/${f}/app") families;
  sharedPath = basePath + "/system/shared/app";
in
  # Priority order: system → families → shared
  (lib.optional (system != null && builtins.pathExists systemPath) systemPath)
  ++ familyPaths
  ++ [sharedPath];
```

### Deduplication Strategy

- **Wildcard expansion phase**: Deduplicate expanded app names (prevents duplicate discovery)
- **Hierarchical resolution phase**: First match wins (existing behavior)
- **Combined**: No duplicate app installations

### Error Handling

```nix
# Validate wildcard results
validateWildcardExpansion = pattern: expandedApps:
  if expandedApps == []
  then
    lib.warn ''
      Warning: Wildcard pattern '${pattern}' matched zero apps
      
      Possible causes:
      - Category directory doesn't exist
      - Category is empty
      - Typo in category name
      
      Available categories:
      ${listAvailableCategories basePath}
    '' []
  else expandedApps;

# List available categories for error messages
listAvailableCategories = basePath: let
  appPath = basePath + "/system/shared/app";
  entries = builtins.readDir appPath;
  dirs = lib.filterAttrs (n: t: t == "directory") entries;
in
  lib.concatStringsSep "\n" (map (cat: "  - ${cat}") (builtins.attrNames dirs));
```

### Alternatives Considered

- **Expand during resolution**: More complex, harder to test
- **Separate wildcard resolver**: Duplication of hierarchy logic
- **Post-resolution expansion**: Would require re-resolving, inefficient

## 5. Edge Cases and Validation

### Empty Category Handling

**Scenario**: `"nonexistent-category/*"` matches zero apps

**Decision**: Emit warning but continue (don't error)

**Rationale**: Allows optional categories, matches shell glob behavior

```nix
# Implementation
if expandedApps == []
then lib.warn "Wildcard '${pattern}' matched zero apps" []
else expandedApps
```

### Duplicate Apps

**Scenario**: User has `["browser/*", "brave"]` where brave is in browser/

**Decision**: Deduplicate using `lib.unique` (keeps first occurrence)

**Rationale**: Intuitive behavior, matches user expectation

### Multi-Level Wildcards

**Scenario**: User tries `"dev/lang/*"` (multi-level)

**Decision**: Not supported (error or treat as literal app name)

**Rationale**: Out of scope (spec explicitly excludes multi-level)

```nix
# Validation
if builtins.match ".*/.*/*" pattern != null
then throw "Multi-level wildcards not supported: ${pattern}"
else ...
```

### Platform-Specific Categories

**Scenario**: `"darwin-only/*"` on nixos

**Decision**: Silently return empty list (category doesn't exist on platform)

**Rationale**: Maintains cross-platform config portability

### Global Wildcard with Settings

**Scenario**: User puts `"*"` in settings array

**Decision**: Already handled by `validateNoWildcardInSettings`

**Rationale**: Settings require explicit selection (safety)

## 6. Performance Considerations

### Benchmark Expectations

- **Wildcard expansion**: \<50ms for 200 apps across 10 categories
- **Directory reads**: ~1ms per `builtins.readDir` call
- **Total overhead**: \<100ms added to evaluation time

### Optimization Strategies

1. **Lazy evaluation**: Nix only evaluates when needed
1. **Minimal readDir calls**: One per category per search path
1. **Efficient deduplication**: `lib.unique` is O(n²) but fast for \<200 items
1. **No caching needed**: Pure evaluation is deterministic and fast

### Scalability Limits

- **200 apps**: Well within performance budget
- **1000+ apps**: Would need benchmarking (unlikely scenario)

## 7. Testing Strategy

### Unit Tests

```nix
# Test cases in discovery-test.nix
testIsWildcard = {
  expr = isWildcard "browser/*";
  expected = true;
};

testExtractCategory = {
  expr = extractCategory "dev/*";
  expected = "dev";
};

testExpandCategoryWildcard = {
  expr = expandCategoryWildcard "browser/*" [./system/shared/app];
  expected = ["brave" "zen" "firefox"];  # Actual apps in repo
};

testDeduplication = {
  expr = resolveWildcards ["browser/*", "brave"] searchPaths;
  expected = ["brave" "zen" "firefox"];  # "brave" deduplicated
};
```

### Integration Tests

Create test user configs:

```nix
# user/test-wildcard/default.nix
{
  user = {
    name = "test-wildcard";
    applications = ["browser/*", "dev/*"];
  };
}
```

Run `nix flake check` and `just build test-wildcard <host>` to verify.

### Edge Case Tests

- Empty category: `["nonexistent/*"]`
- Global wildcard: `["*"]`
- Mixed patterns: `["browser/*", "git", "dev/*"]`
- Duplicates: `["browser/*", "brave"]`

## 8. Documentation Requirements

### CLAUDE.md Updates

Add wildcard syntax section:

```markdown
### Application Wildcards (Feature 037)

Install entire app categories using wildcard patterns:

\`\`\`nix
{
  user = {
    name = "username";
    applications = [
      "browser/*"      # All browsers (zen, brave, firefox, etc.)
      "dev/*"          # All dev tools (git, uv, spec-kit, etc.)
      "git"            # Plus specific app from another category
      # "*"            # Or ALL apps (use with caution)
    ];
  };
}
\`\`\`

**Wildcard Syntax**:
- `"category/*"` - All apps in category (e.g., "productivity/*")
- `"*"` - ALL available apps across ALL categories

**Behavior**:
- Wildcards expand at build time (new apps auto-included)
- Duplicate apps are automatically deduplicated
- Empty categories emit warnings but don't error
- Cross-platform: same syntax works on darwin and nixos
\`\`\`

### Migration Guide (quickstart.md)

Provide before/after examples for common patterns.

## Summary

### Recommended Approach

1. **Pattern Detection**: `builtins.match` with regex
2. **Directory Traversal**: `builtins.readDir` with `lib.filterAttrs`
3. **List Manipulation**: `lib.unique` and `lib.flatten`
4. **Integration Point**: Expand wildcards BEFORE hierarchical resolution
5. **Error Handling**: Warnings for empty categories, errors for invalid patterns
6. **Performance**: No optimizations needed (pure evaluation is fast enough)

### Implementation Checklist

- [ ] Add `isWildcard` and `extractCategory` helper functions
- [ ] Add `expandCategoryWildcard` and `expandGlobalWildcard` functions
- [ ] Add `expandWildcards` coordinator function
- [ ] Modify `resolveApplications` to call `expandWildcards` first
- [ ] Add validation for multi-level wildcards (error)
- [ ] Add warnings for empty category expansions
- [ ] Update CLAUDE.md with wildcard syntax documentation
- [ ] Create integration tests with test user configs
- [ ] Verify performance with `nix flake check`

### No Unresolved Questions

All technical decisions have been made. Implementation can proceed directly to Phase 1 (Design & Contracts).
```
