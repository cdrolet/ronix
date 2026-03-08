# Research: Simplified Application Configuration

**Feature**: 020-app-array-config\
**Date**: 2025-11-30\
**Status**: Complete

## Overview

This document consolidates research findings for implementing simplified application configuration in user files. The research focuses on API design patterns, validation strategies, and integration approaches with the existing Home Manager bootstrap and discovery system.

## Research Questions

1. How should the `applications` field be structured in the user configuration?
1. What validation is needed for the applications array?
1. How does the bootstrap library access userContext for discovery?
1. What error handling strategy provides the best user experience?
1. How do we ensure backward compatibility?

## Findings

### 1. User Configuration API Design

**Decision**: Use `user.applications` as an optional list of strings

**Rationale**:

- **Consistency**: Matches existing user structure pattern (`user.name`, `user.email`, `user.fullName`)
- **Discoverability**: IDE/LSP autocomplete naturally shows `applications` alongside other user fields
- **Type safety**: Nix type system validates list of strings at evaluation time
- **Simplicity**: Users only need to know application names, not discovery internals

**Implementation Pattern**:

```nix
user = {
  name = "cdrolet";
  email = "cdrolet@example.com";
  fullName = "Charles Drolet";
  
  # Optional applications array
  applications = [ "git" "zsh" "helix" "aerospace" ];
};
```

**Alternatives Considered**:

- `apps` field: Rejected - less clear than full word "applications"
- Top-level `applications` array: Rejected - breaks from user structure pattern
- `user.packages` field: Rejected - confusing with `home.packages` (Nix packages vs app configs)

**Type Definition**:

```nix
options.user.applications = lib.mkOption {
  type = lib.types.nullOr (lib.types.listOf lib.types.str);
  default = null;
  description = ''
    List of application names to import and configure.
    Applications are discovered from platform/shared/app/ and platform/{platform}/app/.
    
    Example: [ "git" "zsh" "helix" "aerospace" ]
  '';
  example = [ "git" "zsh" "helix" ];
};
```

______________________________________________________________________

### 2. Validation Strategy

**Decision**: Leverage existing discovery system validation, no additional checks needed

**Rationale**:

- Discovery system already validates application names exist
- Discovery system already provides helpful error messages with suggestions
- Discovery system already handles graceful degradation for user configs
- Adding duplicate validation increases complexity and maintenance burden

**Existing Discovery Validation** (from `platform/shared/lib/discovery.nix`):

- Validates application names against registry
- Provides "Did you mean?" suggestions for typos
- Lists available platforms when app exists elsewhere
- Gracefully skips unavailable apps in user configs (not profiles)

**Error Message Example** (already provided by discovery):

```
error: Application 'gti' not found in any platform

Did you mean one of these?
  - git (in shared, darwin, nixos)
  - tig (in shared)

Tip: Check app name spelling or add the app to platform/*/app/
```

**Alternatives Considered**:

- Pre-validation in bootstrap: Rejected - duplicates discovery logic
- Schema validation: Rejected - type system already validates list of strings
- Custom error messages: Rejected - discovery errors are already excellent

______________________________________________________________________

### 3. UserContext Access in Bootstrap Library

**Decision**: UserContext is passed via Home Manager's `extraSpecialArgs`

**Investigation** (from existing code):

**Platform libs set up userContext** (`platform/darwin/lib/darwin.nix`):

```nix
home-manager.extraSpecialArgs = {
  userContext = {
    user = username;
    platform = "darwin";
    profile = profile;
  };
};
```

**User configs receive userContext** (`user/cdrolet/default.nix`):

```nix
{ config, pkgs, lib, userContext, ... }:
```

**Bootstrap library has access**:

- The bootstrap library is imported by user configs via `imports = [ ../shared/lib/home-manager.nix ];`
- As a Home Manager module, it has access to ALL special args including `userContext`
- Can pass `userContext` directly to discovery functions

**Implementation Pattern**:

```nix
{ config, lib, pkgs, userContext ? null, ... }:

{
  config = lib.mkIf (config.user.applications != null) {
    imports = let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      (discovery.mkApplicationsModule {
        inherit lib;
        applications = config.user.applications;
        # userContext available here if needed by future discovery changes
      })
    ];
  };
}
```

**Rationale**:

- No changes needed to platform libs or flake.nix
- UserContext already flows to all user modules
- Bootstrap can access it just like user configs do

**Alternatives Considered**:

- Pass userContext explicitly: Rejected - already available in module scope
- Calculate context from config: Rejected - userContext already has this info

______________________________________________________________________

### 4. Error Handling Strategy

**Decision**: Fail fast with clear error messages, rely on discovery system errors

**Rationale**:

- Discovery system already provides excellent error messages
- Users expect build to fail if application names are invalid
- Clear errors during `nix flake check` prevent deployment issues
- No silent failures - if user specifies an app, it should be imported or error

**Error Scenarios**:

| Scenario | Behavior | Error Source |
|----------|----------|--------------|
| Typo in app name | Build fails with suggestions | Discovery system |
| Platform-specific app unavailable | Graceful skip (user config) | Discovery system |
| Empty applications array | Success (no imports) | N/A |
| applications = null | Success (no imports) | N/A |
| Non-string in array | Type error at evaluation | Nix type system |
| Application not found | Build fails with details | Discovery system |

**User Experience**:

1. **Immediate feedback**: Errors appear during `nix flake check` or build
1. **Helpful messages**: Discovery provides "did you mean?" suggestions
1. **Clear fix path**: Error messages explain how to resolve issue
1. **No surprises**: Explicit failure better than silent skip

**Alternatives Considered**:

- Silent skip all errors: Rejected - hides configuration mistakes
- Collect and report all errors: Rejected - adds complexity, first error usually most important
- Warning messages: Rejected - users rarely check warnings, errors force fixes

______________________________________________________________________

### 5. Backward Compatibility

**Decision**: Make `applications` field completely optional with null default

**Implementation Strategy**:

**Existing user configs continue to work**:

```nix
# Old pattern - still works
{ userContext, lib, ... }:
let
  discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
in {
  imports = [
    ../shared/lib/home-manager.nix
    (discovery.mkApplicationsModule {
      applications = [ "git" "zsh" "helix" ];
      user = userContext.user;
      platform = userContext.platform;
      profile = userContext.profile;
    })
  ];
  user = { name = "cdrolet"; ... };
}
```

**New pattern - simplified**:

```nix
# New pattern - cleaner
{ userContext, lib, ... }:
{
  imports = [ ../shared/lib/home-manager.nix ];
  
  user = {
    name = "cdrolet";
    email = "cdrolet@example.com";
    fullName = "Charles Drolet";
    applications = [ "git" "zsh" "helix" ];
  };
}
```

**Migration Path**:

1. Feature implemented with `applications` field optional
1. Existing configs keep working (gradual migration)
1. Users can migrate at their own pace
1. No breaking changes, purely additive

**Validation**:

- Test build with all 3 existing users BEFORE migration
- Test build with 1 migrated user
- Test build with mix of old and new patterns
- Confirm `nix flake check` passes for all scenarios

**Alternatives Considered**:

- Required field: Rejected - breaks existing configs
- Deprecate old pattern: Rejected - unnecessary complexity, both patterns are fine
- Migration script: Rejected - users can migrate manually when convenient

______________________________________________________________________

## Implementation Checklist

Based on research findings:

- [ ] Add `user.applications` option to `user/shared/lib/home-manager.nix`
- [ ] Type: `lib.types.nullOr (lib.types.listOf lib.types.str)`
- [ ] Default: `null`
- [ ] Add conditional imports when `applications != null`
- [ ] Import discovery library within bootstrap
- [ ] Call `mkApplicationsModule` with `applications` array
- [ ] Test with existing user configs (no changes)
- [ ] Test with new applications field
- [ ] Test with empty applications array
- [ ] Test with invalid application names (verify error messages)
- [ ] Update CLAUDE.md with new pattern
- [ ] Create user documentation in docs/features/

______________________________________________________________________

## Dependencies

**Existing Code** (no changes required):

- `platform/shared/lib/discovery.nix` - provides `mkApplicationsModule`
- Platform libs (`platform/darwin/lib/darwin.nix`) - provide `userContext`
- Home Manager module system - provides special args

**New Code**:

- `user/shared/lib/home-manager.nix` - add applications field and conditional imports

______________________________________________________________________

## Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Discovery system change breaks integration | High | Low | Discovery system is stable, widely used |
| UserContext not available in bootstrap | High | Very Low | Already tested pattern, same as user configs |
| Performance regression from extra imports | Medium | Very Low | Same number of imports, just different source |
| Users confused by two patterns | Low | Medium | Document both patterns, explain migration is optional |

______________________________________________________________________

## Success Criteria (from spec)

Research validates all success criteria are achievable:

- ✅ **SC-001**: Users can declare applications in 3 lines or fewer

  - Confirmed: Single `applications = [ ... ];` line in user structure

- ✅ **SC-002**: Configuration files reduced by 8-12 lines

  - Confirmed: Eliminates discovery import and mkApplicationsModule call (~10 lines)

- ✅ **SC-003**: New users don't need to understand discovery

  - Confirmed: Applications field is self-documenting, no discovery knowledge needed

- ✅ **SC-004**: 100% backward compatibility

  - Confirmed: Optional field with null default, existing configs unchanged

- ✅ **SC-005**: No performance regression

  - Confirmed: Same discovery mechanism, just different invocation point

- ✅ **SC-006**: Users modify only applications array

  - Confirmed: No imports to touch, just edit the array

______________________________________________________________________

## Conclusion

Research confirms the feature is implementable with minimal code changes (single file modification) and zero risk to existing functionality. The discovery system already provides all necessary validation and error handling. The implementation leverages existing patterns and infrastructure without introducing new dependencies or complexity.

**Recommendation**: Proceed to Phase 1 (Design & Contracts)
