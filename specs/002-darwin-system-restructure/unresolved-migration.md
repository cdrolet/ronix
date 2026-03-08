# Unresolved Migration Items

**Generated**: 2025-10-26\
**Source**: `~/project/dotfiles/scripts/sh/darwin/system.sh`\
**Status**: Items that cannot be migrated to nix-darwin configuration

______________________________________________________________________

## Overview

This document tracks macOS system settings from the dotfiles `system.sh` that **cannot be expressed** in nix-darwin configuration files. These require alternative approaches such as:

- Manual execution (one-time setup)
- Activation scripts
- System-level configuration tools
- LaunchAgents/LaunchDaemons

______________________________________________________________________

## 1. NVRAM Modifications (Requires Sudo + Reboot)

### Boot Arguments

**Commands**:

```bash
sudo nvram boot-args="-v"
sudo nvram SystemAudioVolume=0
```

**Why Not in Nix**:

- Requires root privileges
- Direct NVRAM modification
- Takes effect only after reboot
- On Apple Silicon: Requires Reduced Security mode which disables Apple Pay and iOS app compatibility

**Workaround**:
Manual execution after initial system setup:

```bash
# Enable verbose boot (useful for debugging)
sudo nvram boot-args="-v"

# Mute startup sound
sudo nvram SystemAudioVolume=0

# Reboot to apply
sudo reboot
```

______________________________________________________________________

## 2. Power Management (Requires pmset) ✅ RESOLVED

**Status**: **MIGRATED** (Spec 008 - User Story 1 - 2025-10-27)

**Solution**: Migrated to `modules/darwin/system/power.nix` using `mkPmsetSetSingle` helper function from spec 008. Standby delay configured to 86400 seconds (24 hours) via idempotent activation script.

**Configuration Method**:

- Helper function: `mkPmsetSetSingle { setting = "standbydelay"; value = 86400; scope = "-a"; }`
- Idempotency: Checks current pmset value before setting (avoid unnecessary NVRAM writes)
- Logging: Reports action taken or skipped

**Reference**: See `specs/008-008-complete-unresolved-migration/spec.md` (User Story 1)

**Original Issue**: Requires `pmset` command with root privileges\
**Resolution**: Helper library (spec 008) provides idempotent pmset configuration with check-before-set pattern

______________________________________________________________________

## 3. Firewall Configuration (Requires Sudo) ✅ RESOLVED

**Status**: **MIGRATED** (Spec 009 - User Story 1 - 2025-10-29)

**Solution**: Migrated to `modules/darwin/system/firewall.nix` using `socketfilterfw` command-line tool (preferred over deprecated `defaults write` method on macOS Sequoia). Provides declarative firewall configuration with idempotency checks.

**Configuration Method**:

- Tool: `/usr/libexec/ApplicationFirewall/socketfilterfw` (native macOS firewall CLI)
- Idempotency: Checks current state with `--getglobalstate`, `--getstealthmode`, `--getloggingmode` before setting
- Daemon reload: Uses `pkill -HUP socketfilterfw` to apply changes without reboot

**Configuration Options**:

- `system.defaults.firewall.enabled`: Enable/disable firewall (default: true)
- `system.defaults.firewall.stealthMode`: Enable stealth mode to prevent ping responses (default: true)
- `system.defaults.firewall.logging`: Enable firewall logging (default: false)

**Reference**: See `specs/009-nvram-firewall-security/spec.md` (User Story 1)

**Original Issue**: Requires system-wide preferences with root privileges\
**Resolution**: Activation script (spec 009) using socketfilterfw CLI with idempotent state checks

______________________________________________________________________

## 4. Security & Privacy (System-Level) ✅ RESOLVED

**Status**: **MIGRATED** (Spec 009 - User Story 2 - 2025-10-29)

**Solution**: Migrated to `modules/darwin/system/security.nix` using `mkSystemDefaultsBool` and `mkSystemDefaultsSet` helper functions from spec 009. Provides declarative configuration for guest account and NetBIOS hostname with idempotency and validation.

**Configuration Method**:

- Helper function: `mkSystemDefaultsBool { domain, key, value }` (boolean normalization for system prefs)
- Helper function: `mkSystemDefaultsSet { domain, key, value, type }` (string/int system prefs)
- Idempotency: Checks current value with `sudo defaults read` before writing
- Validation: NetBIOS name limited to 15 characters, alphanumeric + hyphens

**Configuration Options**:

- `system.defaults.loginwindow.GuestEnabled`: Disable guest account at login (default: false)
- `system.defaults.smb.netbiosName`: Set NetBIOS hostname for SMB/Windows networking (default: "Workstation")

**Reference**: See `specs/009-nvram-firewall-security/spec.md` (User Story 2)

**Original Issue**: Requires system-level preferences with root privileges\
**Resolution**: Activation script (spec 009) with idempotent sudo defaults write operations and input validation

______________________________________________________________________

## 5. HiDPI Display Modes ✅ RESOLVED

**Status**: **MIGRATED** (Spec 008 - User Story 2 - 2025-10-27)

**Solution**: Migrated to `modules/darwin/system/screen.nix` using inline activation script with read-before-write pattern. Enables Retina-like scaled resolutions for non-Apple external displays.

**Configuration Method**:

- Activation script: `system.activationScripts.enableHiDPI`
- Idempotency: Checks current value with `defaults read` before writing
- Effect timing: Takes effect after logout/reboot (requires WindowServer restart)

**Reference**: See `specs/008-008-complete-unresolved-migration/spec.md` (User Story 2)

**Original Issue**: WindowServer system-wide setting requiring sudo\
**Resolution**: Activation script (spec 008) with check-before-write idempotency pattern

______________________________________________________________________

## 6. Spotlight Indexing Order

### Configure Search Order

**Command**:

```bash
defaults write com.apple.spotlight orderedItems -array \
    '{"enabled" = 1;"name" = "APPLICATIONS";}' \
    '{"enabled" = 1;"name" = "MENU_SPOTLIGHT_SUGGESTIONS";}' \
    # ... (complex array structure)
```

**Why Not in Nix**:

- Complex nested array/dictionary structure
- Difficult to express in Nix syntax
- May not persist across system updates

**Workaround**:
Use System Settings > Spotlight or create an activation script.

______________________________________________________________________

## 7. Startup Applications

**Configuration**:

```bash
declare -a appsToStartAtLogin=(
    '/Applications/AeroSpace.app'
    '/Applications/ProtonVPN.app'
    '/Applications/Proton Mail Bridge.app'
    '/Applications/Proton Drive.app'
);
configure_startup_from_array "appsToStartAtLogin"
```

**Why Not in Nix**:

- Requires LaunchAgent creation
- User-specific login items
- nix-darwin doesn't manage login items

**Workaround**:
Use System Settings > General > Login Items or create LaunchAgents manually.

______________________________________________________________________

## 8. Dock Items Configuration ✅ RESOLVED

**Status**: **MIGRATED** (Spec 007 - 2025-10-27)

**Solution**: Migrated to `modules/darwin/system/dock.nix` using helper library functions from spec 006. All 17 Dock items (14 applications, 3 spacers, 1 folder) and 15 Dock preferences (13 via nix-darwin defaults, 2 via activation script) are now configured declaratively.

**Configuration Method**:

- Dock items: Helper library functions (`mkDockAddApp`, `mkDockAddSpacer`, `mkDockAddFolder`)
- Dock preferences: `system.defaults.dock.*` + activation script for non-exposed settings
- All operations are idempotent and use high-level declarative functions

**Reference**: See `specs/007-007-complete-dock-migration/spec.md` for complete documentation

**Original Issue**: Requires `dockutil` tool and dynamic dock management\
**Resolution**: Helper library (spec 006) provides idempotent, declarative wrappers around dockutil

______________________________________________________________________

## 9. Service Management

### Borders Service

**Command**:

```bash
brew services start borders
```

**Why Not in Nix**:

- Homebrew service management
- Not a `defaults` command
- Would need nix-darwin LaunchAgent

**Workaround**:
Create nix-darwin LaunchAgent or use homebrew services:

```nix
launchd.user.agents.borders = {
  serviceConfig = {
    ProgramArguments = [ "${pkgs.borders}/bin/borders" ];
    RunAtLoad = true;
  };
};
```

______________________________________________________________________

## 10. One-Time Operations ✅ RESOLVED

**Status**: **MIGRATED** (Spec 008 - User Story 3 - 2025-10-27)

**Solution**: Migrated to `modules/darwin/system/initial-setup.nix` using `mkOneTimeOperation` helper function from spec 008. Both operations run once during initial configuration with marker file tracking.

**Configuration Method**:

- Helper function: `mkOneTimeOperation { name, command, checkCommand }`
- Marker files: `~/.nix-darwin-{operation-name}-complete` track completion
- Idempotency: Checks marker file first (fast path), then runs check command, only executes if needed
- Operations: Unhide Library folder, Enable Spotlight indexing

**Operations Configured**:

1. **Unhide Library folder**: `chflags nohidden ~/Library`

   - Marker: `~/.nix-darwin-unhide-library-complete`
   - Check: `test -f ~/Library/.hidden` (returns 0 if hidden)

1. **Enable Spotlight indexing**: `sudo mdutil -i on /`

   - Marker: `~/.nix-darwin-enable-spotlight-complete`
   - Check: `mdutil -s / | grep -q 'Indexing disabled'` (returns 0 if disabled)

**Reference**: See `specs/008-008-complete-unresolved-migration/spec.md` (User Story 3)

**Original Issue**: One-time operations not persistent preferences\
**Resolution**: Helper library (spec 008) provides marker file tracking with check commands for idempotent one-time operations

______________________________________________________________________

## Summary

**Total Unresolved Items**: 22 settings/operations

- **Sudo Required**: 13 settings
- **Startup/Service Management**: 3 items
- **One-Time Operations**: 2 items
- **Complex Structures**: 4 settings

**Recommendation**: Most unresolved items can be handled through:

1. One-time manual execution during initial setup
1. Nix-darwin activation scripts (for sudo commands)
1. LaunchAgents (for services)
1. System Settings GUI (for user-facing options)
