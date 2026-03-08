# Quick Start: Modularize Flake Configuration Libraries

**Feature**: 011-modularize-flake-libs\
**Date**: 2025-11-01\
**Status**: Complete

## Overview

This guide provides step-by-step instructions for testing and validating the flake modularization feature. Each test corresponds to acceptance scenarios from the specification.

______________________________________________________________________

## Prerequisites

- Nix 2.19+ with flakes enabled
- `just` command runner installed
- Working directory: repository root (`/Users/charles/project/nix-config`)
- Branch: `011-modularize-flake-libs`

______________________________________________________________________

## Test 1: Auto-Discovery of Users

**Corresponds to**: User Story 1 - Acceptance Scenario 1

### Setup

```bash
# Ensure you're on the feature branch
git checkout 011-modularize-flake-libs
```

### Test Steps

**Step 1.1**: Verify current users are discovered

```bash
nix eval .#validUsers --json
```

**Expected Output**:

```json
["cdrokar","cdrolet","cdrixus"]
```

**Step 1.2**: Add a new test user

```bash
mkdir -p user/testuser
cat > user/testuser/default.nix <<'EOF'
{ config, pkgs, lib, ... }:

{
  imports = [
    ../shared/lib/home-manager.nix
  ];

  user.name = "testuser";
  user.email = "test@example.com";
  user.fullName = "Test User";
}
EOF
```

**Step 1.3**: Verify test user is auto-discovered

```bash
nix eval .#validUsers --json
```

**Expected Output**:

```json
["cdrokar","cdrolet","cdrixus","testuser"]
```

**Step 1.4**: Verify justfile sees the new user

```bash
just list-users
```

**Expected Output** (includes testuser):

```
Available users:
  cdrokar
  cdrolet
  cdrixus
  testuser
```

**Step 1.5**: Cleanup

```bash
rm -rf user/testuser
```

**Validation**: ✅ Users are auto-discovered without flake.nix modifications

______________________________________________________________________

## Test 2: Auto-Discovery of Profiles

**Corresponds to**: User Story 1 - Acceptance Scenario 2

### Test Steps

**Step 2.1**: Verify current darwin profiles are discovered

```bash
nix eval .#validProfiles.darwin --json
```

**Expected Output**:

```json
["home-macmini-m4","work"]
```

**Step 2.2**: Add a new test profile

```bash
mkdir -p system/darwin/profiles/test-profile
cat > system/darwin/profiles/test-profile/default.nix <<'EOF'
{ config, pkgs, lib, ... }:

{
  imports = [ ../../settings/default.nix ];
  
  system.stateVersion = 5;
  
  # Test profile: minimal settings
  system.defaults.dock.autohide = lib.mkForce true;
}
EOF
```

**Step 2.3**: Verify test profile is auto-discovered

```bash
nix eval .#validProfiles.darwin --json
```

**Expected Output**:

```json
["home-macmini-m4","test-profile","work"]
```

**Step 2.4**: Verify justfile sees the new profile

```bash
just list-profiles darwin
```

**Expected Output** (includes test-profile):

```
Available darwin profiles:
  home-macmini-m4
  test-profile
  work
```

**Step 2.5**: Cleanup

```bash
rm -rf system/darwin/profiles/test-profile
```

**Validation**: ✅ Profiles are auto-discovered without flake.nix modifications

______________________________________________________________________

## Test 3: User Removal Auto-Detection

**Corresponds to**: User Story 1 - Acceptance Scenario 3

### Test Steps

**Step 3.1**: Create temporary user

```bash
mkdir -p user/tempuser
echo '{ user.name = "tempuser"; }' > user/tempuser/default.nix
```

**Step 3.2**: Verify user is discovered

```bash
nix eval .#validUsers --json | grep tempuser
```

**Expected**: "tempuser" appears in list

**Step 3.3**: Remove user directory

```bash
rm -rf user/tempuser
```

**Step 3.4**: Verify user is no longer discovered

```bash
nix eval .#validUsers --json
```

**Expected**: "tempuser" does NOT appear in list

**Validation**: ✅ User removal automatically reflected in discovery

______________________________________________________________________

## Test 4: Configuration Generation

**Corresponds to**: User Story 1 - Acceptance Scenario 4

### Test Steps

**Step 4.1**: List all darwin configurations

```bash
nix flake show 2>&1 | grep darwinConfigurations -A 10
```

**Expected Output** (includes all user-profile combinations):

```
darwinConfigurations
├── cdrixus-home-macmini-m4: nix-darwin system
├── cdrokar-home-macmini-m4: nix-darwin system
├── cdrokar-work: nix-darwin system
└── cdrolet-work: nix-darwin system
```

**Step 4.2**: Count configurations (should match user×profile combinations)

```bash
nix eval .#darwinConfigurations --apply builtins.attrNames --json | jq 'length'
```

**Expected**: 4 (based on current specific combinations, not full cartesian product)

**Step 4.3**: Verify configuration naming convention

```bash
nix eval .#darwinConfigurations --apply builtins.attrNames --json
```

**Expected Output** (user-profile format):

```json
["cdrixus-home-macmini-m4","cdrokar-home-macmini-m4","cdrokar-work","cdrolet-work"]
```

**Validation**: ✅ All user-profile combinations generated automatically

______________________________________________________________________

## Test 5: Helper Function Usage (Darwin)

**Corresponds to**: User Story 2 - Acceptance Scenarios

### Test Steps

**Step 5.1**: Verify darwin.nix exists

```bash
ls -l system/darwin/lib/darwin.nix
```

**Expected**: File exists

**Step 5.2**: Verify darwin.nix exports mkDarwinConfig

```bash
nix eval --expr 'let lib = import ./system/darwin/lib/darwin.nix { inputs = {}; }; in builtins.attrNames lib'
```

**Expected Output**:

```
[ "mkDarwinConfig" ]
```

**Step 5.3**: Build a darwin configuration using the helper

```bash
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system --dry-run
```

**Expected**: Dry-run succeeds (shows what would be built)

**Step 5.4**: Verify all darwin configs build successfully

```bash
for config in cdrokar-home-macmini-m4 cdrokar-work cdrolet-work cdrixus-home-macmini-m4; do
  echo "Testing $config..."
  nix build .#darwinConfigurations.$config.system --dry-run || echo "FAILED: $config"
done
```

**Expected**: All configs succeed (no FAILED messages)

**Validation**: ✅ Helper function in darwin.nix works correctly

______________________________________________________________________

## Test 6: Flake Validation

**Corresponds to**: Success Criteria SC-005

### Test Steps

**Step 6.1**: Run flake check

```bash
nix flake check
```

**Expected**: No errors (warnings about unknown outputs are acceptable)

**Step 6.2**: Verify flake metadata

```bash
nix flake metadata
```

**Expected**: Displays flake information without errors

**Step 6.3**: Verify flake show output is clean

```bash
nix flake show
```

**Expected**: All configurations listed correctly, no evaluation errors

**Validation**: ✅ Flake passes validation checks

______________________________________________________________________

## Test 7: Justfile Commands

**Corresponds to**: Success Criteria SC-006, SC-007, SC-010

### Test Steps

**Step 7.1**: Test list-users command

```bash
just list-users
```

**Expected Output**:

```
Available users:
  cdrokar
  cdrolet
  cdrixus
```

**Step 7.2**: Test list-profiles command (darwin)

```bash
just list-profiles darwin
```

**Expected Output**:

```
Available darwin profiles:
  home-macmini-m4
  work
```

**Step 7.3**: Test list-profiles command (all platforms)

```bash
just list-profiles
```

**Expected**: Shows profiles for all platforms (darwin, linux if implemented)

**Step 7.4**: Test validation with invalid user

```bash
just install invaliduser home-macmini-m4 2>&1 || echo "Validation caught invalid user"
```

**Expected**: Error message about invalid user (validation working)

**Step 7.5**: Test validation with invalid profile

```bash
just install cdrokar invalidprofile 2>&1 || echo "Validation caught invalid profile"
```

**Expected**: Error message about invalid profile (validation working)

**Validation**: ✅ Justfile commands work with auto-discovered lists

______________________________________________________________________

## Test 8: Build Equivalence

**Corresponds to**: Success Criteria SC-003 (backward compatibility)

### Test Steps

**Step 8.1**: Checkout main branch and build a config

```bash
git stash  # Save current changes
git checkout main
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system --out-link result-main
```

**Step 8.2**: Checkout feature branch and build same config

```bash
git checkout 011-modularize-flake-libs
git stash pop
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system --out-link result-feature
```

**Step 8.3**: Compare derivation paths (should be identical or similar)

```bash
diff <(readlink result-main) <(readlink result-feature) || echo "Derivations differ (expected if refactor changed anything)"
```

**Note**: Derivations may differ slightly due to path changes, but functionality should be identical.

**Step 8.4**: Test that build actually succeeds (not just dry-run)

```bash
nix build .#darwinConfigurations.cdrokar-home-macmini-m4.system
```

**Expected**: Build completes successfully

**Step 8.5**: Cleanup

```bash
rm -f result-main result-feature result
```

**Validation**: ✅ Refactored configurations build successfully

______________________________________________________________________

## Test 9: Line Count Reduction

**Corresponds to**: Success Criteria SC-004

### Test Steps

**Step 9.1**: Count lines in main branch flake.nix

```bash
git checkout main
wc -l flake.nix
```

**Record**: \_\_\_ lines (baseline)

**Step 9.2**: Count lines in feature branch flake.nix

```bash
git checkout 011-modularize-flake-libs
wc -l flake.nix
```

**Record**: \_\_\_ lines (after refactor)

**Step 9.3**: Calculate reduction

```bash
# (baseline - after) / baseline * 100 = % reduction
# Expected: ≥30% reduction
```

**Validation**: ✅ flake.nix reduced by ≥30% lines

______________________________________________________________________

## Test 10: Edge Cases

**Corresponds to**: Edge Cases from spec.md

### Test 10.1: Directory without default.nix

**Setup**:

```bash
mkdir -p user/incomplete-user
# Don't create default.nix
```

**Test**:

```bash
nix eval .#validUsers --json
```

**Expected**: "incomplete-user" does NOT appear

**Cleanup**:

```bash
rmdir user/incomplete-user
```

**Validation**: ✅ Incomplete directories ignored

### Test 10.2: Invalid Nix syntax in default.nix

**Setup**:

```bash
mkdir -p user/broken-user
echo 'this is not valid nix' > user/broken-user/default.nix
```

**Test**:

```bash
nix eval .#validUsers --json 2>&1 || echo "Error caught"
```

**Expected**: Flake evaluation error (fail-fast behavior)

**Cleanup**:

```bash
rm -rf user/broken-user
```

**Validation**: ✅ Invalid Nix causes evaluation error (acceptable)

### Test 10.3: Empty platform (no profiles)

**Test**:

```bash
nix eval .#validProfiles.nixos --json
```

**Expected**: `[]` (empty list, not an error)

**Validation**: ✅ Empty profile lists handled gracefully

______________________________________________________________________

## Test 11: Full End-to-End

**Comprehensive validation of all components**

### Test Steps

**Step 11.1**: Add new user and profile

```bash
# Add user
mkdir -p user/e2euser
cat > user/e2euser/default.nix <<'EOF'
{ config, pkgs, lib, ... }:
{
  imports = [ ../shared/lib/home-manager.nix ];
  user.name = "e2euser";
  user.email = "e2e@test.com";
  user.fullName = "E2E Test User";
}
EOF

# Add profile
mkdir -p system/darwin/profiles/e2e-profile
cat > system/darwin/profiles/e2e-profile/default.nix <<'EOF'
{ config, pkgs, lib, ... }:
{
  imports = [ ../../settings/default.nix ];
  system.stateVersion = 5;
}
EOF
```

**Step 11.2**: Verify both are discovered

```bash
nix eval .#validUsers --json | grep e2euser
nix eval .#validProfiles.darwin --json | grep e2e-profile
```

**Expected**: Both appear in lists

**Step 11.3**: Add configuration combination to flake.nix

```nix
# In darwinCombinations list (if using explicit combinations)
{ user = "e2euser"; profile = "e2e-profile"; }
```

**Step 11.4**: Verify configuration appears

```bash
nix flake show | grep e2euser-e2e-profile
```

**Expected**: Configuration listed

**Step 11.5**: Build the configuration

```bash
nix build .#darwinConfigurations.e2euser-e2e-profile.system --dry-run
```

**Expected**: Dry-run succeeds

**Step 11.6**: Cleanup

```bash
rm -rf user/e2euser system/darwin/profiles/e2e-profile
# Remove from flake.nix darwinCombinations
```

**Validation**: ✅ Full workflow from discovery to build works

______________________________________________________________________

## Regression Tests

**Ensure existing functionality still works**

### Regression 1: All existing configs still build

```bash
for config in cdrokar-home-macmini-m4 cdrokar-work cdrolet-work cdrixus-home-macmini-m4; do
  echo "Building $config..."
  nix build .#darwinConfigurations.$config.system --no-link 2>&1 | tail -5
done
```

**Expected**: All builds succeed

### Regression 2: Flake check passes

```bash
nix flake check
```

**Expected**: No errors (warnings acceptable)

### Regression 3: Justfile commands work

```bash
just list-users
just list-profiles darwin
just check
```

**Expected**: All commands succeed

______________________________________________________________________

## Performance Benchmarks

**Validate performance meets constitutional requirements**

### Benchmark 1: Flake evaluation time

```bash
time nix flake show
```

**Expected**: \<30 seconds (constitutional requirement)

### Benchmark 2: Directory scanning overhead

```bash
# Measure with current users/profiles
time nix eval .#validUsers .#validProfiles --json

# Add 10 dummy users/profiles and re-test
# (Setup omitted for brevity)
time nix eval .#validUsers .#validProfiles --json
```

**Expected**: Overhead negligible (\<1 second even with 10+ entities)

______________________________________________________________________

## Troubleshooting

### Issue: Flake evaluation error "path does not exist"

**Cause**: Invalid path in helper function or missing directory

**Solution**:

```bash
# Check paths in lib files are correct relative to lib location
# darwin.nix: ../profiles/${profile} should resolve correctly
ls -la system/darwin/profiles/
```

### Issue: Configuration not appearing in flake show

**Cause**: User or profile not in defined combinations

**Solution**:

```bash
# Check darwinCombinations list in flake.nix includes the pair
nix eval --expr 'let flake = (import ./flake.nix).outputs; in flake.darwinCombinations'
```

### Issue: Build fails with "infinite recursion"

**Cause**: Circular imports or incorrect path resolution

**Solution**:

```bash
# Check imports in user and profile configs
# Ensure no mutual imports between user → profile → user
```

______________________________________________________________________

## Summary Checklist

After running all tests, verify:

- [ ] Users auto-discovered from user/ directory (Test 1)
- [ ] Profiles auto-discovered from system/\*/profiles/ (Test 2)
- [ ] User removal detected automatically (Test 3)
- [ ] Configurations generated for all combinations (Test 4)
- [ ] Helper functions work correctly (Test 5)
- [ ] Flake validation passes (Test 6)
- [ ] Justfile commands work (Test 7)
- [ ] Builds succeed (backward compatible) (Test 8)
- [ ] flake.nix reduced by ≥30% lines (Test 9)
- [ ] Edge cases handled properly (Test 10)
- [ ] End-to-end workflow works (Test 11)
- [ ] No regressions in existing functionality
- [ ] Performance meets requirements (\<30s eval time)

______________________________________________________________________

**All tests passing**: ✅ Feature ready for production use\
**Any test failing**: ⚠️ Debug and fix before merging

**Next Steps**: Run `/speckit.tasks` to generate implementation tasks.
