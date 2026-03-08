# Research: NVRAM, Firewall, and Security Configuration

**Feature**: 009-nvram-firewall-security\
**Research Date**: 2025-10-28\
**Phase**: 0 (Technical Investigation)

______________________________________________________________________

## Executive Summary

This document consolidates research findings for implementing system-level security configuration in nix-darwin: firewall protection, login security settings, and NVRAM boot configuration. All operations require sudo privileges and must be idempotent. Key decisions:

1. **Firewall**: Use `socketfilterfw` command (not `defaults write`) for reliability on macOS Sequoia 15+
1. **System Defaults**: Implement read-before-write pattern with type-aware comparison
1. **NVRAM**: Support Intel Macs fully; warn/skip boot-args on Apple Silicon due to SIP restrictions
1. **Per-Host Configuration**: Use nix-darwin module options with per-host overrides
1. **Helper Functions**: Create `mkSystemDefaultsSet`, `mkNvramSet`, and optional `mkFirewallConfig`

______________________________________________________________________

## R1: System Defaults Command Research

### Research Questions Answered

✅ **How to read system-level defaults from /Library/Preferences/ (requires sudo)?**\
Use `sudo defaults read <domain> <key>`. Output is plain value on single line. Exit code 0 on success, 1 on error (missing domain/key).

✅ **What's the format for checking current values for idempotency?**\
Plain text output, one value per line. Parse directly for comparison.

✅ **How to handle different value types (int, bool, string)?**

- Integer: Direct string comparison works (`"1"` vs `"1"`)
- Boolean: **Critical discovery** - system prefs use `1`/`0`, not `true`/`false`. Must normalize!
- String: Direct comparison with proper quoting

✅ **Do system defaults require process/service restarts?**\
Generally no, but firewall is exception (see R2). Display settings may require logout (precedent: spec 008 HiDPI).

✅ **What happens if preference domain doesn't exist yet?**\
Returns exit code 1 with stderr: `"Domain ... does not exist"`. Handle with `2>/dev/null || echo "__unset__"`.

### Key Findings

**Command Patterns**:

```bash
# Read system preference
sudo defaults read /Library/Preferences/com.apple.alf globalstate
# Output: 1

# Write system preference
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1
```

**Boolean Storage Inconsistency** (CRITICAL):

- User preferences (`~/Library/Preferences/`): Store as `true`/`false`
- System preferences (`/Library/Preferences/`): Store as `1`/`0`
- **Impact**: Comparison logic must normalize boolean values

**Error Handling**:

- Missing domain: `"Domain ... does not exist"` (exit code 1)
- Missing key: `"domain/default pair ... does not exist"` (exit code 1)
- **Solution**: Use `2>/dev/null || echo "__unset__"` pattern

### Idempotent Pattern (Read-Before-Write)

```bash
# Generic pattern for integers and strings
domain="/Library/Preferences/com.apple.alf"
key="globalstate"
desired="1"

current=$(sudo defaults read "$domain" "$key" 2>/dev/null || echo "__unset__")
if [ "$current" != "$desired" ]; then
    sudo defaults write "$domain" "$key" -int "$desired"
    echo "Set $key to $desired"
else
    echo "Already set to $desired"
fi
```

**Boolean-Safe Pattern** (handles normalization):

```bash
# For boolean values - normalize before comparison
domain="/Library/Preferences/com.apple.loginwindow"
key="GuestEnabled"
desired="false"  # Nix boolean

# Read current value
current=$(sudo defaults read "$domain" "$key" 2>/dev/null || echo "__unset__")

# Normalize current value (1/0 → true/false or 0/1)
case "$current" in
    1|true|yes|YES|TRUE) current_normalized="1" ;;
    0|false|no|NO|FALSE) current_normalized="0" ;;
    *) current_normalized="__unset__" ;;
esac

# Normalize desired value
case "$desired" in
    true) desired_normalized="1" ;;
    false) desired_normalized="0" ;;
esac

# Compare and write
if [ "$current_normalized" != "$desired_normalized" ]; then
    sudo defaults write "$domain" "$key" -bool "$desired"
    echo "Set $key to $desired"
else
    echo "Already set (current: $current)"
fi
```

### Decision: Helper Function Design

Create **two helper functions** in `modules/darwin/lib/mac.nix`:

1. **mkSystemDefaultsSet** - Generic for int/string types
1. **mkSystemDefaultsBool** - Boolean-specific with normalization

**Rationale**: Boolean normalization complexity warrants separate function. Keeps int/string function simple and maintainable.

______________________________________________________________________

## R2: Firewall Configuration Research

### Research Questions Answered

✅ **Does firewall require service restart after defaults write?**\
Using `socketfilterfw` does NOT require manual restart (handles automatically). Using `defaults write` would require restart, but this method is deprecated.

✅ **How to verify firewall is actually running after configuration?**\
Use `socketfilterfw --getglobalstate`, `--getstealthmode`, `--getloggingmode`.

✅ **What's the command to restart firewall service?**\
`sudo pkill -HUP socketfilterfw` (SIGHUP reload). Recommended as safety measure even though not strictly required.

✅ **Are there dependencies between globalstate, stealthenabled, loggingenabled?**\
No dependencies. All three settings are independent. Can be set in any order.

✅ **How to test stealth mode is working (port scanning)?**\
From external machine: `ping <mac-ip>` should timeout. Port scan with `nmap` should show host as "filtered" not "closed".

### Key Findings

**CRITICAL DISCOVERY: defaults write Method Deprecated**

- ❌ `defaults write /Library/Preferences/com.apple.alf.*` - **NOT RELIABLE** on macOS Sequoia (15+)
- ✅ `socketfilterfw` command - **RECOMMENDED** for all macOS versions
- **Source**: nix-darwin issue #1243, confirmed by community testing

**Why socketfilterfw is Better**:

1. Official Apple command-line tool
1. Works reliably on macOS Sequoia (15+) and later
1. Handles service restarts automatically
1. No need for manual firewall daemon reload
1. Provides comprehensive verification commands

### Recommended Configuration Method

**Use socketfilterfw via activation script**:

```bash
# Configure macOS Application Firewall
SOCKETFILTERFW="/usr/libexec/ApplicationFirewall/socketfilterfw"

# Enable firewall
if ! $SOCKETFILTERFW --getglobalstate | grep -q "Firewall is enabled"; then
    echo "Enabling firewall..."
    $SOCKETFILTERFW --setglobalstate on
else
    echo "Firewall already enabled"
fi

# Enable stealth mode
if ! $SOCKETFILTERFW --getstealthmode | grep -q "Stealth mode enabled"; then
    echo "Enabling stealth mode..."
    $SOCKETFILTERFW --setstealthmode on
else
    echo "Stealth mode already enabled"
fi

# Disable logging
if $SOCKETFILTERFW --getloggingmode | grep -q "enabled"; then
    echo "Disabling logging..."
    $SOCKETFILTERFW --setloggingmode off
else
    echo "Logging already disabled"
fi

# Reload firewall (safety measure)
pkill -HUP socketfilterfw 2>/dev/null || true
```

### Command Reference

**socketfilterfw Commands for Our Use Case**:

```bash
# Global state
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on|off

# Stealth mode
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on|off

# Logging control
/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode
/usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on|off
```

**Verification Commands**:

```bash
# Check all settings
echo "Firewall: $($SOCKETFILTERFW --getglobalstate)"
echo "Stealth: $($SOCKETFILTERFW --getstealthmode)"
echo "Logging: $($SOCKETFILTERFW --getloggingmode)"
```

### Testing Stealth Mode

**From External Machine**:

```bash
# Test 1: ICMP ping (should timeout with stealth mode enabled)
ping <mac-ip-address>
# Expected: Request timeout, 100% packet loss

# Test 2: Port scan (should show "filtered" not "closed")
nmap <mac-ip-address>
# Expected: Host appears heavily filtered or down
```

**What Stealth Mode Does**:

- Mac does NOT respond to ICMP ping requests
- Mac does NOT respond to port scans or probing
- Computer appears as if it doesn't exist on network
- Computer STILL answers incoming requests for authorized applications

### Decision: Implementation Strategy

**Do NOT use** `system.defaults.alf.*` - known issue with nix-darwin on recent macOS.

**Instead, use** `system.activationScripts.extraActivation.text` with `socketfilterfw` commands.

**Optionally**: Create helper function `mkFirewallConfig` for cleaner syntax, though the activation script is simple enough to inline.

______________________________________________________________________

## R3: NVRAM Configuration Research

### Research Questions Answered

✅ **How to check current NVRAM values for idempotency?**\
Use `nvram variable-name`. Output format: `variable<TAB>value`. Parse with `cut -f2` or `awk`.

✅ **What's the output format of `nvram -p` or `nvram boot-args`?**\
Tab-separated: `boot-args	-v`. Exit code 0 if exists, 1 if doesn't exist.

✅ **Are there any risks with NVRAM writes (corruption, boot failure)?**\
For our use case (boot-args="-v", SystemAudioVolume=0): **Very low risk**. Verbose mode is diagnostic-only. NVRAM reset available (Cmd+Option+P+R on Intel).

✅ **How to communicate reboot requirement to users?**\
Activation script should print clear message: `"NVRAM configuration complete. Reboot required for changes to take effect."`

✅ **What happens if NVRAM write fails (SIP, firmware password)?**\
Exit code 1 with error message. **Apple Silicon: boot-args blocked by default** (requires Permissive Security). Firmware password: no programmatic detection possible.

### Key Findings

**CRITICAL: Apple Silicon boot-args Restriction**

- **Intel Macs**: boot-args fully supported ✅
- **Apple Silicon**: boot-args **BLOCKED by default** ❌
  - Requires: Reduced Security → Permissive Security + `csrutil enable --without nvram`
  - Disabling NVRAM protection breaks Apple Pay and iOS app compatibility
  - iBoot enforces allow-list for boot arguments
  - **Recommendation**: Skip boot-args on Apple Silicon OR warn users about requirements

**NVRAM Variables for Our Use Case**:

| Variable | Value | Platform | Risk | Effect |
|----------|-------|----------|------|--------|
| `boot-args` | `"-v"` | Intel: ✅ Full support<br>Apple Silicon: ⚠️ Requires SIP mod | Very Low | Verbose boot mode (diagnostic) |
| `SystemAudioVolume` | `%00` (hex) | Intel: ✅ Full support<br>Apple Silicon: ⚠️ May be unstable | Very Low | Mute startup sound |

### Idempotent Pattern

```bash
# Read-compare-write pattern for NVRAM
variable="boot-args"
desired="-v"

# Read current value
current=$(nvram "$variable" 2>/dev/null | cut -f2)

# Compare and write only if different
if [ "$current" != "$desired" ]; then
    echo "Setting NVRAM $variable to $desired..."
    if sudo nvram "$variable=$desired"; then
        echo "✓ NVRAM $variable set successfully"
        needs_reboot=true
    else
        echo "✗ Failed to set NVRAM $variable (SIP restriction? Firmware password?)"
    fi
else
    echo "NVRAM $variable already set to $desired"
fi

# Notify user if reboot needed
if [ "$needs_reboot" = true ]; then
    echo ""
    echo "⚠️  NVRAM CONFIGURATION COMPLETE"
    echo "⚠️  REBOOT REQUIRED for changes to take effect"
    echo ""
fi
```

**SystemAudioVolume (Hex Value)**:

```bash
# SystemAudioVolume uses hex notation
variable="SystemAudioVolume"
desired="%00"  # Mute

current=$(nvram "$variable" 2>/dev/null | cut -f2)

if [ "$current" != "$desired" ]; then
    sudo nvram "$variable=$desired"
fi
```

### Platform Detection Pattern

```nix
{
  system.activationScripts.configureNVRAM = lib.mkIf (pkgs.stdenv.system == "x86_64-darwin") {
    # Only run NVRAM boot-args configuration on Intel Macs
    text = ''
      # Configure boot-args (Intel only)
      current=$(nvram boot-args 2>/dev/null | cut -f2)
      if [ "$current" != "-v" ]; then
          sudo nvram boot-args="-v"
          echo "NVRAM boot-args set. Reboot required."
      fi
    '';
  };

  # SystemAudioVolume can be attempted on both platforms
  system.activationScripts.muteStartupSound = {
    text = ''
      current=$(nvram SystemAudioVolume 2>/dev/null | cut -f2)
      if [ "$current" != "%00" ]; then
          if sudo nvram SystemAudioVolume=%00; then
              echo "Startup sound muted. Reboot required."
          else
              echo "Warning: Could not mute startup sound (may not be supported on this hardware)"
          fi
      fi
    '';
  };
}
```

### Error Detection and Handling

**Exit Codes**:

- `0` = Success
- `1` = Error (permission denied, SIP restriction, variable not found)

**Common Error Messages**:

```bash
# Permission denied (missing sudo)
$ nvram boot-args="-v"
Error setting variable - 'boot-args': (iokit/common) privilege violation.

# SIP restriction (Apple Silicon with default security)
$ sudo nvram boot-args="-v"
Error setting variable - 'boot-args': (iokit/common) not permitted.
```

**Recommended Error Handling**:

```bash
if ! sudo nvram boot-args="-v" 2>&1; then
    echo "⚠️  Failed to set boot-args"
    echo "    This is normal on Apple Silicon with default security settings."
    echo "    To enable: Boot to Recovery → Startup Security Utility → Reduced Security → Allow NVRAM modifications"
    echo "    Note: This may disable Apple Pay and iOS app compatibility."
    echo "    Alternative: Verbose mode is diagnostic only - safe to skip."
fi
```

### Safety Assessment

**boot-args="-v"** (Verbose Boot):

- **Risk Level**: ✅ VERY LOW
- **Effect**: Displays boot log messages on screen instead of Apple logo
- **Reversibility**: Easy - just set `boot-args=""` or reset NVRAM
- **Boot Failure Risk**: None - verbose mode is diagnostic/informational only
- **Recovery**: NVRAM reset (Cmd+Option+P+R on Intel, automatic on Apple Silicon)

**SystemAudioVolume=%00** (Mute Startup Sound):

- **Risk Level**: ✅ VERY LOW
- **Effect**: Cosmetic only - no system functionality impact
- **Reversibility**: Easy - set to different value or delete variable
- **Boot Failure Risk**: None
- **Note**: Some Apple Silicon models may not respect this setting

### Reboot Requirement Communication

**Recommended User Notification Patterns**:

**Pattern 1: Count-Based** (Recommended):

```bash
nvram_changes=0

# ... perform NVRAM writes, increment counter on each successful write ...

if [ $nvram_changes -gt 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════"
    echo " NVRAM CONFIGURATION COMPLETE"
    echo " $nvram_changes variable(s) updated"
    echo ""
    echo " ⚠️  REBOOT REQUIRED for changes to take effect"
    echo "═══════════════════════════════════════════"
    echo ""
fi
```

**Pattern 2: Verbose** (More Detail):

```bash
echo "──────────────────────────────────────"
echo "NVRAM Configuration Summary:"
echo "  boot-args: Updated to -v"
echo "  SystemAudioVolume: Set to 0 (mute)"
echo ""
echo "⚠️  Changes saved to NVRAM"
echo "⚠️  Reboot required to apply"
echo "──────────────────────────────────────"
```

**Pattern 3: Minimal**:

```bash
echo "NVRAM configured. Reboot required for: boot-args, startup sound."
```

### Decision: Implementation Strategy

1. **Create `mkNvramSet` helper function** in `modules/darwin/lib/mac.nix`
1. **Include platform detection** - skip boot-args on Apple Silicon or provide warning
1. **Implement read-before-write idempotency** pattern
1. **Provide clear reboot notification** - use Pattern 1 (count-based)
1. **Handle errors gracefully** - warn but don't fail activation on NVRAM errors
1. **Document limitations** - especially Apple Silicon boot-args restriction

______________________________________________________________________

## R4: NetBIOS Hostname Configuration

### Research Questions Answered

✅ **How to make NetBIOS hostname configurable per-host?**\
Use nix-darwin module option pattern: define option in module, override in `hosts/<hostname>/default.nix`.

✅ **What's the nix-darwin option structure for per-host configuration?**\
Define in module with `lib.mkOption`, set `default` value, override in host config with `system.defaults.smb.netbiosName = "HostSpecificName";`.

✅ **How do host configs override module defaults?**\
Nix module system merges definitions. Last definition wins (host config has higher priority than module default).

✅ **Are there hostname validation rules (length, characters)?**\
Yes - NetBIOS names: **max 15 characters**, alphanumeric + hyphens only, no spaces or special characters.

### NetBIOS Hostname Requirements

**RFC Specifications**:

- **Maximum length**: 15 characters (16th byte reserved for service type)
- **Allowed characters**: A-Z, a-z, 0-9, hyphen (-)
- **Restrictions**: No spaces, no special characters, no dots
- **Case**: Case-insensitive (typically stored uppercase)

**Validation Rules**:

```bash
# Validate NetBIOS hostname
hostname="Work-MacBook"

# Check length
if [ ${#hostname} -gt 15 ]; then
    echo "Warning: Hostname too long (max 15 chars), truncating to ${hostname:0:15}"
    hostname="${hostname:0:15}"
fi

# Check for invalid characters (anything except alphanumeric and hyphen)
if echo "$hostname" | grep -q '[^A-Za-z0-9-]'; then
    echo "Warning: Invalid characters in hostname, sanitizing..."
    hostname=$(echo "$hostname" | sed 's/[^A-Za-z0-9-]/-/g')
fi

# Apply to system
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$hostname"
```

### Module Option Pattern

**Define in `modules/darwin/system/security.nix`**:

```nix
{ config, lib, pkgs, ... }:

{
  options.system.defaults.smb = {
    netbiosName = lib.mkOption {
      type = lib.types.str;
      default = "Workstation";
      description = ''
        NetBIOS hostname for SMB server identification.
        Maximum 15 characters, alphanumeric and hyphens only.
      '';
      example = "Work-MacBook";
    };
  };

  config = {
    system.activationScripts.configureSMBHostname = {
      text = let
        hostname = config.system.defaults.smb.netbiosName;
        # Validation and sanitization in helper function
      in ''
        # Set NetBIOS hostname
        ${mkSystemDefaultsSet {
          domain = "/Library/Preferences/SystemConfiguration/com.apple.smb.server";
          key = "NetBIOSName";
          type = "-string";
          value = hostname;
        }}
      '';
    };
  };
}
```

**Override in `hosts/work-macbook/default.nix`**:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ../../modules/darwin/system
  ];

  # Override NetBIOS hostname for this host
  system.defaults.smb.netbiosName = "Work-MacBook";
}
```

**Override in `hosts/home-macmini/default.nix`**:

```nix
{
  system.defaults.smb.netbiosName = "Home-MacMini";
}
```

### Validation Strategy

**Option 1: Client-Side Validation** (Recommended):

```nix
# In module definition
options.system.defaults.smb.netbiosName = lib.mkOption {
  type = lib.types.strMatching "[A-Za-z0-9-]{1,15}";
  default = "Workstation";
  description = "NetBIOS hostname (max 15 chars, alphanumeric + hyphens)";
};
```

**Option 2: Runtime Sanitization**:

```bash
# In activation script or helper function
sanitize_netbios_name() {
    local name="$1"
    
    # Truncate to 15 characters
    name="${name:0:15}"
    
    # Replace invalid characters with hyphens
    name=$(echo "$name" | sed 's/[^A-Za-z0-9-]/-/g')
    
    # Remove leading/trailing hyphens
    name=$(echo "$name" | sed 's/^-*//' | sed 's/-*$//')
    
    echo "$name"
}

hostname=$(sanitize_netbios_name "${config.system.defaults.smb.netbiosName}")
```

### Decision: Per-Host Configuration Pattern

1. **Define option in `security.nix`** with `lib.mkOption`
1. **Set sensible default**: "Workstation" (matches current dotfiles)
1. **Use `strMatching` type** for compile-time validation
1. **Document in module** with examples for each host
1. **Hosts override in their `default.nix`** with specific values

**Advantages**:

- Type-safe at build time
- Clear documentation of valid values
- Easy to see per-host configuration
- Follows nix-darwin conventions

______________________________________________________________________

## R5: Helper Function Design Patterns

### Research Questions Answered

✅ **Should we create generic `mkSystemDefaultsSet` or specific helpers per domain?**\
**Generic is better** - one function handles all domains. Specific helpers (e.g., `mkFirewallEnable`) add unnecessary abstraction.

✅ **How to handle different value types in one helper?**\
Pass type as parameter (`"-int"`, `"-bool"`, `"-string"`). Booleans need special normalization logic → separate function.

✅ **Should NVRAM helper be separate from system defaults helper?**\
**Yes** - NVRAM uses different commands (`nvram` not `defaults`), different parsing, different error handling, platform detection.

✅ **How to implement read-before-write pattern for multiple value types?**\
Read returns plain text → string comparison works for int/string. Booleans need normalization (see R1).

### Design Decisions

**Three Helper Functions Recommended**:

1. **mkSystemDefaultsSet** - Generic system defaults (int, string)
1. **mkSystemDefaultsBool** - Boolean system defaults (with normalization)
1. **mkNvramSet** - NVRAM variables (with platform detection)

**Rationale**:

- **Separation of concerns**: Each helper does one thing well
- **Type safety**: Boolean normalization encapsulated
- **Platform awareness**: NVRAM helper handles Intel vs Apple Silicon
- **Reusability**: Generic helpers work for any system preference

### Helper Function Signatures

**1. mkSystemDefaultsSet** (Generic):

```nix
mkSystemDefaultsSet = {
  domain,       # string: Full path to preference domain
                #   Example: "/Library/Preferences/com.apple.alf"
  key,          # string: Preference key
                #   Example: "globalstate"
  value,        # any: Value to set (converted to string)
                #   Example: 1, "Workstation"
  type          # string: defaults write type flag
                #   Values: "-int", "-string", "-float", "-data"
}: string;      # Returns: Idempotent shell script
```

**Behavior**:

- Read current value with `sudo defaults read <domain> <key>`
- Compare with desired value (string comparison)
- Write only if different: `sudo defaults write <domain> <key> <type> <value>`
- Log action taken or skipped
- Handle errors: missing domain/key = treat as unset
- Exit code 0 (non-blocking)

**2. mkSystemDefaultsBool** (Boolean-Specific):

```nix
mkSystemDefaultsBool = {
  domain,       # string: Full path to preference domain
  key,          # string: Preference key
  value         # bool: Nix boolean value (true/false)
}: string;      # Returns: Idempotent shell script with normalization
```

**Behavior**:

- Read current value
- Normalize current value (`1`/`true`/`yes` → `1`, `0`/`false`/`no` → `0`)
- Normalize desired value (Nix `true` → `1`, `false` → `0`)
- Compare normalized values
- Write if different: `sudo defaults write <domain> <key> -bool <value>`
- Log action
- Exit code 0

**3. mkNvramSet** (NVRAM Variables):

```nix
mkNvramSet = {
  variable,     # string: NVRAM variable name
                #   Example: "boot-args", "SystemAudioVolume"
  value,        # string: Value to set (may include hex notation)
                #   Example: "-v", "%00"
  platform ?    # string: Optional platform filter
  "all"         #   Values: "all", "intel", "apple-silicon"
                #   Default: "all"
}: string;      # Returns: Idempotent shell script with reboot notice
```

**Behavior**:

- Check platform if filter specified (skip if not matching)
- Read current value with `nvram <variable> | cut -f2`
- Compare with desired value
- Write only if different: `sudo nvram <variable>=<value>`
- Handle errors gracefully (SIP restriction, firmware password)
- Log action and provide user-friendly error messages
- Print reboot notice if changes made
- Exit code 0 (don't block activation on NVRAM failures)

### Implementation Examples

**Example 1: Firewall (using mkSystemDefaultsSet - NOT recommended, use socketfilterfw)**:

```nix
# NOTE: This is for illustration only - use socketfilterfw in practice
{
  system.activationScripts.firewall = {
    text = let
      macLib = import ../lib/mac.nix { inherit lib pkgs config; };
    in ''
      ${macLib.mkSystemDefaultsSet {
        domain = "/Library/Preferences/com.apple.alf";
        key = "globalstate";
        type = "-int";
        value = "1";
      }}
    '';
  };
}
```

**Example 2: Guest Account (using mkSystemDefaultsBool)**:

```nix
{
  system.activationScripts.disableGuestAccount = {
    text = let
      macLib = import ../lib/mac.nix { inherit lib pkgs config; };
    in ''
      ${macLib.mkSystemDefaultsBool {
        domain = "/Library/Preferences/com.apple.loginwindow";
        key = "GuestEnabled";
        value = false;
      }}
    '';
  };
}
```

**Example 3: NetBIOS Hostname (using mkSystemDefaultsSet)**:

```nix
{
  system.activationScripts.setHostname = {
    text = let
      macLib = import ../lib/mac.nix { inherit lib pkgs config; };
      hostname = config.system.defaults.smb.netbiosName;
    in ''
      ${macLib.mkSystemDefaultsSet {
        domain = "/Library/Preferences/SystemConfiguration/com.apple.smb.server";
        key = "NetBIOSName";
        type = "-string";
        value = hostname;
      }}
    '';
  };
}
```

**Example 4: NVRAM Boot Args (using mkNvramSet with platform filter)**:

```nix
{
  system.activationScripts.nvramBootArgs = {
    text = let
      macLib = import ../lib/mac.nix { inherit lib pkgs config; };
    in ''
      ${macLib.mkNvramSet {
        variable = "boot-args";
        value = "-v";
        platform = "intel";  # Skip on Apple Silicon
      }}
    '';
  };
}
```

**Example 5: Startup Sound (using mkNvramSet)**:

```nix
{
  system.activationScripts.muteStartupSound = {
    text = let
      macLib = import ../lib/mac.nix { inherit lib pkgs config; };
    in ''
      ${macLib.mkNvramSet {
        variable = "SystemAudioVolume";
        value = "%00";
        platform = "all";  # Try on both platforms
      }}
    '';
  };
}
```

### Decision Summary

**Adopt three-helper pattern**:

1. `mkSystemDefaultsSet` - generic int/string system defaults
1. `mkSystemDefaultsBool` - boolean-specific with normalization
1. `mkNvramSet` - NVRAM variables with platform detection

**Do NOT create domain-specific helpers** (e.g., `mkFirewallEnable`, `mkSMBHostname`) - adds unnecessary indirection.

**Exception**: Firewall should use `socketfilterfw` directly in activation script, not `defaults write`.

______________________________________________________________________

## Summary of Decisions

| Component | Method | Rationale |
|-----------|--------|-----------|
| **Firewall** | `socketfilterfw` commands in activation script | Reliable on macOS Sequoia 15+, handles restarts automatically |
| **System Defaults** | Read-before-write with `mkSystemDefaultsSet` / `mkSystemDefaultsBool` | Idempotent, type-safe, handles errors gracefully |
| **NVRAM** | `mkNvramSet` with platform detection | Intel full support, Apple Silicon boot-args skipped/warned |
| **Hostname** | Module option with per-host overrides | Standard nix-darwin pattern, type-safe, documented |
| **Helper Functions** | Three focused functions in `mac.nix` | Separation of concerns, reusable, maintainable |

______________________________________________________________________

## Next Steps for Phase 1 (Design)

1. Define helper function signatures in `data-model.md`
1. Create module option structures for security and NVRAM
1. Document validation rules for hostnames
1. Define error handling strategies
1. Create `quickstart.md` with testing procedures
1. Include security verification (port scan for stealth mode)

______________________________________________________________________

## References

- **System Defaults Research**: `docs/research/macos-system-defaults-patterns.md`
- **Firewall Research**: Community findings on socketfilterfw vs defaults write
- **NVRAM Research**: `docs/nvram-research.md`
- **Spec 008**: Power management and HiDPI (precedent for system defaults)
- **Spec 006**: Helper library pattern and design principles
- **nix-darwin Issue #1243**: Firewall configuration issues with defaults
