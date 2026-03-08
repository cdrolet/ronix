# Quickstart Guide: Unresolved Migration MVP

**Feature**: 008-complete-unresolved-migration\
**Phase**: 1 (Design)\
**Date**: 2025-10-27

## Overview

This guide provides step-by-step instructions for testing, verifying, and troubleshooting the Unresolved Migration MVP implementation. It covers power management, HiDPI display configuration, and one-time setup operations.

______________________________________________________________________

## Prerequisites

### System Requirements

- **Platform**: macOS (nix-darwin)
- **Permissions**: Sudo access required for system-level settings
- **Nix**: Nix 2.19+ with flakes enabled
- **nix-darwin**: Installed and configured

### Before You Start

**Check Current State**:

```bash
# Check pmset settings
pmset -g | grep standby

# Check HiDPI setting
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null || echo "Not set"

# Check Library folder visibility
ls -ld ~/Library

# Check Spotlight indexing
mdutil -s /

# Check marker files
ls -la ~/.nix-darwin-*-complete 2>/dev/null || echo "No markers found"
```

**Save output for comparison after configuration**

______________________________________________________________________

## Installation

### Step 1: Verify Branch

```bash
cd ~/project/nix-config
git checkout 008-008-complete-unresolved-migration
git pull origin 008-008-complete-unresolved-migration
```

### Step 2: Review Changes

```bash
# View new/modified files
git diff main --name-status

# Expected changes:
# M    modules/darwin/lib/mac.nix           (2 new helper functions)
# A    modules/darwin/system/power.nix      (new module)
# M    modules/darwin/system/screen.nix     (HiDPI added)
# A    modules/darwin/system/initial-setup.nix (new module)
# M    modules/darwin/system/default.nix    (import new modules)
```

### Step 3: Syntax Validation

```bash
# Validate flake syntax
nix flake check

# Expected output:
# checking ...
# [No errors]
```

### Step 4: Dry-Run Build

```bash
# Test configuration build without applying
darwin-rebuild build --flake .#$(hostname -s)

# Expected output:
# building the system configuration...
# [Success message]
```

### Step 5: Review Activation Scripts

```bash
# View generated activation scripts
nix-instantiate --eval --strict -E '
  let
    config = (import ./flake.nix).darwinConfigurations."$(hostname -s)".config;
  in
    config.system.activationScripts.configurePower.text
'

# Repeat for:
# - config.system.activationScripts.enableHiDPI.text
# - config.system.activationScripts.initialSetup.text
```

______________________________________________________________________

## Deployment

### Step 6: Apply Configuration

```bash
# Apply configuration with sudo
darwin-rebuild switch --flake .#$(hostname -s)

# Monitor output for:
# - "pmset: Set standbydelay to 86400" or "already set"
# - "Enabled HiDPI display modes" or "already enabled"
# - "One-time operation '...' completed" or "already completed"
```

**Activation Output Example**:

```
building the system configuration...
activating configuration...
running activation script: configurePower
pmset: Set standbydelay to 86400 (scope: -a)
running activation script: enableHiDPI
Enabled HiDPI display modes (takes effect after logout)
running activation script: initialSetup
One-time operation 'unhide-library' not needed (check passed)
One-time operation 'enable-spotlight' not needed (check passed)
system configuration complete.
```

______________________________________________________________________

## Verification

### V1: Verify pmset Configuration

**Command**:

```bash
pmset -g | grep standby
```

**Expected Output**:

```
 standby              1
 standbydelay         86400
```

**Interpretation**:

- `standby 1`: Standby mode enabled
- `standbydelay 86400`: 24 hours (86400 seconds)

**Verify Persistence** (after reboot):

```bash
sudo reboot
# After reboot
pmset -g | grep standbydelay
# Should still show 86400
```

______________________________________________________________________

### V2: Verify HiDPI Configuration

**Command**:

```bash
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
```

**Expected Output**:

```
1
```

**Interpretation**: `1` = HiDPI modes enabled

**Verify Display Options** (requires logout):

```bash
# 1. Logout and login
# 2. Connect external display (if available)
# 3. Open System Settings > Displays
# 4. Check for "Scaled" option
# 5. Verify additional resolution options available
```

**Note**: Without external display, setting is stored but no visible effect

______________________________________________________________________

### V3: Verify One-Time Operations

**Check Marker Files**:

```bash
ls -la ~/.nix-darwin-*-complete
```

**Expected Output**:

```
-rw-r--r-- 1 charles staff 0 Oct 27 10:30 .nix-darwin-unhide-library-complete
-rw-r--r-- 1 charles staff 0 Oct 27 10:30 .nix-darwin-enable-spotlight-complete
```

**Check Library Folder**:

```bash
ls -ld ~/Library
```

**Expected**: Directory visible (no "hidden" attribute)

**Check Spotlight**:

```bash
mdutil -s /
```

**Expected Output**:

```
/:
	Indexing enabled.
```

______________________________________________________________________

### V4: Verify Idempotency

**Purpose**: Confirm safe to re-run activation

**Command**:

```bash
darwin-rebuild switch --flake .#$(hostname -s)
```

**Expected Output**:

```
running activation script: configurePower
pmset: standbydelay already set to 86400
running activation script: enableHiDPI
HiDPI display modes already enabled
running activation script: initialSetup
One-time operation 'unhide-library' already completed (marker exists)
One-time operation 'enable-spotlight' already completed (marker exists)
```

**Verification**:

- All logs show "already set" or "already completed"
- No sudo commands executed
- Activation completes quickly (\<2 seconds for these scripts)
- No errors in output

______________________________________________________________________

## Testing Scenarios

### Scenario 1: Fresh System (First-Time Activation)

**Setup**:

```bash
# Reset to pre-configuration state
sudo pmset -a standbydelay 0
sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
rm ~/.nix-darwin-*-complete
```

**Execute**:

```bash
darwin-rebuild switch --flake .#$(hostname -s)
```

**Expected**:

- pmset: "Set standbydelay to 86400" (action taken)
- HiDPI: "Enabled HiDPI display modes" (action taken)
- Library: "not needed" or "completed" (depending on state)
- Spotlight: "not needed" or "completed" (depending on state)

**Verify**:

- `pmset -g | grep standbydelay` shows 86400
- `defaults read ...` shows 1
- Marker files created

______________________________________________________________________

### Scenario 2: Re-Activation (Idempotency Test)

**Setup**: System already configured (Scenario 1 complete)

**Execute**:

```bash
darwin-rebuild switch --flake .#$(hostname -s)
```

**Expected**:

- All operations report "already set" or "already completed"
- No actual commands executed
- Fast completion

**Verify**:

- Settings unchanged
- No errors or warnings

______________________________________________________________________

### Scenario 3: Marker File Reset

**Setup**:

```bash
# Delete marker files only (settings remain)
rm ~/.nix-darwin-*-complete
```

**Execute**:

```bash
darwin-rebuild switch --flake .#$(hostname -s)
```

**Expected**:

- pmset: "already set" (check-before-set pattern)
- HiDPI: "already enabled" (read-before-write pattern)
- Library: Check command passes, "not needed", marker created
- Spotlight: Check command passes, "not needed", marker created

**Verify**:

- Marker files recreated
- Settings unchanged (no unnecessary execution)

______________________________________________________________________

### Scenario 4: Partial Configuration

**Setup**:

```bash
# Configure pmset manually, leave others unconfigured
sudo pmset -a standbydelay 86400
sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
rm ~/.nix-darwin-*-complete
```

**Execute**:

```bash
darwin-rebuild switch --flake .#$(hostname -s)
```

**Expected**:

- pmset: "already set" (skip)
- HiDPI: "Enabled" (action taken)
- Library: "not needed" or "completed"
- Spotlight: "not needed" or "completed"

**Verify**:

- Only missing configurations applied
- Existing settings preserved

______________________________________________________________________

## Troubleshooting

### Issue 1: pmset Setting Not Applied

**Symptoms**:

```bash
pmset -g | grep standbydelay
# Shows value other than 86400
```

**Diagnosis**:

```bash
# Check activation script output
darwin-rebuild switch --flake .#$(hostname -s) 2>&1 | grep pmset

# Check for errors
# Look for "Warning: Failed to set pmset standbydelay"
```

**Possible Causes**:

1. **Insufficient privileges**: Not running with sudo
1. **Invalid pmset setting**: Typo in setting name or value
1. **System restriction**: Some Macs don't support standby

**Solutions**:

```bash
# 1. Verify sudo access
sudo -v

# 2. Manual test
sudo pmset -a standbydelay 86400
pmset -g | grep standbydelay

# 3. Check pmset capabilities
pmset -g cap | grep standby
```

**If standby not supported**: Modify `power.nix` to use different setting

______________________________________________________________________

### Issue 2: HiDPI Setting Not Persisting

**Symptoms**:

```bash
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
# Returns 0 or key not found
```

**Diagnosis**:

```bash
# Check activation script output
darwin-rebuild switch --flake .#$(hostname -s) 2>&1 | grep HiDPI

# Check plist permissions
ls -l /Library/Preferences/com.apple.windowserver.plist
```

**Possible Causes**:

1. **Permission denied**: Can't write to /Library/Preferences
1. **Plist locked**: File marked immutable
1. **Write succeeded but read fails**: Different format expected

**Solutions**:

```bash
# 1. Manual test
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
sudo defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled

# 2. Check plist file directly
sudo plutil -p /Library/Preferences/com.apple.windowserver.plist | grep DisplayResolution

# 3. Verify sudo works
sudo -v
```

______________________________________________________________________

### Issue 3: One-Time Operations Running Repeatedly

**Symptoms**:

- Operations execute on every `darwin-rebuild switch`
- Marker files not created or deleted

**Diagnosis**:

```bash
# Check marker files
ls -la ~/.nix-darwin-*-complete

# Check marker file permissions
ls -ld ~

# Check activation script output
darwin-rebuild switch --flake .#$(hostname -s) 2>&1 | grep "One-time operation"
```

**Possible Causes**:

1. **Marker creation failed**: Permission issue in home directory
1. **Marker path wrong**: Script using different path
1. **Check command always returns 0**: Incorrectly indicates operation needed

**Solutions**:

```bash
# 1. Manually create marker to test
touch ~/.nix-darwin-unhide-library-complete
darwin-rebuild switch --flake .#$(hostname -s)
# Should show "already completed"

# 2. Check home directory permissions
ls -ld ~
# Should be writable by user

# 3. Test check command manually
test -f ~/Library/.hidden && echo "hidden" || echo "visible"
```

______________________________________________________________________

### Issue 4: Activation Script Errors

**Symptoms**:

- `darwin-rebuild switch` fails
- Error messages in output
- Configuration not applied

**Diagnosis**:

```bash
# Verbose rebuild
darwin-rebuild switch --flake .#$(hostname -s) --show-trace

# Check syntax
nix flake check

# Test helper functions
nix-instantiate --eval --strict -E '
  let
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
    config = {};
    macLib = import ./modules/darwin/lib/mac.nix { inherit pkgs lib config; };
  in
    macLib.mkPmsetSet { setting = "standbydelay"; value = 86400; }
'
```

**Possible Causes**:

1. **Syntax error**: Nix expression invalid
1. **Missing import**: Module not imported in default.nix
1. **Helper function error**: Bug in mac.nix

**Solutions**:

```bash
# 1. Fix syntax errors
nix flake check
# Address any errors shown

# 2. Verify imports
grep -r "power.nix\|initial-setup.nix" modules/darwin/system/default.nix

# 3. Test modules individually
nix-instantiate --eval --strict -E '
  (import ./modules/darwin/system/power.nix { 
    config = {}; 
    lib = (import <nixpkgs> {}).lib; 
    pkgs = import <nixpkgs> {}; 
  })
'
```

______________________________________________________________________

## Manual Testing Commands

### Full Test Suite

```bash
#!/usr/bin/env bash
# test-unresolved-mvp.sh

set -e

echo "=== Testing Unresolved Migration MVP ==="

# Test 1: pmset configuration
echo "Test 1: Verify pmset standbydelay"
standby_value=$(pmset -g | grep "^ standbydelay" | awk '{print $2}')
if [ "$standby_value" = "86400" ]; then
  echo "✅ PASS: standbydelay = 86400"
else
  echo "❌ FAIL: standbydelay = $standby_value (expected 86400)"
  exit 1
fi

# Test 2: HiDPI configuration
echo "Test 2: Verify HiDPI enabled"
hidpi_value=$(defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null || echo "0")
if [ "$hidpi_value" = "1" ]; then
  echo "✅ PASS: HiDPI enabled"
else
  echo "❌ FAIL: HiDPI = $hidpi_value (expected 1)"
  exit 1
fi

# Test 3: Marker files exist
echo "Test 3: Verify marker files"
if [ -f ~/.nix-darwin-unhide-library-complete ]; then
  echo "✅ PASS: unhide-library marker exists"
else
  echo "❌ FAIL: unhide-library marker missing"
  exit 1
fi

if [ -f ~/.nix-darwin-enable-spotlight-complete ]; then
  echo "✅ PASS: enable-spotlight marker exists"
else
  echo "❌ FAIL: enable-spotlight marker missing"
  exit 1
fi

# Test 4: Library folder visible
echo "Test 4: Verify Library folder visible"
if [ ! -f ~/Library/.hidden ]; then
  echo "✅ PASS: Library folder visible"
else
  echo "❌ FAIL: Library folder hidden"
  exit 1
fi

# Test 5: Spotlight enabled
echo "Test 5: Verify Spotlight indexing"
if mdutil -s / | grep -q "Indexing enabled"; then
  echo "✅ PASS: Spotlight indexing enabled"
else
  echo "❌ FAIL: Spotlight indexing disabled"
  exit 1
fi

# Test 6: Idempotency
echo "Test 6: Verify idempotency"
rebuild_output=$(darwin-rebuild switch --flake .#$(hostname -s) 2>&1)
if echo "$rebuild_output" | grep -q "already set\|already completed\|already enabled"; then
  echo "✅ PASS: Configuration is idempotent"
else
  echo "⚠️  WARNING: Could not verify idempotency"
fi

echo ""
echo "=== All Tests Passed ==="
```

**Usage**:

```bash
chmod +x test-unresolved-mvp.sh
./test-unresolved-mvp.sh
```

______________________________________________________________________

## Rollback Procedure

### If Configuration Causes Issues

**Step 1: Rollback to Previous Generation**

```bash
# List available generations
darwin-rebuild --list-generations

# Rollback to previous generation
darwin-rebuild --rollback

# Or switch to specific generation
darwin-rebuild switch --flake .#$(hostname -s) --rollback-to <generation-number>
```

**Step 2: Revert Git Changes**

```bash
git checkout main
darwin-rebuild switch --flake .#$(hostname -s)
```

**Step 3: Manual Cleanup** (if needed)

```bash
# Reset pmset (optional)
sudo pmset -a standbydelay 0

# Disable HiDPI (optional)
sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled

# Remove marker files
rm ~/.nix-darwin-*-complete
```

______________________________________________________________________

## Performance Benchmarks

### Expected Activation Times

**First activation** (all operations needed):

- configurePower: ~100ms (check + set)
- enableHiDPI: ~100ms (read + write)
- initialSetup: ~200ms (2 operations with checks)
- **Total**: ~400ms

**Subsequent activations** (idempotent, no changes):

- configurePower: ~50ms (check only)
- enableHiDPI: ~50ms (read only)
- initialSetup: ~20ms (marker file checks only)
- **Total**: ~120ms

**Measure activation time**:

```bash
time darwin-rebuild switch --flake .#$(hostname -s)
```

______________________________________________________________________

## Additional Resources

### Documentation References

- **Feature Specification**: [spec.md](./spec.md)
- **Research Findings**: [research.md](./research.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Implementation Plan**: [plan.md](./plan.md)

### External References

- `man pmset` - Power management settings
- `man defaults` - macOS preferences system
- `man chflags` - File flags (hidden attribute)
- `man mdutil` - Spotlight management
- nix-darwin documentation: https://daiderd.com/nix-darwin/

### Support

**Issues**: Report to project maintainer
**Questions**: Refer to specification documents
**Contributions**: Follow constitutional guidelines

______________________________________________________________________

## Quick Reference

### Essential Commands

```bash
# Verify settings
pmset -g | grep standbydelay
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
ls -la ~/.nix-darwin-*-complete

# Apply configuration
darwin-rebuild switch --flake .#$(hostname -s)

# Rollback
darwin-rebuild --rollback

# Reset for testing
sudo pmset -a standbydelay 0
sudo defaults delete /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
rm ~/.nix-darwin-*-complete
```

### File Locations

- Helper library: `modules/darwin/lib/mac.nix`
- Power module: `modules/darwin/system/power.nix`
- Screen module: `modules/darwin/system/screen.nix`
- Setup module: `modules/darwin/system/initial-setup.nix`
- Marker files: `~/.nix-darwin-*-complete`

______________________________________________________________________

**Last Updated**: 2025-10-27\
**Feature**: 008-complete-unresolved-migration\
**Status**: Ready for implementation
