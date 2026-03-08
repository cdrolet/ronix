# Contract: Discovery Functions API

**Feature**: 013-refactor-system-structure
**Created**: 2025-01-27
**Version**: 1.1.0

## Changelog

### Version 1.1.0 (2025-01-27)

- **BREAKING**: `discoverUsers` no longer takes `basePath` parameter (uses hardcoded relative path)
- **REMOVED**: `findRepoRoot` function (dead code - never actually used)
- **CHANGED**: `resolveApplications` now requires `basePath` parameter (no longer optional)
- Standardized all discovery functions to use hardcoded relative paths from known flake context

## Purpose

Defines the API contract for shared discovery functions that automatically find and load modules from directory structures.

## Module Location

**Implementation**: `system/shared/lib/discovery.nix`\
**Usage**: `flake.nix`, `system/darwin/settings/default.nix`, any defaults.nix file

## Function Signatures

### discoverUsers

```nix
discoverUsers :: → [String]
```

**Purpose**: Discovers user directories that contain `default.nix` files.

**Parameters**: None (uses hardcoded path relative to repo root: `../../../user`)

**Returns**: List of user names (strings) corresponding to directories with `default.nix`

**Examples**:

```nix
discoverUsers
# Returns: ["cdrokar", "cdrolet", "cdrixus"]
```

**Behavior**:

- Scans `user/` directory from repository root
- Filters directories that contain a `default.nix` file
- Returns directory names as user identifiers
- Pure function (no side effects)
- Called from flake context with known relative path
- Handles non-existent directories via Nix evaluation error

**Used By**: `flake.nix` for generating user-profile combinations

______________________________________________________________________

### discoverProfiles

```nix
discoverProfiles :: String → [String]
```

**Purpose**: Discovers profile directories for a specific platform.

**Parameters**:

- `platform` (String): Platform identifier (e.g., `"darwin"`, `"nixos"`)

**Returns**: List of profile names (strings) found in `system/${platform}/profiles/`

**Examples**:

```nix
discoverProfiles "darwin"
# Returns: ["home-macmini-m4", "work"]

discoverProfiles "nixos"
# Returns: ["gnome-desktop-1", "kde-desktop-1", "server-1"]
```

**Behavior**:

- Scans `system/${platform}/profiles/` directory
- Filters directories that contain a `default.nix` file
- Returns directory names as profile identifiers
- Pure function (no side effects)
- Platform directory must exist (Nix evaluation error if missing)

**Used By**: `flake.nix` for platform-specific profile discovery, `system/{platform}/lib/{platform}.nix`

______________________________________________________________________

### discoverAllProfilesPrefixed

```nix
discoverAllProfilesPrefixed :: → [String]
```

**Purpose**: Discovers all profiles across all platforms with platform prefixes.

**Parameters**: None (uses hardcoded platform list: `["darwin", "nixos"]`)

**Returns**: List of prefixed profile names (strings) like `"${platform}-${profile}"`

**Examples**:

```nix
discoverAllProfilesPrefixed
# Returns: ["darwin-home-macmini-m4", "darwin-work", "nixos-gnome-desktop-1", ...]
```

**Behavior**:

- Checks which platforms exist in `system/{platform}/profiles/`
- Calls `discoverProfiles` for each existing platform
- Prefixes each profile with platform name
- Flattens results into single list
- Pure function (no side effects)

**Used By**: `flake.nix` for user-facing validation lists (justfile commands)

______________________________________________________________________

### discoverModules

```nix
discoverModules :: Path → [String]
```

**Purpose**: Recursively discovers all `.nix` files in a directory tree, excluding `default.nix`.

**Parameters**:

- `basePath` (Path): Base directory to scan (e.g., `./system/darwin/settings`)

**Returns**: List of relative file paths (strings) to `.nix` files, preserving subdirectory structure

**Examples**:

```nix
discoverModules ./system/darwin/settings
# Returns: ["dock.nix", "finder.nix", "keyboard.nix", ...]

discoverModules ./system/shared/app
# Returns: ["dev/git.nix", "dev/sdkman.nix", "editor/helix.nix", "shell/zsh.nix", ...]
```

**Behavior**:

- Recursively traverses directory tree
- Filters files with `.nix` extension
- **Excludes** `default.nix` (prevents circular dependencies)
- Preserves relative paths including subdirectories
- Pure function (no side effects)
- Returns empty list for empty directories (valid, no error)

**Used By**: `system/darwin/settings/default.nix`, any defaults.nix file that needs auto-discovery

**Import Pattern**:

```nix
imports = map (file: ./${file}) (discoverModules ./.);
```

______________________________________________________________________

## Implementation Contract

### Purity Requirements

All functions MUST be:

- ✅ Pure (no side effects, deterministic outputs for same inputs)
- ✅ Evaluation-time only (execute during Nix evaluation, not at runtime)
- ✅ Platform-agnostic (work identically on all platforms)

### Error Handling

**Non-existent Directories**:

- Functions may be called with non-existent directory paths
- Nix evaluation errors are acceptable (no special error handling required)
- Error messages should be clear (provided by Nix builtins)

**Invalid Files**:

- Invalid Nix modules discovered by `discoverModules` cause normal Nix evaluation errors
- No special handling needed (Nix evaluation will fail naturally)
- Functions themselves do not validate module correctness

### Performance

- Functions execute during Nix evaluation (build time)
- Results are cached by Nix automatically
- Recursive discovery performance acceptable for typical directory sizes (\<100 modules)

## Usage Examples

### In flake.nix

```nix
let
  discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
  validUsers = discovery.discoverUsers;
  darwinProfiles = discovery.discoverProfiles "darwin";
in
  { ... }
```

### In defaults.nix

```nix
let
  discovery = lib.callPackage ../../shared/lib/discovery.nix {};
in
{
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}
```

## Migration Contract

### From flake.nix

**Before**: Discovery functions embedded in `flake.nix`\
**After**: Import from `system/shared/lib/discovery.nix`

**Breaking Changes**: None (function signatures unchanged)

### To Auto-Discovery

**Before**: Manual import list in defaults.nix\
**After**: Auto-discovery via `discoverModules`

**Breaking Changes**: None (behaviorally equivalent, just automatic)

## Versioning

**Version**: 1.1.0
**Stability**: Stable (part of feature implementation)
**Breaking Changes**: See changelog above
**Future Extensions**: May add filtering options (e.g., `discoverModulesWithFilter`) if needed

## Testing

**Unit Testing**: Functions tested via Nix evaluation (successful build = correct behavior)\
**Integration Testing**: Used in actual profiles and settings to verify discovery\
**Edge Cases**: Empty directories, non-existent paths, invalid modules all handled

## Compliance

**Implementation**: `system/shared/lib/discovery.nix`\
**Usage**: `flake.nix`, `system/darwin/settings/default.nix`\
**Validation**: Nix evaluation automatically validates function correctness
