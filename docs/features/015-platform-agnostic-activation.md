# Platform-Agnostic Activation System

**Feature**: 015-platform-agnostic-activation\
**Status**: Implemented\
**Date**: 2025-11-11

## Overview

The platform-agnostic activation system provides uniform `build` and `install` commands that work identically across all supported platforms (macOS and NixOS). This eliminates the need to remember platform-specific commands like `darwin-rebuild` or `nixos-rebuild`, making configuration management simpler and more consistent.

**Key Benefits**:

- Same commands work on all platforms
- Clean separation of build and activation phases
- Better error messages with built-in validation
- Easier to add support for new platforms
- Reduced cognitive load when working across multiple systems

## Quick Start

### Building a Configuration

Build compiles your configuration to verify it's valid without applying changes:

```bash
just build <user> <platform> <profile>

# Examples
just build cdrokar darwin home-macmini-m4
just build cdrolet darwin work
```

### Installing a Configuration

Install activates a previously built configuration, applying it to your system:

```bash
just install <user> <platform> <profile>

# Examples
just install cdrokar darwin home-macmini-m4
just install cdrolet darwin work
```

**Note**: Both darwin and NixOS now require sudo privileges for system activation. You may be prompted for your password.

## How It Works

### Architecture

The system uses a two-phase approach:

1. **Build Phase** (`just build`):

   - Uses platform-agnostic `nix build` command
   - Compiles configuration and creates `./result` symlink
   - No system changes applied
   - Fast feedback on syntax/configuration errors

1. **Activation Phase** (`just install`):

   - Verifies `./result` exists from previous build
   - Extracts platform-specific activation script from build output
   - Executes activation with appropriate permissions
   - Applies changes to running system

### Platform-Specific Details

The system centralizes platform differences in helper functions:

**Darwin (macOS)**:

- Build target: `darwinConfigurations.<user>-<profile>.system`
- Activation script: `result/sw/bin/darwin-rebuild`
- Requires: sudo privileges

**NixOS (Linux)**:

- Build target: `nixosConfigurations.<user>-<profile>.config.system.build.toplevel`
- Activation script: `result/bin/switch-to-configuration`
- Requires: sudo privileges

## Usage Workflows

### Standard Workflow (Recommended)

Build first to verify changes, then activate if successful:

```bash
# 1. Make configuration changes
vim user/cdrokar/default.nix

# 2. Build to verify syntax
just build cdrokar darwin home-macmini-m4

# 3. Review any errors, fix, and rebuild
# (repeat until build succeeds)

# 4. Activate once build is successful
just install cdrokar darwin home-macmini-m4
```

**Why this is recommended**:

- Catches errors early without system changes
- Allows inspection of build output
- Separates compilation from activation
- Safer for production systems

### Quick Workflow

For experienced users making minor changes:

```bash
# Build and install in sequence
just build cdrokar darwin home-macmini-m4 && just install cdrokar darwin home-macmini-m4
```

**Note**: If you skip the build step, install will fail with:

```
Error: Build result not found. Run 'just build' first.
```

## Common Scenarios

### Testing Configuration Changes

```bash
# 1. Make changes
vim system/darwin/app/development/helix.nix

# 2. Build to test
just build cdrokar darwin home-macmini-m4

# 3. Fix any errors and rebuild
# (errors show immediately during build)

# 4. Activate when ready
just install cdrokar darwin home-macmini-m4

# 5. If problems occur, rollback
darwin-rebuild --rollback  # macOS
sudo nixos-rebuild --rollback  # NixOS
```

### Switching Profiles

```bash
# Switch to work profile
just build cdrokar darwin work
just install cdrokar darwin work

# Later, switch back to home profile
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

### Adding a New Application

```bash
# 1. Add app to your applications list
vim user/cdrokar/default.nix
# Add "new-app" to applications array

# 2. Verify app module exists
ls system/darwin/app/*/*/new-app.nix

# 3. Build to verify
just build cdrokar darwin home-macmini-m4

# 4. Install to activate
just install cdrokar darwin home-macmini-m4

# 5. Verify app is available
which new-app
```

### Setting Up a New Machine

```bash
# 1. Clone repository
git clone <repo-url> ~/nix-config
cd ~/nix-config

# 2. Build for your configuration
just build <your-user> <your-platform> <your-profile>

# 3. Install the configuration
just install <your-user> <your-platform> <your-profile>

# Example for macOS work machine
just build cdrolet darwin work
just install cdrolet darwin work
```

## Error Handling

### Build Result Not Found

```
Error: Build result not found. Run 'just build <user> <platform> <profile>' first.
```

**Cause**: Attempted to install without building first.

**Solution**:

```bash
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4
```

### Invalid User/Platform/Profile

```
Error: Invalid user 'typo'
Valid users: cdrokar cdrolet cdronix
```

**Cause**: Typo or non-existent user/platform/profile.

**Solution**: Check available options:

```bash
just list-users
just list-profiles
```

### Build Failures

```
error: attribute 'somePackage' missing
```

**Cause**: Syntax error or missing package in configuration.

**Solution**:

1. Read error message carefully
1. Fix the configuration issue
1. Rebuild to verify fix

### Activation Failures

```
error: Failed to restart service 'some-service'
```

**Cause**: Service configuration is invalid or service won't start.

**Solution**:

1. Review service configuration
1. Fix the issue
1. Rebuild and reinstall
1. If system is unstable, rollback:

```bash
darwin-rebuild --rollback  # macOS
sudo nixos-rebuild --rollback  # NixOS
```

## Advanced Topics

### Inspecting Build Results

```bash
# Build configuration
just build cdrokar darwin home-macmini-m4

# Examine what's in the result
ls -la result/

# Darwin
ls -la result/sw/bin/  # Applications and tools
cat result/sw/bin/darwin-rebuild  # Activation script

# NixOS
ls -la result/bin/  # System tools
cat result/bin/switch-to-configuration  # Activation script
```

### Building Multiple Configurations

```bash
# Build all your configurations to verify they compile
just build cdrokar darwin home-macmini-m4
just build cdrokar darwin work
just build cdrolet darwin work

# Then deploy to appropriate machines
```

### Cleaning Up

```bash
# Remove result symlink
rm result

# Or just rebuild, which replaces it
just build cdrokar darwin home-macmini-m4
```

## Extending to New Platforms

The system is designed for easy extensibility. To add a new platform:

### 1. Add Platform Configuration Paths

Edit `justfile` function `_flake-output-path`:

```bash
_flake-output-path platform user profile:
    #!/usr/bin/env bash
    if [ "{{platform}}" = "darwin" ]; then
        echo "darwinConfigurations.{{user}}-{{profile}}.system"
    elif [ "{{platform}}" = "newplatform" ]; then
        echo "newplatformConfigurations.{{user}}-{{profile}}.system"
    else
        echo "nixosConfigurations.{{user}}-{{profile}}.config.system.build.toplevel"
    fi
```

### 2. Add Activation Script Location

Edit `justfile` function `_activation-script-path`:

```bash
_activation-script-path platform:
    #!/usr/bin/env bash
    if [ "{{platform}}" = "darwin" ]; then
        echo "result/sw/bin/darwin-rebuild"
    elif [ "{{platform}}" = "newplatform" ]; then
        echo "result/bin/newplatform-activate"
    else
        echo "result/bin/switch-to-configuration"
    fi
```

### 3. Add Platform-Specific Arguments (If Needed)

If the new platform requires different activation arguments, edit `_rebuild-command`:

```bash
_rebuild-command platform command_type user profile:
    # ... build logic ...
    
    # Activation logic
    script=$(just _activation-script-path {{platform}})
    
    if [ "{{platform}}" = "newplatform" ]; then
        sudo "$script" --custom-arg {{command_type}}
    elif [ "{{platform}}" = "darwin" ]; then
        sudo "$script" {{command_type}} --flake ".#{{user}}-{{profile}}" --show-trace
    else
        sudo "$script" {{command_type}}
    fi
```

**That's it!** The platform is now supported with the same uniform commands.

## Migration from Previous System

### Before (Platform-Specific)

```bash
# macOS
darwin-rebuild switch --flake ".#cdrokar-home-macmini-m4"

# NixOS
sudo nixos-rebuild switch --flake ".#cdrokar-desktop"
```

### After (Platform-Agnostic)

```bash
# macOS
just install cdrokar darwin home-macmini-m4

# NixOS
just install cdrokar nixos desktop
```

**Advantages**:

- Same command structure across all platforms
- Built-in validation (checks user/platform/profile exist)
- Clearer error messages
- Separated build and activation phases
- Easier to remember and document

## Troubleshooting

### Command Hangs During Build

**Symptoms**: No output for several minutes.

**Causes**:

- Large builds take time
- Downloading dependencies over network
- Disk I/O operations

**Solutions**:

- Wait patiently (some builds are legitimately slow)
- Check network connection
- Cancel (Ctrl+C) and check disk space
- Try verbose output: `nix build --show-trace --verbose`

### Permission Denied During Activation

**macOS**:

```
Error: Could not set system preference (permission denied)
```

**Solution**: Verify user is in admin group:

```bash
groups | grep admin
```

**NixOS**:

```
sudo: command not found
```

**Solution**: Ensure user is in wheel group and sudo is installed.

### Partial Activation Success

**Symptoms**: Some services start, others fail.

**Diagnosis**:

```bash
# macOS: Check service status
launchctl list | grep nix-darwin

# NixOS: Check failed services
systemctl --failed
```

**Solution**:

1. Review failed service configurations
1. Fix errors
1. Rebuild and reinstall
1. May need to manually stop broken services first

## Tips and Best Practices

### 1. Always Build Before Install

```bash
# Good: Verify before activating
just build cdrokar darwin home-macmini-m4
just install cdrokar darwin home-macmini-m4

# Risky: May fail during activation
just install cdrokar darwin home-macmini-m4
```

### 2. Keep Multiple Generations

Don't immediately clean up old generations. They allow rollback if problems occur.

```bash
# View generations (macOS)
darwin-rebuild --list-generations

# View generations (NixOS)
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

### 3. Test Major Changes in VMs (NixOS)

For significant NixOS changes, test in VM first:

```bash
# Build VM
nix build ".#nixosConfigurations.cdrokar-desktop.config.system.build.vm"

# Run VM
./result/bin/run-nixos-vm

# Test changes, then apply to real system if successful
```

### 4. Use Version Control

```bash
# Commit working configurations before experimenting
git add -A
git commit -m "Working configuration before adding X"

# Experiment freely
# ...

# If things break, revert
git reset --hard HEAD
```

### 5. Check What Changed

Review changes before activating:

```bash
# Compare build output with current system (approximate)
nix store diff-closures /run/current-system ./result
```

## Reference

### Command List

```bash
just --list              # Show all available commands
just list-users          # List valid users
just list-profiles       # List valid profiles by platform
just list-combinations   # List all valid user/platform/profile combos
just build <user> <platform> <profile>    # Build configuration
just install <user> <platform> <profile>  # Install configuration
```

### File Locations

- **User configs**: `user/<username>/default.nix`
- **Platform configs**: `system/<platform>/`
- **Profile configs**: `system/<platform>/profiles/<profile>/`
- **App modules**: `system/<platform>/app/` or `system/shared/app/`
- **Justfile**: `./justfile` (command definitions)
- **Build output**: `./result` (symlink)

### Related Documentation

- [Feature Specification](../../specs/015-platform-agnostic-activation/spec.md)
- [Implementation Plan](../../specs/015-platform-agnostic-activation/plan.md)
- [Quick Start Guide](../../specs/015-platform-agnostic-activation/quickstart.md)
- [Project Constitution](../../.specify/memory/constitution.md)
- [Repository README](../../README.md)

## Support

### Getting Help

- Review error messages carefully (they usually indicate the problem)
- Check this documentation for common scenarios
- Consult the specification for detailed requirements
- Review the justfile for command implementation details

### Contributing

If you encounter issues or have suggestions:

1. Document the problem clearly
1. Provide steps to reproduce
1. Include error messages
1. Suggest potential solutions
1. Submit via project's contribution process

## Version History

- **v1.0.0** (2025-11-11): Initial implementation
  - Platform-agnostic build command
  - Platform-agnostic install command
  - Extensibility helpers for new platforms
  - Comprehensive documentation
