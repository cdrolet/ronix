# Feature Specification: Standalone Home-Manager Migration

**Feature Branch**: `036-standalone-home-manager`\
**Created**: 2026-01-01\
**Status**: Draft\
**Priority**: P0 (Critical - Blocks Feature 035 and affects entire architecture)\
**Constitutional Impact**: High - Changes core architecture pattern

## Problem Statement

The current nix-darwin home-manager module integration does not properly extend `lib` with home-manager's `lib.hm` utilities. This causes:

1. **Build failures** for all modules using `lib.hm.dag.entryAfter` in activation scripts
1. **Broken settings modules** in `system/*/settings/home/` subdirectories
1. **Blocked features** - Feature 035 (Claude Apps) cannot be completed
1. **Architecture fragility** - Any new home-manager features may not work

### Root Cause

When using `home-manager.darwinModules.home-manager`:

- The module does NOT extend `lib` with home-manager's utilities
- Modules receive nixpkgs' `lib` which lacks `lib.hm`
- Attempts to override via `extraSpecialArgs` or `_module.args` fail due to Nix module system semantics

Standalone home-manager properly extends lib in `modules/lib/stdlib-extended.nix` before module evaluation.

### Evidence

- GitHub Issue [#2959](https://github.com/nix-community/home-manager/issues/2959): "attribute 'hm' missing" errors
- GitHub Issue [#5980](https://github.com/nix-community/home-manager/issues/5980): Passing lib to extraSpecialArgs breaks home-manager
- Release 25.11 (November 2025) changed module integration - possible regression

## Proposed Solution

Migrate from **nix-darwin module integration** to **standalone home-manager mode**.

### Architecture Change

**Current (Module Integration):**

```
flake.nix
  └─ darwinConfigurations
       └─ nix-darwin.lib.darwinSystem
            ├─ System modules
            └─ home-manager.darwinModules.home-manager
                 └─ home-manager.users.${user}
                      └─ User modules (lib.hm NOT available ❌)
```

**Proposed (Standalone):**

```
flake.nix
  ├─ darwinConfigurations (System only)
  │    └─ nix-darwin.lib.darwinSystem
  │         └─ System modules (NO home-manager)
  │
  └─ homeConfigurations (Users independent)
       └─ home-manager.lib.homeManagerConfiguration
            └─ User modules (lib.hm available ✅)
```

## Benefits

### 1. **Solves lib.hm Issue** ✅

- Standalone home-manager properly extends lib with lib.hm
- All activation scripts work: `lib.hm.dag.entryAfter`, `lib.hm.gvariant`, etc.
- Unblocks Feature 035 and future development

### 2. **Better Multi-User Isolation** ✅

- Aligns with Constitution v2.0.0: "Multi-User Isolation: Users can't interfere with each other"
- Each user manages their own home-manager config independently
- Users can activate their configs without system rebuild

### 3. **Faster User Iteration** ✅

- User dotfile changes don't require `darwin-rebuild` (slow)
- Only run `home-manager switch` (faster)
- System and user concerns properly separated

### 4. **Cross-Platform Compatibility** ✅

- Home-manager configs work identically on NixOS
- Future NixOS migration requires no user config changes
- Better separation: nix-darwin for macOS-specific, home-manager for portable

## Trade-offs

### Workflow Changes

**Current:**

```bash
just install user host    # One command for everything
```

**Proposed:**

```bash
just install user host    # Runs BOTH:
  darwin-rebuild switch   # System
  home-manager switch     # User
```

**Mitigation**: Hide complexity behind justfile - users see no difference

### Configuration Complexity

**Added complexity:**

- Two flake outputs instead of one
- Separate build/activation phases
- Need to understand which configs go where

**Mitigation**:

- Clear documentation in CLAUDE.md
- Discovery system works the same
- Pure data configs unchanged (users don't see internal changes)

### Coordination Between System and User

**Challenge**: System packages installed separately from user configs

**Example scenario**:

- System installs homebrew cask for app
- User config references that app

**Mitigation**:

- Document activation order (system first, then user)
- Most apps don't need tight coordination
- Can still reference system packages via `pkgs`

## Implementation Plan

### Phase 1: Setup & Validation (No Breaking Changes)

**Goal**: Prove standalone mode works alongside current integration

1. Add `homeConfigurations` output to flake.nix
1. Create test user configuration in standalone mode
1. Verify `lib.hm` is available and activation scripts work
1. Test dual-mode (both integration and standalone for same user)

**Success criteria**:

- `home-manager switch --flake .#testuser@testhost` succeeds
- Test activation script using `lib.hm.dag.entryAfter` works
- No impact on existing `darwin-rebuild` workflow

### Phase 2: Migration (One User at a Time)

**Goal**: Migrate all users to standalone while maintaining stability

1. Update platform libs (darwin.nix) to prepare for transition
1. Migrate one user (e.g., cdrokar) completely
1. Update justfile for dual-command workflow
1. Test full workflow end-to-end
1. Migrate remaining users (cdrolet, cdrixus)
1. Verify all hosts work with all users

**Success criteria**:

- All users can build and activate
- All activation scripts work (wallpaper, fonts, git-repos, etc.)
- No errors about lib.hm missing

### Phase 3: Cleanup & Documentation

**Goal**: Remove old integration, update docs

1. Remove `home-manager.darwinModules.home-manager` from darwinSystem
1. Remove sharedModules attempting to inject lib.hm
1. Remove home-manager-lib.nix helper (no longer needed)
1. Update CLAUDE.md with new architecture
1. Update Constitution if architectural principles changed
1. Add troubleshooting guide for common issues

**Success criteria**:

- Clean architecture with no legacy code
- Documentation accurate and complete
- Users understand new workflow

## Files Affected

### New Files

- `specs/036-standalone-home-manager/spec.md` (this file)
- `specs/036-standalone-home-manager/plan.md` (detailed implementation)
- `specs/036-standalone-home-manager/research.md` (lib.hm investigation)
- `specs/036-standalone-home-manager/migration-guide.md` (step-by-step)

### Modified Files

- `flake.nix` - Add homeConfigurations output
- `system/darwin/lib/darwin.nix` - Remove home-manager integration
- `system/nixos/lib/nixos.nix` - Remove home-manager integration (future)
- `justfile` - Update install/build commands for dual-mode
- `CLAUDE.md` - Document new architecture
- `user/shared/lib/home-manager.nix` - May need updates for standalone mode

### Files to Remove (Phase 3)

- `system/shared/lib/home-manager-lib.nix` - Workaround no longer needed
- Any code attempting to inject lib.hm via sharedModules/extraSpecialArgs

## Risks & Mitigation

### Risk 1: Breaking Existing Users

**Probability**: Medium\
**Impact**: High

**Mitigation**:

- Phased rollout (Phase 1 = no changes to existing workflow)
- Test thoroughly with one user before migrating all
- Keep both modes working during transition
- Clear rollback path documented

### Risk 2: Unforeseen Edge Cases

**Probability**: Medium\
**Impact**: Medium

**Mitigation**:

- Comprehensive testing of all activation scripts
- Check all settings modules work in standalone mode
- Test on actual hardware (not just build)
- Community examples as reference

### Risk 3: Workflow Confusion

**Probability**: Low\
**Impact**: Low

**Mitigation**:

- justfile abstracts complexity
- Clear documentation
- Error messages guide users to correct command

## Success Metrics

### Functional

- [ ] All users can build without lib.hm errors
- [ ] All activation scripts execute successfully
- [ ] Wallpaper, fonts, git-repos, dock configs all work
- [ ] Feature 035 (Claude Apps) can be completed

### Performance

- [ ] `home-manager switch` faster than full `darwin-rebuild`
- [ ] User config changes don't trigger system rebuild
- [ ] Overall activation time acceptable (< 2x current)

### Quality

- [ ] No errors in build output
- [ ] No warnings about lib.hm
- [ ] Clean separation between system and user configs
- [ ] Documentation clear and complete

## Dependencies

**Blocks**:

- Feature 035 (Claude Apps Integration)
- Any future features using home-manager activation scripts
- Settings modules relying on lib.hm utilities

**Blocked by**:

- None

**Related**:

- Constitution v2.0.0 (Multi-User Isolation)
- Architecture refactor (settings/home/ structure)

## References

### Research

- See `specs/036-standalone-home-manager/research.md` for detailed lib.hm investigation
- Session transcript from 2026-01-01 documenting discovery process

### External Resources

- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [GitHub Issue #2959](https://github.com/nix-community/home-manager/issues/2959) - attribute 'dag' missing
- [GitHub Issue #5980](https://github.com/nix-community/home-manager/issues/5980) - Passing lib to extraSpecialArgs breaks HM
- [NixOS Discourse: Nix-Darwin and Home-Manager](https://discourse.nixos.org/t/some-questions-about-nix-darwin-and-home-manager/58913)
- [Callista Blog: Embracing Flakes and Home Manager](https://callistaenterprise.se/blogg/teknik/2025/04/10/nix-flakes/)

## Timeline

**Estimated effort**: 2-3 sessions

- **Session 1**: Phase 1 (Setup & Validation) - 2-3 hours
- **Session 2**: Phase 2 (Migration) - 2-3 hours
- **Session 3**: Phase 3 (Cleanup) - 1-2 hours

**Target completion**: Before continuing Feature 035

## Open Questions

1. Should we migrate NixOS at the same time, or wait until we have NixOS hosts?

   - **Recommendation**: Wait - no NixOS hosts currently, YAGNI principle

1. How should we handle apps that need both system and user config (like homebrew casks)?

   - **Recommendation**: System installs cask, user configures it - document pattern

1. Should justfile commands change (breaking) or stay compatible?

   - **Recommendation**: Stay compatible - hide dual commands behind existing interface

1. Do we need a rollback plan if standalone mode doesn't work?

   - **Recommendation**: Yes - keep git branch, document how to revert in migration-guide.md
