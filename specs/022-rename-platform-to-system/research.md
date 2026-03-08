# Research: Rename Platform to System Directory

**Feature**: 022-rename-platform-to-system\
**Phase**: 0 (Research)\
**Date**: 2025-12-05

## Research Objective

Identify all files referencing `platform/` directory paths and determine the optimal git rename strategy to preserve history while updating all import paths.

## Research Questions

### Q1: What is the best `git mv` strategy to preserve history?

**Answer**: Use `git mv platform system` for the top-level directory rename.

**Git History Preservation**:

- Git automatically detects renames with >50% similarity
- Since we're renaming the directory itself (not contents), similarity will be 100%
- Git tracks moves through content similarity, not path names
- Strategy: Single atomic `git mv` command followed by path updates in separate commit

**Two-Commit Strategy**:

1. **Commit 1**: `git mv platform system` (pure rename, no content changes)
   - Preserves history with 100% similarity
   - Easy to verify with `git log --follow system/`
1. **Commit 2**: Update all import paths referencing `platform/`
   - Content changes separated from rename
   - Easier to review and revert if needed

### Q2: Which files contain import paths referencing `platform/`?

**Search Strategy**:

```bash
# Find all .nix files with "platform/" in imports or paths
rg 'platform/' --type nix --glob '!specs/**' -l

# Find relative imports in user configs
rg '\.\./\.\./platform/' user/ -l

# Find imports in flake.nix
rg 'platform/' flake.nix
```

**Expected Files** (based on repository structure):

- `flake.nix` - imports platform libs (`platform/darwin/lib/darwin.nix`, `platform/nixos/lib/nixos.nix`)
- `user/*/default.nix` - imports discovery lib (`../../platform/shared/lib/discovery.nix`)
- `platform/shared/lib/discovery.nix` - internal relative paths to platform dirs
- `platform/darwin/lib/darwin.nix` - internal relative paths
- `platform/nixos/lib/nixos.nix` - internal relative paths
- App files in `platform/*/app/**/*.nix` - may have relative imports

### Q3: Which documentation files reference `platform/` directory?

**Search Strategy**:

```bash
# Find markdown files with directory references
rg 'platform/' --type md --glob '!specs/**' -l

# Specifically check key docs
rg 'platform/' CLAUDE.md README.md docs/ -l
```

**Expected Files**:

- `CLAUDE.md` - architecture section, directory structure examples
- `README.md` - quick start guide, structure overview
- `docs/features/*.md` - feature documentation referencing structure
- `.specify/memory/constitution.md` - already updated in v2.1.0 (uses `platform/`)

**Note**: Constitution v2.1.0 CHANGED from `system/` to `platform/` terminology. This feature REVERTS that decision and requires constitution amendment.

### Q4: Are there string references to "platform/" that should remain unchanged?

**Answer**: YES - Must distinguish between:

**CHANGE (directory references)**:

- Import paths: `import ../../platform/shared/lib/discovery.nix`
- Directory paths in comments: `# Located in platform/darwin/app/`
- Documentation structure examples: `platform/darwin/app/`
- File path strings: `basePath = ./../../platform/`

**KEEP UNCHANGED (OS platform references)**:

- User field: `platform = "darwin"` or `platform = "nixos"`
- Function parameters: `discoverHosts = platform: let`
- Variable names: `validPlatforms`, `platformType`, `currentPlatform`
- Comments explaining OS platform: `# platform can be "darwin" or "nixos"`

**Detection Strategy**:

```bash
# Find potential false positives (keep these)
rg 'platform\s*=' --type nix           # Field assignments
rg 'platform:' --type nix              # Function parameters
rg '"(darwin|nixos)"' --type nix       # Platform values
```

## Research Findings

### Git Rename Strategy

**Recommended Approach**:

```bash
# Step 1: Rename directory (preserves history)
git mv platform system
git commit -m "refactor: rename platform/ to system/ directory"

# Step 2: Update all import paths (separate commit)
# [Use sed or manual edits to update paths]
git commit -m "refactor: update import paths from platform/ to system/"

# Step 3: Update documentation (separate commit)
git commit -m "docs: update references from platform/ to system/"
```

**Verification**:

```bash
# Verify history preservation
git log --follow system/darwin/lib/darwin.nix

# Verify similarity score
git log --stat -M -1
```

### Files Requiring Updates

**Category 1: Nix Import Paths** (requires sed/manual update):

- `flake.nix`
- `user/cdrokar/default.nix`
- `user/cdrolet/default.nix`
- `user/cdrixus/default.nix`
- `system/shared/lib/discovery.nix` (post-rename, internal paths)
- `system/darwin/lib/darwin.nix` (post-rename, internal paths)
- `system/nixos/lib/nixos.nix` (post-rename, internal paths)
- Any app files with relative imports

**Category 2: Documentation** (requires manual review):

- `CLAUDE.md`
- `README.md`
- `docs/features/*.md` (all feature documentation)
- `.specify/memory/constitution.md` (REQUIRES AMENDMENT - revert v2.1.0 change)

**Category 3: Tooling** (requires sed/manual update):

- `justfile` (if contains hardcoded paths)
- Any shell scripts in `.specify/scripts/`

### Import Path Patterns

**Pattern 1: Absolute imports from flake.nix**

```nix
# BEFORE
import ./platform/darwin/lib/darwin.nix

# AFTER
import ./system/darwin/lib/darwin.nix
```

**Pattern 2: Relative imports from user configs**

```nix
# BEFORE (from user/cdrokar/default.nix)
import ../../platform/shared/lib/discovery.nix

# AFTER
import ../../system/shared/lib/discovery.nix
```

**Pattern 3: Internal relative paths in libs**

```nix
# BEFORE (in platform/shared/lib/discovery.nix)
basePath = ./../../${platform}/host;

# AFTER (in system/shared/lib/discovery.nix)
basePath = ./../../${platform}/host;  # NO CHANGE (variable reference)
```

**Pattern 4: Comments and strings**

```nix
# BEFORE
# Located in platform/darwin/app/aerospace.nix

# AFTER
# Located in system/darwin/app/aerospace.nix
```

### Validation Plan

**Pre-Rename Checks**:

1. ✅ Run `nix flake check` (baseline)
1. ✅ Build all configurations (baseline)
1. ✅ Commit current state (rollback point)

**Post-Rename Checks** (after each commit):

1. ✅ Run `nix flake check` (must pass)
1. ✅ Build all configurations (must succeed)
1. ✅ Verify git history preserved: `git log --follow system/`
1. ✅ Check similarity score: `git log --stat -M -1` (expect 100%)

**Post-Path-Update Checks**:

1. ✅ Run `nix flake check` (must pass)
1. ✅ Build all configurations (must succeed)
1. ✅ Verify no remaining `platform/` references: `rg 'platform/' --type nix --glob '!specs/**'`
1. ✅ Test discovery system: `nix eval .#darwinConfigurations --apply builtins.attrNames`

**Documentation Validation**:

1. ✅ All `platform/` directory references changed to `system/`
1. ✅ User `platform` field examples unchanged (still show `platform = "darwin"`)
1. ✅ Constitution amended to revert v2.1.0 terminology change

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Git history lost | High | Use `git mv` command, verify with `--follow` |
| Missed import paths | High | Use `rg 'platform/'` exhaustive search before/after |
| Breaking user configs | High | Test builds after each commit |
| False positive replacements | Medium | Manual review of each change, distinguish directory vs field |
| Documentation inconsistency | Low | Update all docs in single commit |

## Implementation Sequence

**Phase 1: Preparation**

1. Run baseline validation
1. Create feature branch
1. Generate complete list of files to update

**Phase 2: Directory Rename**

1. Execute `git mv platform system`
1. Commit with clear message
1. Verify history preservation

**Phase 3: Code Updates**

1. Update flake.nix imports
1. Update user config imports
1. Update internal lib paths
1. Update any app imports
1. Commit all changes
1. Run validation

**Phase 4: Documentation Updates**

1. Update CLAUDE.md
1. Update README.md
1. Update docs/features/
1. Amend constitution (revert v2.1.0)
1. Commit all changes

**Phase 5: Final Validation**

1. Run full test suite
1. Build all configurations
1. Verify no remaining references
1. Merge to main

## Questions for Clarification

None - this is a straightforward refactoring task with clear scope.

## Conclusion

The rename operation is low-risk with clear validation checkpoints. The two-commit strategy (rename first, then update paths) ensures git history preservation while making the changes reviewable. The key challenge is distinguishing between directory path references (change) and OS platform field references (keep unchanged).

**Ready for Phase 1**: Design phase not needed (refactoring task). Proceed directly to Phase 2 (task generation).
