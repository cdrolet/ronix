# Implementation Plan: App Discovery System

**Spec**: 014-app-discovery-system\
**Estimated Time**: 2-3 days\
**Complexity**: Medium

______________________________________________________________________

## Overview

Implement application discovery system that allows users to specify apps by name instead of manual imports. Core implementation involves extending `discovery.nix` with app resolution logic and creating an `applications.nix` module.

______________________________________________________________________

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────┐
│ User Config (user/cdrokar/default.nix)              │
│                                                      │
│  imports = [ ../shared/lib/applications.nix ];      │
│  applications = [ "git" "zsh" "aerospace" ];        │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ applications.nix Module                             │
│                                                      │
│  - Defines options.applications                     │
│  - Calls discovery.resolveApplications              │
│  - Converts app names → imports                     │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ discovery.nix (extended)                            │
│                                                      │
│  resolveApplications:                               │
│  - detectContext (caller location)                  │
│  - buildSearchPaths (priority order)                │
│  - resolveApp (find each app)                       │
│  - matchAppPath (recursive search)                  │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│ File System                                         │
│                                                      │
│  system/shared/app/**/*.nix                         │
│  system/darwin/app/**/*.nix                         │
│  system/nixos/app/**/*.nix                          │
└─────────────────────────────────────────────────────┘
```

______________________________________________________________________

## Implementation Phases

### Phase 1: Core Discovery Functions (MVP Foundation)

**Goal**: Add app resolution logic to `discovery.nix`

**Tasks**:

1. Add `resolveApplications` function to `discovery.nix`
1. Implement `detectContext` helper
1. Implement `buildSearchPaths` helper
1. Implement `resolveApp` helper
1. Implement `findAppInPath` recursive search
1. Add error handling with basic messages

**Deliverable**: `discovery.nix` exports `resolveApplications` function

**Testing**:

```nix
# Test in nix repl
discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
discovery.resolveApplications {
  apps = [ "git" "zsh" ];
  callerPath = ./user/cdrokar/default.nix;
}
# Expected: [ path/to/git.nix, path/to/zsh.nix ]
```

______________________________________________________________________

### Phase 2: Applications Module (Integration)

**Goal**: Create module that uses discovery functions

**Tasks**:

1. Create `system/shared/lib/applications.nix`
1. Define `options.applications` (list of strings)
1. Integrate with `resolveApplications`
1. Generate `imports` from resolved paths
1. Add module-level error handling

**Deliverable**: `applications.nix` module ready to import

**Testing**:

```nix
# Test in user config
{
  imports = [ ../shared/lib/applications.nix ];
  applications = [ "git" ];
}
# Build and verify git.nix imported
```

______________________________________________________________________

### Phase 3: User Story 1 - Simple App Declaration (P1 MVP)

**Goal**: Users can specify apps by simple names

**Tasks**:

1. Test with one user config (cdrokar)
1. Verify apps resolve correctly
1. Verify configuration builds
1. Verify Home Manager activates
1. Test with multiple apps (10+)

**Deliverable**: Working simple name resolution

**Validation**:

- ✅ `applications = [ "git" "zsh" "helix" ]` works
- ✅ All apps correctly imported
- ✅ Configuration builds successfully
- ✅ No duplicate imports

______________________________________________________________________

### Phase 4: User Story 2 - Platform-Specific Priority (P1 MVP)

**Goal**: Platform-specific apps prioritized correctly

**Tasks**:

1. Implement context detection (darwin vs nixos vs user)
1. Implement priority-based search path ordering
1. Test from Darwin profile
1. Test from user config
1. Verify platform-specific apps found first

**Deliverable**: Smart priority resolution

**Validation**:

- ✅ Darwin profile: `darwin/app/` searched before `shared/app/`
- ✅ User config: `shared/app/` searched before platform-specific
- ✅ Platform-specific apps correctly resolved

______________________________________________________________________

### Phase 5: User Story 3 - Path Disambiguation (P2)

**Goal**: Support partial and full paths

**Tasks**:

1. Implement path detection (contains "/")
1. Implement partial path matching
1. Implement full path matching
1. Test mixed name + path lists
1. Document disambiguation syntax

**Deliverable**: Path disambiguation working

**Validation**:

- ✅ `"darwin/aerospace"` finds `system/darwin/app/aerospace.nix`
- ✅ `"shared/app/dev/git"` finds exact path
- ✅ `"system/shared/app/dev/git"` finds exact path
- ✅ Mixed lists work: `[ "git" "darwin/aerospace" ]`

______________________________________________________________________

### Phase 6: User Story 4 - Error Messages (P2)

**Goal**: Helpful errors when apps not found

**Tasks**:

1. Implement error generation with searched paths
1. Implement fuzzy matching for suggestions
1. Format error messages clearly
1. Test various error scenarios
1. Document error troubleshooting

**Deliverable**: Clear, actionable error messages

**Validation**:

- ✅ Shows app name that failed
- ✅ Shows paths that were searched
- ✅ Suggests similar app names
- ✅ Shows caller location

______________________________________________________________________

### Phase 7: Documentation & Migration

**Goal**: Update docs and provide migration guide

**Tasks**:

1. Update README.md with applications pattern
1. Add examples to user config templates
1. Document migration from manual imports
1. Create migration checklist
1. Update architecture documentation

**Deliverable**: Complete documentation

______________________________________________________________________

### Phase 8: Testing & Validation

**Goal**: Comprehensive testing across all scenarios

**Tasks**:

1. Test all user configs
1. Test all profile types
1. Test error scenarios
1. Performance testing
1. Backward compatibility verification

**Deliverable**: Fully validated system

______________________________________________________________________

## Technical Implementation Details

### Function: `resolveApplications`

```nix
resolveApplications = {
  apps,        # List of app names/paths
  callerPath,  # Path of caller file
  basePath ? null,  # Repo root (auto-detected if null)
}: let
  # Auto-detect base path by climbing up from caller
  repoRoot = if basePath != null then basePath else findRepoRoot callerPath;
  
  # Detect caller context
  context = detectContext callerPath repoRoot;
  
  # Build prioritized search paths
  searchPaths = buildSearchPaths context repoRoot;
  
  # Resolve each app
  resolved = builtins.map (appName:
    let result = resolveApp appName searchPaths repoRoot;
    in if result == null 
       then throw (formatError appName searchPaths callerPath repoRoot)
       else result
  ) apps;
in
  resolved;
```

### Function: `detectContext`

```nix
detectContext = callerPath: basePath: let
  # Get path relative to repo root
  relPath = lib.removePrefix (toString basePath) (toString callerPath);
  
  # Pattern matching on path
  isDarwinProfile = lib.hasInfix "/system/darwin/profiles/" relPath;
  isNixosProfile = lib.hasInfix "/system/nixos/profiles/" relPath;
  isUserConfig = lib.hasInfix "/user/" relPath;
in {
  callerPath = callerPath;
  callerType = 
    if isDarwinProfile then "darwin-profile"
    else if isNixosProfile then "nixos-profile"
    else if isUserConfig then "user-config"
    else "unknown";
  platform = 
    if isDarwinProfile then "darwin"
    else if isNixosProfile then "nixos"
    else null;
  basePath = basePath;
};
```

### Function: `buildSearchPaths`

```nix
buildSearchPaths = context: basePath: let
  darwinAppPath = basePath + "/system/darwin/app";
  nixosAppPath = basePath + "/system/nixos/app";
  sharedAppPath = basePath + "/system/shared/app";
in
  if context.callerType == "darwin-profile" then
    [ darwinAppPath sharedAppPath ]
  else if context.callerType == "nixos-profile" then
    [ nixosAppPath sharedAppPath ]
  else if context.callerType == "user-config" then
    [ sharedAppPath ] 
    ++ (lib.optional (builtins.pathExists darwinAppPath) darwinAppPath)
    ++ (lib.optional (builtins.pathExists nixosAppPath) nixosAppPath)
  else
    [ sharedAppPath ];  # Default fallback
```

### Function: `resolveApp`

```nix
resolveApp = appName: searchPaths: basePath: let
  # Check if appName contains path separator
  hasPath = lib.hasInfix "/" appName;
  
  # Try each search path in order
  findInPaths = paths:
    if paths == [] then null
    else let
      result = if hasPath 
               then matchPartialPath appName (builtins.head paths) basePath
               else findAppInPath appName (builtins.head paths);
    in
      if result != null 
      then result 
      else findInPaths (builtins.tail paths);
in
  findInPaths searchPaths;
```

### Function: `findAppInPath`

```nix
findAppInPath = appName: searchPath: let
  # Recursive directory search
  searchDir = dir:
    if !builtins.pathExists dir then null
    else let
      entries = builtins.readDir dir;
      
      # Check for direct match: appName.nix
      directMatch = dir + "/${appName}.nix";
      hasDirectMatch = entries ? ${appName + ".nix"} or false;
      
      # Check for directory match: appName/default.nix
      dirMatch = dir + "/${appName}/default.nix";
      hasDirMatch = (entries ? ${appName} or false) && 
                    (entries.${appName} == "directory") &&
                    builtins.pathExists dirMatch;
      
      # Try subdirectories
      subdirs = lib.filterAttrs (n: v: v == "directory") entries;
      searchSubdirs = lib.findFirst 
        (subdir: (searchDir (dir + "/${subdir}")) != null)
        null
        (builtins.attrNames subdirs);
    in
      if hasDirectMatch then directMatch
      else if hasDirMatch then dirMatch
      else if searchSubdirs != null then searchDir (dir + "/${searchSubdirs}")
      else null;
in
  searchDir searchPath;
```

### Function: `matchPartialPath`

```nix
matchPartialPath = appPath: searchPath: basePath: let
  # Try to match partial path
  # "darwin/aerospace" should match "system/darwin/app/aerospace.nix"
  
  # Remove leading slash if present
  cleanPath = lib.removePrefix "/" appPath;
  
  # Try various combinations
  attempts = [
    searchPath + "/${cleanPath}.nix"
    searchPath + "/${cleanPath}/default.nix"
    basePath + "/${cleanPath}.nix"
    basePath + "/${cleanPath}/default.nix"
  ];
  
  # Find first existing path
  lib.findFirst builtins.pathExists null attempts;
in
  matchPath;
```

______________________________________________________________________

## Error Handling Strategy

### Error Types

1. **App Not Found**: Search all paths, no match
1. **Ambiguous Match**: Multiple apps with same name (future)
1. **Invalid Path**: Path format invalid

### Error Message Format

```
error: Application 'appName' not found

Searched locations:
  - system/darwin/app/appName.nix (not found)
  - system/shared/app/**/appName.nix (not found)

Did you mean one of these?
  - similarApp1 (system/darwin/app/similarApp1.nix)
  - similarApp2 (system/shared/app/dev/similarApp2.nix)

Called from: user/cdrokar/default.nix

Tip: Use partial path for disambiguation: "darwin/appName"
```

### Fuzzy Matching (Simple Implementation)

```nix
# Calculate similarity using Levenshtein distance (simplified)
fuzzyMatch = searchTerm: availableApps: let
  # For MVP: simple prefix/suffix matching
  matches = lib.filter (app: 
    lib.hasPrefix searchTerm app || 
    lib.hasSuffix searchTerm app ||
    lib.hasInfix searchTerm app
  ) availableApps;
in
  lib.take 3 matches;  # Top 3 suggestions
```

______________________________________________________________________

## Performance Considerations

### Optimization Strategies

1. **Early Exit**: Stop searching on first match
1. **Path Existence Checks**: Skip non-existent directories
1. **Lazy Evaluation**: Only search when needed
1. **Memoization**: Cache results within build (future)

### Expected Performance

- **Small configs (1-10 apps)**: < 50ms
- **Medium configs (10-30 apps)**: < 200ms
- **Large configs (30+ apps)**: < 500ms

### Benchmarking

```bash
# Before implementation
time nix eval .#darwinConfigurations.user-profile.config.imports

# After implementation
time nix eval .#darwinConfigurations.user-profile.config.imports
# Should be within 10% of baseline
```

______________________________________________________________________

## Migration Strategy

### Phase 1: Opt-In (Week 1)

- Feature available but not required
- Users can try on one config
- Gather feedback

### Phase 2: Documentation (Week 2)

- Update all docs
- Add migration guide
- Create examples

### Phase 3: Gradual Adoption (Weeks 3-4)

- Migrate one user config per day
- Monitor for issues
- Refine based on feedback

### Phase 4: Complete (Month 2+)

- All configs migrated (optional)
- Manual imports still supported
- Pattern documented

______________________________________________________________________

## Testing Plan

### Unit Tests (Nix REPL)

```nix
# Test 1: Simple name resolution
let
  discovery = import ./system/shared/lib/discovery.nix { inherit lib; };
in discovery.resolveApplications {
  apps = [ "git" ];
  callerPath = ./user/test/default.nix;
}
# Expected: [ /.../system/shared/app/dev/git.nix ]

# Test 2: Platform priority
discovery.resolveApplications {
  apps = [ "aerospace" ];
  callerPath = ./system/darwin/profiles/test/default.nix;
}
# Expected: [ /.../system/darwin/app/aerospace.nix ]

# Test 3: Partial path
discovery.resolveApplications {
  apps = [ "darwin/aerospace" ];
  callerPath = ./user/test/default.nix;
}
# Expected: [ /.../system/darwin/app/aerospace.nix ]

# Test 4: Error handling
discovery.resolveApplications {
  apps = [ "nonexistent" ];
  callerPath = ./user/test/default.nix;
}
# Expected: Error with suggestions
```

### Integration Tests

```bash
# Test 1: User config with applications list
cd /Users/charles/project/nix-config
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system

# Test 2: Verify imports match expectations
nix eval .#darwinConfigurations.cdrokar-home-macmini-m4.config.imports
# Should include all apps from applications list

# Test 3: Mixed manual + auto imports
# Config with both imports = [...] and applications = [...]
nix build .#darwinConfigurations.test-mixed.system

# Test 4: Error handling
# Config with applications = [ "nonexistent" ]
nix build .#darwinConfigurations.test-error.system
# Should show helpful error message
```

______________________________________________________________________

## Rollback Plan

If issues arise:

1. **Immediate**: Users can revert to manual imports
1. **Short-term**: Keep both patterns working
1. **Long-term**: Fix issues, don't remove feature

**No Breaking Changes**: Feature is purely additive

______________________________________________________________________

## Success Metrics

### Must Achieve

- ✅ Simple names resolve correctly (100% success rate)
- ✅ Platform priority works (darwin before shared)
- ✅ Configuration builds successfully
- ✅ No performance regression (< 10% slower)
- ✅ Clear error messages
- ✅ Backward compatible (100%)

### Nice to Have

- ⚪ < 5% build time increase
- ⚪ Fuzzy matching with Levenshtein distance
- ⚪ Performance caching
- ⚪ 80%+ user adoption in 1 month

______________________________________________________________________

## Risk Mitigation

### Risk: Ambiguous app names

**Mitigation**:

- Clear priority rules
- Partial path disambiguation
- Document naming conventions

### Risk: Performance degradation

**Mitigation**:

- Benchmark before/after
- Early exit optimization
- Path existence checks

### Risk: Complex error messages

**Mitigation**:

- Clear format with examples
- Show searched paths
- Provide suggestions

______________________________________________________________________

## Timeline

### Week 1: Core Implementation

- Day 1-2: Phase 1 (Discovery functions)
- Day 3-4: Phase 2 (Applications module)
- Day 5: Phase 3 (Simple names - MVP)

### Week 2: Feature Complete

- Day 1-2: Phase 4 (Platform priority)
- Day 3: Phase 5 (Path disambiguation)
- Day 4-5: Phase 6 (Error messages)

### Week 3: Documentation & Testing

- Day 1-2: Phase 7 (Documentation)
- Day 3-5: Phase 8 (Testing & validation)

**Total**: 2-3 weeks for full implementation

______________________________________________________________________

## Dependencies

### Required

- Spec 013: discovery.nix infrastructure ✅
- Existing app organization ✅
- Nix module system knowledge ✅

### Optional

- Performance profiling tools
- Fuzzy matching library (for better suggestions)

______________________________________________________________________

## Future Enhancements

Post-MVP features (not in this implementation):

1. **App Groups**: Reusable app collections
1. **Conditional Apps**: Platform-aware lists
1. **Dependency Resolution**: Auto-include dependencies
1. **App Metadata**: Expose app information
1. **Validation**: Warn about platform incompatibilities
1. **Wildcards**: Support `"dev/*"` patterns
1. **Aliases**: Map old names to new names

______________________________________________________________________

## References

- Spec 014: [spec.md](./spec.md)
- Data Model: [data-model.md](./data-model.md)
- Quickstart: [quickstart.md](./quickstart.md)
- Spec 013: discovery.nix foundation
