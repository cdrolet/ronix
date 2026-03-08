# API Surface Documentation: Discovery System

**Date**: 2025-11-15\
**Purpose**: Ensure backward compatibility during refactor\
**Source**: platform/shared/lib/discovery.nix (before refactor)

## Public API (Exported Functions)

These functions MUST remain backward compatible:

### 1. `discoverUsers`

```nix
discoverUsers :: → [String]
```

**Purpose**: Discover all users in the repository\
**Returns**: List of user directory names with default.nix\
**Usage**: Called from flake.nix\
**Status**: ✅ NO CHANGES NEEDED

______________________________________________________________________

### 2. `discoverProfiles`

```nix
discoverProfiles :: String → [String]
```

**Parameters**:

- `platform` (String): Platform name (e.g., "darwin", "nixos")

**Purpose**: Discover profiles for a specific platform\
**Returns**: List of profile directory names with default.nix\
**Usage**: Called from flake.nix\
**Status**: ✅ NO CHANGES NEEDED

______________________________________________________________________

### 3. `discoverModules`

```nix
discoverModules :: Path → [String]
```

**Parameters**:

- `basePath` (Path): Directory to scan

**Purpose**: Recursively discover all .nix files (except default.nix)\
**Returns**: List of relative file paths\
**Usage**: Internal helper, also used by other modules\
**Status**: ✅ NO CHANGES NEEDED

______________________________________________________________________

### 4. `discoverApplicationNames`

```nix
discoverApplicationNames :: Path → [String]
```

**Parameters**:

- `basePath` (Path): Directory to scan (e.g., platform/darwin/app)

**Purpose**: Discover application names in directory\
**Returns**: List of app names (file names without .nix)\
**Usage**: Internal helper\
**Status**: ✅ NO CHANGES NEEDED

______________________________________________________________________

### 5. `discoverApplications`

```nix
discoverApplications :: {
  callerPath :: Path
  basePath :: Path
} → [String]
```

**Parameters**:

- `callerPath` (Path): Path of calling module
- `basePath` (Path): Repository root

**Purpose**: Discover all apps available for caller context\
**Returns**: List of app names\
**Usage**: Internal helper\
**Status**: ⚠️ INTERNAL CHANGES (behavior unchanged)

______________________________________________________________________

### 6. `resolveApplications`

```nix
resolveApplications :: {
  apps :: [String]
  callerPath :: Path
  basePath :: Path
} → [Path]
```

**Parameters**:

- `apps` ([String]): List of app names to resolve
- `callerPath` (Path): Path of calling module
- `basePath` (Path): Repository root

**Purpose**: Resolve app names to absolute paths\
**Returns**: List of resolved paths\
**Usage**: Called by mkApplicationsModule\
**Status**: ⚠️ MAJOR CHANGES (graceful degradation for user configs)

______________________________________________________________________

### 7. `detectContext`

```nix
detectContext :: Path → Path → {
  callerPath :: Path
  callerType :: String
  platform :: String | null
  basePath :: Path
}
```

**Parameters**:

- `callerPath` (Path): Path of calling module
- `basePath` (Path): Repository root

**Purpose**: Detect caller context (platform, type)\
**Returns**: Context object\
**Usage**: Internal helper\
**Status**: 🔧 REFACTOR NEEDED (remove hardcoded platforms)

**Current behavior** (MUST PRESERVE):

- Darwin profile path → `{ platform = "darwin"; callerType = "darwin-profile" }`
- NixOS profile path → `{ platform = "nixos"; callerType = "nixos-profile" }`
- User config path → `{ platform = null; callerType = "user-config" }`

**New behavior** (MUST MATCH):

- ANY platform profile path → extract platform dynamically
- User config path → same as before

______________________________________________________________________

### 8. `buildSearchPaths`

```nix
buildSearchPaths :: {
  callerPath :: Path
  callerType :: String
  platform :: String | null
  basePath :: Path
} → [Path]
```

**Parameters**:

- `context` (Context): Context from detectContext
- `basePath` (Path): Repository root

**Purpose**: Build prioritized search paths\
**Returns**: Ordered list of paths to search\
**Usage**: Internal helper\
**Status**: 🔧 REFACTOR NEEDED (remove hardcoded paths)

**Current behavior** (MUST PRESERVE PRIORITY):

- Darwin profile → [darwin/app, shared/app]
- NixOS profile → [nixos/app, shared/app]
- User config → [shared/app, darwin/app (if exists), nixos/app (if exists)]

**New behavior** (SAME PRIORITY, DYNAMIC PLATFORMS):

- {platform} profile → [{platform}/app, shared/app]
- User config → [shared/app]

______________________________________________________________________

### 9. `findAppInPath`

```nix
findAppInPath :: String → Path → Path | null
```

**Parameters**:

- `appName` (String): App name to find
- `searchPath` (Path): Directory to search

**Purpose**: Find app in specific directory (recursive)\
**Returns**: Absolute path or null\
**Usage**: Internal helper\
**Status**: ✅ NO CHANGES NEEDED

______________________________________________________________________

### 10. `mkApplicationsModule`

```nix
mkApplicationsModule :: {
  lib :: Lib
  applications :: [String] | ["*"]
  user :: String (optional)
  platform :: String (optional)
  profile :: String (optional)
} → Module
```

**Parameters**:

- `lib` (Lib): nixpkgs lib
- `applications` ([String]): App names to import, or ["\*"] for all
- Optional: user, platform, profile (for context, not used currently)

**Purpose**: Create module importing applications by name\
**Returns**: Nix module with imports\
**Usage**: Called from user configs and profiles\
**Status**: ⚠️ BEHAVIOR CHANGE (graceful degradation)

**Current behavior**:

- Resolves all apps
- Errors if any app not found

**New behavior** (BREAKING FOR USER CONFIGS, COMPATIBLE FOR PROFILES):

- User configs: Skip unavailable apps (graceful)
- Profiles: Error on missing apps (strict)
- Must detect caller type to determine behavior

______________________________________________________________________

## Internal Functions (Not Exported)

These are helpers used internally:

- `discoverDirectoriesWithDefault` - Generic directory scanner
- `matchPartialPath` - Partial path matching helper
- `resolveApp` - Single app resolution

## New Functions to Add

### `discoverPlatforms`

```nix
discoverPlatforms :: Path → [String]
```

**Purpose**: Discover all platforms in repository\
**Returns**: List of platform names (excludes "shared")\
**Status**: 🆕 NEW FUNCTION

______________________________________________________________________

### `buildAppRegistry`

```nix
buildAppRegistry :: Path → {
  platforms :: [String]
  apps :: { "${platform}" :: [String], shared :: [String] }
  index :: { "${appName}" :: [String] }
}
```

**Purpose**: Build complete app registry for validation\
**Returns**: Registry with platform/app mappings\
**Status**: 🆕 NEW FUNCTION

______________________________________________________________________

## Backward Compatibility Requirements

1. ✅ **Public API unchanged**: All exported functions have same signatures
1. ⚠️ **Behavior changes**:
   - User configs: Now skip unavailable apps instead of erroring
   - Profiles: Behavior unchanged (strict validation)
   - Error messages: Improved (more helpful)
1. ✅ **Existing configs work**: No user action required
1. 🔧 **Internal refactor**: detectContext and buildSearchPaths made platform-agnostic

## Testing Requirements

After refactor, verify:

- [ ] Existing user configs build successfully
- [ ] All app imports resolve correctly
- [ ] Platform-specific apps work on their platforms
- [ ] User configs with mixed platform apps build (graceful skip)
- [ ] Profiles error on missing apps (strict)
- [ ] Error messages are helpful
