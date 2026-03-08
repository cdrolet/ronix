# Hierarchical Discovery Pattern Research

## Feature 021: Host/Flavor Architecture

**Research Task**: Design `discoverWithHierarchy` function for host/flavor architecture\
**Date**: 2025-12-03\
**Status**: Complete\
**Scope**: Extend discovery system to support: platform → flavor → shared search hierarchy

______________________________________________________________________

## Executive Summary

The hierarchical discovery pattern enables intelligent fallback-based module resolution across the platform/flavor/shared directory structure. This research documents:

1. **Function signature** optimized for Nix purity and clarity
1. **Search algorithm** with deterministic ordering and first-match semantics
1. **Error handling** providing clear user feedback
1. **Integration points** with existing discovery system and platform libraries
1. **Implementation patterns** for both applications and settings

**Key Finding**: The design leverages existing discovery primitives (`discoverModules`, `findAppInPath`, `builtins.pathExists`) and follows established patterns from feature 020 (pure data). No new low-level primitives needed.

______________________________________________________________________

## Part 1: Current Discovery System Analysis

### Existing Architecture

The discovery system (`platform/shared/lib/discovery.nix`) provides:

#### **1. Low-Level Primitives**

```nix
# Recursive directory scanning
discoverModules :: Path → [String]  # Returns relative paths like ["git.nix", "dev/git.nix"]

# File existence checking
findAppInPath :: String → Path → Path?  # Searches directory tree for app

# Dynamic path construction
builtins.pathExists :: Path → Bool   # Check if path exists
builtins.readDir :: Path → {String: FileType}  # List directory contents
```

#### **2. Mid-Level Functions**

```nix
# Application discovery from paths
discoverApplicationNames :: Path → [String]   # Extract app names from files

# Caller context detection
detectContext :: Path → Path → {callerType, platform}  # Determine context

# Search path building
buildSearchPaths :: Context → Path → [Path]  # Priority-ordered search paths
```

#### **3. High-Level API**

```nix
# Resolve named apps to absolute paths
resolveApplications :: {apps, callerPath, basePath} → [Path]

# Convenience wrapper
mkApplicationsModule :: {lib, applications} → Module
```

### Current Search Order (Flat 2-Level)

```
User Config Context:
  → platform/shared/app/

Profile/Host Context (darwin):
  → platform/darwin/app/
  → platform/shared/app/
```

**Observation**: Current system already uses context-aware search ordering. We extend this to 3-level hierarchy.

______________________________________________________________________

## Part 2: Feature 020 Pattern Analysis

Feature 020 (pure data user configurations) established a proven pattern we'll mirror:

### Pure Data Extraction Before Module Evaluation

```nix
# In platform/darwin/lib/darwin.nix (current feature 020 implementation)

let
  # 1. Load user config as PLAIN FILE (no module eval yet)
  userDataPath = ../../../user/${user};
  userData = import userDataPath { };

  # 2. Extract applications before module system runs
  userApplications = userData.user.applications or [];

  # 3. Generate imports module
  appsModule = discovery.mkApplicationsModule {
    inherit lib;
    applications = userApplications;
  };

in {
  home-manager.users.${user}.imports = [
    userData            # Pure data
    appsModule          # Generated imports
    ...
  ];
}
```

**Key Insight**: This avoids infinite recursion by extracting data attributes BEFORE module evaluation. We'll use the same pattern for hosts and flavors.

### Why This Works

- `userData.user.applications` is **plain attribute access** on an imported file
- Not `config.user.applications` through the module system
- Works because file import happens at flake.nix evaluation time
- Platform library has full context for discovery before module system runs

______________________________________________________________________

## Part 3: Hierarchical Discovery Function Design

### Question 1: Function Signature

**Proposed Signature**:

```nix
# Resolve a single item (app or setting) using hierarchical search
# Type: discoverWithHierarchy :: {
#   itemName :: String,           # Name of app/setting to find
#   itemType :: String,           # Type: "app" or "setting"
#   platform :: String,           # Platform name: "darwin", "nixos"
#   flavor :: String?,            # Optional flavor name (null = skip flavor search)
#   basePath :: Path,             # Repository root for relative path construction
# } → Path?
#
# Returns: Absolute path to first matching module, or null if not found
# Error Handling: Throws with context if validation fails (see section 4)

discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,
  basePath,
}:
```

**Rationale for Design Choices**:

1. **Single record parameter**: Named arguments prevent positional errors and make call sites self-documenting

   ```nix
   # ✅ Clear intent
   discoverWithHierarchy { itemName = "git"; itemType = "app"; platform = "darwin"; }

   # ❌ Unclear what "app" and "darwin" mean
   discoverApp "git" "app" "darwin"
   ```

1. **itemType string** instead of enum: Nix doesn't have enums; string with validation is simpler

   ```nix
   # Validation in function catches typos
   validTypes = ["app" "setting"];
   _ = assert builtins.elem itemType validTypes or throw ...;
   ```

1. **Optional flavor parameter** with default null: Gracefully handles both cases

   ```nix
   # When flavor = null, skip flavor search tier entirely
   # No special "no flavor" marker needed
   ```

1. **basePath explicit**: No assumptions about working directory (flake context aware)

   ```nix
   # Platform libs always know repo root and pass explicitly
   # Makes function pure and testable
   ```

### Question 2: Search Algorithm

**Deterministic Three-Tier Hierarchy**:

```nix
let
  # Tier 1: Platform-specific
  platformPath = basePath + "/platform/${platform}/${itemType}";
  tier1Result = findItemInPath itemName platformPath;
  
  # Tier 2: Flavor-specific (if flavor provided)
  flavorPath = basePath + "/platform/shared/flavor/${flavor}/${itemType}";
  hasFlavor = flavor != null && flavor != "";
  tier2Result = if hasFlavor
    then findItemInPath itemName flavorPath
    else null;
  
  # Tier 3: Shared fallback
  sharedPath = basePath + "/platform/shared/${itemType}";
  tier3Result = findItemInPath itemName sharedPath;
  
in
  # Return first match (short-circuit)
  if tier1Result != null then tier1Result
  else if tier2Result != null then tier2Result
  else tier3Result
```

**Search Algorithm Pseudocode**:

```
function discoverWithHierarchy(itemName, itemType, platform, flavor, basePath):
  
  # Validate inputs
  assert itemName is non-empty string
  assert itemType in ["app", "setting"]
  assert platform is non-empty string
  assert flavor is null or non-empty string
  assert basePath is valid path
  
  # Tier 1: Platform-specific directory
  platformDir := basePath/platform/{platform}/{itemType}
  result := findItemInPath(itemName, platformDir)
  if result is not null:
    return result
  
  # Tier 2: Flavor-specific directory (conditional)
  if flavor is not null and flavor is not empty:
    flavorDir := basePath/platform/shared/flavor/{flavor}/{itemType}
    result := findItemInPath(itemName, flavorDir)
    if result is not null:
      return result
  
  # Tier 3: Shared fallback directory
  sharedDir := basePath/platform/shared/{itemType}
  result := findItemInPath(itemName, sharedDir)
  return result  # May be null

```

**Visualization**:

```
Search Hierarchy (in order of priority):

┌─────────────────────────────────────────┐
│ 1. platform/{platform}/{itemType}/      │  First: platform-specific
│    └─ findItemInPath(itemName)          │  (e.g., platform/darwin/app/)
│                                         │
│ 2. platform/shared/flavor/{flavor}/{...}│  Second: flavor-specific
│    └─ (if flavor != null)               │  (if flavor provided)
│    └─ findItemInPath(itemName)          │
│                                         │
│ 3. platform/shared/{itemType}/          │  Third: shared fallback
│    └─ findItemInPath(itemName)          │  (always available)
└─────────────────────────────────────────┘

Example searches for "git" app on darwin with "work" flavor:

1. platform/darwin/app/git.nix             ← Platform-specific (HIGHEST PRIORITY)
   platform/darwin/app/dev/git.nix         ← Recursive subdirs
   ❌ Not found

2. platform/shared/flavor/work/app/git.nix ← Flavor-specific (MEDIUM PRIORITY)
   platform/shared/flavor/work/app/*/git.nix
   ❌ Not found

3. platform/shared/app/git.nix             ← Shared fallback (LOWEST PRIORITY)
   ✅ FOUND! Return path

Result: /Users/charles/project/nix-config/platform/shared/app/git.nix
```

### Question 3: Return Semantics

**First-Match vs Collect-All**:

The design uses **first-match** semantics (return immediately on first success):

```nix
# ✅ CORRECT: First match found
if tier1 != null then tier1
else if tier2 != null then tier2
else tier3

# ❌ WRONG: Collects all matches (creates complex merging)
allMatches = [ tier1 tier2 tier3 ] ++ builtins.filter (x: x != null) [...]
```

**Rationale**:

1. **Matches user expectations**: Platform override should fully replace, not merge
1. **Simpler semantics**: No ambiguity about merge order
1. **Matches darwin/settings/default.nix pattern**: Uses `discoverModules` on single directory, not hierarchy
1. **Prevents surprises**: Settings from multiple tiers won't unexpectedly combine

**Example with Settings**:

```
Host configuration requests: settings = ["locale", "default"]

For "locale":
  1. platform/darwin/settings/locale.nix    ← FOUND
  ↳ Return this, don't check flavor/shared
  
For "default":
  1. platform/darwin/settings/default.nix   ← Found (imports all darwin settings)
  ↳ Return this, imports all discovered darwin settings
```

### Question 4: Handling null/Missing Flavor

**Clean Handling of Optional Flavor**:

```nix
discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,     # Default to null if not provided
  basePath,
}: let
  # Validate flavor if provided
  hasValidFlavor = flavor != null && flavor != "";
  
  # Build tier 2 path (skipped if no valid flavor)
  tier2Path = basePath + "/platform/shared/flavor/${flavor}/${itemType}";
  
  # Conditional search
  tier2Result = if hasValidFlavor
    then (if builtins.pathExists tier2Path
          then findItemInPath itemName tier2Path
          else null)
    else null;
in
  # ... rest of algorithm
```

**Behavior**:

- `flavor = null` → Skip tier 2 entirely
- `flavor = ""` → Skip tier 2 entirely (same as null)
- `flavor = "work"` → Search tier 2 at `platform/shared/flavor/work/{itemType}`

**No Special Cases Needed**: The function naturally handles all three states.

______________________________________________________________________

## Part 4: Error Handling Approach

### Validation Layers

**Layer 1: Input Validation** (fail fast)

```nix
# Type checking and range validation
validationErrors = lib.flatten [
  (if !(lib.isString itemName) then ["itemName must be string"] else [])
  (if itemName == "" then ["itemName cannot be empty"] else [])
  (if !builtins.elem itemType ["app" "setting"] then 
    ["itemType must be 'app' or 'setting', got '${itemType}'"] else [])
  (if !(lib.isString platform) || platform == "" then 
    ["platform must be non-empty string"] else [])
  (if flavor != null && flavor == "" then 
    ["flavor must be non-empty string or null"] else [])
  (if !(builtins.pathExists basePath) then 
    ["basePath does not exist: ${toString basePath}"] else [])
];

_ = if validationErrors != [] then
  throw ''
    discoverWithHierarchy: Invalid arguments
    
    ${lib.concatMapStringsSep "\n" (err: "  - ${err}") validationErrors}
  ''
else null;
```

**Layer 2: Search Execution** (graceful null return)

```nix
# If item not found in any tier, return null
# Caller decides if this is an error (depends on context)
result = if tier1 != null then tier1
         else if tier2 != null then tier2
         else tier3;  # May be null

result  # Caller handles null
```

**Layer 3: Caller Context Error Messages**

Platform libraries decide how to handle null results based on context:

```nix
# In darwin.nix or nixos.nix

let
  result = discoverWithHierarchy { inherit itemName itemType platform flavor basePath; };
  
  # Strict validation for required items
  _ = assert result != null or throw ''
    Application '${itemName}' not found in hierarchy:
    
    Searched (in order):
      1. platform/${platform}/app/
      2. platform/shared/flavor/${flavor}/app/  (if flavor = "${flavor}")
      3. platform/shared/app/
    
    Tip: Add the application to one of these locations
  '';
in
  result
```

**Error Message Quality**:

```
Error Example 1: Missing application
─────────────────────────────────────
Application 'vscode' not found in hierarchy

Searched (in order):
  1. platform/darwin/app/
  2. platform/shared/flavor/work/app/  (flavor = "work")
  3. platform/shared/app/

Available applications: git, zsh, helix, aerospace, borders
Did you mean one of these? Check: platform/*/app/

Tip: Add vscode to one of the search paths or check spelling


Error Example 2: Invalid flavor
────────────────────────────────
Flavor 'gaming' referenced in host configuration does not exist

Searched: platform/shared/flavor/gaming/
Host: work-mac
Flavor: gaming

Available flavors: work, home
Did you mean one of these?

Tip: Create platform/shared/flavor/gaming/ or change host.flavor
```

### Special Case: Settings with "default" Keyword

Settings arrays support special "default" keyword:

```nix
# In host configuration
host = {
  name = "work-mac";
  settings = [ "default" "security" ];  # "default" = import all platform settings
};
```

**Resolution for "default"**:

```nix
# "default" is NOT resolved via discoverWithHierarchy
# Instead, use discoverModules on platform settings directory:

platformSettingsPath = basePath + "/platform/${platform}/settings";

defaultSettings = if itemName == "default"
  then discovery.discoverModules platformSettingsPath
  else [discoverWithHierarchy { inherit itemName itemType platform flavor basePath; }];

# This follows darwin/settings/default.nix pattern exactly
```

______________________________________________________________________

## Part 5: Integration with Existing Discovery System

### Extension Points

The discovery system needs these enhancements:

#### **1. New Function: `discoverWithHierarchy`**

```nix
discoverWithHierarchy = { itemName, itemType, platform, flavor ? null, basePath }: let
  # ... implementation (see Part 3)
in
  result;
```

**Location**: Add to `platform/shared/lib/discovery.nix` exports

#### **2. Enhanced: `findItemInPath` (reuse existing)**

The existing `findItemInPath` already does recursive search:

```nix
findAppInPath = appName: searchPath: let
  searchDir = dir:
    if !builtins.pathExists dir then null
    else
      # Checks for: appName.nix, appName/default.nix, recursive subdirs
      ...
in
  searchDir searchPath;
```

**Can be reused directly** - no changes needed.

#### **3. No New Low-Level Primitives Needed**

All required capabilities already exist:

- ✅ `builtins.pathExists` - check path exists
- ✅ `builtins.readDir` - list directory
- ✅ `discoverModules` - recursive .nix file discovery
- ✅ `findAppInPath` - recursive item search
- ✅ `lib.filter*` - array filtering

### Platform Library Integration Points

#### **In `platform/darwin/lib/darwin.nix`**:

```nix
# Current pattern (Feature 020)
let
  userApplications = userData.user.applications or [];
  appsModule = discovery.mkApplicationsModule {
    applications = userApplications;
  };
in { ... }

# Extended pattern (Feature 021)
let
  # Load host as pure data
  hostData = import ../host/${hostName} { };
  
  # Extract flavor and apps/settings BEFORE module eval
  hostFlavor = hostData.flavor or null;
  hostApplications = hostData.applications or [];
  hostSettings = hostData.settings or [];
  
  # Generate apps module using hierarchy
  appsModule = mkApplicationsModuleWithHierarchy {
    applications = hostApplications;
    itemType = "app";
    inherit platform hostFlavor;
  };
  
  # Generate settings module using hierarchy
  settingsModule = mkSettingsModuleWithHierarchy {
    settings = hostSettings;
    itemType = "setting";
    inherit platform hostFlavor;
  };
  
in { ... }
```

#### **New Helper: `mkApplicationsModuleWithHierarchy`**

```nix
# Convenience wrapper (optional - for code clarity)
mkApplicationsModuleWithHierarchy = {
  lib,
  applications,
  itemType,
  platform,
  flavor ? null,
}:
let
  repoRoot = ../../../..;  # Adjust based on caller location
  
  # Resolve each app using hierarchy
  resolvedPaths = map (appName: let
    result = discoverWithHierarchy {
      itemName = appName;
      inherit itemType platform flavor;
      basePath = repoRoot;
    };
    _ = assert result != null or throw "App '${appName}' not found in ${platform}";
  in result) applications;
  
in {
  imports = resolvedPaths;
};
```

______________________________________________________________________

## Part 6: Complete Implementation Example

### End-to-End Workflow

**Host Configuration (Pure Data)**:

```nix
# platform/darwin/host/work-mac/default.nix
{ ... }:

{
  name = "work-mac";
  flavor = "work";
  
  applications = [
    "git"
    "zsh"
    "helix"
    "aerospace"
  ];
  
  settings = [
    "default"        # Import all darwin settings
    "security"       # darwin-specific override
  ];
}
```

**Flavor Definition**:

```nix
# platform/shared/flavor/work/settings/default.nix
{ config, lib, ... }:

{
  imports = map (file: ./${file}) (discovery.discoverModules ./.);
}

# platform/shared/flavor/work/settings/dnd-focus.nix
{ lib, ... }:

{
  system.defaults.dock.autohide = lib.mkDefault true;
  system.defaults.screensaver.askForPassword = lib.mkDefault true;
}
```

**Platform Library Orchestration**:

```nix
# platform/darwin/lib/darwin.nix

let
  # Load host as pure data
  hostData = import ../host/work-mac { };
  
  # Extract before module eval
  hostFlavor = hostData.flavor or null;
  hostApps = hostData.applications or [];
  hostSettings = hostData.settings or [];
  
  # Resolve applications with hierarchy
  appPaths = map (appName: 
    discoverWithHierarchy {
      itemName = appName;
      itemType = "app";
      platform = "darwin";
      flavor = hostFlavor;
      basePath = repoRoot;
    }
  ) hostApps;
  
  # Resolve settings with hierarchy
  settingPaths = map (settingName:
    if settingName == "default"
    then # Special case: import all platform settings
      map (file: ../settings/${file}) 
        (discovery.discoverModules ../settings)
    else
      discoverWithHierarchy {
        itemName = settingName;
        itemType = "setting";
        platform = "darwin";
        flavor = hostFlavor;
        basePath = repoRoot;
      }
  ) hostSettings;
  
in {
  home-manager.users.cdrolet.imports =
    hostData ++        # Pure data
    appsModule ++      # Resolved apps
    settingsModule ++  # Resolved settings
    [...]
}
```

**Resolution Example**:

```
Search for "security" setting in darwin with "work" flavor:

1. discoverWithHierarchy {
     itemName = "security"
     itemType = "setting"
     platform = "darwin"
     flavor = "work"
     basePath = /repo
   }

2. Tier 1: /repo/platform/darwin/settings/security.nix
   ✅ FOUND → Return path
   
3. (Tier 2 and 3 not searched due to first-match)

Result: /repo/platform/darwin/settings/security.nix
```

______________________________________________________________________

## Part 7: Answers to Research Questions

### Q1: How should the hierarchical discovery function work?

**A**: Three-tier search with first-match semantics:

1. Platform-specific directory (`platform/{platform}/{itemType}/`)
1. Flavor-specific directory (`platform/shared/flavor/{flavor}/{itemType}/`) - conditional
1. Shared fallback (`platform/shared/{itemType}/`)

Stops at first match, returns null if not found.

### Q2: What parameters does it need?

**A**: Single record parameter with five named fields:

```nix
{
  itemName,           # Name of app/setting to find
  itemType,           # Type: "app" or "setting"
  platform,           # Platform: "darwin", "nixos"
  flavor ? null,      # Optional flavor name
  basePath,           # Repository root path
}
```

### Q3: Should it return first match or collect all matches?

**A**: First match only. Collecting all matches would:

- Create ambiguous merge semantics
- Break user expectations for overrides
- Add complexity without clear benefit

First-match follows the darwin/settings/default.nix pattern and is intuitive.

### Q4: How to handle the case when flavor is null/not provided?

**A**: Treat as "no flavor" and skip tier 2 entirely. The optional parameter with default null makes this clean:

```nix
flavor ? null,  # Caller may omit
# ... later ...
if flavor != null && flavor != "" then tier2 else skip
```

No special markers or sentinel values needed.

### Q5: What's the cleanest function signature?

**A**: Single record parameter with named fields:

```nix
discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,
  basePath,
}:
```

Benefits:

- Self-documenting call sites
- Prevents argument order errors
- Handles optional parameters gracefully
- Matches Nix conventions

______________________________________________________________________

## Part 8: Relationship to Feature 020 Pattern

### Parallel Implementations

| Aspect | Feature 020 (User Apps) | Feature 021 (Host/Flavor) |
|--------|------------------------|--------------------------|
| **Pure Data** | User config attributes | Host config attributes |
| **Extraction** | `userData.user.applications` | `hostData.applications` |
| **Resolution** | `mkApplicationsModule` | `discoverWithHierarchy` |
| **Search Scope** | 2-level (platform → shared) | 3-level (platform → flavor → shared) |
| **Special Cases** | Wildcard `"*"` | Wildcard `"*"` + `"default"` |
| **Location** | Platform library orchestration | Platform library orchestration |
| **Error Handling** | Application registry + suggestions | Hierarchical search results |

### Inheritance of Patterns

Feature 021 builds directly on Feature 020:

- ✅ Pure data extraction (same pattern)
- ✅ Pre-evaluation loading (same pattern)
- ✅ Platform library orchestration (same pattern)
- ✅ Error handling philosophy (similar approach)
- ✅ Use of discovery system (reuse existing functions)

______________________________________________________________________

## Part 9: Implementation Validation Checklist

### Design Validation

- ✅ Function signature is type-safe and self-documenting
- ✅ Search algorithm is deterministic and predictable
- ✅ Return semantics (first-match) match user expectations
- ✅ Null flavor handling is clean and natural
- ✅ Error messages are actionable and contextual
- ✅ Reuses existing discovery system primitives
- ✅ Follows patterns established in Feature 020
- ✅ Integrates cleanly with platform libraries
- ✅ Supports all use cases in feature specification

### Quality Criteria

- ✅ No new architectural dependencies
- ✅ Minimal additions to discovery.nix (\<100 lines)
- ✅ Compatible with Nix module system constraints
- ✅ Can be tested independently (pure function)
- ✅ Provides helpful error messages
- ✅ Handles edge cases gracefully
- ✅ Documentation is complete with examples

______________________________________________________________________

## Part 10: Recommended Function Signature

### Final Design

```nix
# Resolve an item (application or setting) using hierarchical search
#
# Type: discoverWithHierarchy :: {
#   itemName :: String,
#   itemType :: "app" | "setting",
#   platform :: String,
#   flavor :: String | null,
#   basePath :: Path,
# } → Path | null
#
# Search order:
#   1. platform/{platform}/{itemType}/{itemName}
#   2. platform/shared/flavor/{flavor}/{itemType}/{itemName}  (if flavor provided)
#   3. platform/shared/{itemType}/{itemName}
#
# Returns: Absolute path to first match, or null if not found
#
# Examples:
#   # Find app in darwin with work flavor
#   discoverWithHierarchy {
#     itemName = "git";
#     itemType = "app";
#     platform = "darwin";
#     flavor = "work";
#     basePath = /repo;
#   }
#   # Result: /repo/platform/darwin/app/dev/git.nix
#
#   # Find setting without flavor (skips tier 2)
#   discoverWithHierarchy {
#     itemName = "locale";
#     itemType = "setting";
#     platform = "darwin";
#     flavor = null;
#     basePath = /repo;
#   }
#   # Result: /repo/platform/shared/settings/locale.nix

discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,
  basePath,
}: let
  # Validation
  validTypes = ["app" "setting"];
  validationFailed = lib.flatten [
    (if !lib.isString itemName || itemName == "" then 
      ["itemName must be non-empty string"] else [])
    (if !builtins.elem itemType validTypes then 
      ["itemType must be 'app' or 'setting'"] else [])
    (if !lib.isString platform || platform == "" then 
      ["platform must be non-empty string"] else [])
    (if flavor != null && (!lib.isString flavor || flavor == "") then 
      ["flavor must be non-empty string or null"] else [])
  ];
  
  _ = if validationFailed != [] then
    throw "discoverWithHierarchy: Invalid arguments\n${lib.concatStringsSep "\n" 
      (map (err: "  - ${err}") validationFailed)}"
    else null;

  # Tier 1: Platform-specific
  platformPath = basePath + "/platform/${platform}/${itemType}";
  tier1Result = 
    if builtins.pathExists platformPath
    then findAppInPath itemName platformPath
    else null;

  # Tier 2: Flavor-specific (conditional)
  flavorPath = basePath + "/platform/shared/flavor/${flavor}/${itemType}";
  tier2Result = 
    if flavor != null && flavor != "" && builtins.pathExists flavorPath
    then findAppInPath itemName flavorPath
    else null;

  # Tier 3: Shared fallback
  sharedPath = basePath + "/platform/shared/${itemType}";
  tier3Result = 
    if builtins.pathExists sharedPath
    then findAppInPath itemName sharedPath
    else null;

in
  # Return first match (short-circuit)
  if tier1Result != null then tier1Result
  else if tier2Result != null then tier2Result
  else tier3Result
```

______________________________________________________________________

## Conclusion

The hierarchical discovery function design:

1. **Is pragmatic**: Leverages existing discovery primitives, no new infrastructure
1. **Is clear**: Simple three-tier search with predictable ordering
1. **Is extensible**: Integrates cleanly with platform libraries for future enhancements
1. **Is robust**: Comprehensive validation and error handling
1. **Is proven**: Mirrors successful Feature 020 patterns

Ready for implementation in discovery.nix with integration into platform libraries.

______________________________________________________________________

## Next Steps

1. ✅ Research phase complete (this document)
1. **Implementation phase**: Add `discoverWithHierarchy` to `discovery.nix`
1. **Integration phase**: Update `platform/darwin/lib/darwin.nix` and `nixos.nix` to use hierarchical discovery
1. **Migration phase**: Convert profiles to hosts, create flavor structure
1. **Testing phase**: Validate all combinations build and apply correctly
