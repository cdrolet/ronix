# Deprecated Settings

**Generated**: 2025-10-26\
**Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`\
**Status**: Settings that are obsolete in modern macOS

______________________________________________________________________

## Overview

This document tracks settings from the dotfiles `system.sh` that have been **intentionally skipped** during migration because they:

- Are deprecated in modern macOS versions
- No longer have any effect
- Reference removed features
- Are superseded by newer settings

______________________________________________________________________

## 1. iTunes / Music.app Settings (4 settings)

### iTunes Ping

**Commands**:

```bash
defaults write com.apple.iTunes disablePingSidebar -bool true
defaults write com.apple.iTunes disablePing -bool true
```

**Status**: **DEPRECATED**\
**Reason**: iTunes Ping was discontinued by Apple in 2012. Music.app doesn't have this feature.

______________________________________________________________________

### Media Keys Control

**Command**:

```bash
defaults write com.apple.rcd.plist RCAppControlEnabled -bool false
```

**Status**: **DEPRECATED**\
**Reason**:

- iTunes is now Music.app
- Media key handling changed significantly in macOS 10.15+
- This setting no longer has effect

______________________________________________________________________

### iTunes Search Shortcuts

**Command**:

```bash
defaults write com.apple.iTunes NSUserKeyEquivalents -dict-add "Target Search Field" -string "@F"
```

**Status**: **DEPRECATED**\
**Reason**: iTunes-specific, not applicable to Music.app

______________________________________________________________________

## 2. Dashboard Settings (1 setting)

### Dashboard Developer Mode

**Command**:

```bash
defaults write com.apple.dashboard devmode -bool true
```

**Status**: **DEPRECATED**\
**Reason**: Dashboard was removed in macOS Catalina (10.15). This setting has no effect.

______________________________________________________________________

## 3. Secure Empty Trash (1 setting)

### Enable Secure Empty Trash

**Command**:

```bash
defaults write com.apple.finder EmptyTrashSecurely -bool true
```

**Status**: **DEPRECATED**\
**Reason**:

- Removed in macOS El Capitan (10.11)
- Apple removed due to SSD wear concerns
- Modern SSDs make "secure erase" less meaningful
- Setting still exists but has no effect

**Alternative**: Use `srm` command if secure deletion is needed.

______________________________________________________________________

## 4. Glass Dock Effect (1 setting)

### Enable 2D Dock

**Command**:

```bash
defaults write com.apple.dock no-glass -bool true
```

**Status**: **POSSIBLY DEPRECATED**\
**Reason**:

- The "3D glass" dock effect was removed years ago
- Modern macOS uses a different dock design
- This setting may have no effect on recent versions

**Note**: Kept in migration as `CustomUserPreferences` in case it still works on some versions.

______________________________________________________________________

## 5. Menu Bar Transparency (1 setting)

### Disable Menu Bar Transparency

**Command**:

```bash
defaults write NSGlobalDomain AppleEnableMenuBarTransparency -bool false
```

**Status**: **DEPRECATED**\
**Reason**:

- Menu bar design changed significantly in macOS Big Sur (11.0)
- Transparency is now controlled differently
- This setting may have limited or no effect

**Note**: Migrated anyway as it's harmless if ineffective.

______________________________________________________________________

## 6. Hidden/Unknown Settings

### Hide Dock

**Command**:

```bash
defaults write com.apple.dock hide-mirror -bool true
```

**Status**: **UNKNOWN**\
**Reason**:

- Not documented in official Apple documentation
- Purpose unclear
- May be deprecated or never public

**Decision**: Skipped from migration due to unknown purpose/effect.

______________________________________________________________________

## Summary

**Total Deprecated Settings**: 8-10 settings

- **Completely Removed Features**: 5 (iTunes Ping, Dashboard, Secure Trash)
- **Design Changes**: 2 (Glass Dock, Menu Bar Transparency)
- **Unknown/Undocumented**: 1 (hide-mirror)

**Migration Decisions**:

- ❌ **Skipped**: iTunes/Ping, Dashboard, hide-mirror
- ⚠️ **Migrated with Note**: Secure Empty Trash, Glass Dock, Menu Bar Transparency
  - These are included in case they still work on some macOS versions
  - Clearly marked as "migrated from system.sh"
  - Using `lib.mkDefault` so they can be easily overridden

______________________________________________________________________

## Recommendations

1. **For iTunes Settings**: If you need similar functionality in Music.app, check Music.app preferences in System Settings
1. **For Dashboard**: Use Mission Control spaces or third-party alternatives
1. **For Secure Deletion**: Use `srm` command or encrypted volumes
1. **For Dock Effects**: Modern macOS provides different customization through System Settings

______________________________________________________________________

## References

- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [macOS Release Notes](https://developer.apple.com/documentation/macos-release-notes)
- Dashboard removed: macOS Catalina 10.15 (2019)
- iTunes replaced by Music.app: macOS Catalina 10.15 (2019)
- Secure Empty Trash removed: OS X El Capitan 10.11 (2015)
- Ping discontinued: September 2012
