# Research: Unresolved Migration MVP

**Feature**: 008-complete-unresolved-migration\
**Phase**: 0 (Technical Investigation)\
**Date**: 2025-10-27

## Overview

This document captures technical research findings for implementing three low-risk unresolved migration items: power management (pmset), display configuration (HiDPI), and one-time setup operations. Research focuses on command behavior, idempotency strategies, and error handling patterns.

______________________________________________________________________

## R1: pmset Command Research

### Command Structure

**Basic Syntax**:

```bash
pmset [-a | -b | -c | -u] [setting value] [...]
```

**Scope Flags**:

- `-a`: All power sources (battery, charger, UPS) - **DEFAULT for system-wide settings**
- `-b`: Battery power only
- `-c`: Charger (AC/wall power) only
- `-u`: UPS power only

**Root Requirement**: `pmset` must be run as root to modify settings (read-only without sudo)

### Current System State

**Test Command**: `pmset -g`

**Output Format**:

```
System-wide power settings:
Currently in use:
 standby              0
 Sleep On Power Button 1
 autorestart          0
 powernap             1
 networkoversleep     0
 disksleep            10
 sleep                1 (sleep prevented by zen, powerd)
 ttyskeepawake        1
 displaysleep         10 (display sleep prevented by zen)
 tcpkeepalive         1
 powermode            0
 womp                 0
```

**Parsing Strategy**:

- Each setting on its own line
- Format: `<whitespace><setting><whitespace><value>[<optional comment>]`
- Can extract with: `pmset -g | grep "^ standby" | awk '{print $2}'`
- Alternative: `pmset -g | grep standby` (simpler, works for unique settings)

### Standby Setting Details

**Current Value**: `standby 0` (disabled)
**Target Value**: `standby 86400` (24 hours = 86400 seconds)

**What standby does**:

- Controls when system enters standby mode (hibernation-like state)
- Value in seconds of inactivity before standby
- 0 = disabled (never enter standby)
- 86400 = 24 hours (only enter standby after 24 hours)

**Persistence**: Settings persist across reboots (stored in NVRAM/PRAM)

### Idempotency Strategy

**Approach**: Check before set

```bash
# Check current value
current_value=$(pmset -g | grep "^ standby" | awk '{print $2}')

# Only set if different
if [ "$current_value" != "86400" ]; then
  sudo pmset -a standby 86400
fi
```

**Benefits**:

- Avoids unnecessary writes to NVRAM
- Reduces activation script execution time
- Clear logging (only logs when change made)

### Error Handling

**Possible Failures**:

1. `pmset -g` fails (unlikely, read-only command)
1. `pmset -a standby 86400` fails (requires sudo, invalid value)

**Strategy**:

- If check fails: Log warning, attempt set anyway (fail-safe)
- If set fails: Log error, continue (non-critical setting)
- Always return exit code 0 (don't block other activation scripts)

**Error Pattern**:

```bash
current_value=$(pmset -g | grep "^ standby" | awk '{print $2}' 2>/dev/null)
if [ "$current_value" != "86400" ]; then
  if sudo pmset -a standby 86400 2>/dev/null; then
    echo "Set standby delay to 86400 seconds (24 hours)"
  else
    echo "Warning: Failed to set standby delay" >&2
  fi
fi
```

### Verification

**Manual Verification**:

```bash
pmset -g | grep standby
# Should show: standby              86400
```

**Automated Verification**:

```bash
[ "$(pmset -g | grep "^ standby" | awk '{print $2}')" = "86400" ]
```

### Design Decision: mkPmsetSet Function

**Signature**:

```nix
mkPmsetSet = { setting, value, scope ? "-a" }: string
```

**Implementation Pattern**:

```nix
mkPmsetSet = { setting, value, scope ? "-a" }: ''
  # Check current value
  current=$(pmset -g | grep "^ ${setting}" | awk '{print $2}' 2>/dev/null)
  
  # Only set if different
  if [ "$current" != "${toString value}" ]; then
    if sudo pmset ${scope} ${setting} ${toString value} 2>/dev/null; then
      echo "pmset: Set ${setting} to ${toString value} (scope: ${scope})"
    else
      echo "Warning: Failed to set pmset ${setting}" >&2
    fi
  else
    echo "pmset: ${setting} already set to ${toString value}"
  fi
'';
```

______________________________________________________________________

## R2: HiDPI Display Configuration

### Setting Details

**Target**: Enable HiDPI (Retina-like) resolution modes for external displays

**Command**:

```bash
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
```

**Location**: `/Library/Preferences/` (system-wide, requires sudo)
**Affected Service**: WindowServer (macOS display management)

### Current System State

**Test Command**: `defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled`

**Output**: `1` (boolean true, already enabled on this system)

**Interpretation**:

- `1` = HiDPI modes enabled
- `0` = HiDPI modes disabled
- Key not found = default behavior (usually disabled)

### Idempotency Strategy

**Approach**: Read before write

```bash
current_value=$(defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null)

if [ "$current_value" != "1" ]; then
  sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true
fi
```

**Edge Case**: Key doesn't exist

```bash
# defaults read returns exit code 1 if key doesn't exist
# Safe to write in this case
```

### Effect and Timing

**When it takes effect**:

- Setting is written immediately
- Display options appear after **logout/reboot** (WindowServer restart required)
- No immediate impact on current session

**User Impact**:

- Adds additional scaled resolution options in System Settings > Displays
- Does NOT change current resolution
- Only beneficial if external display connected
- No negative impact on built-in displays

**Verification**:

- Immediate: Check plist value with `defaults read`
- After logout: Check System Settings > Displays for scaled options

### Error Handling

**Possible Failures**:

1. `defaults read` fails (key doesn't exist - expected on first run)
1. `defaults write` fails (permission issue, disk space)

**Strategy**:

- If read fails: Assume not set, attempt write
- If write fails: Log error, continue (non-critical)
- Return exit code 0 regardless

**Error Pattern**:

```bash
current_value=$(defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null || echo "0")

if [ "$current_value" != "1" ]; then
  if sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true 2>/dev/null; then
    echo "Enabled HiDPI display modes (takes effect after logout)"
  else
    echo "Warning: Failed to enable HiDPI display modes" >&2
  fi
else
  echo "HiDPI display modes already enabled"
fi
```

### Verification

**Immediate Verification**:

```bash
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled
# Should output: 1
```

**User Verification** (after logout):

1. Connect external display
1. Open System Settings > Displays
1. Check for "Scaled" resolution options
1. Should see additional scaled resolutions

### Design Decision: Direct Activation Script

**No helper function needed** - simple one-time check and write pattern

**Implementation**:

```nix
system.activationScripts.enableHiDPI = {
  text = ''
    # Enable HiDPI display modes for external displays
    current_value=$(defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled 2>/dev/null || echo "0")
    
    if [ "$current_value" != "1" ]; then
      if sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true 2>/dev/null; then
        echo "Enabled HiDPI display modes (takes effect after logout)"
      else
        echo "Warning: Failed to enable HiDPI display modes" >&2
      fi
    else
      echo "HiDPI display modes already enabled"
    fi
  '';
};
```

______________________________________________________________________

## R3: One-Time Operation Patterns

### Use Cases

**Two one-time operations in MVP**:

1. **Unhide Library folder**: `chflags nohidden ~/Library`
1. **Enable Spotlight indexing**: `sudo mdutil -i on /`

**Characteristics**:

- Should run once during initial system setup
- Safe to run multiple times (idempotent by nature)
- No need to run on every `darwin-rebuild switch`

### Marker File Strategy

**Pattern**: Use marker files to track completion

**Marker File Location**: `~/.nix-darwin-<operation-name>-complete`

**Examples**:

- `~/.nix-darwin-unhide-library-complete`
- `~/.nix-darwin-enable-spotlight-complete`

**Rationale**:

- Hidden files (dot prefix) rarely cleaned by users
- User home directory always accessible
- Clear naming convention indicates purpose
- Easy to manually reset (delete marker file)

**Cleanup**: No automatic cleanup needed (operations are safe to repeat)

### Check Command Strategy

**Alternative/Fallback**: Use check commands to verify if operation needed

**Examples**:

- Library hidden: `test -f ~/Library/.hidden` (returns 0 if hidden file exists)
- Spotlight disabled: `mdutil -s / | grep -q "Indexing disabled"` (returns 0 if disabled)

**Combined Strategy**:

1. Check marker file first (fast path)
1. If no marker, run check command
1. If check indicates operation needed, run command
1. Create marker file on success

### Current System State

**Library Folder**:

```bash
$ ls -ld ~/Library
drwx------+ /Users/charles/Library

$ test -f ~/Library/.hidden && echo "hidden" || echo "visible"
visible
```

**Result**: Library folder already visible (no action needed)

**Spotlight Indexing**:

```bash
$ mdutil -s /
/:
	Indexing enabled.
```

**Result**: Spotlight already enabled (no action needed)

### Idempotency Validation

**Both operations are naturally idempotent**:

1. **chflags nohidden**: Running multiple times has no additional effect

   - First run: Removes hidden flag (if set)
   - Subsequent runs: Flag already removed, no change
   - No error, no side effects

1. **mdutil -i on**: Running multiple times has no additional effect

   - First run: Enables indexing (if disabled)
   - Subsequent runs: Already enabled, no change
   - No error, no side effects

**Conclusion**: Marker files are optimization, not requirement (operations safe to repeat)

### Error Handling

**Possible Failures**:

1. Marker file can't be created (disk full, permission issue)
1. Check command fails (command not found, permission issue)
1. Main command fails (permission issue, command not found)

**Strategy**:

- If marker exists, skip (fast path)
- If check command fails, log warning and skip operation
- If main command fails, log error, don't create marker
- Return exit code 0 regardless (don't block other activations)

### Design Decision: mkOneTimeOperation Function

**Signature**:

```nix
mkOneTimeOperation = {
  name,          # Unique identifier (e.g., "unhide-library")
  command,       # Shell command to run
  checkCommand   # Command to check if operation needed (exit 0 = needed)
}: string
```

**Implementation Pattern**:

```nix
mkOneTimeOperation = { name, command, checkCommand }: ''
  marker_file="$HOME/.nix-darwin-${name}-complete"
  
  # Fast path: marker file exists
  if [ -f "$marker_file" ]; then
    echo "One-time operation '${name}' already completed (marker exists)"
  else
    # Check if operation needed
    if ${checkCommand} 2>/dev/null; then
      # Operation needed, run command
      if ${command} 2>/dev/null; then
        # Success, create marker
        touch "$marker_file" 2>/dev/null
        echo "One-time operation '${name}' completed successfully"
      else
        echo "Warning: One-time operation '${name}' failed" >&2
      fi
    else
      # Operation not needed, create marker anyway
      touch "$marker_file" 2>/dev/null
      echo "One-time operation '${name}' not needed (check passed)"
    fi
  fi
'';
```

**Usage Examples**:

```nix
${macLib.mkOneTimeOperation {
  name = "unhide-library";
  command = "chflags nohidden ~/Library";
  checkCommand = "test -f ~/Library/.hidden";
}}

${macLib.mkOneTimeOperation {
  name = "enable-spotlight";
  command = "sudo mdutil -i on /";
  checkCommand = "mdutil -s / | grep -q 'Indexing disabled'";
}}
```

### Verification

**Manual Verification**:

```bash
# Check marker files
ls -la ~/.nix-darwin-*-complete

# Check Library folder
ls -ld ~/Library | grep -v hidden

# Check Spotlight
mdutil -s /
```

**Reset Operation** (for testing):

```bash
rm ~/.nix-darwin-unhide-library-complete
rm ~/.nix-darwin-enable-spotlight-complete
```

______________________________________________________________________

## R4: Activation Script Ordering

### nix-darwin Activation Script Execution

**Documentation Research**: nix-darwin activation scripts run in dependency order

**Execution Flow**:

1. System activationScripts run during `darwin-rebuild switch`
1. Scripts run as root (sudo implicit)
1. No guaranteed order unless dependencies specified
1. All scripts run on every `darwin-rebuild switch`

**Dependency Specification**:

```nix
system.activationScripts.myScript = {
  text = ''...'';
  deps = [ "otherScript" ];  # Run after otherScript
};
```

### Dependencies in MVP

**Our modules**:

- `power.nix`: Standalone (no dependencies)
- `screen.nix`: Standalone (no dependencies)
- `initial-setup.nix`: Standalone (no dependencies)

**Conclusion**: No ordering dependencies required for MVP

### Shared Library Dependencies

**All modules depend on**:

- `modules/darwin/lib/mac.nix` (helper library)
- Imported at module level with `let macLib = import ../lib/mac.nix { ... };`
- No activation script dependencies needed

### Error Handling Philosophy

**Each script is independent**:

- Failure in one script shouldn't block others
- All scripts return exit code 0 (even on error)
- Errors logged to stderr, continue execution

**Example from dock.nix**:

```nix
system.activationScripts.configureDock = {
  text = ''
    ${macLib.mkDockClear}
    ${macLib.mkDockAddApp { ... }}
    # ... more operations
    ${macLib.mkDockRestart}
  '';
};
```

**No explicit error handling** - helper functions handle errors internally

### Design Decision: Independent Scripts

**Pattern for MVP**:

```nix
# power.nix
system.activationScripts.configurePower = { text = ''...''; };

# screen.nix
system.activationScripts.enableHiDPI = { text = ''...''; };

# initial-setup.nix
system.activationScripts.initialSetup = { text = ''...''; };
```

**No dependencies needed**:

- Scripts can run in any order
- Each script is idempotent
- Failures don't cascade

### Activation Script Naming Convention

**Pattern**: `configure<Topic>`, `enable<Feature>`, `initialSetup`

**Examples from existing code**:

- `configureDock` (from dock.nix)
- `configurePower` (new in power.nix)
- `enableHiDPI` (new in screen.nix)
- `initialSetup` (new in initial-setup.nix)

**Rationale**: Clear, descriptive names that indicate purpose

______________________________________________________________________

## Research Summary

### Key Findings

1. **pmset**: Idempotent via check-before-set pattern, grep parsing reliable, scope flag `-a` for system-wide
1. **HiDPI**: Simple defaults read/write pattern, takes effect after logout, naturally idempotent
1. **One-Time Operations**: Marker files + check commands provide robust idempotency, operations safe to repeat
1. **Activation Scripts**: Independent execution, no ordering dependencies needed, errors don't cascade

### Helper Functions Required

1. **mkPmsetSet**: Check current value, set if different, log actions
1. **mkOneTimeOperation**: Marker file + check command + main command, comprehensive logging

### Module Structure Validated

- `power.nix`: Single activation script using `mkPmsetSet`
- `screen.nix`: Single activation script with inline defaults read/write
- `initial-setup.nix`: Single activation script using `mkOneTimeOperation` (twice)

### Risk Assessment

**All risks LOW**:

- pmset: Standard utility, well-documented, persistent settings
- HiDPI: Non-destructive, only adds display options
- One-time ops: Safe to repeat, naturally idempotent
- Activation scripts: Independent, error handling in place

### Ready for Phase 1

**All technical unknowns resolved**:

- ✅ Command syntax and behavior documented
- ✅ Idempotency strategies defined
- ✅ Error handling patterns established
- ✅ Verification methods confirmed
- ✅ Activation script ordering understood

**Proceed to Phase 1**: Design data model and create quickstart guide

______________________________________________________________________

## References

- `man pmset` - Power Management Settings utility
- `man defaults` - macOS defaults system
- `man chflags` - Change file flags (hidden attribute)
- `man mdutil` - Manage Spotlight metadata stores
- nix-darwin documentation: activation scripts
- Existing implementation: `modules/darwin/system/dock.nix`
- Helper library: `modules/darwin/lib/mac.nix`
