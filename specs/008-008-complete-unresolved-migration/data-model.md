# Data Model: Unresolved Migration MVP

**Feature**: 008-complete-unresolved-migration\
**Phase**: 1 (Design)\
**Date**: 2025-10-27

## Overview

This document defines the data entities, helper function interfaces, validation rules, and error handling strategies for the Unresolved Migration MVP. The design extends the helper library pattern established in Feature 006.

______________________________________________________________________

## Entities

### E1: Power Management Setting

**Definition**: A pmset configuration value that controls system power behavior

**Attributes**:

- `setting` (string): pmset parameter name (e.g., "standbydelay")
- `value` (int/string): desired setting value (e.g., 86400)
- `scope` (string): power source scope (-a, -b, -c, -u)

**Example**:

```nix
{
  setting = "standbydelay";
  value = 86400;  # 24 hours in seconds
  scope = "-a";   # All power sources
}
```

**Validation Rules**:

- `setting`: Must be valid pmset parameter (see `man pmset`)
- `value`: Must match setting's expected type (int for standbydelay)
- `scope`: Must be one of: "-a", "-b", "-c", "-u"

**Constraints**:

- Requires root privileges to modify
- Values persist in NVRAM across reboots
- System-wide setting affects all users

______________________________________________________________________

### E2: Display Setting

**Definition**: A WindowServer preference that controls display behavior

**Attributes**:

- `key` (string): Preference key (e.g., "DisplayResolutionEnabled")
- `value` (bool): Desired boolean value (true/false)
- `domain` (string): Preference domain path

**Example**:

```nix
{
  key = "DisplayResolutionEnabled";
  value = true;
  domain = "/Library/Preferences/com.apple.windowserver";
}
```

**Validation Rules**:

- `key`: Must be valid WindowServer preference key
- `value`: Must be boolean (true/false)
- `domain`: Must be writable system-level path

**Constraints**:

- Requires root privileges to modify
- Changes take effect after logout/reboot
- System-wide setting affects all users

______________________________________________________________________

### E3: One-Time Operation

**Definition**: A system setup command that should execute once during initial configuration

**Attributes**:

- `name` (string): Unique operation identifier
- `command` (string): Shell command to execute
- `checkCommand` (string): Command to verify if operation needed
- `markerFile` (path): File path to track completion

**Example**:

```nix
{
  name = "unhide-library";
  command = "chflags nohidden ~/Library";
  checkCommand = "test -f ~/Library/.hidden";
  markerFile = "~/.nix-darwin-unhide-library-complete";
}
```

**Validation Rules**:

- `name`: Must be unique, lowercase-with-hyphens
- `command`: Must be valid shell command
- `checkCommand`: Must return exit code 0 if operation needed
- `markerFile`: Must be in user home directory, hidden (dot prefix)

**Constraints**:

- Operations must be idempotent (safe to repeat)
- Marker files track completion state
- Commands may require root privileges

______________________________________________________________________

## Helper Function Interfaces

### F1: mkPmsetSet

**Purpose**: Generate idempotent shell script to set pmset configuration

**Signature**:

```nix
mkPmsetSet :: {
  setting  :: String,       # pmset parameter name
  value    :: Int | String, # desired value
  scope    :: String        # optional, default "-a"
} -> String                 # returns shell script
```

**Type Constraints**:

- `setting`: Non-empty string
- `value`: Coerced to string via `toString`
- `scope`: Must match pattern `^-(a|b|c|u)$`

**Return Value**: Multi-line shell script string that:

1. Checks current pmset value
1. Compares with desired value
1. Sets value if different (with sudo)
1. Logs action taken or skipped
1. Returns exit code 0 (always)

**Example Usage**:

```nix
${macLib.mkPmsetSet {
  setting = "standbydelay";
  value = 86400;
  scope = "-a";
}}
```

**Generated Script**:

```bash
# Check current value
current=$(pmset -g | grep "^ standbydelay" | awk '{print $2}' 2>/dev/null)

# Only set if different
if [ "$current" != "86400" ]; then
  if sudo pmset -a standbydelay 86400 2>/dev/null; then
    echo "pmset: Set standbydelay to 86400 (scope: -a)"
  else
    echo "Warning: Failed to set pmset standbydelay" >&2
  fi
else
  echo "pmset: standbydelay already set to 86400"
fi
```

**Error Handling**:

- Parsing failure: Attempt set anyway (fail-safe)
- Set command failure: Log to stderr, return 0
- Invalid scope: Nix evaluation error (caught at build time)

**Idempotency**: Guaranteed via check-before-set pattern

______________________________________________________________________

### F2: mkOneTimeOperation

**Purpose**: Generate idempotent shell script to run one-time setup operations

**Signature**:

```nix
mkOneTimeOperation :: {
  name         :: String,  # unique operation identifier
  command      :: String,  # shell command to execute
  checkCommand :: String   # command to check if operation needed
} -> String                # returns shell script
```

**Type Constraints**:

- `name`: Non-empty string, valid filename characters
- `command`: Non-empty string, valid shell command
- `checkCommand`: Non-empty string, must return exit code

**Return Value**: Multi-line shell script string that:

1. Checks for marker file (fast path)
1. Runs check command if no marker
1. Executes main command if check indicates needed
1. Creates marker file on success
1. Logs all actions
1. Returns exit code 0 (always)

**Marker File Pattern**: `$HOME/.nix-darwin-{name}-complete`

**Example Usage**:

```nix
${macLib.mkOneTimeOperation {
  name = "unhide-library";
  command = "chflags nohidden ~/Library";
  checkCommand = "test -f ~/Library/.hidden";
}}
```

**Generated Script**:

```bash
marker_file="$HOME/.nix-darwin-unhide-library-complete"

# Fast path: marker file exists
if [ -f "$marker_file" ]; then
  echo "One-time operation 'unhide-library' already completed (marker exists)"
else
  # Check if operation needed (exit 0 = needed)
  if test -f ~/Library/.hidden 2>/dev/null; then
    # Operation needed, run command
    if chflags nohidden ~/Library 2>/dev/null; then
      # Success, create marker
      touch "$marker_file" 2>/dev/null
      echo "One-time operation 'unhide-library' completed successfully"
    else
      echo "Warning: One-time operation 'unhide-library' failed" >&2
    fi
  else
    # Operation not needed, create marker anyway
    touch "$marker_file" 2>/dev/null
    echo "One-time operation 'unhide-library' not needed (check passed)"
  fi
fi
```

**Error Handling**:

- Marker exists: Skip (fast path, no error)
- Check command fails: Log warning, skip operation
- Main command fails: Log error, don't create marker
- Marker creation fails: Log warning, operation still ran

**Idempotency**: Guaranteed via marker file + check command pattern

______________________________________________________________________

## Module Configuration Interfaces

### M1: power.nix (NEW)

**Module Path**: `modules/darwin/system/power.nix`

**Configuration Options**: None (MVP uses hardcoded values in activation script)

**Activation Script**: `system.activationScripts.configurePower`

**Behavior**:

- Sets `standbydelay` to 86400 seconds (24 hours)
- Uses `mkPmsetSet` helper function
- Idempotent via check-before-set
- Logs actions to activation output

**Future Extensions**:

```nix
# Potential options for future releases
options.darwin.power = {
  standbyDelay = lib.mkOption {
    type = lib.types.int;
    default = 86400;
    description = "Standby delay in seconds";
  };
};
```

______________________________________________________________________

### M2: screen.nix (UPDATE)

**Module Path**: `modules/darwin/system/screen.nix`

**Existing Configuration**: (Preserved from previous implementation)

**New Activation Script**: `system.activationScripts.enableHiDPI`

**Behavior**:

- Enables HiDPI display modes for external displays
- Uses inline defaults read/write (no helper function needed)
- Idempotent via read-before-write
- Logs actions to activation output

**Future Extensions**:

```nix
# Potential options for future releases
options.darwin.screen.enableHiDPI = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Enable HiDPI display modes for external displays";
};
```

______________________________________________________________________

### M3: initial-setup.nix (NEW)

**Module Path**: `modules/darwin/system/initial-setup.nix`

**Configuration Options**: None (MVP uses hardcoded operations in activation script)

**Activation Script**: `system.activationScripts.initialSetup`

**Behavior**:

- Unhides ~/Library folder (if hidden)
- Enables Spotlight indexing (if disabled)
- Uses `mkOneTimeOperation` helper function (twice)
- Idempotent via marker files + check commands
- Logs actions to activation output

**Future Extensions**:

```nix
# Potential options for future releases
options.darwin.initialSetup.operations = lib.mkOption {
  type = lib.types.listOf (lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      command = lib.mkOption { type = lib.types.str; };
      checkCommand = lib.mkOption { type = lib.types.str; };
    };
  });
  default = [
    { name = "unhide-library"; command = "chflags nohidden ~/Library"; checkCommand = "test -f ~/Library/.hidden"; }
    { name = "enable-spotlight"; command = "sudo mdutil -i on /"; checkCommand = "mdutil -s / | grep -q 'Indexing disabled'"; }
  ];
  description = "List of one-time operations to run during initial setup";
};
```

______________________________________________________________________

## Validation Rules

### VR1: pmset Setting Validation

**Rule**: Setting must be valid pmset parameter

**Valid Settings** (common subset):

- `standbydelay` (int): Seconds before standby
- `standby` (0/1): Enable/disable standby
- `sleep` (int): Minutes before sleep
- `displaysleep` (int): Minutes before display sleep
- `disksleep` (int): Minutes before disk sleep
- `powernap` (0/1): Enable/disable Power Nap
- `autorestart` (0/1): Auto-restart on power loss

**Validation Method**: Documented in `man pmset`, no runtime validation (user responsibility)

**Nix Type**: `lib.types.str` (not validated, trust user input)

______________________________________________________________________

### VR2: pmset Scope Validation

**Rule**: Scope must be one of the four valid flags

**Valid Scopes**:

- `-a`: All power sources (battery + charger + UPS)
- `-b`: Battery power only
- `-c`: Charger (AC) power only
- `-u`: UPS power only

**Default**: `-a` (most common, system-wide)

**Validation Method**: Pattern matching in helper function (build-time check)

______________________________________________________________________

### VR3: One-Time Operation Name Validation

**Rule**: Name must be unique and filesystem-safe

**Valid Characters**: `[a-z0-9-]` (lowercase letters, numbers, hyphens)

**Invalid Characters**: Spaces, uppercase, special characters

**Examples**:

- ✅ `unhide-library`
- ✅ `enable-spotlight`
- ✅ `configure-git-credentials`
- ❌ `Unhide Library` (uppercase, spaces)
- ❌ `enable_spotlight` (underscore)

**Rationale**: Used in marker filename, must be filesystem-safe

**Validation Method**: No runtime validation (user responsibility, reviewed in code review)

______________________________________________________________________

### VR4: Command Safety Validation

**Rule**: Commands must be idempotent and safe to repeat

**Idempotent Commands**:

- ✅ `chflags nohidden ~/Library` (safe to repeat)
- ✅ `sudo mdutil -i on /` (safe to repeat)
- ✅ `defaults write ...` (overwrites value)
- ✅ `mkdir -p ~/directory` (creates if not exists)

**Non-Idempotent Commands**:

- ❌ `echo "text" >> file` (appends on every run)
- ❌ `rm -rf ~/directory` (destructive, not repeatable)
- ❌ `open /Applications/App.app` (launches repeatedly)

**Validation Method**: Manual review in code review, no automated validation

______________________________________________________________________

## Error Handling Strategies

### Strategy 1: Fail-Safe Pattern

**Principle**: Errors in non-critical operations should not block activation

**Implementation**:

- All activation scripts return exit code 0
- Errors logged to stderr with `echo "..." >&2`
- Commands wrapped with `2>/dev/null` to suppress stderr
- Success/failure logged for debugging

**Example**:

```bash
if sudo pmset -a standbydelay 86400 2>/dev/null; then
  echo "Success: Set standby delay"
else
  echo "Warning: Failed to set standby delay" >&2
fi
# Always continues, never exits non-zero
```

______________________________________________________________________

### Strategy 2: Check-Before-Set Pattern

**Principle**: Only execute commands when necessary

**Implementation**:

- Read current state before writing
- Compare current vs. desired state
- Only execute if different
- Log whether action taken or skipped

**Benefits**:

- Reduces unnecessary writes to NVRAM/disk
- Speeds up activation script execution
- Clear logging shows when changes made

**Example**:

```bash
current=$(pmset -g | grep "^ standbydelay" | awk '{print $2}')
if [ "$current" != "86400" ]; then
  # Only set if different
  sudo pmset -a standbydelay 86400
fi
```

______________________________________________________________________

### Strategy 3: Marker File Pattern

**Principle**: Track one-time operation completion

**Implementation**:

- Create hidden marker file on success
- Check marker file before running operation
- Operations remain idempotent even if marker deleted
- User can manually reset by deleting marker

**Marker Location**: `$HOME/.nix-darwin-{operation-name}-complete`

**Benefits**:

- Fast path: skip operation if marker exists
- User-controllable: delete marker to re-run
- Persistent: survives system updates
- Safe: operations idempotent even without marker

**Example**:

```bash
marker="$HOME/.nix-darwin-unhide-library-complete"
if [ -f "$marker" ]; then
  echo "Operation already completed"
else
  chflags nohidden ~/Library
  touch "$marker"
fi
```

______________________________________________________________________

### Strategy 4: Logging Pattern

**Principle**: Comprehensive logging for debugging

**Log Levels**:

- **Info**: Normal operation (to stdout)
- **Warning**: Non-critical failure (to stderr)
- **Skip**: Operation not needed (to stdout)

**Log Format**:

```
<component>: <action> <details>
```

**Examples**:

```bash
echo "pmset: Set standbydelay to 86400 (scope: -a)"
echo "pmset: standbydelay already set to 86400"
echo "Warning: Failed to set pmset standbydelay" >&2
echo "One-time operation 'unhide-library' completed successfully"
echo "One-time operation 'unhide-library' already completed (marker exists)"
```

**Benefits**:

- Clear action taken/skipped
- Easy to debug from `darwin-rebuild` output
- Warning messages visible but non-blocking

______________________________________________________________________

## Data Flow

### Flow 1: pmset Configuration

```
User Request (power.nix)
  ↓
mkPmsetSet helper function
  ↓
Generated shell script
  ↓
system.activationScripts.configurePower
  ↓
darwin-rebuild switch
  ↓
Execution (as root)
  ↓
pmset -g (read current)
  ↓
Compare current vs. desired
  ↓
[If different] sudo pmset -a standbydelay 86400
  ↓
Log result
  ↓
Return 0 (always)
```

______________________________________________________________________

### Flow 2: HiDPI Configuration

```
User Request (screen.nix)
  ↓
Inline activation script
  ↓
system.activationScripts.enableHiDPI
  ↓
darwin-rebuild switch
  ↓
Execution (as root)
  ↓
defaults read (check current)
  ↓
Compare current vs. desired
  ↓
[If different] sudo defaults write
  ↓
Log result
  ↓
Return 0 (always)
```

______________________________________________________________________

### Flow 3: One-Time Operations

```
User Request (initial-setup.nix)
  ↓
mkOneTimeOperation helper function (x2)
  ↓
Generated shell scripts
  ↓
system.activationScripts.initialSetup
  ↓
darwin-rebuild switch
  ↓
Execution (as root)
  ↓
[For each operation]
  ↓
Check marker file
  ↓
[If no marker] Run check command
  ↓
[If check indicates needed] Run main command
  ↓
[If success] Create marker
  ↓
Log result
  ↓
Return 0 (always)
```

______________________________________________________________________

## Testing Considerations

### Test Case 1: First Activation (Clean System)

**Initial State**:

- pmset standbydelay = 0
- HiDPI = not set
- Library folder = visible
- Spotlight = enabled
- No marker files exist

**Expected Behavior**:

- pmset: Set to 86400 (logged)
- HiDPI: Written to plist (logged)
- Library: Operation not needed (logged)
- Spotlight: Operation not needed (logged)
- Markers created for both one-time ops

**Verification**:

```bash
pmset -g | grep standby  # Should show 86400
defaults read /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled  # Should show 1
ls ~/.nix-darwin-*-complete  # Should show 2 marker files
```

______________________________________________________________________

### Test Case 2: Re-Activation (Idempotency)

**Initial State**: After Test Case 1

**Expected Behavior**:

- pmset: Already set (logged, no action)
- HiDPI: Already set (logged, no action)
- Library: Marker exists (logged, skip)
- Spotlight: Marker exists (logged, skip)

**Verification**:

- All logs show "already set" or "already completed"
- No sudo commands executed
- Activation completes quickly (\<1 second)

______________________________________________________________________

### Test Case 3: Manual Reset (Marker Deletion)

**Initial State**: After Test Case 2

**Action**: Delete marker files

```bash
rm ~/.nix-darwin-*-complete
```

**Expected Behavior**:

- pmset: Already set (no action)
- HiDPI: Already set (no action)
- Library: Check command passes (not needed, marker created)
- Spotlight: Check command passes (not needed, marker created)

**Verification**:

- Marker files recreated
- No actual commands executed (operations not needed)

______________________________________________________________________

## Summary

### Entities Defined

1. Power Management Setting (pmset configuration)
1. Display Setting (WindowServer preference)
1. One-Time Operation (setup command with tracking)

### Helper Functions Specified

1. `mkPmsetSet`: Idempotent pmset configuration
1. `mkOneTimeOperation`: One-time setup with marker tracking

### Modules Designed

1. `power.nix`: Power management configuration
1. `screen.nix`: Display configuration (HiDPI)
1. `initial-setup.nix`: One-time setup operations

### Validation Rules Established

- pmset settings and scopes
- Operation name format
- Command safety (idempotency)

### Error Handling Strategies

- Fail-safe pattern (always return 0)
- Check-before-set (optimize execution)
- Marker file pattern (track completion)
- Comprehensive logging (debug support)

### Ready for Implementation

All interfaces defined, validation rules established, error handling specified. Proceed to create quickstart guide, then generate tasks.

______________________________________________________________________

## References

- **Research**: [research.md](./research.md) - Technical investigation findings
- **Specification**: [spec.md](./spec.md) - Feature requirements
- **Helper Library**: `modules/darwin/lib/mac.nix` - Existing implementation
- **Example Module**: `modules/darwin/system/dock.nix` - Reference pattern
