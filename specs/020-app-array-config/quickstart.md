# Quickstart: Simplified Application Configuration

**Feature**: 020-app-array-config\
**For**: Developers implementing this feature\
**Date**: 2025-11-30

## Overview

This quickstart guides implementation of the simplified application configuration feature, which adds an optional `applications` field to the user configuration structure. Users can declare applications as a simple array instead of manually importing the discovery library.

## Prerequisites

- Nix 2.19+ with flakes enabled
- Existing nix-config repository with user/system split structure
- Familiarity with Home Manager modules and Nix type system
- Understanding of existing discovery system (`platform/shared/lib/discovery.nix`)

## Implementation Steps

### Step 1: Add `applications` Option to Bootstrap Library

**File**: `user/shared/lib/home-manager.nix`

**Action**: Add new option definition in the `options.user` attribute set

```nix
# Add after existing user options (name, email, fullName, languages, etc.)
applications = lib.mkOption {
  type = lib.types.nullOr (lib.types.listOf lib.types.str);
  default = null;
  description = ''
    List of application names to automatically discover and import.
    
    Applications are resolved from the platform application registry:
    - platform/shared/app/**/*.nix (cross-platform applications)
    - platform/{platform}/app/**/*.nix (platform-specific applications)
    
    Examples: [ "git" "zsh" "helix" "aerospace" ]
  '';
  example = [ "git" "zsh" "helix" ];
};
```

**Estimated Time**: 5 minutes

______________________________________________________________________

### Step 2: Add Conditional Import Logic

**File**: `user/shared/lib/home-manager.nix` (same file)

**Action**: Add conditional imports in the `config` section

```nix
config = lib.mkIf (config.user.name != null) {
  # ... existing config (home.stateVersion, home.username, etc.)
  
  # NEW: Conditional application imports
  imports = lib.optionals (config.user.applications != null) [
    (
      let
        discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
      in
        discovery.mkApplicationsModule {
          inherit lib;
          applications = config.user.applications;
        }
    )
  ];
};
```

**Key Points**:

- Use `lib.optionals` to conditionally add imports when `applications != null`
- Import discovery library within the conditional (no need to import at top level)
- Pass `applications` array directly to `mkApplicationsModule`
- Discovery system handles all validation and error messages

**Estimated Time**: 10 minutes

______________________________________________________________________

### Step 3: Validate Syntax and Type Checking

**Command**: `nix flake check`

**Expected Output**: Should pass with no errors (existing configs unchanged)

**Action**: Run from repository root

```bash
cd /path/to/nix-config
nix flake check
```

**Troubleshooting**:

- **Syntax error**: Check balanced parentheses and braces
- **Import error**: Verify discovery library path (`../../platform/shared/lib/discovery.nix`)
- **Type error**: Ensure `lib.types.nullOr (lib.types.listOf lib.types.str)` is correct

**Estimated Time**: 2 minutes

______________________________________________________________________

### Step 4: Test with Existing User Configs (Backward Compatibility)

**Action**: Build each existing user without modifications

```bash
just build cdrokar home-macmini-m4
just build cdrolet work
just build cdrixus home-macmini-m4
```

**Expected Result**: All builds succeed (backward compatible, `applications` defaults to null)

**If Build Fails**:

- Check that conditional import uses `lib.optionals` (returns empty list when null)
- Verify default value is `null`, not `[]`
- Review error message for clues

**Estimated Time**: 5 minutes (3 builds × ~1-2 min each)

______________________________________________________________________

### Step 5: Migrate One User Config (Test New Pattern)

**File**: `user/cdrokar/default.nix` (test user)

**Before** (old pattern):

```nix
{ config, pkgs, lib, userContext, ... }:

{
  imports =
    let
      discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
    in [
      ../shared/lib/home-manager.nix
      (discovery.mkApplicationsModule {
        inherit lib;
        applications = [ "git" "zsh" "starship" "bat" "atuin" "helix" "aerospace" ];
      })
    ];

  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
    fullName = "Charles Drokar";
  };
}
```

**After** (new pattern):

```nix
{ config, pkgs, lib, userContext, ... }:

{
  imports = [ ../shared/lib/home-manager.nix ];

  user = {
    name = "cdrokar";
    email = "cdrokar@example.com";
    fullName = "Charles Drokar";
    
    # Simplified application declaration
    applications = [
      "git"
      "zsh"
      "starship"
      "bat"
      "atuin"
      "helix"
      "aerospace"
    ];
  };
}
```

**Changes**:

- ✅ Removed discovery library import
- ✅ Removed `mkApplicationsModule` call from imports
- ✅ Moved application list to `user.applications` field
- ✅ Kept all application names identical (no functional change)

**Estimated Time**: 3 minutes

______________________________________________________________________

### Step 6: Build Migrated User Config

**Command**: `just build cdrokar home-macmini-m4`

**Expected Result**: Build succeeds, same applications imported as before

**Validation**:

- Build completes without errors
- No warnings about missing applications
- User environment includes all declared applications

**If Build Fails**:

- Check for typos in application names
- Verify `applications` field is inside `user = { ... }`
- Review error message (discovery provides helpful suggestions)

**Estimated Time**: 2 minutes

______________________________________________________________________

### Step 7: Test Error Handling

**Action**: Temporarily add invalid application name

```nix
user.applications = [ "git" "gti" "zsh" ];  # "gti" is typo
```

**Expected Error**:

```
error: Application 'gti' not found in any platform

Did you mean one of these?
  - git (in shared, darwin, nixos)

Tip: Check app name spelling or add the app to platform/*/app/
```

**Validation**:

- Error message is clear and helpful
- Suggests correct spelling
- Build fails (doesn't silently skip)

**Action**: Fix typo and rebuild successfully

**Estimated Time**: 3 minutes

______________________________________________________________________

### Step 8: Test Edge Cases

**Test Case 1: Empty Applications List**

```nix
user.applications = [];
```

**Expected**: Build succeeds, no applications imported

**Test Case 2: Null Applications (Explicit)**

```nix
user.applications = null;
```

**Expected**: Build succeeds, same as omitting field

**Test Case 3: Single Application**

```nix
user.applications = [ "git" ];
```

**Expected**: Build succeeds, only git imported

**Test Case 4: Platform-Specific App on Different Platform**

```nix
# On darwin
user.applications = [ "git" "aerospace" ];  # aerospace is darwin-only
```

**Expected**: Both imported (aerospace available on darwin)

**Estimated Time**: 10 minutes (4 test cases × 2-3 min each)

______________________________________________________________________

### Step 9: Update Documentation

**File**: `CLAUDE.md`

**Action**: Update the "Adding Content" → "New User" section with new pattern

**Before**:

```nix
imports = [
  ../shared/lib/home-manager.nix
  (discovery.mkApplicationsModule {
    applications = [ "git" "zsh" ];
    user = userContext.user;
    platform = userContext.platform;
    profile = userContext.profile;
  })
];
```

**After**:

```nix
imports = [ ../shared/lib/home-manager.nix ];

user = {
  name = "<username>";
  email = "<email>";
  fullName = "<full name>";
  applications = [ "git" "zsh" ];  # Simple array declaration
};
```

**File**: `docs/features/020-app-array-config.md` (create new)

**Content**: User-facing documentation explaining:

- How to declare applications
- What application names are available
- Error handling and troubleshooting
- Migration from old pattern (optional)

**Estimated Time**: 15 minutes

______________________________________________________________________

### Step 10: Final Validation

**Command**: `nix flake check`

**Expected**: All checks pass

**Command**: `just check` (if available)

**Expected**: All validation passes

**Action**: Build all user configs to ensure nothing broke

```bash
just build cdrokar home-macmini-m4
just build cdrolet work
just build cdrixus home-macmini-m4
```

**Expected**: All builds succeed

**Estimated Time**: 5 minutes

______________________________________________________________________

## Total Estimated Time

| Phase | Time |
|-------|------|
| Step 1: Add option | 5 min |
| Step 2: Add logic | 10 min |
| Step 3: Validate syntax | 2 min |
| Step 4: Test backward compat | 5 min |
| Step 5: Migrate test user | 3 min |
| Step 6: Build migrated | 2 min |
| Step 7: Test errors | 3 min |
| Step 8: Test edge cases | 10 min |
| Step 9: Update docs | 15 min |
| Step 10: Final validation | 5 min |
| **Total** | **60 minutes** |

**Actual time may vary**: First-time implementation may take 90 minutes with testing and documentation.

______________________________________________________________________

## Verification Checklist

After implementation, verify:

- [ ] `nix flake check` passes with no errors
- [ ] All existing user configs build successfully (backward compatible)
- [ ] Migrated user config builds successfully (new pattern works)
- [ ] Invalid application names produce helpful error messages
- [ ] Empty applications list builds successfully
- [ ] Null applications builds successfully (same as omitting field)
- [ ] CLAUDE.md updated with new pattern
- [ ] User documentation created in `docs/features/`
- [ ] Constitution compliance maintained (module \<200 lines)

______________________________________________________________________

## Common Issues and Solutions

### Issue: "infinite recursion encountered"

**Cause**: Circular import between bootstrap and discovery

**Solution**: Import discovery inside the conditional, not at module top level

```nix
# ❌ WRONG - imports at top level can cause recursion
let
  discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
in {
  imports = lib.optionals ... [ (discovery.mkApplicationsModule ...) ];
}

# ✅ CORRECT - import inside conditional
imports = lib.optionals (config.user.applications != null) [
  (let discovery = import ../../platform/shared/lib/discovery.nix { inherit lib; };
   in discovery.mkApplicationsModule ...)
];
```

______________________________________________________________________

### Issue: "attribute 'applications' missing"

**Cause**: Trying to access `config.user.applications` before option is defined

**Solution**: Ensure option definition comes before config section

```nix
{
  options.user.applications = lib.mkOption { ... };  # Define first
  
  config = lib.mkIf ... {
    imports = ... config.user.applications ...;  # Use second
  };
}
```

______________________________________________________________________

### Issue: Build succeeds but applications not imported

**Cause**: Conditional logic not triggering or wrong placement

**Solution**: Verify conditional uses `lib.optionals` and checks correct field

```nix
# Verify this condition
lib.optionals (config.user.applications != null) [...]

# Debug: Check if applications field has value
# Add temporary trace
lib.traceValSeq config.user.applications (lib.optionals ...)
```

______________________________________________________________________

### Issue: Type error with empty list

**Cause**: Using wrong conditional check

**Solution**: Use `!= null` not `!= []`

```nix
# ✅ CORRECT - checks for null
lib.optionals (config.user.applications != null) [...]

# ❌ WRONG - empty list is valid, should still import (nothing)
lib.optionals (config.user.applications != []) [...]
```

______________________________________________________________________

## Next Steps After Implementation

1. **Migrate remaining users** (optional, can be gradual):

   - `user/cdrolet/default.nix`
   - `user/cdrixus/default.nix`

1. **Update templates** (if user templates exist):

   - Use new pattern in user configuration templates
   - Remove discovery import boilerplate

1. **Announce to users** (if team project):

   - Share documentation on new simplified pattern
   - Explain migration is optional (backward compatible)
   - Highlight benefits (fewer lines, easier to maintain)

1. **Monitor for issues**:

   - Watch for confusion or questions
   - Collect feedback on error messages
   - Consider future enhancements based on usage

______________________________________________________________________

## Success Criteria

Implementation is successful when:

1. ✅ Users can declare applications in 3 lines or fewer
1. ✅ Configuration files reduced by 8-12 lines (migrated users)
1. ✅ New users don't need to understand discovery system
1. ✅ 100% backward compatibility maintained
1. ✅ No performance regression (build time unchanged)
1. ✅ Users only need to edit applications array to manage apps

All criteria should be met with the implementation steps above.
