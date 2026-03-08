# Research Summary: Hierarchical Discovery Pattern

## Feature 021: Host/Flavor Architecture

**Research Task**: Design hierarchical discovery function for host/flavor architecture\
**Completion Date**: 2025-12-03\
**Status**: Ready for Implementation

______________________________________________________________________

## Quick Answers to Research Questions

### 1. How should the hierarchical discovery function work?

**Answer**: Three-tier search with first-match semantics.

```
Tier 1: platform/{platform}/{itemType}/           (platform-specific)
Tier 2: platform/shared/flavor/{flavor}/{itemType} (flavor-specific, optional)
Tier 3: platform/shared/{itemType}/               (shared fallback)
```

Returns immediately on first match. Returns null if not found in any tier.

**Why this approach**:

- Matches user expectations for overrides (platform > flavor > shared)
- Follows existing darwin/settings/default.nix pattern
- Simple and predictable
- First-match prevents merge complexity

______________________________________________________________________

### 2. What parameters does it need?

**Answer**: Single record parameter with five named fields:

```nix
discoverWithHierarchy = {
  itemName,           # String: name of app/setting to find
  itemType,           # String: "app" or "setting"
  platform,           # String: "darwin" or "nixos"
  flavor ? null,      # String or null: optional flavor name
  basePath,           # Path: repository root
}:
```

**Why record parameters**:

- Self-documenting call sites
- Prevents argument order errors
- Handles optional parameters elegantly
- Matches Nix conventions

______________________________________________________________________

### 3. Should it return first match or collect all matches?

**Answer**: First match only.

**Why**:

- Simpler semantics (no ambiguous merging)
- Matches user expectations (override, don't merge)
- Follows existing discovery patterns
- Prevents unexpected behavior

**Example**:

```
Search for "git" app with darwin/work flavor:
  1. platform/darwin/app/dev/git.nix ✅ FOUND
  → Return immediately, don't check flavor or shared
```

______________________________________________________________________

### 4. How to handle null/missing flavor?

**Answer**: Cleanly skip tier 2 using optional parameter and conditional logic.

```nix
flavor ? null,              # Default to null if omitted

# Later in algorithm:
if flavor != null && flavor != "" then
  tier2Result = search(flavorPath)
else
  tier2Result = null        # Skip tier 2 entirely
```

**Behavior**:

- `flavor = null` → Skip tier 2
- `flavor = ""` → Skip tier 2 (same as null)
- `flavor = "work"` → Search tier 2 at `platform/shared/flavor/work/{itemType}`

No special markers or sentinel values needed.

______________________________________________________________________

### 5. What's the cleanest function signature?

**Answer**: The proposed signature above.

```nix
discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,
  basePath,
}:
```

**Benefits**:

- Single responsibility (resolve one item)
- Named parameters prevent errors
- Clear input/output contract
- Easy to test and reason about
- Matches Nix idioms

______________________________________________________________________

## Proposed Function Signature

```nix
# Resolve an item (app or setting) using hierarchical search across platform/flavor/shared
#
# Type: discoverWithHierarchy :: {
#   itemName :: String,             # Name of item to find
#   itemType :: "app" | "setting",  # Type of item
#   platform :: String,             # Platform name
#   flavor :: String | null,        # Optional flavor reference
#   basePath :: Path,               # Repository root
# } → Path | null
#
# Search order (returns on first match):
#   1. platform/{platform}/{itemType}/{itemName}
#   2. platform/shared/flavor/{flavor}/{itemType}/{itemName}  (if flavor provided)
#   3. platform/shared/{itemType}/{itemName}
#
# Returns: Absolute path to first match, or null if not found
#
# Example: Find "git" app on darwin with "work" flavor
#   discoverWithHierarchy {
#     itemName = "git";
#     itemType = "app";
#     platform = "darwin";
#     flavor = "work";
#     basePath = /repo;
#   }
#   → /repo/platform/shared/app/dev/git.nix (or darwin-specific version)

discoverWithHierarchy = {
  itemName,
  itemType,
  platform,
  flavor ? null,
  basePath,
}: let
  # Input validation
  validationErrors = lib.flatten [
    (if !lib.isString itemName || itemName == "" then 
      ["itemName must be non-empty string"] else [])
    (if !builtins.elem itemType ["app" "setting"] then 
      ["itemType must be 'app' or 'setting'"] else [])
    (if !lib.isString platform || platform == "" then 
      ["platform must be non-empty string"] else [])
    (if flavor != null && (!lib.isString flavor || flavor == "") then 
      ["flavor must be non-empty string or null"] else [])
  ];
  
  _ = if validationErrors != [] then
    throw "discoverWithHierarchy: Invalid arguments\n${lib.concatStringsSep "\n"
      (map (e: "  - ${e}") validationErrors)}"
    else null;

  # Tier 1: Platform-specific
  tier1Path = basePath + "/platform/${platform}/${itemType}";
  tier1Result = 
    if builtins.pathExists tier1Path
    then findAppInPath itemName tier1Path
    else null;

  # Tier 2: Flavor-specific (conditional)
  flavorPath = basePath + "/platform/shared/flavor/${flavor}/${itemType}";
  tier2Result = 
    if flavor != null && flavor != "" && builtins.pathExists flavorPath
    then findAppInPath itemName flavorPath
    else null;

  # Tier 3: Shared fallback
  tier3Path = basePath + "/platform/shared/${itemType}";
  tier3Result = 
    if builtins.pathExists tier3Path
    then findAppInPath itemName tier3Path
    else null;

in
  # Return first match (short-circuit evaluation)
  if tier1Result != null then tier1Result
  else if tier2Result != null then tier2Result
  else tier3Result
```

______________________________________________________________________

## Search Algorithm Pseudocode

```
ALGORITHM discoverWithHierarchy(params)

  INPUT:  {itemName, itemType, platform, flavor?, basePath}
  OUTPUT: Path | null

  # Validation Phase
  FOR EACH error IN validateInputs(params):
    THROW error description

  # Path Construction Phase
  tier1Path := basePath + "/platform/" + platform + "/" + itemType
  IF flavor != null AND flavor != "" THEN
    tier2Path := basePath + "/platform/shared/flavor/" + flavor + "/" + itemType
  ELSE
    tier2Path := null

  tier3Path := basePath + "/platform/shared/" + itemType

  # Search Phase (stop at first match)
  IF pathExists(tier1Path) THEN
    result := findAppInPath(itemName, tier1Path)
    IF result != null THEN
      RETURN result

  IF tier2Path != null AND pathExists(tier2Path) THEN
    result := findAppInPath(itemName, tier2Path)
    IF result != null THEN
      RETURN result

  IF pathExists(tier3Path) THEN
    result := findAppInPath(itemName, tier3Path)
    RETURN result  # May be null

  RETURN null

END ALGORITHM
```

______________________________________________________________________

## Error Handling Approach

**Three-Layer Strategy**:

1. **Input Validation** (by function)

   - Validates types, ranges, and required fields
   - Throws immediately with specific error

1. **Search Execution** (by function)

   - Returns null if item not found
   - No error thrown (caller decides if critical)

1. **Caller Context** (by platform library)

   - Determines if null is an error (strict) or skip (lenient)
   - Provides helpful error messages with context

**Example Error Message**:

```
Application 'vscode' not found in darwin hierarchy

Searched (in order):
  1. platform/darwin/app/
  2. platform/shared/flavor/work/app/  (flavor = "work")
  3. platform/shared/app/

Available applications: git, zsh, helix, aerospace, borders
Did you mean one of these?

Tip: Add vscode to one of the search paths or check spelling
```

______________________________________________________________________

## Integration Points

### 1. Discovery System (`platform/shared/lib/discovery.nix`)

Add `discoverWithHierarchy` function and export it:

```nix
{
  inherit
    discoverUsers
    discoverProfiles
    discoverModules
    ...
    discoverWithHierarchy;  # NEW
}
```

**No changes needed to existing functions** - reuses `findAppInPath`.

### 2. Platform Libraries (`platform/darwin/lib/darwin.nix`, etc.)

Use hierarchical discovery when loading host configurations:

```nix
let
  # Load host data as pure data
  hostData = import ../host/${hostName} { };
  
  # Extract before module eval (Feature 020 pattern)
  hostFlavor = hostData.flavor or null;
  hostApps = hostData.applications or [];
  hostSettings = hostData.settings or [];
  
  # Resolve using hierarchy
  appPaths = map (appName: 
    discovery.discoverWithHierarchy {
      itemName = appName;
      itemType = "app";
      inherit platform hostFlavor;
      basePath = repoRoot;
    }
  ) hostApps;
in
  { home-manager.users.${user}.imports = [ ... appPaths ... ]; }
```

**No changes to user config pattern** (Feature 020 unchanged).

______________________________________________________________________

## Relationship to Feature 020

| Aspect | Feature 020 | Feature 021 |
|--------|------------|------------|
| **Scope** | User applications only | System + flavor configuration |
| **Pure Data** | ✅ User config attributes | ✅ Host config attributes |
| **Extraction** | Before module eval | Before module eval |
| **Search Pattern** | 2-level (platform → shared) | 3-level (platform → flavor → shared) |
| **Discovery** | `mkApplicationsModule` | `discoverWithHierarchy` |
| **Error Handling** | Application registry | Hierarchical search results |

Feature 021 **mirrors and extends** Feature 020 - same philosophy, broader scope.

______________________________________________________________________

## Implementation Checklist

**Discovery System**:

- [ ] Add `discoverWithHierarchy` function to `discovery.nix`
- [ ] Validate all input parameters
- [ ] Implement three-tier search logic
- [ ] Provide null return for not found
- [ ] Add comprehensive documentation

**Platform Libraries**:

- [ ] Update `darwin.nix` to load hosts as pure data
- [ ] Update `darwin.nix` to use hierarchical discovery for apps
- [ ] Update `darwin.nix` to use hierarchical discovery for settings
- [ ] Handle "default" keyword for settings
- [ ] Add validation errors for "\*" in settings array

**Directory Structure**:

- [ ] Create `platform/shared/flavor/` directory
- [ ] Rename `platform/darwin/profiles/` to `platform/darwin/host/`
- [ ] Rename `platform/nixos/profiles/` to `platform/nixos/host/` (if exists)

**Testing**:

- [ ] Test app found at tier 1 (platform-specific)
- [ ] Test app found at tier 2 (flavor-specific)
- [ ] Test app found at tier 3 (shared)
- [ ] Test setting with "default" keyword
- [ ] Test error message for missing item
- [ ] Test validation error for invalid inputs
- [ ] Run `nix flake check` successfully
- [ ] Verify builds don't break

______________________________________________________________________

## Key Design Decisions

1. **First-Match Semantics**: Stop at first match, don't collect all
1. **Optional Flavor**: Skip tier 2 cleanly when flavor is null
1. **Record Parameters**: Single named parameter set for clarity
1. **Reuse Existing Functions**: Leverage `findAppInPath`, `builtins.pathExists`
1. **Error Handling**: Validation by function, context by caller
1. **Settings Special Case**: "default" keyword imports all platform settings, not "\*"

______________________________________________________________________

## Ready for Implementation

All research questions answered. Design is:

- ✅ **Complete**: All requirements addressed
- ✅ **Pragmatic**: Uses existing primitives, no new infrastructure
- ✅ **Clear**: Simple three-tier algorithm
- ✅ **Extensible**: Integrates with platform libraries naturally
- ✅ **Proven**: Mirrors successful Feature 020 pattern

**Next Phase**: Implementation in `discovery.nix` and platform libraries.

______________________________________________________________________

## Documentation Files Created

1. **DISCOVERY-RESEARCH.md** - Comprehensive research document

   - Current system analysis
   - Feature 020 pattern study
   - Detailed design rationale
   - Complete examples and validation
   - Relationship to existing patterns

1. **DISCOVERY-ALGORITHM.md** - Algorithm implementation guide

   - Detailed pseudocode
   - Search diagrams
   - Integration points
   - Edge case handling
   - Performance analysis
   - Implementation checklist

1. **RESEARCH-SUMMARY.md** - This file

   - Quick answers to all research questions
   - Proposed function signature
   - Algorithm pseudocode
   - Error handling approach
   - Integration points summary
   - Implementation readiness

______________________________________________________________________

**Research completed**: 2025-12-03\
**Status**: Ready for Phase 1 (Implementation Planning)
