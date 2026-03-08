# Spec 014: App Discovery System

**Status**: Draft\
**Priority**: P1 (High Impact - Developer Experience)\
**Estimated Effort**: 2-3 days\
**Dependencies**: Spec 013 (uses existing discovery.nix infrastructure)

______________________________________________________________________

## Overview

Replace manual app imports with a declarative app discovery system that allows users and profiles to specify apps by name instead of complex file paths.

### Problem Statement

**Current State**: Users must manually import app modules with fragile paths:

```nix
# user/cdrokar/default.nix
{
  imports = [
    ../../system/shared/app/dev/git.nix
    ../../system/shared/app/dev/sdkman.nix
    ../../system/shared/app/shell/zsh.nix
    ../../system/shared/app/shell/starship.nix
    ../../system/darwin/app/aerospace.nix
    ../../system/darwin/app/borders.nix
    # ... more apps
  ];
}
```

**Issues**:

- ❌ Fragile relative paths break when files move
- ❌ Developer must know exact location of every app
- ❌ Path differs between user configs and profile configs
- ❌ No disambiguation when apps exist in multiple locations
- ❌ Error-prone manual maintenance of import lists

**Desired State**: Simple declarative app list:

```nix
# user/cdrokar/default.nix
{
  applications = [
    "git"
    "sdkman"
    "zsh"
    "starship"
    "aerospace"
    "borders"
  ];
}
```

______________________________________________________________________

## Goals

### Primary Goals

1. **Simplify App Declaration**: Replace complex imports with simple name-based lists
1. **Auto-Discovery**: Automatically find app modules by name
1. **Location Independence**: Work from any location (user configs, profiles, etc.)
1. **Smart Resolution**: Prioritize apps closer to caller (darwin/app before shared/app)
1. **Backward Compatible**: Existing manual imports continue to work

### Secondary Goals

1. **Path Disambiguation**: Support optional paths when same app exists in multiple locations
1. **Clear Error Messages**: Helpful errors when app not found
1. **Performance**: Fast discovery (cached when possible)
1. **Extensibility**: Easy to add new search locations

______________________________________________________________________

## User Stories

### User Story 1: Simple App Declaration (P1) 🎯 MVP

**As a** user configuring my system\
**I want to** specify apps by simple names\
**So that** I don't need to know or maintain complex file paths

**Acceptance Criteria**:

- ✅ Can specify apps as simple string list: `["git", "zsh", "helix"]`
- ✅ System automatically finds and imports corresponding `.nix` files
- ✅ Works in both user configs (`user/*/default.nix`) and profiles (`system/*/profiles/*/default.nix`)
- ✅ Clear error message if app not found

**Examples**:

```nix
# user/cdrokar/default.nix
{
  applications = [
    "git"
    "sdkman"
    "zsh"
    "starship"
    "bat"
    "atuin"
    "helix"
  ];
}
```

System automatically resolves to:

- `git` → `system/shared/app/dev/git.nix`
- `sdkman` → `system/shared/app/dev/sdkman.nix`
- `zsh` → `system/shared/app/shell/zsh.nix`
- etc.

______________________________________________________________________

### User Story 2: Platform-Specific App Priority (P1) 🎯 MVP

**As a** Darwin profile\
**I want** platform-specific apps to take precedence\
**So that** I get the right app when names collide

**Acceptance Criteria**:

- ✅ When app exists in both `darwin/app/` and `shared/app/`, Darwin profile gets `darwin/app/` version
- ✅ When app exists in both `nixos/app/` and `shared/app/`, NixOS profile gets `nixos/app/` version
- ✅ Search prioritizes closest "app" folder first (bottom-up search)

**Priority Order** (from Darwin profile):

1. `system/darwin/app/` (closest)
1. `system/shared/app/`
1. (Error if not found)

**Priority Order** (from user config):

1. `system/shared/app/` (closest shared location)
1. `system/darwin/app/` (if darwin exists)
1. `system/nixos/app/` (if nixos exists)
1. (Error if not found)

______________________________________________________________________

### User Story 3: Path Disambiguation (P2)

**As a** user with apps that have the same name\
**I want to** specify partial or full paths\
**So that** I can choose the correct app

**Acceptance Criteria**:

- ✅ Can specify partial path: `"darwin/aerospace"` → `system/darwin/app/aerospace.nix`
- ✅ Can specify full path: `"system/shared/app/dev/git"` → exact match
- ✅ Can mix names and paths in same list

**Examples**:

```nix
{
  applications = [
    "git"                              # Auto-discovered
    "darwin/aerospace"                 # Partial path (finds system/darwin/app/aerospace.nix)
    "shared/app/shell/zsh"             # Partial path
    "system/shared/app/editor/helix"   # Full path (from repo root)
  ];
}
```

______________________________________________________________________

### User Story 4: Clear Error Messages (P2)

**As a** developer configuring apps\
**I want** helpful error messages when apps aren't found\
**So that** I can quickly fix configuration issues

**Acceptance Criteria**:

- ✅ Error shows which app name failed
- ✅ Error shows search paths that were checked
- ✅ Error suggests similar app names (fuzzy match)
- ✅ Build fails immediately (fail-fast)

**Example Error**:

```
error: Application 'aerospacee' not found

Searched locations:
  - system/darwin/app/aerospacee.nix (not found)
  - system/shared/app/**/aerospacee.nix (not found)

Did you mean one of these?
  - aerospace (system/darwin/app/aerospace.nix)
  - airflow (system/shared/app/dev/airflow.nix)

Called from: user/cdrokar/default.nix:15
```

______________________________________________________________________

### User Story 5: Performance Optimization (P3)

**As a** system builder\
**I want** app discovery to be fast\
**So that** builds complete quickly

**Acceptance Criteria**:

- ✅ Discovery results cached per build
- ✅ No performance regression compared to manual imports
- ✅ Lazy evaluation where possible

______________________________________________________________________

## Technical Design

### Discovery Algorithm

**Function**: `resolveApplications :: [String] -> [Path]`

**Algorithm**:

```
For each app name in applications list:
  1. Determine caller context (user config vs profile)
  2. Build search path list based on context
  3. For each search path (in priority order):
     a. If app name contains "/" → match partial path
     b. Otherwise → recursively search for <name>.nix in app folders
  4. Return first match or error with suggestions
```

**Search Path Priority**:

From **Darwin Profile** (`system/darwin/profiles/*/default.nix`):

1. `system/darwin/app/` (same platform)
1. `system/shared/app/` (shared)

From **NixOS Profile** (`system/nixos/profiles/*/default.nix`):

1. `system/nixos/app/` (same platform)
1. `system/shared/app/` (shared)

From **User Config** (`user/*/default.nix`):

1. `system/shared/app/` (platform-agnostic)
1. `system/darwin/app/` (if exists)
1. `system/nixos/app/` (if exists)

### Implementation Structure

**New Function in `system/shared/lib/discovery.nix`**:

```nix
resolveApplications = {
  apps,           # List of app names/paths
  callerPath,     # Path of file calling this function
  basePath ? ./../../..,  # Repository root
}: let
  # Determine caller context (user config, darwin profile, nixos profile)
  callerContext = detectContext callerPath;
  
  # Build search paths based on context
  searchPaths = buildSearchPaths callerContext basePath;
  
  # Resolve each app
  resolvedApps = map (appName: 
    resolveApp appName searchPaths basePath
  ) apps;
in
  resolvedApps;
```

**New Module: `system/shared/lib/applications.nix`**:

```nix
{ config, lib, ... }:

{
  options.applications = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "List of application names to import";
    example = [ "git" "zsh" "helix" "darwin/aerospace" ];
  };

  config = lib.mkIf (config.applications != []) {
    imports = 
      let
        discovery = import ./discovery.nix { inherit lib; };
        callerPath = ./.;  # Will be overridden by actual caller
      in
        discovery.resolveApplications {
          apps = config.applications;
          inherit callerPath;
        };
  };
}
```

______________________________________________________________________

## Data Model

See [data-model.md](./data-model.md) for detailed data structures.

### App Name Formats

```nix
# Format 1: Simple name (auto-discovered)
"git"  # Resolves to: system/shared/app/dev/git.nix

# Format 2: Partial path (disambiguation)
"darwin/aerospace"  # Resolves to: system/darwin/app/aerospace.nix
"shared/app/dev/git"  # Resolves to: system/shared/app/dev/git.nix

# Format 3: Full path (explicit)
"system/shared/app/editor/helix"  # Exact match from repo root

# Format 4: With .nix extension (also supported)
"git.nix"  # Resolves to: system/shared/app/dev/git.nix
```

### Search Result Structure

```nix
{
  appName = "git";
  resolvedPath = /nix/store/.../system/shared/app/dev/git.nix;
  searchPaths = [
    "system/darwin/app/git.nix"
    "system/shared/app/**/git.nix"  # ← matched here
  ];
  matchType = "recursive-search";  # or "partial-path" or "exact-path"
}
```

______________________________________________________________________

## Migration Strategy

### Phase 1: Add Discovery Function (Non-Breaking)

1. Add `resolveApplications` to `discovery.nix`
1. Create `applications.nix` module
1. Test with single user config
1. Verify backward compatibility

### Phase 2: Opt-In Migration

1. Update one user config to use `applications = []`
1. Validate all apps resolve correctly
1. Document pattern in README.md
1. Let users opt-in gradually

### Phase 3: Full Migration (Optional)

1. Migrate all user configs
1. Migrate profile configs
1. Update documentation
1. Consider deprecating manual imports

### Backward Compatibility

✅ **100% Backward Compatible**

- Existing `imports = [ ... ]` continue to work
- `applications = []` is opt-in
- Both can coexist in same config
- No breaking changes to existing configs

______________________________________________________________________

## Examples

### Before (Manual Imports)

```nix
# user/cdrokar/default.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../shared/lib/home-manager.nix
    ../../system/shared/app/dev/git.nix
    ../../system/shared/app/dev/sdkman.nix
    ../../system/shared/app/shell/zsh.nix
    ../../system/shared/app/shell/starship.nix
    ../../system/shared/app/shell/bat.nix
    ../../system/shared/app/shell/atuin.nix
    ../../system/shared/app/shell/ghostty.nix
    ../../system/shared/app/editor/helix.nix
    ../../system/darwin/app/aerospace.nix
    ../../system/darwin/app/borders.nix
  ];

  user.name = "cdrokar";
  user.email = "charles@example.com";
  user.fullName = "Charles Drolet";
}
```

### After (Auto-Discovery)

```nix
# user/cdrokar/default.nix
{ config, pkgs, lib, ... }:

{
  imports = [
    ../shared/lib/home-manager.nix
    ../shared/lib/applications.nix  # Enable app discovery
  ];

  # Simple app list - no paths needed!
  applications = [
    # Shared apps (auto-discovered in system/shared/app/)
    "git"
    "sdkman"
    "zsh"
    "starship"
    "bat"
    "atuin"
    "ghostty"
    "helix"
    
    # Platform-specific apps (auto-discovered in system/darwin/app/)
    "aerospace"
    "borders"
  ];

  user.name = "cdrokar";
  user.email = "charles@example.com";
  user.fullName = "Charles Drolet";
}
```

**Reduction**: 11 import lines → 1 import + simple list

______________________________________________________________________

## Testing Strategy

### Unit Tests

```nix
# Test 1: Simple name resolution
resolveApplications { apps = ["git"]; callerPath = ./user/cdrokar; }
# Expected: [ /nix/store/.../system/shared/app/dev/git.nix ]

# Test 2: Platform-specific priority
resolveApplications { apps = ["aerospace"]; callerPath = ./system/darwin/profiles/home; }
# Expected: [ /nix/store/.../system/darwin/app/aerospace.nix ]

# Test 3: Partial path disambiguation
resolveApplications { apps = ["darwin/aerospace"]; callerPath = ./user/cdrokar; }
# Expected: [ /nix/store/.../system/darwin/app/aerospace.nix ]

# Test 4: App not found
resolveApplications { apps = ["nonexistent"]; callerPath = ./user/cdrokar; }
# Expected: Error with suggestions

# Test 5: Mixed names and paths
resolveApplications { 
  apps = ["git", "darwin/aerospace", "system/shared/app/shell/zsh"];
  callerPath = ./user/cdrokar;
}
# Expected: [ git.nix, aerospace.nix, zsh.nix ]
```

### Integration Tests

1. **Test Scenario**: User config with 10 apps

   - Verify all apps resolve correctly
   - Verify configuration builds
   - Verify Home Manager activates

1. **Test Scenario**: Darwin profile with platform-specific apps

   - Verify darwin apps prioritized over shared
   - Verify configuration builds
   - Verify nix-darwin activates

1. **Test Scenario**: Mixed manual imports + applications list

   - Verify both work together
   - Verify no duplicate imports

______________________________________________________________________

## Success Criteria

### Must Have (MVP)

- ✅ Users can specify apps as simple names
- ✅ Platform-specific apps automatically prioritized
- ✅ Clear error messages when app not found
- ✅ 100% backward compatible with existing imports
- ✅ Works from both user configs and profiles
- ✅ Documentation updated with examples

### Should Have

- ✅ Partial path disambiguation
- ✅ Performance: no significant build time increase (\<5%)
- ✅ Helpful error suggestions (fuzzy matching)

### Nice to Have

- ⚪ Result caching for repeated builds
- ⚪ Migration tool to convert existing imports
- ⚪ Validation warnings for deprecated patterns

______________________________________________________________________

## Risks & Mitigation

### Risk 1: Performance Degradation

**Impact**: Medium\
**Likelihood**: Low

**Mitigation**:

- Cache discovery results per build
- Use Nix's lazy evaluation
- Benchmark before/after
- Only search when `applications` list provided

### Risk 2: Ambiguous App Names

**Impact**: Low\
**Likelihood**: Medium

**Mitigation**:

- Clear priority rules (closer wins)
- Support partial paths for disambiguation
- Error messages show all matches
- Document naming conventions

### Risk 3: Complex Error Messages

**Impact**: Low\
**Likelihood**: Medium

**Mitigation**:

- Show searched paths
- Suggest similar names (fuzzy match)
- Show caller location
- Document troubleshooting steps

______________________________________________________________________

## Open Questions

1. **Q**: Should we support wildcards (e.g., `"dev/*"`)?
   **A**: Defer to future enhancement (complexity > value for MVP)

1. **Q**: Should we cache discovery results across builds?
   **A**: Profile first, optimize only if needed (likely not needed)

1. **Q**: Should we validate app compatibility (e.g., darwin apps in NixOS)?
   **A**: Yes, but as a warning not error (future enhancement)

1. **Q**: Should we support app aliases (e.g., `"vim" → "helix"`)?
   **A**: Defer to future enhancement (use simple name mapping in user config for now)

______________________________________________________________________

## Future Enhancements

### Post-MVP Features

1. **App Groups**: Define reusable app collections

   ```nix
   appGroups.development = [ "git" "helix" "zsh" ];
   applications = appGroups.development ++ [ "aerospace" ];
   ```

1. **Conditional Apps**: Platform-aware app lists

   ```nix
   applications = [
     "git"
     "zsh"
   ] ++ lib.optionals pkgs.stdenv.isDarwin [
     "aerospace"
     "borders"
   ];
   ```

1. **App Metadata**: Expose app information

   ```nix
   apps.git.description
   apps.git.dependencies
   apps.git.platform
   ```

1. **Dependency Resolution**: Auto-include dependencies

   ```nix
   applications = [ "aerospace" ];
   # Automatically includes "borders" if aerospace depends on it
   ```

______________________________________________________________________

## References

- **Constitution**: `.specify/memory/constitution.md` v2.0.0 (app-centric organization)
- **Spec 013**: Refactor system structure (discovery.nix foundation)
- **Spec 010**: Repo restructure (current app organization)
- **Nix Manual**: Module system, imports, discovery patterns

______________________________________________________________________

## Appendix

### Related Specs

- Spec 010: Repo restructure (established app organization)
- Spec 013: System structure refactor (created discovery.nix)

### File Structure Impact

**New Files**:

- `system/shared/lib/applications.nix` (application option module)

**Modified Files**:

- `system/shared/lib/discovery.nix` (add resolveApplications function)
- User configs (optional migration to applications list)
- README.md (document new pattern)

**No Breaking Changes**: All existing imports continue to work
