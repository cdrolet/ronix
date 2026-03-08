# Research: lib.hm Availability in nix-darwin Home-Manager Integration

**Date**: 2026-01-01\
**Researcher**: Claude (AI Assistant)\
**Context**: Feature 035 implementation blocked by lib.hm errors

## Problem Discovery

During Feature 035 (Claude Apps Integration) implementation, build failures occurred with error:

```
error: attribute 'hm' missing
at system/darwin/settings/home/wallpaper.nix:90:5:
  89|   home.activation.setDarwinWallpaper = lib.mkIf (hasWallpaper || hasWallpapers) (
  90|     lib.hm.dag.entryAfter ["writeBoundary"] (
```

This error appeared in MULTIPLE files:

- `system/darwin/settings/home/wallpaper.nix`
- `system/darwin/settings/home/home-directory.nix`
- `system/darwin/settings/home/fonts.nix`
- `system/shared/settings/home/git-repos.nix`
- `system/shared/family/linux/settings/home/fonts.nix`
- `user/shared/lib/secrets.nix`
- `system/shared/settings/home/cachix.nix`

## Investigation Process

### 1. Initial Hypothesis: Missing Import

**Thought**: Maybe lib.hm needs to be explicitly imported.

**Test**: Checked home-manager documentation and examples.

**Result**: ❌ Documentation shows `lib.hm` should be automatically available in home-manager modules.

### 2. Hypothesis: Wrong Module Context

**Thought**: Maybe settings/home/ modules are being loaded at system level instead of home-manager level.

**Test**: Verified import path in `system/darwin/lib/darwin.nix`:

```nix
home-manager.users.${user} = {
  imports = [
    ../settings/home/default.nix  # ✓ Correct - inside home-manager.users
  ];
};
```

**Result**: ❌ Modules ARE in correct context.

### 3. Hypothesis: Can Override lib via extraSpecialArgs

**Thought**: Pass extended lib through `home-manager.extraSpecialArgs`.

**Test**:

```nix
home-manager.extraSpecialArgs = {
  lib = lib.extend (self: super: inputs.home-manager.lib);
};
```

**Result**: ❌ Module parameters take precedence over specialArgs. Didn't work.

### 4. Hypothesis: Can Override lib via \_module.args

**Thought**: Use `home-manager.sharedModules` to set `_module.args.lib`.

**Test**:

```nix
home-manager.sharedModules = [
  {
    _module.args.lib = lib.extend (self: super: {
      hm = inputs.home-manager.lib.hm;
    });
  }
];
```

**Result**: ❌ Still didn't override the lib parameter. Error persisted.

### 5. Hypothesis: Import lib.hm Directly in Modules

**Thought**: Create helper that imports home-manager's lib utilities.

**Test**: Created `system/shared/lib/home-manager-lib.nix`:

```nix
{lib, homeManager}:
let
  mkHmLib = import "${homeManager}/modules/lib/.";
in
  mkHmLib {inherit lib;}
```

**Result**: ❌ Failed because:

- Needed to pass `homeManager` (inputs.home-manager) to modules
- Can't use `builtins.getFlake` in pure build context (needs --impure)
- `homeManager` not in `_module.args` even when passed via `extraSpecialArgs`

### 6. ROOT CAUSE DISCOVERED

**Investigation**: Checked how standalone home-manager provides lib.hm.

**Finding**: In standalone mode, home-manager extends lib BEFORE module evaluation:

From `home-manager/modules/default.nix`:

```nix
let
  extendedLib = import ./lib/stdlib-extended.nix lib;  # ← Extension happens here
  
  rawModule = extendedLib.evalModules {
    modules = [ configuration ] ++ hmModules;
    # ...
  };
```

From `home-manager/modules/lib/stdlib-extended.nix`:

```nix
nixpkgsLib:

let
  mkHmLib = import ./.;
in
nixpkgsLib.extend (
  self: super: {
    hm = mkHmLib { lib = self; };  # ← lib.hm added here
  }
)
```

**The nix-darwin integration does NOT do this!**

Checked `home-manager/nix-darwin/default.nix` and `home-manager/nixos/common.nix`:

- Neither file extends lib with lib.hm
- They assume it's already available (works in standalone, NOT in module integration)

## Root Cause Conclusion

**The nix-darwin home-manager module integration does NOT extend lib with lib.hm.**

This is either:

1. An oversight in the nix-darwin integration module
1. A regression introduced in recent home-manager versions
1. Expected behavior that was never documented

## Community Research

### GitHub Issues Found

1. **[Issue #2959](https://github.com/nix-community/home-manager/issues/2959)** (May 2022)

   - "attribute 'hm' missing when trying to use activations"
   - Resolution: User needed to properly structure configs
   - Indicates this is a known pain point

1. **[Issue #5980](https://github.com/nix-community/home-manager/issues/5980)** (October 2024)

   - "Passing lib argument to extraSpecialArgs breaks home manager"
   - **Critical**: Maintainer says you should NOT override lib via extraSpecialArgs
   - Confirms our approach #3 was wrong

1. **[Issue #7344](https://github.com/nix-community/home-manager/issues/7344)** (Recent)

   - "home.activation scripts ignore DRY_RUN variable when integrated with nix-darwin"
   - Shows ongoing issues with nix-darwin integration

### NixOS Discourse

**[Discussion: Questions About Nix-Darwin and Home-Manager](https://discourse.nixos.org/t/some-questions-about-nix-darwin-and-home-manager/58913)**

- Community recommends standalone mode for better separation
- Module integration "more convenient" but has limitations

### Home-Manager Release Notes

**Release 25.11 (November 2025)** - Current version in our flake:

- "Home Manager no longer creates unnecessary per-user 'shadow profiles' when used as a module"
- Significant changes to module integration
- **No documented breaking changes to lib.hm**, but...
- Timing suggests possible regression

## Solution Analysis

### Option 1: Fix nix-darwin Integration (❌ Not Feasible)

**Approach**: Patch home-manager's nix-darwin module to extend lib.

**Pros**: Would fix the root cause

**Cons**:

- Requires maintaining a fork of home-manager
- Upstream may not accept the patch (might be intentional)
- Complex to maintain across updates

**Verdict**: Not recommended

### Option 2: Work Around with Helper Library (❌ Attempted, Failed)

**Approach**: Import lib.hm utilities directly in modules that need them.

**Pros**: Minimal architectural change

**Cons**:

- Can't pass `homeManager` input to modules (not in \_module.args)
- Can't use `builtins.getFlake` in pure builds
- Fragile, requires changes in every affected module

**Verdict**: Technical blockers prevent this approach

### Option 3: Migrate to Standalone Home-Manager (✅ RECOMMENDED)

**Approach**: Stop using `home-manager.darwinModules.home-manager`, use `home-manager.lib.homeManagerConfiguration` instead.

**Pros**:

- Solves lib.hm issue completely (standalone mode properly extends lib)
- Better separation of system vs user concerns
- Faster user iteration (no system rebuild for user changes)
- Aligns with multi-user isolation (Constitution v2.0.0)
- Cross-platform compatible (same config works on NixOS)

**Cons**:

- Workflow changes (two commands instead of one)
- Flake restructuring required
- Need to determine what stays in system vs user config

**Verdict**: Best long-term solution

## Technical Details: How Standalone Mode Fixes This

### Current (Module Integration)

```nix
inputs.nix-darwin.lib.darwinSystem {
  modules = [
    inputs.home-manager.darwinModules.home-manager  # ← Uses nix-darwin integration
    {
      home-manager.users.${user} = {
        imports = [ ./user-config.nix ];  # ← lib does NOT have lib.hm ❌
      };
    }
  ];
}
```

### Proposed (Standalone)

```nix
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.aarch64-darwin;
  modules = [
    ./user-config.nix  # ← lib DOES have lib.hm ✅
  ];
}
```

The key difference: `homeManagerConfiguration` calls `modules/default.nix` which extends lib before evaluation.

## Verification Plan

Once migrated to standalone mode, verify:

1. **lib.hm.dag available**:

   ```nix
   home.activation.test = lib.hm.dag.entryAfter ["writeBoundary"] ''
     echo "lib.hm.dag works!"
   '';
   ```

1. **All affected modules build**:

   - wallpaper.nix, fonts.nix, git-repos.nix, etc.
   - No "attribute 'hm' missing" errors

1. **Activation scripts execute**:

   - Run `home-manager switch`
   - Check activation output for script execution
   - Verify wallpaper set, fonts installed, repos cloned

1. **lib.hm utilities accessible**:

   ```nix
   # These should all work:
   lib.hm.dag.entryBefore
   lib.hm.dag.entryAfter
   lib.hm.dag.entryAnywhere
   lib.hm.gvariant.mkUint32
   lib.hm.types.dagOf
   ```

## Recommendations

1. **Immediate**: Create Feature 036 for standalone home-manager migration
1. **Priority**: P0 - Blocks Feature 035 and affects entire architecture
1. **Approach**: Phased migration (setup → migrate → cleanup)
1. **Testing**: Thorough validation in Phase 1 before migrating users
1. **Documentation**: Update CLAUDE.md with new architecture pattern
1. **Consider**: File upstream issue if this is a regression in home-manager 25.11

## References

### Source Code Analyzed

- `home-manager/modules/default.nix` - Module evaluation entry point
- `home-manager/modules/lib/stdlib-extended.nix` - lib.hm extension
- `home-manager/nix-darwin/default.nix` - Darwin integration module
- `home-manager/nixos/common.nix` - Common integration code

### External Links

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [GitHub Issue #2959](https://github.com/nix-community/home-manager/issues/2959)
- [GitHub Issue #5980](https://github.com/nix-community/home-manager/issues/5980)
- [NixOS Discourse Discussion](https://discourse.nixos.org/t/some-questions-about-nix-darwin-and-home-manager/58913)
- [Callista Blog: Flakes and Home Manager](https://callistaenterprise.se/blogg/teknik/2025/04/10/nix-flakes/)

### Session Notes

- Full investigation process documented in session transcript (2026-01-01)
- Multiple approaches attempted and failed before finding root cause
- Community research conducted to validate findings
- Impact analysis performed for migration decision

## Timeline

- **Discovery**: 2026-01-01 during Feature 035 implementation
- **Investigation**: ~4 hours of research and testing
- **Decision**: Migrate to standalone mode (Feature 036)
- **Next**: Implementation in separate feature branch

______________________________________________________________________

**Conclusion**: The lib.hm availability issue is a fundamental limitation of the nix-darwin home-manager integration. Standalone mode is the correct architectural solution that solves the immediate problem while providing long-term benefits for the codebase.
