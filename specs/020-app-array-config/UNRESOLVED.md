# Unresolved Implementation Blockers

**Feature**: 020-app-array-config - Simplified Application Configuration\
**Date**: 2025-11-30\
**Status**: BLOCKED - Requires architectural decision

## Problem Statement

The feature specification requires that users declare applications in `user.applications` array and have them automatically imported without manually calling the discovery system. However, **this is fundamentally incompatible with how the Nix module system works**.

## Blocking Issues

### Issue 1: Infinite Recursion with Config-Based Imports

**Problem**: The Nix module system evaluates `imports` before evaluating `config`. Any attempt to reference `config` (including `config.user.applications`) in `imports` or in a file being imported causes infinite recursion.

**Error Message**:

```
error: infinite recursion encountered

if you get an infinite recursion here, you probably reference `config` in `imports`. 
If you are trying to achieve a conditional import behavior dependent on `config`, 
consider importing unconditionally, and using `mkEnableOption` and `mkIf` to control its effect.
```

**What We Tried**:

1. Conditional imports in bootstrap library - infinite recursion
1. Separate auto-applications.nix module - infinite recursion
1. Function-based module approach - infinite recursion
1. Using `options.user.applications.isDefined` - infinite recursion
1. Placing imports at different nesting levels - infinite recursion

**Root Cause**: This is not a bug - it's by design. The Nix module system intentionally prevents config from affecting imports to avoid circular dependencies.

### Issue 2: Specification vs. Nix Constraints

**Specification Requirements** (from FR-002, FR-003, FR-004):

- FR-002: "The home-manager bootstrap library MUST automatically process the applications array when present"
- FR-003: "The bootstrap library MUST invoke the discovery system's `mkApplicationsModule` function with the provided application names"
- FR-004: "Users MUST NOT be required to manually import the discovery library"

**Nix Constraints**:

- Imports must be static (cannot depend on config values)
- Modules cannot dynamically import other modules based on configuration
- The only way to make imports conditional is at the call site (user config), not in an imported module

**Contradiction**: The spec requires automatic imports from bootstrap (no user action), but Nix requires explicit imports from user config (user action).

## Attempted Solutions

### Attempt 1: Conditional Imports in Bootstrap

```nix
# user/shared/lib/home-manager.nix
imports = lib.optionals (config.user.applications != null) [...]
```

**Result**: Infinite recursion - `config` not available in `imports`

### Attempt 2: Separate Module with Conditional Logic

```nix
# user/shared/lib/auto-applications.nix
if config.user.applications != null then
  discovery.mkApplicationsModule {...}
else {}
```

**Result**: Infinite recursion - module imported by user config still references `config` in its `imports`

### Attempt 3: Function-Based Wrapper

```nix
# Returns a module that reads config
{}: { config, lib, ... }: {
  imports = if config.user.applications != null then [...] else [];
}
```

**Result**: Infinite recursion - even inside returned module, `imports` cannot reference `config`

## What WOULD Work (But Violates Spec)

### Working Solution 1: User Explicitly Passes Applications

```nix
# user/cdronix/default.nix
imports = [
  (import ../shared/lib/auto-applications.nix {
    applications = [ "git" "zsh" "helix" ];
  })
];
```

**Issue**: Violates FR-004 - user must manually configure imports\
**Benefit**: No infinite recursion, works with Nix module system

### Working Solution 2: Simplified Import Helper

```nix
# user/cdronix/default.nix  
imports = [
  ../shared/lib/home-manager.nix
  (mkApplications [ "git" "zsh" "helix" ])
];
```

**Issue**: Still requires user to call function in imports\
**Benefit**: Simpler than current discovery pattern, no infinite recursion

### Working Solution 3: Package Installation Only (No Module Imports)

```nix
# Install packages from user.applications, but don't import modules
home.packages = map (name: pkgs.${name}) config.user.applications;
```

**Issue**: Doesn't import app configuration modules (settings, aliases, etc.)\
**Benefit**: Works within Nix constraints, provides partial value

## Questions for Stakeholder

1. **Can we redefine "automatic"?**

   - Would a one-line import helper be acceptable?
   - Example: `(mkApps [ "git" "zsh" ])` instead of full discovery boilerplate

1. **Can we split the feature?**

   - Phase 1: Simplified import syntax (still manual but cleaner)
   - Phase 2: Full automation (if/when Nix supports it)

1. **Can we accept package-only installation?**

   - Applications get installed but without full module configuration
   - Users wanting full config still use explicit imports

1. **Can we document this as a Nix limitation?**

   - Feature "works" but requires one line in imports
   - Better than current pattern (10+ lines of discovery boilerplate)

## Recommended Path Forward

**Option A**: Redefine Success (Pragmatic)

- Change spec to allow simplified import helper instead of fully automatic
- User still adds ONE line to imports, but it's much simpler
- Achieves 80% of value (reduced boilerplate) within Nix constraints
- Update FR-004 to: "Users MUST NOT be required to manually call discovery.mkApplicationsModule"

**Option B**: Split Feature (Incremental)

- Implement simplified import helper now (achievable)
- Document automatic imports as future enhancement
- Wait for Nix module system evolution or flakes v2

**Option C**: Package-Only Mode (Limited Value)

- Install packages from applications array
- Full configuration still requires explicit imports
- Partial solution but within Nix constraints

## Impact Assessment

**If we proceed with current approach**: Permanent blocker, cannot implement

**If we choose Option A**:

- Delivers 80% of value (simpler syntax)
- Works within Nix constraints
- Requires spec update

**If we choose Option B**:

- Delivers immediate value with clear upgrade path
- Honest about limitations
- Maintains spec goals long-term

**If we choose Option C**:

- Minimal value (just package installation)
- May confuse users (why no config?)
- Not worth the complexity

## Conclusion

This feature **cannot be implemented as specified** due to fundamental Nix module system constraints. We need stakeholder input on which compromise is acceptable.

**Recommendation**: Choose Option A - redefine "automatic" as "simplified one-line helper" which still provides significant value over current 10-line discovery boilerplate.
