# Quickstart: Darwin System Defaults Restructuring and Migration

**Feature**: Darwin System Defaults Restructuring and Migration\
**Date**: 2025-10-26\
**Purpose**: Quick reference for testing, validation, and common operations

## Prerequisites

- macOS system with nix-darwin installed
- Access to nix-config repository on branch `002-darwin-system-restructure`
- Access to dotfiles repository at `~/project/dotfiles`
- Nix 2.19+ with flakes enabled

## Quick Commands

### Build & Test

```bash
# Navigate to repository
cd /Users/charles/project/nix-config

# Check syntax and build configuration
nix flake check

# Build without applying (dry-run)
darwin-rebuild build --flake .

# Preview changes without applying
darwin-rebuild build --flake . && \
  nvd diff /run/current-system ./result

# Apply configuration (actual system change)
darwin-rebuild switch --flake .

# Apply with verbose output
darwin-rebuild switch --flake . --show-trace
```

### Verification

```bash
# Verify a specific setting was applied
defaults read com.apple.dock autohide
# Expected output: 1 (for true) or 0 (for false)

# Verify Finder settings
defaults read com.apple.finder ShowPathbar
defaults read com.apple.finder AppleShowAllExtensions

# Verify keyboard settings
defaults read NSGlobalDomain KeyRepeat
defaults read NSGlobalDomain InitialKeyRepeat

# Check all dock settings
defaults read com.apple.dock

# Check all NSGlobalDomain settings
defaults read NSGlobalDomain
```

### Rollback

```bash
# Revert to previous configuration
git revert HEAD
darwin-rebuild switch --flake .

# Or roll back to previous generation
darwin-rebuild switch --rollback

# List available generations
darwin-rebuild --list-generations
```

______________________________________________________________________

## Testing Workflow

### Phase 1: Restructure Testing

**Objective**: Verify that moving settings to topic modules doesn't break anything

```bash
# 1. Capture current state
defaults read > /tmp/before-restructure.txt

# 2. Apply restructured configuration
darwin-rebuild switch --flake .

# 3. Capture new state
defaults read > /tmp/after-restructure.txt

# 4. Compare
diff /tmp/before-restructure.txt /tmp/after-restructure.txt
# Expected: No differences (or only timestamps)

# 5. Visual verification
# - Check Dock appearance and behavior
# - Open Finder, verify path bar, status bar, extensions visible
# - Test trackpad gestures
# - Verify keyboard repeat rate
```

### Phase 2: Migration Testing

**Objective**: Verify that migrated settings from system.sh apply correctly

```bash
# 1. Identify a setting being migrated (example: Activity Monitor)
defaults read com.apple.ActivityMonitor ShowCategory

# 2. Apply migration
darwin-rebuild switch --flake .

# 3. Verify the setting changed
defaults read com.apple.ActivityMonitor ShowCategory
# Expected: Value from system.sh (e.g., 100)

# 4. Test functionality
# - Open Activity Monitor
# - Verify it shows all processes (ShowCategory = 100)
# - Check sort order and update frequency
```

### Phase 3: Regression Testing

**Objective**: Ensure no existing functionality broke

**Checklist**:

- [ ] Dock auto-hides and shows correctly
- [ ] Dock size and position are correct
- [ ] Finder shows file extensions
- [ ] Finder shows path bar and status bar
- [ ] Trackpad tap-to-click works
- [ ] Keyboard repeat rate feels normal
- [ ] Screenshots save to correct location
- [ ] Dark mode is enabled (if configured)
- [ ] System animations work as expected

______________________________________________________________________

## Module-Specific Testing

### Test dock.nix

```bash
# Verify Dock settings
defaults read com.apple.dock autohide
defaults read com.apple.dock autohide-delay
defaults read com.apple.dock tilesize
defaults read com.apple.dock show-recents

# Visual test
# - Hide and show Dock (move mouse to bottom)
# - Check Dock size
# - Verify no recent apps shown
```

### Test finder.nix

```bash
# Verify Finder settings
defaults read com.apple.finder AppleShowAllExtensions
defaults read com.apple.finder ShowPathbar
defaults read com.apple.finder ShowStatusBar
defaults read com.apple.finder FXPreferredViewStyle

# Visual test
# - Open Finder
# - Verify file extensions visible
# - Check path bar at bottom
# - Check status bar at bottom
# - Verify list view (Nlsv)
```

### Test trackpad.nix

```bash
# Verify trackpad settings
defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking
defaults read NSGlobalDomain com.apple.mouse.tapBehavior

# Physical test
# - Tap trackpad (should register as click)
# - Two-finger right-click
```

### Test keyboard.nix

```bash
# Verify keyboard settings
defaults read NSGlobalDomain KeyRepeat
defaults read NSGlobalDomain InitialKeyRepeat

# Physical test
# - Hold down a key, verify repeat rate
# - Verify delay before repeat starts
```

______________________________________________________________________

## Common Issues & Solutions

### Issue: Settings don't apply

**Symptoms**: After `darwin-rebuild switch`, `defaults read` shows old values

**Solutions**:

```bash
# 1. Log out and log back in (some settings require session restart)

# 2. Restart affected applications
killall Dock
killall Finder
killall SystemUIServer

# 3. Check if setting requires sudo (unsupported in nix-darwin user defaults)
# Document in unresolved-migration.md

# 4. Verify Nix expression syntax
nix-instantiate --eval --expr 'with import <nixpkgs> {}; system.defaults.dock.autohide'
```

### Issue: Build fails

**Symptoms**: `darwin-rebuild build` exits with error

**Solutions**:

```bash
# 1. Check syntax
nix flake check

# 2. Show detailed error trace
darwin-rebuild build --flake . --show-trace

# 3. Verify module imports
cat modules/darwin/system/default.nix
# Ensure all .nix files are listed

# 4. Check for typos in option names
# Compare against nix-darwin documentation
```

### Issue: Conflicting settings

**Symptoms**: Setting appears to be set to wrong value

**Solutions**:

```bash
# 1. Search for duplicate definitions
rg "autohide" modules/darwin/

# 2. Check host-specific overrides
cat hosts/*/default.nix | rg "autohide"

# 3. Verify precedence (last definition wins)
# In nix-darwin, later imports override earlier ones
```

### Issue: Module too large

**Symptoms**: applications.nix exceeds 200 lines

**Solutions**:

```bash
# Create sub-modules
mkdir -p modules/darwin/system/applications/
mv modules/darwin/system/applications.nix modules/darwin/system/applications/default.nix

# Split by application category
# modules/darwin/system/applications/
#   ├── default.nix (imports all)
#   ├── browsers.nix (Safari, etc.)
#   ├── productivity.nix (Mail, Calendar, etc.)
#   └── utilities.nix (Activity Monitor, etc.)
```

______________________________________________________________________

## Validation Checklist

### Pre-Migration

- [ ] Current configuration builds successfully
- [ ] Current system state captured (defaults read > before.txt)
- [ ] Git branch created and checked out
- [ ] Backup of current configuration exists

### Post-Restructure

- [ ] All topic modules created
- [ ] system/default.nix imports all modules
- [ ] defaults.nix imports ./system
- [ ] Configuration builds successfully
- [ ] No settings regressions (diff before/after)
- [ ] All constitutional requirements met

### Post-Migration

- [ ] Settings from system.sh migrated or documented
- [ ] unresolved-migration.md created with unsupported settings
- [ ] deprecated-settings.md created with skipped settings
- [ ] All hosts can build and apply configuration
- [ ] Runtime verification passed (spot checks)
- [ ] Constitution updated with organizational principles

______________________________________________________________________

## Performance Benchmarks

### Build Times

```bash
# Measure build time
time darwin-rebuild build --flake .

# Expected:
# - Clean build: < 5 minutes
# - Incremental build: < 30 seconds
# - Evaluation only: < 5 seconds
```

### Apply Times

```bash
# Measure apply time
time darwin-rebuild switch --flake .

# Expected:
# - First apply: 1-3 minutes
# - Subsequent applies: < 1 minute
```

### System Responsiveness

- Dock animations should be smooth
- Finder should open instantly
- System Preferences should respond immediately
- No lag in keyboard or trackpad input

______________________________________________________________________

## Debugging Tips

### View Nix Expression

```bash
# See what Nix expression is generated
nix eval .#darwinConfigurations.work-macbook.config.system.defaults.dock --json

# See all system defaults
nix eval .#darwinConfigurations.work-macbook.config.system.defaults --json | jq
```

### Trace Module Imports

```bash
# Show module import tree
nix-instantiate --eval --expr 'builtins.trace (builtins.attrNames (import ./modules/darwin/system {})) "done"'
```

### Compare Configurations

```bash
# Compare two hosts
diff <(nix eval .#darwinConfigurations.work-macbook.config.system.defaults --json) \
     <(nix eval .#darwinConfigurations.home-macmini.config.system.defaults --json)
```

### Check for Unused Settings

```bash
# Find settings defined but not imported
rg "system.defaults" modules/darwin/system/*.nix | cut -d: -f2 | sort | uniq -c
```

______________________________________________________________________

## Migration Verification Script

```bash
#!/usr/bin/env bash
# verify-migration.sh - Verify settings from system.sh were migrated

set -euo pipefail

echo "Verifying migrated settings..."

# Extract domains from system.sh
grep -E "^defaults write" ~/project/dotfiles/scripts/sh/darwin/system.sh | \
  awk '{print $3}' | sort | uniq > /tmp/domains-in-systemsh.txt

# Check each domain
while read -r domain; do
  echo "Checking domain: $domain"
  
  # Check if domain exists in nix configuration
  if rg -q "$domain" modules/darwin/system/*.nix; then
    echo "  ✓ Found in nix config"
  else
    echo "  ✗ NOT found in nix config"
    echo "  → Check unresolved-migration.md or deprecated-settings.md"
  fi
done < /tmp/domains-in-systemsh.txt

echo ""
echo "Verification complete."
echo "Review any '✗ NOT found' entries in documentation files."
```

______________________________________________________________________

## Next Steps

After successful planning:

1. Run `/speckit.tasks` to generate detailed implementation tasks
1. Begin implementation following task order
1. Test incrementally after each topic module
1. Document unresolved settings as they're discovered
1. Update constitution after migration complete

______________________________________________________________________

## Resources

- [nix-darwin options reference](https://daiderd.com/nix-darwin/manual/index.html)
- [macOS defaults commands](https://macos-defaults.com/)
- [Blueprint pattern](https://github.com/numtide/blueprint)
- Current system.sh: `~/project/dotfiles/scripts/sh/darwin/system.sh`
- Spec: `specs/002-darwin-system-restructure/spec.md`
- Data model: `specs/002-darwin-system-restructure/data-model.md`
