# Hierarchical Discovery Algorithm Details

## Feature 021: Host/Flavor Architecture

**Purpose**: Detailed algorithm documentation for implementing `discoverWithHierarchy`\
**Date**: 2025-12-03\
**Scope**: Complete pseudocode, integration diagrams, and implementation notes

______________________________________________________________________

## Algorithm Overview

### Three-Tier Hierarchical Search

```
┌──────────────────────────────────────────────────────────────────┐
│                   SEARCH REQUEST                                 │
│  itemName="git", itemType="app", platform="darwin", flavor="work"│
└──────────────────────────────────┬───────────────────────────────┘
                                   │
                ┌──────────────────┴──────────────────┐
                │                                     │
        ┌───────▼────────┐                ┌──────────▼───────────┐
        │ Validate Input │                │ Check Path Exists    │
        │ - itemName     │                │ - basePath valid?    │
        │ - itemType     │                │ - itemType in list?  │
        │ - platform     │                └──────────────────────┘
        │ - flavor       │
        └────────────────┘
                │
                ▼
      ┌─────────────────────────────────────────┐
      │    TIER 1: PLATFORM-SPECIFIC            │
      │  /platform/{platform}/{itemType}/       │
      │                                         │
      │  Path: /repo/platform/darwin/app/      │
      │  Search: findAppInPath("git", path)    │
      │  Result: /...darwin/app/dev/git.nix ✅ │
      │                                         │
      │  IF FOUND: Return immediately          │
      └─────────────────────────────────────────┘
                │
                │ ❌ NOT FOUND
                ▼
      ┌─────────────────────────────────────────┐
      │    TIER 2: FLAVOR-SPECIFIC              │
      │  (Only if flavor != null)               │
      │  /platform/shared/flavor/{flavor}/...   │
      │                                         │
      │  Path: /repo/platform/shared/flavor/   │
      │         work/app/                      │
      │  Search: findAppInPath("git", path)    │
      │  Result: null ❌                        │
      │                                         │
      │  IF FOUND: Return immediately          │
      └─────────────────────────────────────────┘
                │
                │ ❌ NOT FOUND
                ▼
      ┌─────────────────────────────────────────┐
      │    TIER 3: SHARED FALLBACK              │
      │  /platform/shared/{itemType}/           │
      │                                         │
      │  Path: /repo/platform/shared/app/      │
      │  Search: findAppInPath("git", path)    │
      │  Result: /...shared/app/dev/git.nix ✅ │
      │                                         │
      │  Return result (may be null)            │
      └─────────────────────────────────────────┘
                │
                ▼
      ┌─────────────────────────────────────────┐
      │   RETURN FIRST MATCH OR NULL            │
      │   /repo/platform/shared/app/dev/git.nix │
      └─────────────────────────────────────────┘
```

______________________________________________________________________

## Detailed Algorithm Pseudocode

### Input Validation Phase

```
FUNCTION validateInputs(itemName, itemType, platform, flavor, basePath)

  errors := []
  
  # Check itemName
  IF itemName is not a string OR length(itemName) == 0 THEN
    errors.push("itemName must be non-empty string")
  
  # Check itemType
  validTypes := ["app", "setting"]
  IF itemType NOT IN validTypes THEN
    errors.push("itemType must be 'app' or 'setting', got: " + itemType)
  
  # Check platform
  IF platform is not a string OR length(platform) == 0 THEN
    errors.push("platform must be non-empty string")
  
  # Check flavor (optional, but validate if provided)
  IF flavor is not null THEN
    IF flavor is not a string OR length(flavor) == 0 THEN
      errors.push("flavor must be non-empty string or null")
  
  # Check basePath
  IF NOT pathExists(basePath) THEN
    errors.push("basePath does not exist: " + basePath)
  
  # Report all errors at once
  IF length(errors) > 0 THEN
    THROW "discoverWithHierarchy: Invalid arguments\n" + join(errors, "\n")
  
  RETURN null  # Validation passed
END FUNCTION
```

### Path Construction Phase

```
FUNCTION constructPaths(basePath, platform, itemType, flavor)

  # Tier 1: Platform-specific
  tier1Path := basePath + "/platform/" + platform + "/" + itemType
  
  # Tier 2: Flavor-specific (conditional)
  IF flavor != null AND flavor != "" THEN
    tier2Path := basePath + "/platform/shared/flavor/" + flavor + "/" + itemType
  ELSE
    tier2Path := null
  
  # Tier 3: Shared fallback
  tier3Path := basePath + "/platform/shared/" + itemType
  
  RETURN {
    tier1 : tier1Path,
    tier2 : tier2Path,
    tier3 : tier3Path
  }
END FUNCTION
```

### Search Phase

```
FUNCTION searchHierarchy(itemName, paths)

  VARIABLES
    tier1Result := null
    tier2Result := null
    tier3Result := null
  
  # Tier 1 Search: Platform-specific
  IF pathExists(paths.tier1) THEN
    tier1Result := findAppInPath(itemName, paths.tier1)
    IF tier1Result != null THEN
      RETURN tier1Result  # Found at tier 1, stop searching
  
  # Tier 2 Search: Flavor-specific (if flavor exists)
  IF paths.tier2 != null AND pathExists(paths.tier2) THEN
    tier2Result := findAppInPath(itemName, paths.tier2)
    IF tier2Result != null THEN
      RETURN tier2Result  # Found at tier 2, stop searching
  
  # Tier 3 Search: Shared fallback
  IF pathExists(paths.tier3) THEN
    tier3Result := findAppInPath(itemName, paths.tier3)
    IF tier3Result != null THEN
      RETURN tier3Result  # Found at tier 3
  
  # Not found anywhere
  RETURN null
END FUNCTION
```

### Error Context Phase (in caller)

```
FUNCTION handleNotFound(itemName, itemType, platform, flavor, basePath)

  IF result == null THEN
    VARIABLES
      searchedPaths := []
      availableItems := []
    
    # Build list of paths searched
    searchedPaths.push("/platform/" + platform + "/" + itemType + "/")
    
    IF flavor != null THEN
      searchedPaths.push("/platform/shared/flavor/" + flavor + "/" + itemType + "/")
    
    searchedPaths.push("/platform/shared/" + itemType + "/")
    
    # Try to find similar items for suggestions
    tier3Path := basePath + "/platform/shared/" + itemType
    IF pathExists(tier3Path) THEN
      availableItems := discoverApplicationNames(tier3Path)
    
    # Build helpful error message
    THROW "

Item '" + itemName + "' not found in " + platform + " " + itemType + " hierarchy
      
Searched (in order):
" + join(map(p => "  - " + p, searchedPaths), "\n") + "

Called from host configuration with flavor = '" + flavor + "'

Available " + itemType + "s:
" + join(availableItems, ", ") + "

Tip: Add '" + itemName + "' to one of the search paths or check spelling
    "
  ENDIF
END FUNCTION
```

### Complete Algorithm

```
ALGORITHM discoverWithHierarchy(params)

  # Extract parameters (record syntax)
  itemName := params.itemName
  itemType := params.itemType
  platform := params.platform
  flavor := params.flavor ?? null          # Default to null if omitted
  basePath := params.basePath
  
  # Phase 1: Validate inputs
  validateInputs(itemName, itemType, platform, flavor, basePath)
  
  # Phase 2: Construct search paths
  paths := constructPaths(basePath, platform, itemType, flavor)
  
  # Phase 3: Search hierarchy
  result := searchHierarchy(itemName, paths)
  
  # Phase 4: Return result (caller handles null)
  RETURN result
  
END ALGORITHM
```

______________________________________________________________________

## Integration Points

### Point 1: Discovery System Addition

**File**: `platform/shared/lib/discovery.nix`

```nix
# Add to exports section at end of file
{
  inherit
    discoverUsers
    discoverProfiles
    discoverModules
    discoverApplicationNames
    discoverPlatforms
    buildAppRegistry
    discoverApplications
    resolveApplications
    detectContext
    buildSearchPaths
    findAppInPath
    mkApplicationsModule
    
    # NEW: Hierarchical discovery
    discoverWithHierarchy;  # ADD THIS LINE
}
```

**Where to add function in file**: After existing discovery functions, before final exports

### Point 2: Platform Library Integration (Darwin)

**File**: `platform/darwin/lib/darwin.nix`

```nix
# In mkDarwinConfig function, after loading host data:

let
  # ... existing code ...
  
  # Load host as pure data
  hostDataPath = ../host/${host};
  hostData = import hostDataPath { };
  
  # Extract configuration before module eval
  hostFlavor = hostData.flavor or null;
  hostApplications = hostData.applications or [];
  hostSettings = hostData.settings or [];
  
  # Resolve applications with hierarchy
  appPaths = map (appName: let
    result = discovery.discoverWithHierarchy {
      itemName = appName;
      itemType = "app";
      platform = "darwin";
      flavor = hostFlavor;
      basePath = ../../../../;  # Repo root
    };
    _ = assert result != null or throw ''
      Application '${appName}' not found in host configuration
      Searched: platform/darwin/app/, platform/shared/flavor/${hostFlavor}/app/, platform/shared/app/
    '';
  in result) hostApplications;
  
  # Resolve settings with hierarchy
  settingPaths = lib.flatten (map (settingName: 
    if settingName == "default"
    then
      # Special case: discover all settings in platform directory
      map (file: ../settings/${file})
        (discovery.discoverModules ../settings)
    else
      let
        result = discovery.discoverWithHierarchy {
          itemName = settingName;
          itemType = "setting";
          platform = "darwin";
          flavor = hostFlavor;
          basePath = ../../../../;
        };
        _ = assert result != null or throw ''
          Setting '${settingName}' not found in host configuration
          Searched: platform/darwin/settings/, platform/shared/flavor/${hostFlavor}/settings/, platform/shared/settings/
        '';
      in [result]
  ) hostSettings);
  
  # Generate modules
  appsModule = { imports = appPaths; };
  settingsModule = { imports = settingPaths; };

in {
  # Use modules in home-manager configuration
  home-manager.users.${user}.imports = [
    hostData           # Pure host data
    appsModule         # Resolved applications
    settingsModule     # Resolved settings
    ...                # Existing imports
  ];
}
```

### Point 3: Error Handling in Platform Library

```nix
# Pattern for non-strict error handling (for user apps, not required)
let
  result = discovery.discoverWithHierarchy {
    itemName = appName;
    itemType = "app";
    platform = "darwin";
    flavor = hostFlavor;
    basePath = repoRoot;
  };
in
  # For user apps, could be lenient (null = skip)
  # For host apps, should be strict (null = error)
  if result != null
  then result
  else null  # Skip if not found
```

______________________________________________________________________

## Search Order Examples

### Example 1: Finding "git" App

```
Request:
  itemName = "git"
  itemType = "app"
  platform = "darwin"
  flavor = "work"
  basePath = /repo

Execution:
  Tier 1: /repo/platform/darwin/app/
    └─ findAppInPath("git", /repo/platform/darwin/app/)
       └─ Recursively search: 
          ├─ /repo/platform/darwin/app/git.nix? NO
          ├─ /repo/platform/darwin/app/git/default.nix? NO
          ├─ /repo/platform/darwin/app/dev/git.nix? YES ✅
       └─ FOUND!
  
  Return: /repo/platform/darwin/app/dev/git.nix
  (Tiers 2 and 3 not searched)
```

### Example 2: Finding Non-Existent "custom-app" with Fallback

```
Request:
  itemName = "custom-app"
  itemType = "app"
  platform = "darwin"
  flavor = null
  basePath = /repo

Execution:
  Tier 1: /repo/platform/darwin/app/
    └─ findAppInPath("custom-app", /repo/platform/darwin/app/)
       └─ Recursively search: NO MATCH ❌
  
  Tier 2: SKIPPED (flavor is null)
  
  Tier 3: /repo/platform/shared/app/
    └─ findAppInPath("custom-app", /repo/platform/shared/app/)
       └─ Recursively search:
          ├─ /repo/platform/shared/app/custom-app.nix? NO
          ├─ /repo/platform/shared/app/custom-app/default.nix? NO
          ├─ /repo/platform/shared/app/*/custom-app.nix? NO
       └─ NOT FOUND ❌
  
  Return: null
  Error handled by caller
```

### Example 3: Setting with "default" Keyword

```
Request (from host settings array):
  settings = ["default", "locale"]

For "default":
  NOT resolved via discoverWithHierarchy
  Instead:
    discoveryModules /repo/platform/darwin/settings/
    Returns: ["dock.nix", "security.nix", "locale.nix", ...]
    Result: Imports all platform settings
  
For "locale":
  discoveryWithHierarchy {
    itemName = "locale"
    itemType = "setting"
    platform = "darwin"
    flavor = null
  }
  Tier 1: /repo/platform/darwin/settings/
    └─ Finds: /repo/platform/darwin/settings/locale.nix ✅
  Return: /repo/platform/darwin/settings/locale.nix

Final imports:
  [ all platform settings ] + [ locale setting ]
```

______________________________________________________________________

## Special Cases and Edge Handling

### Case 1: Flavor Doesn't Exist

```nix
# In host configuration
host = {
  name = "work-mac";
  flavor = "gaming";  # This flavor doesn't exist
  applications = ["steam"];
};

# When searching for steam app:
Tier 1: /platform/darwin/app/ → NOT FOUND
Tier 2: /platform/shared/flavor/gaming/app/ → PATH DOESN'T EXIST (skipped gracefully)
Tier 3: /platform/shared/app/ → FOUND (if exists)

# No special error about missing flavor needed
# Either app is found in tier 3, or error about missing app
```

**Design Rationale**: Flavor paths are checked with `pathExists` before searching, so non-existent flavor gracefully skips tier 2 without special handling.

### Case 2: Null Flavor

```nix
# In host configuration (no flavor field)
host = {
  name = "minimal-mac";
  # flavor field omitted → defaults to null
  applications = ["git"];
};

# When resolving apps:
flavor = null  # Default value
# Tier 2 condition: if flavor != null && flavor != ""
#   → FALSE, skip tier 2 entirely
# Only tiers 1 and 3 searched
```

### Case 3: Empty String Flavor

```nix
# Unusual but possible
host = {
  flavor = "";  # Empty string
  applications = ["git"];
};

# Treated same as null:
if flavor != null && flavor != "" THEN  # FALSE
  # Skip tier 2
```

### Case 4: Wildcard in Applications Array

```nix
host = {
  applications = ["*"];  # Import all apps
};

# Handled in mkApplicationsModule wrapper:
# NOT in discoverWithHierarchy
# Discovery system already handles "*" expansion before calling hierarchy resolver
```

### Case 5: Wildcard in Settings Array (Should Fail)

```nix
host = {
  settings = ["*"];  # ERROR: Not supported
};

# Validation in platform library:
_ = assert !builtins.elem "*" hostSettings or throw ''
  Settings array cannot use "*" wildcard
  Use settings = ["default"] to import all platform settings instead
  or list specific settings: ["locale", "dock", "security"]
'';
```

______________________________________________________________________

## Performance Characteristics

### Path Existence Checks

```
Each call to discoverWithHierarchy makes:
  - 0-3 pathExists calls (one per tier if reached)
  - 1-3 findAppInPath calls (recursive directory scans)
  
Typical case (found at tier 1):
  - 1 pathExists call
  - 1 recursive directory scan
  - STOP (first match)

Worst case (found at tier 3):
  - 3 pathExists calls
  - 3 recursive directory scans
  - SCAN entire shared/ directory
```

### Optimization Notes

1. **Tier 2 Conditional**: Only evaluated if flavor != null, saves a pathExists call
1. **First-Match Semantics**: Stops searching immediately, doesn't scan all tiers
1. **Directory Caching**: `builtins.readDir` results can be cached by Nix evaluator
1. **Search Scope**: Each tier searches independently, no cross-tier overhead

### Benchmark Expectations

```
Current discovery system overhead: <50ms per configuration
Hierarchical search overhead: <20ms additional
  (one extra tier, but conditional on flavor)

Total evaluation time: Dominated by module system, not discovery
```

______________________________________________________________________

## Integration Checklist

- [ ] Add `discoverWithHierarchy` function to `discovery.nix`
- [ ] Add function to exports in `discovery.nix`
- [ ] Update `platform/darwin/lib/darwin.nix` to use hierarchical discovery
- [ ] Update `platform/nixos/lib/nixos.nix` to use hierarchical discovery (if exists)
- [ ] Create `platform/shared/flavor/` directory structure
- [ ] Migrate profiles to hosts in each platform
- [ ] Test application resolution with multiple tiers
- [ ] Test setting resolution with "default" keyword
- [ ] Test error messages for missing items
- [ ] Run `nix flake check` to validate all configurations
- [ ] Update documentation to reference hierarchy
- [ ] Update CLAUDE.md with new architecture

______________________________________________________________________

## Summary

The hierarchical discovery algorithm:

1. **Validates inputs** for correctness
1. **Constructs paths** for all three tiers
1. **Searches tiers in order** (platform → flavor → shared)
1. **Returns first match** immediately when found
1. **Returns null** if not found anywhere
1. **Delegates error handling** to caller for context-aware messages

The implementation is:

- **Pure**: No side effects, deterministic results
- **Efficient**: Stops at first match, conditional tier 2
- **Robust**: Comprehensive validation and error context
- **Clear**: Simple three-step algorithm, easy to understand
- **Extensible**: Can be reused for other item types in future
