# Research: Platform-Agnostic Discovery System

**Feature**: 017-platform-agnostic-discovery\
**Date**: 2025-11-15\
**Status**: Phase 0 - Research Complete

## Overview

This document captures research findings for redesigning the discovery system to be truly platform-agnostic by scanning the complete repository tree and filtering by context instead of hardcoding platform names.

## Research Questions

### 1. How to scan repository tree without hardcoding platform names?

**Decision**: Use `builtins.readDir` recursively starting from repository root, filtering for `platform/*` directories dynamically.

**Rationale**:

- `builtins.readDir` returns attrset of directory entries: `{ name = "directory" | "regular" | ... }`
- Can discover all platforms by scanning `platform/` directory
- No need to hardcode "darwin", "nixos", etc.
- Works for any future platform additions (nix-on-droid, kali, etc.)

**Implementation approach**:

```nix
discoverPlatforms = basePath: let
  platformDir = basePath + "/platform";
  entries = builtins.readDir platformDir;
  # Filter for directories, exclude "shared"
  platforms = lib.filterAttrs (name: type: 
    type == "directory" && name != "shared"
  ) entries;
in
  builtins.attrNames platforms;
```

**Alternatives considered**:

- **Pattern matching on paths**: Rejected - still requires knowing platform names
- **Config file listing platforms**: Rejected - adds maintenance burden, redundant with filesystem

**Nix builtins reference**:

- `builtins.readDir :: Path → AttrSet String String`
- `builtins.pathExists :: Path → Bool`
- Available at evaluation time, no IFD needed

______________________________________________________________________

### 2. How to validate apps exist in tree even when not in current platform?

**Decision**: Two-phase validation - (1) collect all apps across all platforms, (2) filter by current platform, (3) validate requested apps exist in phase 1.

**Rationale**:

- Prevents errors when user config references darwin-specific app but builds on nixos
- Allows users to maintain single config across multiple platforms
- Provides helpful error if app truly doesn't exist anywhere

**Implementation approach**:

```nix
# Phase 1: Discover all apps across all platforms
discoverAllApps = basePath: let
  platforms = discoverPlatforms basePath;
  sharedApps = discoverApplicationNames (basePath + "/platform/shared/app");
  platformApps = lib.flatten (map (platform:
    discoverApplicationNames (basePath + "/platform/${platform}/app")
  ) platforms);
in
  lib.unique (sharedApps ++ platformApps);

# Phase 2: Filter by current platform
filterByPlatform = { allApps, currentPlatform, basePath }: apps:
  lib.filter (app:
    # Check if app exists in shared or current platform
    appExistsIn (basePath + "/platform/shared/app") app ||
    appExistsIn (basePath + "/platform/${currentPlatform}/app") app
  ) apps;

# Phase 3: Validate existence
validateApps = { allApps, requestedApps }:
  let
    missing = lib.filter (app: !(lib.elem app allApps)) requestedApps;
  in
    if missing != [] then
      throw "Apps not found in any platform: ${lib.concatStringsSep ", " missing}"
    else
      requestedApps;
```

**Alternatives considered**:

- **Error on platform mismatch**: Rejected - locks users to single platform
- **Silent filtering**: Rejected - harder to debug missing apps
- **Warn but don't error**: Rejected - Nix has no warning mechanism at eval time

**Edge cases**:

- App exists in platform A, user on platform B: silently skip (graceful degradation)
- App doesn't exist anywhere: throw error with helpful message
- App name typo: caught by validation in phase 3

______________________________________________________________________

### 3. How to detect caller context without hardcoding platform names?

**Decision**: Extract platform name from caller path using dynamic pattern matching.

**Rationale**:

- Caller path contains platform name: `/path/to/platform/darwin/profiles/...`
- Can extract platform dynamically using string operations
- No need to hardcode darwin/nixos checks

**Implementation approach**:

```nix
detectContext = callerPath: basePath: let
  callerStr = toString callerPath;
  baseStr = toString basePath;
  relPath = lib.removePrefix baseStr callerStr;
  
  # Extract platform from path like "/platform/darwin/profiles/..."
  platformMatch = builtins.match ".*/platform/([^/]+)/.*" relPath;
  platform = if platformMatch != null then builtins.head platformMatch else null;
  
  # Determine caller type
  isProfile = lib.hasInfix "/profiles/" relPath;
  isUserConfig = lib.hasInfix "/user/" relPath;
in {
  callerPath = callerPath;
  platform = platform;
  callerType = 
    if isProfile && platform != null then "${platform}-profile"
    else if isUserConfig then "user-config"
    else "unknown";
  basePath = basePath;
};
```

**Nix string functions used**:

- `builtins.match :: String → String → [String] | null` - regex matching with capture groups
- `lib.removePrefix :: String → String → String`
- `lib.hasInfix :: String → String → Bool`

**Alternatives considered**:

- **Hardcoded checks** (current): Rejected - violates platform-agnostic principle
- **Passing platform as parameter**: Rejected - caller may not know their platform
- **Environment variables**: Rejected - not available at eval time, impure

**Test cases**:

- `/platform/darwin/profiles/home/default.nix` → `{ platform = "darwin"; callerType = "darwin-profile"; }`
- `/platform/nixos/profiles/server/default.nix` → `{ platform = "nixos"; callerType = "nixos-profile"; }`
- `/user/cdrokar/default.nix` → `{ platform = null; callerType = "user-config"; }`
- `/platform/shared/app/git.nix` → `{ platform = null; callerType = "unknown"; }`

______________________________________________________________________

### 4. How to build search paths without knowing platform names in advance?

**Decision**: Use detected platform from context, fall back to "shared" for unknown contexts.

**Rationale**:

- Platform already detected dynamically in `detectContext`
- Search paths = current platform + shared (in priority order)
- Works for any platform, not just darwin/nixos

**Implementation approach**:

```nix
buildSearchPaths = context: basePath:
  let
    sharedPath = basePath + "/platform/shared/app";
    platformPath = 
      if context.platform != null
      then basePath + "/platform/${context.platform}/app"
      else null;
  in
    # Platform-specific first (if exists), then shared
    (lib.optional (platformPath != null && builtins.pathExists platformPath) platformPath)
    ++ [ sharedPath ];
```

**Search priority**:

1. Current platform apps (e.g., `platform/darwin/app`)
1. Shared apps (e.g., `platform/shared/app`)

**Why not search all platforms?**:

- Performance: avoid scanning directories not needed
- Correctness: platform-specific apps may conflict (e.g., aerospace on darwin vs i3 on linux)
- Clear semantics: current platform + shared = available apps

**Alternatives considered**:

- **Search all platforms**: Rejected - performance cost, potential conflicts
- **User-specified search paths**: Rejected - complexity, violates convention
- **Profile-level overrides**: Deferred - can add later if needed

______________________________________________________________________

### 5. How to handle app name ambiguity (same name in multiple platforms)?

**Decision**: Priority-based resolution - current platform wins over shared.

**Rationale**:

- Platform-specific version usually more optimized/configured
- Explicit override capability (user can specify "shared/git" vs "darwin/git")
- Follows principle of specific overrides general

**Implementation approach**:

```nix
resolveApp = appName: searchPaths: basePath: let
  # Try each search path in priority order
  findInPaths = paths:
    if paths == [] then null
    else let
      currentPath = builtins.head paths;
      result = findAppInPath appName currentPath;
    in
      if result != null then result
      else findInPaths (builtins.tail paths);
in
  findInPaths searchPaths;
```

**Explicit disambiguation syntax**:

```nix
applications = [
  "git"              # Uses platform-specific if exists, else shared
  "shared/git"       # Forces shared version
  "darwin/git"       # Forces darwin version (errors if on different platform)
];
```

**Edge cases**:

- App only in shared: resolves to shared
- App in both platform and shared: resolves to platform version
- App only in other platform: validation error with helpful message
- Explicit path to wrong platform: error at resolution time

**Alternatives considered**:

- **Shared always wins**: Rejected - defeats purpose of platform-specific apps
- **Error on ambiguity**: Rejected - too strict, breaks common case
- **Merge configurations**: Rejected - complex, unclear semantics

______________________________________________________________________

## Performance Considerations

### Evaluation Time Impact

**Current approach**: Hardcoded paths, minimal filesystem access

- ~2-3 `builtins.readDir` calls per resolution
- ~5-10 `builtins.pathExists` checks per resolution

**New approach**: Dynamic scanning

- ~1 `builtins.readDir` for platform discovery (cached)
- ~3-5 `builtins.readDir` per app resolution (recursive search)
- ~10-15 `builtins.pathExists` checks per resolution

**Estimated impact**: +50-100ms for typical 50-app build

- Nix evaluation is lazy - only scans when apps are actually resolved
- `builtins.readDir` results are cached within evaluation
- Acceptable trade-off for platform-agnostic design

**Optimization opportunities** (if needed):

1. Cache platform discovery results
1. Cache app discovery per search path
1. Build app index once, reuse for all resolutions

**When to optimize**: If evaluation time exceeds 2 seconds for typical config

______________________________________________________________________

### Memory Impact

**Current approach**:

- Minimal - only stores resolved paths

**New approach**:

- Platform list: ~5 strings (~100 bytes)
- All app names: ~50 strings (~2 KB)
- Search paths: ~10 paths (~500 bytes)

**Total additional memory**: \<5 KB per evaluation

- Negligible impact
- No optimization needed

______________________________________________________________________

## Error Messages

### Design Principle

Error messages should be **actionable** and **context-aware**.

### App Not Found Error

**Before** (current):

```
error: Application 'aerospace' not found

Searched locations:
  - /nix/store/.../platform/shared/app/**/aerospace.nix

Called from: /nix/store/.../user/cdrokar/default.nix
```

**After** (improved):

```
error: Application 'aerospace' not found in platform 'nixos'

Available in other platforms:
  - darwin: platform/darwin/app/aerospace.nix

Searched in current context:
  - platform/nixos/app/**/aerospace.nix
  - platform/shared/app/**/aerospace.nix

Called from: user/cdrokar/default.nix

Tip: This app is platform-specific. Either:
  1. Remove 'aerospace' from applications list for nixos builds
  2. Add a platform-agnostic alternative to your config
```

### App Doesn't Exist Anywhere

**After** (new):

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

**Implementation**: Use Levenshtein distance or simple prefix matching for suggestions

______________________________________________________________________

## Migration Strategy

### Backward Compatibility

**Goal**: Existing configs continue to work without changes.

**Approach**:

1. New functions are additions, not replacements
1. Existing API (`mkApplicationsModule`) unchanged
1. Internal implementation refactored to use new logic

**Testing**:

- Build existing configs (cdrokar, cdrolet, cdrixus) on darwin
- Verify all apps resolve correctly
- Check error messages are helpful

### Deprecation Path

**Not needed** - This is an internal refactor, no user-facing API changes.

______________________________________________________________________

## Related Research

### Prior Art: Nixpkgs Module System

**Observation**: Nixpkgs uses similar pattern for `lib.systems.examples`

- Lists known systems but allows custom systems
- Type checking validates structure, not specific values
- Dynamic discovery preferred over hardcoded lists

**Lesson**: Platform-agnostic design is idiomatic Nix.

### Community Patterns: Home Manager

**Observation**: Home Manager supports multiple platforms

- Uses `pkgs.stdenv.isDarwin` / `isLinux` for platform detection
- Modules are platform-agnostic by default
- Platform-specific config via `lib.mkIf`

**Lesson**: Detection at runtime (eval time) > compile-time hardcoding

### Feature 016: Platform Delegation Research

**Key Finding**: Flake inputs must be centralized (cannot delegate to platform libs)

- Relevant constraint: discovery must work with centralized flake.nix
- Our approach: Discovery happens within flake evaluation, accesses filesystem directly
- No conflict: We're not trying to delegate inputs, just discovery logic

**Lesson**: Centralized orchestration in flake.nix is optimal, but internal logic can be dynamic.

______________________________________________________________________

## Decisions Summary

| Question | Decision | Rationale |
|----------|----------|-----------|
| Tree scanning | `builtins.readDir` from repo root | Platform-agnostic, no hardcoding |
| App validation | Two-phase: collect all, filter by platform | Graceful degradation for cross-platform configs |
| Context detection | Extract platform from caller path | Dynamic, works for any platform |
| Search paths | Current platform + shared | Performance, clear semantics |
| Name ambiguity | Priority-based (platform > shared) | Explicit override option, specific > general |
| Performance | +50-100ms acceptable | Lazy evaluation, caching mitigates cost |
| Error messages | Actionable, context-aware | Better DX, easier debugging |
| Migration | Backward compatible | No user-facing changes |

______________________________________________________________________

## Open Questions

None - all research questions resolved.

______________________________________________________________________

## Next Steps

**Phase 1**: Design

1. Create data-model.md defining types and data structures
1. Create contracts/ defining function signatures
1. Create quickstart.md with usage examples
1. Update agent context with new approach

**Phase 2**: Implementation (via `/speckit.tasks`)

1. Implement `discoverPlatforms` function
1. Refactor `detectContext` to extract platform dynamically
1. Refactor `buildSearchPaths` to use detected platform
1. Implement two-phase app validation
1. Update error messages
1. Test with existing configs
1. Monitor module size (split if >250 lines)
