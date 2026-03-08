# Feature 036 Status

**Feature**: Standalone Home-Manager Migration\
**Status**: 📋 Specification Complete - Ready for Implementation\
**Created**: 2026-01-01\
**Last Updated**: 2026-01-01

## Quick Summary

Migrating from nix-darwin's home-manager module integration to standalone home-manager mode to solve the lib.hm availability issue discovered during Feature 035.

## Current State

### ✅ Completed

- Problem identified and root cause determined
- Comprehensive research documented (research.md)
- Feature specification written (spec.md)
- Implementation phases planned
- Feature 035 marked as blocked with clear resolution path
- CLAUDE.md updated with known issues and upcoming changes

### 🔄 In Progress

- None - waiting to begin implementation

### ⏳ Pending

- Phase 1: Setup & Validation
- Phase 2: Migration
- Phase 3: Cleanup & Documentation

## Files Created

- `specs/036-standalone-home-manager/spec.md` - Full feature specification
- `specs/036-standalone-home-manager/research.md` - lib.hm investigation details
- `specs/036-standalone-home-manager/STATUS.md` - This file
- Updated: `specs/035-claude-apps-integration/spec.md` - Marked as blocked
- Updated: `CLAUDE.md` - Added known issues section

## Next Steps

1. **Begin Phase 1**: Add homeConfigurations to flake.nix
1. **Test with one user**: Verify lib.hm works in standalone mode
1. **Validate approach**: Ensure activation scripts execute correctly
1. **Proceed to migration**: Once Phase 1 proves successful

## Dependencies

**Blocks**:

- Feature 035 (Claude Apps Integration) - Cannot complete until lib.hm is available
- All future features using home-manager activation scripts

**Blocked By**:

- None - can start immediately

## References

- **Research**: `specs/036-standalone-home-manager/research.md`
- **Spec**: `specs/036-standalone-home-manager/spec.md`
- **Blocked Feature**: `specs/035-claude-apps-integration/spec.md`
- **Documentation**: `CLAUDE.md` (Known Issues section)

## Risk Assessment

**Overall Risk**: 🟡 Medium

- Implementation complexity: Medium (flake restructuring required)
- Testing effort: High (must verify all activation scripts)
- Rollback difficulty: Low (git branch + clear documentation)
- User impact: Low (justfile hides workflow changes)

## Timeline Estimate

- **Phase 1**: 2-3 hours (setup + validation)
- **Phase 2**: 2-3 hours (migration)
- **Phase 3**: 1-2 hours (cleanup)
- **Total**: 5-8 hours across 2-3 sessions

## Success Criteria

- [ ] All users can build without lib.hm errors
- [ ] All activation scripts execute successfully
- [ ] Feature 035 can be unblocked and completed
- [ ] Documentation reflects new architecture
- [ ] justfile commands work seamlessly

______________________________________________________________________

**Ready to begin implementation when you are!**
