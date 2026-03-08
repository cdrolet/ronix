# Quickstart: Complete Dock Migration from Dotfiles

**Feature**: 007-complete-dock-migration\
**Date**: 2025-10-27\
**Audience**: System administrators applying Dock configuration

______________________________________________________________________

## Overview

This guide provides step-by-step instructions for applying the migrated Dock configuration from dotfiles to your macOS system using nix-darwin.

**What This Does**:

- Configures 17 Dock items (14 apps, 3 spacers, 1 folder)
- Applies 15 Dock preferences (auto-hide, animations, sizes, etc.)
- Uses helper library functions for idempotent configuration

**Time**: ~5 minutes (plus any application installations if needed)

______________________________________________________________________

## Prerequisites

### 1. Required Software

✅ **nix-darwin installed and configured**

```bash
# Verify nix-darwin
darwin-rebuild --version

# Should output version number
```

✅ **Helper library from spec 006**

```bash
# Verify helper library exists
ls modules/darwin/lib/mac.nix

# Should show file exists
```

✅ **Applications installed**

The following applications must be installed before Dock configuration:

**Third-party applications** (14):

- `/Applications/Zen.app`
- `/Applications/Brave Browser.app`
- `/Applications/Bitwarden.app`
- `/Applications/Qobuz.app`
- `/Applications/Zed.app`
- `/Applications/Ghostty.app`
- `/Applications/Obsidian.app`
- `/Applications/UTM.app`

**System applications** (included with macOS):

- `/System/Applications/Mail.app`
- `/System/Applications/Maps.app`
- `/System/Applications/System Settings.app`
- `/System/Applications/Utilities/Activity Monitor.app`
- `/System/Applications/Utilities/Print Center.app`

**Verify application installation**:

```bash
# Check if all apps exist
for app in \
  "/Applications/Zen.app" \
  "/Applications/Brave Browser.app" \
  "/Applications/Bitwarden.app" \
  "/Applications/Qobuz.app" \
  "/Applications/Zed.app" \
  "/Applications/Ghostty.app" \
  "/Applications/Obsidian.app" \
  "/Applications/UTM.app"; do
  if [ -d "$app" ]; then
    echo "✓ $app"
  else
    echo "✗ $app (NOT FOUND)"
  fi
done
```

### 2. Repository State

✅ **On correct branch**

```bash
cd ~/project/nix-config
git branch --show-current
# Should show: 007-007-complete-dock-migration
```

✅ **No uncommitted changes** (optional, but recommended)

```bash
git status
# Should show: nothing to commit, working tree clean
```

______________________________________________________________________

## Step-by-Step Instructions

### Step 1: Review Current Dock Configuration

**Optional**: Take a screenshot of current Dock for comparison

```bash
# Capture current Dock configuration
dockutil --list > ~/dock-before.txt

# View current Dock items
cat ~/dock-before.txt
```

### Step 2: Build Darwin Configuration

**Test build** (dry-run, doesn't apply changes):

```bash
cd ~/project/nix-config
nix build .#darwinConfigurations.home-macmini.system --dry-run
```

**Expected output**: Should complete without errors

**If build fails**: Check error messages for missing dependencies or syntax errors

### Step 3: Apply Configuration

**Apply the configuration**:

```bash
darwin-rebuild switch --flake .#home-macmini
```

**What happens**:

1. nix-darwin applies `system.defaults.dock.*` settings (13 preferences)
1. Activation script runs:
   - Applies 2 additional preferences via `defaults write`
   - Clears existing Dock items
   - Adds 17 new items (apps, spacers, folder)
   - Restarts Dock to apply changes

**Expected duration**: 30-60 seconds

**Visual cue**: Dock will restart (brief disappear/reappear)

### Step 4: Verify Configuration

**Check Dock items**:

```bash
# List current Dock items
dockutil --list

# Should show 14 items (apps and folders, spacers not listed)
```

**Expected Dock layout** (left to right):

1. Zen
1. Brave Browser
1. Mail
1. Maps
1. Bitwarden
1. Qobuz
1. *(spacer)*
1. Zed
1. Ghostty
1. Obsidian
1. UTM
1. *(spacer)*
1. System Settings
1. Activity Monitor
1. Print Center
1. *(spacer)*
1. Downloads *(folder)*

**Check Dock preferences**:

```bash
# Verify auto-hide is enabled
defaults read com.apple.dock autohide
# Should return: 1

# Verify Dock size is 36
defaults read com.apple.dock tilesize
# Should return: 36

# Verify recent apps disabled
defaults read com.apple.dock show-recents
# Should return: 0

# Verify spring loading enabled
defaults read com.apple.dock enable-spring-load-actions-on-all-items
# Should return: 1
```

**Visual verification**:

- [ ] Dock auto-hides when cursor moves away
- [ ] Dock size appears smaller (36px)
- [ ] Running apps show indicator lights (dots)
- [ ] Hidden apps appear translucent
- [ ] No "Recent Applications" section

### Step 5: Test Idempotency

**Rerun configuration** (should succeed without changes):

```bash
darwin-rebuild switch --flake .#home-macmini
```

**Expected result**:

- No errors
- Dock doesn't change
- Completes quickly (no redundant operations)

**Why this matters**: Confirms helper functions are idempotent (safe to rerun)

______________________________________________________________________

## Troubleshooting

### Problem: Application Not Found

**Symptom**: Build succeeds but app missing from Dock

**Cause**: Application not installed on system

**Solution**:

```bash
# Install missing application
# Example for Homebrew-managed apps:
brew install --cask bitwarden

# Re-run darwin-rebuild
darwin-rebuild switch --flake .#home-macmini
```

### Problem: Dock Doesn't Restart

**Symptom**: Changes applied but Dock looks the same

**Cause**: Dock restart failed or delayed

**Solution**:

```bash
# Manually restart Dock
killall Dock

# Dock will automatically relaunch
```

### Problem: Build Fails with "path does not exist"

**Symptom**: Error during `darwin-rebuild` about missing file

**Cause**: Helper library or module file not present

**Solution**:

```bash
# Verify helper library exists
ls modules/darwin/lib/mac.nix

# Verify dock.nix exists
ls modules/darwin/system/dock.nix

# If missing, ensure you're on correct branch
git branch --show-current  # Should be 007-007-complete-dock-migration
```

### Problem: Permission Denied

**Symptom**: `darwin-rebuild` fails with permission errors

**Cause**: Insufficient permissions for system changes

**Solution**:

```bash
# darwin-rebuild should NOT require sudo
# If prompted, check your nix-darwin installation

# Verify you're in the nix-users group
groups | grep nix-users
```

### Problem: Dock Items in Wrong Order

**Symptom**: Apps appear but not in expected sequence

**Cause**: dockutil position conflicts or race condition

**Solution**:

```bash
# Clear Dock manually and reapply
dockutil --remove all

# Rerun configuration
darwin-rebuild switch --flake .#home-macmini
```

______________________________________________________________________

## Advanced Usage

### Customizing Dock Items

**To add/remove apps**, edit `modules/darwin/system/dock.nix`:

```nix
# Add new app
${macLib.mkDockAddApp { 
  path = "/Applications/NewApp.app"; 
  position = 18;  # After Downloads folder
}}

# Remove an app: Delete the corresponding mkDockAddApp line
```

**Remember**: Update position numbers if inserting in middle of list

### Customizing Preferences

**To change Dock settings**, edit the `system.defaults.dock` section:

```nix
system.defaults.dock = {
  tilesize = 48;  # Change from 36 to 48 for larger icons
  autohide = false;  # Disable auto-hide
  # ... other settings
};
```

### Testing Configuration Changes

**Before committing** changes:

```bash
# 1. Test build
nix build .#darwinConfigurations.home-macmini.system --dry-run

# 2. Apply to test system
darwin-rebuild switch --flake .#home-macmini

# 3. Verify changes
dockutil --list
defaults read com.apple.dock

# 4. Rollback if needed
darwin-rebuild switch --rollback
```

______________________________________________________________________

## Validation Checklist

After applying configuration, verify:

- [ ] All 14 applications appear in Dock
- [ ] 3 spacers visible as separators
- [ ] Downloads folder at end of Dock
- [ ] Dock auto-hides when cursor leaves
- [ ] Dock size is noticeably smaller (36px)
- [ ] No "Recent Applications" section
- [ ] Running apps show indicator dots
- [ ] Hidden apps appear translucent
- [ ] Minimize animation uses "scale" effect
- [ ] Windows minimize into app icon (not separate Dock spot)
- [ ] Mission Control animations are fast
- [ ] Spaces don't auto-rearrange when switching

______________________________________________________________________

## Next Steps

### After Successful Application

1. **Update documentation**:

   ```bash
   # Mark unresolved item #8 as complete
   vim specs/002-darwin-system-restructure/unresolved-migration.md
   ```

1. **Commit changes** (if satisfied):

   ```bash
   git add modules/darwin/system/dock.nix
   git commit -m "feat: complete Dock migration from dotfiles (spec 007)"
   ```

1. **Merge to main** (when ready):

   ```bash
   git checkout main
   git merge 007-007-complete-dock-migration
   ```

### If Issues Found

1. **Rollback** to previous configuration:

   ```bash
   darwin-rebuild switch --rollback
   ```

1. **Report issues** in spec 007 documentation

1. **Iterate** on configuration until correct

______________________________________________________________________

## Reference Commands

**Quick reference for common operations**:

```bash
# Check Dock items
dockutil --list

# Read all Dock preferences
defaults read com.apple.dock

# Read specific preference
defaults read com.apple.dock <key>

# Manually add item
dockutil --add "/Applications/App.app"

# Manually remove item
dockutil --remove "App"

# Restart Dock
killall Dock

# Rebuild Darwin system
darwin-rebuild switch --flake .#home-macmini

# Dry-run build
nix build .#darwinConfigurations.home-macmini.system --dry-run

# Rollback to previous generation
darwin-rebuild switch --rollback
```

______________________________________________________________________

## Support & Resources

- **Feature Spec**: [spec.md](./spec.md)
- **Implementation Plan**: [plan.md](./plan.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Research Findings**: [research.md](./research.md)
- **Helper Library Guide**: `docs/guides/helper-libraries.md`
- **nix-darwin Manual**: https://daiderd.com/nix-darwin/manual/
- **dockutil Documentation**: https://github.com/kcrawford/dockutil

______________________________________________________________________

## Summary

**Time Investment**: ~5 minutes\
**Prerequisites**: nix-darwin, helper library, apps installed\
**Key Command**: `darwin-rebuild switch --flake .#home-macmini`\
**Validation**: Visual Dock check + `dockutil --list` + `defaults read com.apple.dock`\
**Rollback**: `darwin-rebuild switch --rollback`

**Success Criteria**:

- ✅ 17 Dock items configured correctly
- ✅ 15 Dock preferences applied
- ✅ Configuration is idempotent
- ✅ Dock matches dotfiles specification
