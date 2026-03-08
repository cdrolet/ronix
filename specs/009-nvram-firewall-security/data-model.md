# Data Model: NVRAM, Firewall, and Security Configuration

**Feature**: 009-nvram-firewall-security\
**Phase**: 1 (Design)\
**Date**: 2025-10-28

______________________________________________________________________

## Overview

This document defines the data structures, interfaces, and validation rules for implementing system-level security configuration in nix-darwin. Three primary domains:

1. **Firewall Configuration** - Application Layer Firewall via socketfilterfw
1. **Security Settings** - Login window and SMB hostname via system defaults
1. **NVRAM Boot Configuration** - Boot arguments and startup sound via NVRAM

______________________________________________________________________

## Entity Definitions

### 1. System Firewall Preferences

**Storage**: Managed by `socketfilterfw` daemon (not direct plist manipulation)\
**Verification**: `/usr/libexec/ApplicationFirewall/socketfilterfw` commands\
**Requires**: sudo privileges

**Attributes**:

- `globalState` (enum): Firewall enabled/disabled

  - Values: `on`, `off`
  - Stored internally by socketfilterfw

- `stealthMode` (enum): Stealth mode enabled/disabled

  - Values: `on`, `off`
  - Effect: When enabled, Mac doesn't respond to ICMP pings or port scans

- `loggingMode` (enum): Firewall logging enabled/disabled

  - Values: `on`, `off`
  - Logs to `/var/log/appfirewall.log` when enabled

**State Transitions**:

```
off → on (enable firewall)
on → off (disable firewall - not recommended)
```

**Validation Rules**:

- socketfilterfw must exist at `/usr/libexec/ApplicationFirewall/socketfilterfw`
- Commands must be run with sudo/root privileges
- Settings can be applied independently (no ordering requirements)

______________________________________________________________________

### 2. Login Window Preferences

**Storage**: `/Library/Preferences/com.apple.loginwindow.plist`\
**Access Method**: `defaults` command with sudo\
**Requires**: sudo privileges, affects system-wide login behavior

**Attributes**:

- `GuestEnabled` (boolean): Guest account access
  - Type: Boolean stored as integer (`0`=disabled, `1`=enabled)
  - Default: Should be `false` (disabled) for security
  - Effect: Controls whether guest account appears on login screen

**State Transitions**:

```
enabled → disabled (disable guest account - recommended)
disabled → enabled (enable guest account - not recommended)
```

**Validation Rules**:

- Value must be boolean
- System preferences store booleans as `0`/`1`, not `true`/`false`
- Changes take effect immediately (no logout required)
- Verification: Check login screen or read plist back

______________________________________________________________________

### 3. SMB Server Configuration

**Storage**: `/Library/Preferences/SystemConfiguration/com.apple.smb.server.plist`\
**Access Method**: `defaults` command with sudo\
**Requires**: sudo privileges

**Attributes**:

- `NetBIOSName` (string): SMB/CIFS network hostname
  - Type: String (max 15 characters)
  - Character restrictions: A-Z, a-z, 0-9, hyphen (-)
  - No spaces, no special characters
  - Case-insensitive (typically stored uppercase)
  - Default: "Workstation"
  - Configurable per-host via module option

**State Transitions**:

```
(unset) → "Workstation" (default)
"Workstation" → "Work-MacBook" (per-host override)
```

**Validation Rules**:

- Length: 1-15 characters (NetBIOS limitation)
- Characters: Alphanumeric + hyphens only (`[A-Za-z0-9-]+`)
- No leading/trailing hyphens
- No spaces or special characters
- Truncate if > 15 characters
- Sanitize invalid characters

______________________________________________________________________

### 4. NVRAM Variables

**Storage**: Non-volatile RAM (firmware-level)\
**Access Method**: `nvram` command with sudo\
**Requires**: sudo privileges, **reboot to take effect**

**Attributes**:

**4.1 boot-args**:

- Type: String
- Value for this feature: `"-v"` (verbose boot mode)
- Format: Space-separated kernel flags
- Effect: Displays boot log messages instead of Apple logo
- Platform support:
  - Intel: ✅ Full support
  - Apple Silicon: ⚠️ **Blocked by default** (requires Reduced Security + NVRAM modification permission)

**4.2 SystemAudioVolume**:

- Type: Hex value (byte)
- Value for this feature: `%00` (mute)
- Format: `%XX` where XX is hex byte (00-FF)
- Effect: Mutes startup sound
- Platform support:
  - Intel: ✅ Full support
  - Apple Silicon: ⚠️ May work but behavior varies by model

**State Transitions**:

```
(unset) → "-v" (enable verbose boot)
"-v" → "" (disable verbose boot)
(unset) → "%00" (mute startup sound)
"%00" → "%80" (unmute with specific volume)
```

**Validation Rules**:

- boot-args must be valid kernel flags string
- SystemAudioVolume must be hex notation `%XX`
- Write requires sudo
- **Read-back verification required** (write may silently fail on Apple Silicon)
- **Reboot required** for changes to take effect
- Platform detection: skip boot-args on Apple Silicon or warn user

______________________________________________________________________

## Helper Function Specifications

### 1. mkSystemDefaultsSet

**Purpose**: Set system-level defaults (integers and strings) with idempotency

**Signature**:

```nix
mkSystemDefaultsSet = {
  domain,       # string: Full path to preference domain
                #   Example: "/Library/Preferences/com.apple.alf"
  key,          # string: Preference key name
                #   Example: "globalstate"
  value,        # string: Value to set
                #   Example: "1", "Workstation"
  type          # string: defaults write type flag
                #   Values: "-int", "-string", "-float", "-data"
}: string;      # Returns: Bash shell script (idempotent)
```

**Behavior**:

1. Read current value: `sudo defaults read "$domain" "$key" 2>/dev/null`
1. Handle missing domain/key: Use sentinel value `"__unset__"`
1. Compare current with desired (string comparison)
1. Write only if different: `sudo defaults write "$domain" "$key" "$type" "$value"`
1. Log action taken: "Set $key to $value" or "Already set to $value"
1. Exit code 0 (non-blocking even on error)

**Error Handling**:

- Missing domain: Treat as `__unset__`, attempt write
- Missing key: Treat as `__unset__`, attempt write
- Permission denied: Log error, exit 0 (don't block activation)
- Write failure: Log error with sudo reminder, exit 0

**Example Output (Bash)**:

```bash
# Read current value
_domain="/Library/Preferences/SystemConfiguration/com.apple.smb.server"
_key="NetBIOSName"
_value="Work-MacBook"
_type="-string"
_current=$(sudo defaults read "$_domain" "$_key" 2>/dev/null || echo "__unset__")

if [ "$_current" != "$_value" ]; then
    echo "Setting $_key to $_value..."
    if sudo defaults write "$_domain" "$_key" $_type "$_value"; then
        echo "✓ $_key set successfully"
    else
        echo "✗ Failed to set $_key (permission denied? Check sudo)"
    fi
else
    echo "$_key already set to $_value"
fi
```

______________________________________________________________________

### 2. mkSystemDefaultsBool

**Purpose**: Set system-level boolean defaults with normalization (handles `0`/`1` vs `true`/`false`)

**Signature**:

```nix
mkSystemDefaultsBool = {
  domain,       # string: Full path to preference domain
  key,          # string: Preference key name
  value         # bool: Nix boolean (true or false)
}: string;      # Returns: Bash shell script with normalization
```

**Behavior**:

1. Read current value: `sudo defaults read "$domain" "$key" 2>/dev/null`
1. **Normalize current value**:
   - `1`, `true`, `yes`, `YES`, `TRUE` → normalized to `"1"`
   - `0`, `false`, `no`, `NO`, `FALSE` → normalized to `"0"`
   - Missing/error → `"__unset__"`
1. **Normalize desired value**:
   - Nix `true` → `"1"`
   - Nix `false` → `"0"`
1. Compare normalized values
1. Write if different: `sudo defaults write "$domain" "$key" -bool "$value"`
1. Log action taken
1. Exit code 0 (non-blocking)

**Normalization Rationale**:

- System preferences (`/Library/Preferences/`) store booleans as `0`/`1`
- User preferences (`~/Library/Preferences/`) store booleans as `true`/`false`
- Comparison must normalize to consistent format

**Example Output (Bash)**:

```bash
_domain="/Library/Preferences/com.apple.loginwindow"
_key="GuestEnabled"
_desired="false"  # Nix boolean as string

# Read and normalize current value
_current=$(sudo defaults read "$_domain" "$_key" 2>/dev/null || echo "__unset__")

case "$_current" in
    1|true|yes|YES|TRUE) _current_norm="1" ;;
    0|false|no|NO|FALSE) _current_norm="0" ;;
    *) _current_norm="__unset__" ;;
esac

# Normalize desired value
case "$_desired" in
    true) _desired_norm="1" ;;
    false) _desired_norm="0" ;;
esac

if [ "$_current_norm" != "$_desired_norm" ]; then
    echo "Setting $_key to $_desired..."
    sudo defaults write "$_domain" "$_key" -bool "$_desired"
    echo "✓ $_key set successfully"
else
    echo "$_key already set (current: $_current)"
fi
```

______________________________________________________________________

### 3. mkNvramSet

**Purpose**: Set NVRAM variables with idempotency and platform detection

**Signature**:

```nix
mkNvramSet = {
  variable,     # string: NVRAM variable name
                #   Example: "boot-args", "SystemAudioVolume"
  value,        # string: Value to set (may include hex %XX notation)
                #   Example: "-v", "%00"
  platform ?    # string: Optional platform filter
  "all"         #   Values: "all", "intel", "apple-silicon"
                #   Default: "all"
  warnOnAppleSilicon ? # bool: Warn instead of skip on Apple Silicon
  false         #   Default: false (skip silently)
}: string;      # Returns: Bash shell script with reboot notice
```

**Behavior**:

1. **Platform detection** (if platform != "all"):
   - Check `uname -m`: `x86_64` = Intel, `arm64` = Apple Silicon
   - If platform filter doesn't match, skip (or warn if `warnOnAppleSilicon`)
1. Read current value: `nvram "$variable" 2>/dev/null | cut -f2`
1. Compare current with desired (string comparison)
1. Write if different: `sudo nvram "$variable=$value"`
1. **Error handling**:
   - SIP restriction: Detect error, provide helpful message with resolution steps
   - Firmware password: Can't detect, generic error message
   - Permission denied: Remind about sudo requirement
1. Track if any changes made (for reboot notice)
1. **Reboot notice**: If changes made, print prominent reboot reminder
1. Exit code 0 (non-blocking even on error)

**Example Output (Bash)**:

```bash
_variable="boot-args"
_value="-v"
_platform="intel"
_needs_reboot=false

# Platform detection
if [ "$_platform" != "all" ]; then
    _arch=$(uname -m)
    if [ "$_platform" = "intel" ] && [ "$_arch" != "x86_64" ]; then
        echo "Skipping $_variable (Intel only, current platform: $_arch)"
        exit 0
    elif [ "$_platform" = "apple-silicon" ] && [ "$_arch" != "arm64" ]; then
        echo "Skipping $_variable (Apple Silicon only, current platform: $_arch)"
        exit 0
    fi
fi

# Read current value
_current=$(nvram "$_variable" 2>/dev/null | cut -f2)

if [ "$_current" != "$_value" ]; then
    echo "Setting NVRAM $_variable to $_value..."
    if sudo nvram "$_variable=$_value" 2>&1; then
        echo "✓ NVRAM $_variable set successfully"
        _needs_reboot=true
    else
        echo "✗ Failed to set NVRAM $_variable"
        if [ "$_arch" = "arm64" ]; then
            echo "  Note: On Apple Silicon, boot-args requires:"
            echo "   1. Boot to Recovery Mode (hold power button)"
            echo "   2. Utilities → Startup Security Utility"
            echo "   3. Select disk → Security Policy → Reduced Security"
            echo "   4. Check 'Allow user management of kernel extensions from identified developers'"
            echo "   5. Check 'Allow NVRAM modifications'"
            echo "  Warning: This may disable Apple Pay and iOS app compatibility."
        fi
    fi
else
    echo "NVRAM $_variable already set to $_value"
fi

# Reboot notice
if [ "$_needs_reboot" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo " ⚠️  NVRAM UPDATED - REBOOT REQUIRED"
    echo "═══════════════════════════════════════════"
    echo ""
fi
```

______________________________________________________________________

## Module Option Structures

### 1. Firewall Module (`modules/darwin/system/firewall.nix`)

**Note**: Due to known issues with `system.defaults.alf.*` on recent macOS, this module uses `system.activationScripts` with `socketfilterfw` commands directly instead of nix-darwin defaults options.

**Implementation Structure**:

```nix
{ config, lib, pkgs, ... }:

{
  # No options defined - firewall configured via activation script
  # Future: Could add options for enable/stealth/logging if needed
  
  config = {
    system.activationScripts.configureFirewall = {
      text = ''
        echo "──────────────────────────────────────"
        echo "Configuring macOS Application Firewall"
        echo "──────────────────────────────────────"
        
        SOCKETFILTERFW="/usr/libexec/ApplicationFirewall/socketfilterfw"
        
        # Enable firewall
        if ! $SOCKETFILTERFW --getglobalstate | grep -q "Firewall is enabled"; then
            echo "→ Enabling firewall..."
            $SOCKETFILTERFW --setglobalstate on
        else
            echo "✓ Firewall already enabled"
        fi
        
        # Enable stealth mode
        if ! $SOCKETFILTERFW --getstealthmode | grep -q "Stealth mode enabled"; then
            echo "→ Enabling stealth mode..."
            $SOCKETFILTERFW --setstealthmode on
        else
            echo "✓ Stealth mode already enabled"
        fi
        
        # Disable logging
        if $SOCKETFILTERFW --getloggingmode | grep -q "enabled"; then
            echo "→ Disabling logging..."
            $SOCKETFILTERFW --setloggingmode off
        else
            echo "✓ Logging already disabled"
        fi
        
        # Reload firewall
        pkill -HUP socketfilterfw 2>/dev/null || true
        
        echo "──────────────────────────────────────"
      '';
    };
  };
}
```

**Future Extension** (if options needed):

```nix
options.darwin.firewall = {
  enable = lib.mkEnableOption "Configure macOS Application Firewall";
  
  stealthMode = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable stealth mode (no response to ICMP/port scans)";
  };
  
  logging = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable firewall logging";
  };
};
```

______________________________________________________________________

### 2. Security Module (`modules/darwin/system/security.nix`)

**Module Options**:

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  macLib = import ../lib/mac.nix { inherit lib pkgs config; };
in
{
  options = {
    system.defaults.loginwindow = {
      GuestEnabled = mkOption {
        type = types.nullOr types.bool;
        default = false;
        description = ''
          Enable guest account access on the login window.
          Setting to false disables the guest account for security.
        '';
      };
    };
    
    system.defaults.smb = {
      netbiosName = mkOption {
        type = types.strMatching "[A-Za-z0-9-]{1,15}";
        default = "Workstation";
        description = ''
          NetBIOS hostname for SMB/CIFS server identification.
          Maximum 15 characters, alphanumeric and hyphens only.
          Configure per-host in hosts/<hostname>/default.nix.
        '';
        example = "Work-MacBook";
      };
    };
  };
  
  config = {
    system.activationScripts.configureSecurity = {
      text = ''
        echo "──────────────────────────────────────"
        echo "Configuring Security Settings"
        echo "──────────────────────────────────────"
        
        # Disable guest account
        ${macLib.mkSystemDefaultsBool {
          domain = "/Library/Preferences/com.apple.loginwindow";
          key = "GuestEnabled";
          value = config.system.defaults.loginwindow.GuestEnabled;
        }}
        
        # Set NetBIOS hostname
        ${macLib.mkSystemDefaultsSet {
          domain = "/Library/Preferences/SystemConfiguration/com.apple.smb.server";
          key = "NetBIOSName";
          type = "-string";
          value = config.system.defaults.smb.netbiosName;
        }}
        
        echo "──────────────────────────────────────"
      '';
    };
  };
}
```

**Per-Host Configuration Example** (`hosts/work-macbook/default.nix`):

```nix
{
  system.defaults.smb.netbiosName = "Work-MacBook";
}
```

______________________________________________________________________

### 3. NVRAM Module (`modules/darwin/system/nvram.nix`)

**Module Options**:

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  macLib = import ../lib/mac.nix { inherit lib pkgs config; };
  isIntel = pkgs.stdenv.system == "x86_64-darwin";
in
{
  options = {
    system.nvram = {
      bootArgs = mkOption {
        type = types.nullOr types.str;
        default = "-v";
        description = ''
          NVRAM boot arguments (kernel flags).
          Common values:
            "-v" = verbose boot (show boot log instead of Apple logo)
            "-s" = single-user mode
            "-x" = safe mode
          
          Note: On Apple Silicon, boot-args requires Reduced Security
          with NVRAM modification permission. This disables Apple Pay
          and iOS app compatibility. Configuration will skip on Apple
          Silicon by default.
          
          Requires reboot to take effect.
        '';
        example = "-v";
      };
      
      muteStartupSound = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Mute the startup sound (sets SystemAudioVolume NVRAM variable to 0).
          Requires reboot to take effect.
          May not work reliably on some Apple Silicon models.
        '';
      };
    };
  };
  
  config = {
    system.activationScripts.configureNVRAM = {
      text = ''
        echo "──────────────────────────────────────"
        echo "Configuring NVRAM Variables"
        echo "──────────────────────────────────────"
        
        _nvram_changes=0
        
        # Configure boot-args (Intel only)
        ${optionalString (config.system.nvram.bootArgs != null) ''
          ${macLib.mkNvramSet {
            variable = "boot-args";
            value = config.system.nvram.bootArgs;
            platform = "intel";
            warnOnAppleSilicon = true;
          }}
          [ $? -eq 0 ] && _nvram_changes=$((_nvram_changes + 1))
        ''}
        
        # Mute startup sound
        ${optionalString config.system.nvram.muteStartupSound ''
          ${macLib.mkNvramSet {
            variable = "SystemAudioVolume";
            value = "%00";
            platform = "all";
          }}
          [ $? -eq 0 ] && _nvram_changes=$((_nvram_changes + 1))
        ''}
        
        echo "──────────────────────────────────────"
        
        # Reboot notice if changes made
        if [ $_nvram_changes -gt 0 ]; then
            echo ""
            echo "═══════════════════════════════════════════"
            echo " ⚠️  NVRAM CONFIGURATION COMPLETE"
            echo " $_nvram_changes variable(s) updated"
            echo ""
            echo " REBOOT REQUIRED for changes to take effect"
            echo "═══════════════════════════════════════════"
            echo ""
        fi
      '';
    };
  };
}
```

______________________________________________________________________

## Validation Rules

### 1. Firewall Validation

**Pre-execution Checks**:

- socketfilterfw exists at `/usr/libexec/ApplicationFirewall/socketfilterfw`
- Script running with sudo/root privileges

**Post-execution Verification**:

```bash
# Verify firewall enabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "Firewall is enabled"

# Verify stealth mode
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode | grep -q "Stealth mode enabled"

# Verify logging disabled
/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode | grep -q "disabled"
```

______________________________________________________________________

### 2. System Defaults Validation

**NetBIOS Hostname**:

- Length: 1-15 characters
- Pattern: `[A-Za-z0-9-]{1,15}`
- No leading/trailing hyphens
- No spaces or special characters

**Validation at Nix Evaluation Time**:

```nix
# In option definition
type = types.strMatching "[A-Za-z0-9-]{1,15}";
```

**Validation at Runtime** (optional additional sanitization):

```bash
_hostname="${config.system.defaults.smb.netbiosName}"

# Truncate to 15 chars
_hostname="${_hostname:0:15}"

# Sanitize invalid characters
_hostname=$(echo "$_hostname" | sed 's/[^A-Za-z0-9-]/-/g')

# Remove leading/trailing hyphens
_hostname=$(echo "$_hostname" | sed 's/^-*//' | sed 's/-*$//')
```

______________________________________________________________________

### 3. NVRAM Validation

**boot-args**:

- Must be valid kernel flags string
- Common safe values: `"-v"`, `"-v -s"`, `"-x"`
- **Platform restriction**: Intel only (or warn on Apple Silicon)

**SystemAudioVolume**:

- Must be hex notation: `%XX` where XX is 00-FF
- For mute: `%00`
- Valid range: `%00` to `%FF` (0-255)

**Post-write Verification**:

```bash
# Verify boot-args was set
_verify=$(nvram boot-args 2>/dev/null | cut -f2)
if [ "$_verify" = "-v" ]; then
    echo "✓ boot-args verified"
else
    echo "✗ boot-args verification failed (current: $_verify)"
fi
```

______________________________________________________________________

## Error Handling Strategies

### 1. Firewall Errors

| Error Scenario | Detection | Action | Exit Code |
|----------------|-----------|--------|-----------|
| socketfilterfw not found | `[ ! -x "$SOCKETFILTERFW" ]` | Log error, skip configuration | 0 (non-blocking) |
| Command fails | Exit code != 0 | Log error with command output | 0 (non-blocking) |
| Permission denied | stderr contains "privilege" | Log error, remind about sudo | 0 (non-blocking) |

**Error Message Template**:

```
✗ Failed to enable firewall
  Command: socketfilterfw --setglobalstate on
  Error: (permission denied / command failed)
  Resolution: Ensure running with sudo privileges
```

______________________________________________________________________

### 2. System Defaults Errors

| Error Scenario | Detection | Action | Exit Code |
|----------------|-----------|--------|-----------|
| Domain doesn't exist | stderr "does not exist" | Treat as unset, attempt write | 0 |
| Key doesn't exist | stderr "does not exist" | Treat as unset, attempt write | 0 |
| Permission denied | Exit code != 0 | Log error with sudo reminder | 0 |
| Write fails | Exit code != 0 | Log error, continue | 0 |

**Error Message Template**:

```
✗ Failed to set NetBIOSName
  Domain: /Library/Preferences/SystemConfiguration/com.apple.smb.server
  Error: Permission denied
  Resolution: Ensure running with sudo: darwin-rebuild switch
```

______________________________________________________________________

### 3. NVRAM Errors

| Error Scenario | Detection | Action | Exit Code |
|----------------|-----------|--------|-----------|
| Platform mismatch | `uname -m` check | Skip or warn based on config | 0 |
| SIP restriction | stderr "not permitted" | Log detailed help message | 0 |
| Firmware password | stderr varies | Log generic error | 0 |
| Permission denied | stderr "privilege violation" | Log error with sudo reminder | 0 |
| Write fails | Exit code != 0 | Log error, check common causes | 0 |

**Error Message Template** (SIP Restriction):

```
✗ Failed to set boot-args (SIP restriction)
  
  On Apple Silicon, boot-args requires:
  1. Restart and hold power button until "Loading startup options" appears
  2. Select your startup disk
  3. Hold Command-R to enter Recovery Mode
  4. Utilities → Startup Security Utility
  5. Select your disk → Security Policy → Reduced Security
  6. Check "Allow user management of kernel extensions"
  7. Check "Allow NVRAM modifications"
  
  ⚠️  WARNING: This configuration:
  - Disables Apple Pay functionality
  - Prevents running iOS apps on macOS
  - Reduces system security
  
  Alternative: Verbose boot is diagnostic only. Consider skipping
  this configuration on Apple Silicon systems.
```

______________________________________________________________________

## Testing and Verification

### 1. Firewall Verification

**Check Configuration**:

```bash
# Quick status check
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode
```

**Test Stealth Mode** (from external machine):

```bash
# Should timeout with stealth mode enabled
ping <mac-ip-address>

# Should show "filtered" ports, not "closed"
nmap <mac-ip-address>
```

______________________________________________________________________

### 2. Security Settings Verification

**Guest Account**:

```bash
# Check plist
sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled
# Expected: 0

# Visual check: Login screen should not show "Guest" option
```

**NetBIOS Hostname**:

```bash
# Check plist
sudo defaults read /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName
# Expected: Your configured hostname (e.g., "Work-MacBook")

# Network check
nmblookup -A <mac-ip>
# Should show NetBIOS name in output
```

______________________________________________________________________

### 3. NVRAM Verification

**Before Reboot**:

```bash
# Check NVRAM variables were written
nvram boot-args
# Expected: boot-args	-v

nvram SystemAudioVolume
# Expected: SystemAudioVolume	%00
```

**After Reboot**:

```bash
# Verify verbose boot mode was active
# Expected: Boot screen showed log messages, not Apple logo

# Verify startup sound was muted
# Expected: No sound on boot

# Re-check NVRAM values persisted
nvram boot-args
nvram SystemAudioVolume
```

______________________________________________________________________

## Implementation Checklist

**Helper Functions** (`modules/darwin/lib/mac.nix`):

- [ ] Implement `mkSystemDefaultsSet` with read-before-write pattern
- [ ] Implement `mkSystemDefaultsBool` with boolean normalization
- [ ] Implement `mkNvramSet` with platform detection and reboot notice
- [ ] Add inline documentation for each function
- [ ] Test helper functions with `nix-instantiate`

**Firewall Module** (`modules/darwin/system/firewall.nix`):

- [ ] Create activation script with socketfilterfw commands
- [ ] Add idempotency checks for each setting
- [ ] Test firewall configuration
- [ ] Verify stealth mode from external machine
- [ ] Document module with header comments

**Security Module** (`modules/darwin/system/security.nix`):

- [ ] Define `system.defaults.loginwindow.GuestEnabled` option
- [ ] Define `system.defaults.smb.netbiosName` option with validation
- [ ] Implement activation script using helpers
- [ ] Test guest account disable
- [ ] Test per-host hostname configuration
- [ ] Document module with examples

**NVRAM Module** (`modules/darwin/system/nvram.nix`):

- [ ] Define `system.nvram.bootArgs` option
- [ ] Define `system.nvram.muteStartupSound` option
- [ ] Implement activation script with platform detection
- [ ] Add reboot requirement notice
- [ ] Test on Intel Mac (if available)
- [ ] Test on Apple Silicon Mac (verify warning/skip behavior)
- [ ] Document platform limitations

**Integration**:

- [ ] Update `modules/darwin/system/default.nix` to import new modules
- [ ] Test full configuration with `darwin-rebuild build`
- [ ] Test dry-run with `darwin-rebuild switch --dry-run`
- [ ] Deploy and verify all settings
- [ ] Update `specs/002-darwin-system-restructure/unresolved-migration.md`

______________________________________________________________________

## Summary

This design provides:

1. **Three focused modules**: firewall, security, NVRAM - each with single responsibility
1. **Three helper functions**: System defaults (int/string), system defaults (bool), NVRAM
1. **Per-host configuration**: NetBIOS hostname configurable via module options
1. **Platform awareness**: Intel/Apple Silicon detection for NVRAM boot-args
1. **Idempotent operations**: Read-before-write pattern throughout
1. **User communication**: Clear logging, reboot notices, helpful error messages
1. **Type safety**: Nix-level validation for hostnames and booleans
1. **Error resilience**: Non-blocking errors (exit code 0) to prevent activation failures

**Next Phase**: Generate `quickstart.md` with testing procedures and troubleshooting guides.
