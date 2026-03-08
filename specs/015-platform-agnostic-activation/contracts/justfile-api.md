# Justfile API Contract: Platform-Agnostic Activation

**Feature**: 015-platform-agnostic-activation\
**Date**: 2025-11-11\
**Version**: 1.0.0

## Overview

This document specifies the behavior contracts for justfile recipes modified by the platform-agnostic activation feature. These contracts define the expected inputs, outputs, side effects, and error conditions for each recipe.

______________________________________________________________________

## Modified Recipes

### `_rebuild-command`

**Purpose**: Core helper that executes either build or activation operations using platform-agnostic methods.

**Signature**:

```bash
_rebuild-command platform command_type user profile
```

**Parameters**:

- `platform` (string, required): Platform identifier (e.g., "darwin", "nixos")
- `command_type` (string, required): Operation type ("build" or activation command like "switch", "boot", "test")
- `user` (string, required): Username
- `profile` (string, required): Profile name

**Preconditions**:

- Platform must be valid (checked by caller via `_validate-all`)
- User must exist (checked by caller via `_validate-all`)
- Profile must exist for platform (checked by caller via `_validate-all`)

**Behavior**:

**If `command_type == "build"`**:

1. Get flake output path via `_flake-output-path`
1. Execute `nix build ".#{output_path}" --show-trace`
1. Creates `./result` symlink to nix store path
1. Return exit code from nix build (0 = success, non-zero = failure)

**If `command_type != "build"` (activation commands)**:

1. Check if `./result` symlink exists
   - If NO → Print error "Build result not found. Run 'just build' first." and exit 1
   - If YES → Continue
1. Determine activation script path based on platform:
   - darwin: `result/sw/bin/darwin-rebuild`
   - nixos: `result/bin/switch-to-configuration`
1. Execute activation script with platform-specific sudo handling:
   - darwin: `result/sw/bin/darwin-rebuild {command_type} --show-trace`
   - nixos: `sudo result/bin/switch-to-configuration {command_type}`
1. Return exit code from activation script

**Postconditions**:

- **Build mode**: `./result` symlink exists and points to valid nix store path
- **Activation mode**: System configuration is applied (if exit code 0)

**Error Conditions**:

| Error | Exit Code | Message | Recovery |
|-------|-----------|---------|----------|
| Nix build failure | Non-zero | Nix error output | Fix configuration errors |
| Build result missing | 1 | "Build result not found. Run 'just build' first." | Run `just build` |
| Activation script missing | Non-zero | Script execution error | Verify platform configuration |
| Activation failure | Non-zero | Activation script error output | Review logs, fix configuration |
| Permission denied | Non-zero | Permission error from script | Use sudo or check permissions |

**Side Effects**:

- **Build mode**: Creates/updates `./result` symlink, downloads derivations to nix store
- **Activation mode**: Modifies running system (services, settings, files), creates new system generation

**Example Usage**:

```bash
# Build darwin configuration
just _rebuild-command darwin build cdrokar home-macmini-m4

# Activate darwin configuration
just _rebuild-command darwin switch cdrokar home-macmini-m4

# Build nixos configuration
just _rebuild-command nixos build cdrokar desktop

# Activate nixos configuration (requires sudo internally)
just _rebuild-command nixos switch cdrokar desktop
```

______________________________________________________________________

### `build`

**Purpose**: User-facing command to build configuration without activating.

**Signature**:

```bash
build user platform profile
```

**Parameters**:

- `user` (string, required): Username
- `platform` (string, required): Platform identifier
- `profile` (string, required): Profile name

**Preconditions**:

- User, platform, and profile must be valid (enforced by `_validate-all`)

**Behavior**:

1. Validate parameters via `_validate-all`
1. Print "Building configuration for {user} on {platform} with profile {profile}..."
1. Call `_rebuild-command {platform} build {user} {profile}`
1. If successful, print "Build successful!"
1. Return exit code from `_rebuild-command`

**Postconditions**:

- `./result` symlink exists and contains built configuration
- Activation script is available in result

**Error Conditions**:

- Inherits all error conditions from `_validate-all` and `_rebuild-command`

**Side Effects**:

- Creates/updates `./result` symlink
- Downloads/builds nix derivations

**Example Usage**:

```bash
just build cdrokar darwin home-macmini-m4
just build cdrolet nixos desktop
```

**Backward Compatibility**: ✅

- Command signature unchanged
- Output format unchanged
- Behavior functionally equivalent (uses different underlying implementation)

______________________________________________________________________

### `install`

**Purpose**: User-facing command to build and activate configuration.

**Signature**:

```bash
install user platform profile
```

**Parameters**:

- `user` (string, required): Username
- `platform` (string, required): Platform identifier
- `profile` (string, required): Profile name

**Preconditions**:

- User, platform, and profile must be valid (enforced by `_validate-all`)
- **Optional**: `./result` may exist from previous build (will use it if present)

**Behavior**:

1. Validate parameters via `_validate-all`
1. Print "Installing configuration for {user} on {platform} with profile {profile}..."
1. Call `_rebuild-command {platform} switch {user} {profile}`
   - **Note**: If `./result` doesn't exist, `_rebuild-command` will error
   - Users should run `just build` first for best practice
1. If successful, print "Installation complete!"
1. Return exit code from `_rebuild-command`

**Postconditions**:

- System configuration is applied and active
- New system generation created
- Services restarted as needed

**Error Conditions**:

- Inherits all error conditions from `_validate-all` and `_rebuild-command`
- Additional: "Build result not found. Run 'just build' first." if no result

**Side Effects**:

- Modifies running system configuration
- Restarts/reloads system services
- Creates new system generation
- May prompt for password (nixos sudo)

**Example Usage**:

```bash
# Best practice: build first, then install
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4

# Quick install (builds if needed, errors if result missing)
just install cdrolet nixos desktop
```

**Backward Compatibility**: ✅

- Command signature unchanged
- Output format unchanged
- Behavior functionally equivalent (uses different underlying implementation)

**Migration Note**:

- Old behavior: Used `darwin-rebuild switch` or `nixos-rebuild switch` directly
- New behavior: Uses activation script from `./result`
- User experience: Identical (same commands, same output, same end result)

______________________________________________________________________

## Helper Recipes (Unchanged)

### `_validate-all`

**Purpose**: Validate user, platform, and profile parameters.

**Contract**: No changes from current implementation.

**Signature**:

```bash
_validate-all user platform profile
```

**Behavior**:

1. Call `_validate-user {user}`
1. Call `_validate-platform {platform}`
1. Call `_validate-profile-for-platform {platform} {profile}`
1. Exit 1 if any validation fails
1. Exit 0 if all validations pass

______________________________________________________________________

### `_flake-output-path`

**Purpose**: Return the flake output path for a given platform configuration.

**Contract**: No changes from current implementation.

**Signature**:

```bash
_flake-output-path platform user profile
```

**Behavior**:

- If platform == "darwin": Return `"darwinConfigurations.{user}-{profile}.system"`
- Else: Return `"nixosConfigurations.{user}-{profile}.config.system.build.toplevel"`

**Extensibility**: Add new platforms by adding cases to this recipe.

______________________________________________________________________

## Testing Contracts

### Unit Tests (Manual Validation)

**Test 1: Build Success**

```bash
# Given: Valid darwin configuration
# When: just build cdrokar darwin home-macmini-m4
# Then: Exit code 0, ./result exists, "Build successful!" printed
```

**Test 2: Build Failure**

```bash
# Given: Invalid configuration (syntax error)
# When: just build cdrokar darwin home-macmini-m4
# Then: Exit code non-zero, nix error shown, no "Build successful!"
```

**Test 3: Install Success**

```bash
# Given: Valid build result exists
# When: just install cdrokar darwin home-macmini-m4
# Then: Exit code 0, system updated, "Installation complete!" printed
```

**Test 4: Install Without Build**

```bash
# Given: No ./result exists
# When: just install cdrokar darwin home-macmini-m4
# Then: Exit code 1, error "Build result not found. Run 'just build' first."
```

**Test 5: Activation Failure**

```bash
# Given: Build result with configuration that fails activation
# When: just install cdrokar darwin home-macmini-m4
# Then: Exit code non-zero, activation error shown, no "Installation complete!"
```

**Test 6: Platform Extension**

```bash
# Given: New platform added to _flake-output-path and _rebuild-command
# When: just build newuser newplatform newprofile
# Then: Builds successfully using new platform's flake output path
```

### Integration Tests

**Test 1: Full Workflow**

```bash
# 1. Build configuration
just build cdrokar darwin home-macmini-m4
# Verify: ./result exists

# 2. Install configuration
just install cdrokar darwin home-macmini-m4
# Verify: System generation incremented, changes applied

# 3. Rebuild (no changes)
just install cdrokar darwin home-macmini-m4
# Verify: No errors, generation unchanged (same config)
```

**Test 2: Error Recovery**

```bash
# 1. Try install without build
just install cdrokar darwin home-macmini-m4
# Verify: Error message, exit code 1

# 2. Build first
just build cdrokar darwin home-macmini-m4
# Verify: Success

# 3. Install now succeeds
just install cdrokar darwin home-macmini-m4
# Verify: Success
```

______________________________________________________________________

## Performance Contracts

**Build Performance**:

- **Target**: Within 10% of baseline (darwin-rebuild build performance)
- **Measurement**: Time from command start to "Build successful!"
- **Baseline**: ~20-30 seconds for incremental builds (no changes)
- **Acceptable**: ≤33 seconds for incremental builds

**Activation Performance**:

- **Target**: Identical to current implementation
- **Measurement**: Time from activation start to completion
- **Expected**: No measurable difference (same activation script)

**Memory Usage**:

- **Target**: Identical to current implementation
- **Expected**: No additional memory overhead (same underlying tools)

______________________________________________________________________

## Backward Compatibility Guarantees

**Command Interface**: ✅ UNCHANGED

- All user-facing commands have same signatures
- No new required parameters
- No removed functionality

**Output Format**: ✅ UNCHANGED

- Same success messages
- Same error messages (enhanced context in some cases)
- Same exit codes

**Configuration Files**: ✅ UNCHANGED

- No changes to user configurations
- No changes to platform configurations
- No changes to profile definitions

**Existing Workflows**: ✅ COMPATIBLE

- Build then install workflow unchanged
- Direct install workflow unchanged
- Error handling patterns unchanged
- Generation management unchanged

______________________________________________________________________

## Extensibility Contracts

**Adding New Platform**:

Required changes:

1. Add case to `_flake-output-path` (1 line)
1. Add case to `_rebuild-command` for activation script path (2-3 lines)

Automatic behaviors:

- Validation works automatically (filesystem-based discovery)
- Build recipe works automatically
- Install recipe works automatically
- Error handling works automatically

**Adding New Command Type**:

Required changes:

1. Document new command type in this contract
1. Verify activation script supports it

Automatic behaviors:

- Recipe passes command through to activation script
- Error handling works automatically

______________________________________________________________________

## Migration Guide

**For Users**:

- No action required
- Commands work identically
- Output looks the same
- Performance unchanged

**For Developers**:

- Review this contract before modifying recipes
- Test both build and install workflows after changes
- Verify activation script locations if adding platforms
- Update this contract if changing behavior

**For Future Platforms**:

1. Define flake output path pattern
1. Document activation script location
1. Document sudo requirements
1. Add to `_flake-output-path` helper
1. Add to `_rebuild-command` helper
1. Test build and install workflows
1. Update quickstart.md with examples

______________________________________________________________________

## Version History

### 1.0.0 (2025-11-11)

- Initial contract for platform-agnostic activation feature
- Defines `_rebuild-command`, `build`, `install` behavior
- Establishes backward compatibility guarantees
- Documents extensibility patterns
