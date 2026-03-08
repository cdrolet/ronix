# Quick Start: Platform-Agnostic Activation

**Feature**: 015-platform-agnostic-activation\
**Date**: 2025-11-11\
**Audience**: Developers using nix-config repository

## Overview

This guide explains how to use the platform-agnostic activation system after implementation. The system provides uniform build and install commands that work identically across all supported platforms.

______________________________________________________________________

## Basic Usage

### Building a Configuration

Build compiles your configuration without activating it. This is useful for verifying that your changes are valid before applying them.

```bash
# Build for current user on darwin
just build cdrokar darwin home-macmini-m4

# Build for another user
just build cdrolet darwin work

# Build for nixos
just build cdrokar nixos desktop
```

**What happens**:

1. Validates that user, platform, and profile exist
1. Compiles configuration using `nix build`
1. Creates `./result` symlink pointing to build output
1. Prints "Build successful!" if everything works

**Output**:

```
Building configuration for cdrokar on darwin with profile home-macmini-m4...
<nix build output>
Build successful!
```

______________________________________________________________________

### Installing (Activating) a Configuration

Install activates a built configuration, applying it to your running system.

```bash
# Install darwin configuration
just install cdrokar darwin home-macmini-m4

# Install nixos configuration (will prompt for sudo password)
just install cdrokar nixos desktop
```

**What happens**:

1. Validates that user, platform, and profile exist
1. Checks if `./result` exists (from previous build)
1. Executes activation script from build output
1. Updates running system
1. Prints "Installation complete!" if successful

**Output**:

```
Installing configuration for cdrokar on darwin with profile home-macmini-m4...
<activation output>
Installation complete!
```

______________________________________________________________________

## Recommended Workflow

### Standard Workflow (Build First)

This is the safest approach: build and verify before activating.

```bash
# 1. Make changes to your configuration files
vim user/cdrokar/default.nix

# 2. Build to verify changes compile
just build cdrokar darwin home-macmini-m4

# 3. If build succeeds, activate
just install cdrokar darwin home-macmini-m4
```

**Why this is recommended**:

- Catches syntax errors early (at build time)
- Separates compile phase from activation phase
- Allows inspection of build output before applying
- Faster feedback loop for configuration errors

______________________________________________________________________

### Quick Workflow (Direct Install)

For experienced users who want to skip the separate build step.

```bash
# Make changes and install directly
vim user/cdrokar/default.nix
just install cdrokar darwin home-macmini-m4
```

**Caveat**: If you haven't built recently, you'll see:

```
Error: Build result not found. Run 'just build' first.
```

In that case, run `just build` and then try `just install` again.

______________________________________________________________________

## Platform-Specific Notes

### macOS (darwin)

**Activation**:

- No sudo required
- Changes apply immediately
- May see prompts for system preferences that require admin approval

**Example**:

```bash
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

**Generation Management**:

```bash
# View generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback
```

______________________________________________________________________

### Linux (nixos)

**Activation**:

- **Sudo required** (password prompt will appear)
- System services may restart
- Boot menu updated with new generation

**Example**:

```bash
just build cdrokar nixos desktop
just install cdrokar nixos desktop  # Will prompt for sudo password
```

**Generation Management**:

```bash
# View generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild --rollback
```

______________________________________________________________________

## Common Scenarios

### Scenario 1: Testing Configuration Changes

```bash
# 1. Make your changes
vim platform/darwin/app/aerospace.nix

# 2. Build to verify syntax
just build cdrokar darwin home-macmini-m4

# 3. If build fails, fix errors and rebuild
# (repeat until build succeeds)

# 4. Activate once build succeeds
just install cdrokar darwin home-macmini-m4

# 5. Test the changes
# If something is wrong, rollback:
darwin-rebuild --rollback
```

______________________________________________________________________

### Scenario 2: Switching Profiles

```bash
# Build and install work profile
just build cdrokar darwin work
just install cdrokar darwin work

# Later, switch back to home profile
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

______________________________________________________________________

### Scenario 3: Setting Up a New Machine

```bash
# 1. Clone the repository
git clone <repo-url> ~/nix-config
cd ~/nix-config

# 2. Build for your user and platform
just build <your-user> <your-platform> <your-profile>

# 3. Install the configuration
just install <your-user> <your-platform> <your-profile>

# Example for new darwin machine:
just build cdrolet darwin work
just install cdrolet darwin work
```

______________________________________________________________________

### Scenario 4: Adding a New Application

```bash
# 1. Add app to your user config
vim user/cdrokar/default.nix
# Add "new-app" to applications list

# 2. Create or verify app module exists
ls platform/darwin/app/new-app.nix

# 3. Build and test
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4

# 4. Verify app is installed
which new-app
```

______________________________________________________________________

## Error Handling

### Error: Build result not found

```
Error: Build result not found. Run 'just build' first.
```

**Cause**: Tried to install without building first.

**Solution**:

```bash
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

______________________________________________________________________

### Error: Invalid user/platform/profile

```
Error: Invalid user 'typo'
Valid users: cdrokar cdrolet cdronix
```

**Cause**: Typo in user/platform/profile name.

**Solution**: Check available options:

```bash
just list-users
just list-profiles
```

Then use correct spelling.

______________________________________________________________________

### Error: Nix build failure

```
error: attribute 'somePackage' missing
```

**Cause**: Syntax error or missing package in configuration.

**Solution**:

1. Read the error message carefully
1. Fix the configuration error
1. Rebuild:

```bash
just build cdrokar darwin home-macmini-m4
```

______________________________________________________________________

### Error: Activation failure

```
error: Failed to restart service 'some-service'
```

**Cause**: Service configuration is invalid or service startup failed.

**Solution**:

1. Review error message for specific service
1. Check service configuration
1. Fix configuration
1. Rebuild and reinstall:

```bash
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

If system is in bad state, rollback:

```bash
darwin-rebuild --rollback  # macOS
sudo nixos-rebuild --rollback  # NixOS
```

______________________________________________________________________

## Advanced Usage

### Building Multiple Configurations

```bash
# Build all your configurations
just build cdrokar darwin home-macmini-m4
just build cdrokar darwin work
just build cdrokar nixos desktop

# Verify all succeed before deploying
```

______________________________________________________________________

### Inspecting Build Results

```bash
# Build configuration
just build cdrokar darwin home-macmini-m4

# Inspect what's in the result
ls -la result/
ls -la result/sw/bin/  # Darwin apps and tools
ls -la result/bin/     # NixOS system tools

# Check activation script
result/sw/bin/darwin-rebuild --help  # Darwin
result/bin/switch-to-configuration --help  # NixOS (may need sudo)
```

______________________________________________________________________

### Cleaning Up Old Results

```bash
# Remove result symlink
rm result

# Or rebuild, which replaces it
just build cdrokar darwin home-macmini-m4
```

______________________________________________________________________

## Migration from Old System

### Before This Feature

You used platform-specific commands:

```bash
# Darwin
darwin-rebuild switch --flake ".#cdrokar-home-macmini-m4"

# NixOS
sudo nixos-rebuild switch --flake ".#cdrokar-desktop"
```

### After This Feature

You use uniform commands:

```bash
# Darwin
just install cdrokar darwin home-macmini-m4

# NixOS
just install cdrokar nixos desktop
```

**Benefits**:

- Same command structure across platforms
- Validation built-in (checks user/platform/profile exist)
- Clear error messages
- Separated build and activation phases
- Easier to remember

______________________________________________________________________

## Tips and Best Practices

### 1. Always Build First

```bash
# Good
just build cdrokar darwin home-macmini-m4  # Verify it compiles
just install cdrokar darwin home-macmini-m4  # Then activate

# Risky
just install cdrokar darwin home-macmini-m4  # Might fail if not built
```

### 2. Use Tab Completion

If your shell supports it:

```bash
just build cdr<TAB>  # Autocompletes to cdrokar
```

### 3. Check What Changed

```bash
# Before installing, see what will change
just diff cdrokar darwin home-macmini-m4
```

### 4. Keep Old Generations

Don't clean up generations immediately after changes. Keep a few in case you need to rollback:

```bash
# Darwin: view generations
darwin-rebuild --list-generations

# NixOS: view generations
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

### 5. Test in VM First (NixOS)

For major NixOS changes, test in a VM before applying to production:

```bash
# Build NixOS VM
nix build ".#nixosConfigurations.cdrokar-desktop.config.system.build.vm"

# Run VM
./result/bin/run-nixos-vm

# Test changes in VM, then apply to real system
```

______________________________________________________________________

## Troubleshooting

### Issue: Command hangs during build

**Symptoms**: Build seems stuck, no output for several minutes.

**Solutions**:

- Wait (large builds can take time)
- Check network (might be downloading packages)
- Press Ctrl+C to cancel, check disk space
- Try with verbose output: `nix build --show-trace --verbose`

______________________________________________________________________

### Issue: Permission denied during activation

**Symptoms** (darwin):

```
Error: Could not set system preference (permission denied)
```

**Solution**: User must be in admin group. Check with:

```bash
groups | grep admin
```

**Symptoms** (nixos):

```
sudo: command not found
```

**Solution**: Ensure sudo is installed and user is in wheel group.

______________________________________________________________________

### Issue: Activation partially succeeds

**Symptoms**: Some services start, others fail.

**Diagnosis**:

```bash
# Darwin: check service status
launchctl list | grep nix-darwin

# NixOS: check service status
systemctl --failed
```

**Solution**:

- Review failed service configurations
- Fix errors
- Rebuild and reinstall
- May need to manually stop broken services before reinstalling

______________________________________________________________________

## Getting Help

### Command Reference

```bash
# List available commands
just --list

# List valid users
just list-users

# List valid profiles by platform
just list-profiles

# List all valid combinations
just list-combinations
```

### Configuration Reference

- User configs: `user/{username}/default.nix`
- Platform configs: `platform/{platform}/`
- Profile configs: `platform/{platform}/profiles/{profile}/`
- App modules: `platform/{platform}/app/` or `platform/shared/app/`

### Documentation

- Feature specification: `specs/015-platform-agnostic-activation/spec.md`
- Implementation plan: `specs/015-platform-agnostic-activation/plan.md`
- Data model: `specs/015-platform-agnostic-activation/data-model.md`
- API contracts: `specs/015-platform-agnostic-activation/contracts/justfile-api.md`

______________________________________________________________________

## Next Steps

After familiarizing yourself with basic usage:

1. **Customize your configuration**: Add apps, modify settings
1. **Create additional profiles**: Work, home, travel, etc.
1. **Share configurations**: Help other users set up their configs
1. **Add new platforms**: Extend the system to support additional platforms

The platform-agnostic design makes all of these easier than before!
