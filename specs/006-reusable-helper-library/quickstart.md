# Quickstart Guide: Helper Library Testing & Validation

**Feature**: 006-reusable-helper-library\
**Purpose**: Provide step-by-step testing procedures, validation workflows, and usage examples for the activation script helper library system.

## Quick Start (5 Minutes)

### For New Developers

1. **Understand the structure**:

   ```
   modules/
   ├── shared/lib/          # Cross-platform utilities
   ├── linux/lib/           # Linux init system libraries
   ├── darwin/lib/          # macOS-specific helpers
   ├── nixos/lib/           # NixOS extensions
   └── kali/lib/            # Kali Linux extensions (future)
   ```

1. **Import the library in your module**:

   ```nix
   { config, lib, pkgs, ... }:

   let
     macLib = import ../lib/mac.nix { inherit pkgs lib; };  # Darwin
     # OR
     nixosLib = import ../lib/nixos.nix { inherit pkgs lib; };  # NixOS
   in
   ```

1. **Use helper functions in activation scripts**:

   ```nix
   system.activationScripts.myScript = {
     text = ''
       ${macLib.mkDockClear}
       ${macLib.mkDockAddApp { path = "/Applications/Safari.app"; }}
       ${macLib.mkDockRestart}
     '';
   };
   ```

1. **Test the activation**:

   ```bash
   # Darwin
   darwin-rebuild switch --flake .

   # NixOS
   sudo nixos-rebuild switch --flake .
   ```

______________________________________________________________________

## Prerequisites

### Required Knowledge

- Basic Nix expression syntax
- Understanding of nix-darwin or NixOS activation scripts
- Bash scripting fundamentals
- Your target platform's system tools (defaults, dockutil, systemctl, etc.)

### Required Tools

- Nix 2.19+ installed
- nix-darwin (macOS) or NixOS
- Text editor with Nix syntax support
- Terminal access with sudo privileges

### Environment Setup

```bash
# Clone the repository
git clone <repo-url>
cd nix-config

# Checkout feature branch
git checkout 006-reusable-helper-library

# Verify structure exists
ls -la modules/shared/lib/
ls -la modules/darwin/lib/     # macOS
ls -la modules/nixos/lib/      # NixOS
```

______________________________________________________________________

## Testing Procedures

### Test 1: Validate Shared Library Functions

**Objective**: Verify all shared library functions generate correct shell code and are platform-agnostic.

**Procedure**:

1. Create test module: `modules/shared/test-shared.nix`

   ```nix
   { config, lib, pkgs, ... }:

   let
     sharedLib = import ./lib { inherit pkgs lib; };
   in
   {
     # Test mkRunAsUser
     system.activationScripts.testRunAsUser = {
       text = sharedLib.shell.mkRunAsUser "testuser" "echo 'Hello from testuser'";
     };
     
     # Test mkIdempotentFile
     system.activationScripts.testIdempotentFile = {
       text = sharedLib.shell.mkIdempotentFile {
         path = "/tmp/test-file.txt";
         content = "test content";
         mode = "644";
       };
     };
     
     # Test mkLoggedCommand
     system.activationScripts.testLoggedCommand = {
       text = sharedLib.shell.mkLoggedCommand {
         name = "Test Operation";
         cmd = "echo 'This is a test'";
         level = "INFO";
       };
     };
   }
   ```

1. Build and activate:

   ```bash
   darwin-rebuild switch --flake .  # or nixos-rebuild
   ```

1. **Expected Results**:

   - ✅ `/tmp/test-file.txt` exists with content "test content" and mode 644
   - ✅ Log messages appear with timestamp and "Test Operation" name
   - ✅ Commands execute without errors
   - ✅ Running activation again produces no changes (idempotent)

1. **Validation Checklist**:

   - [ ] File created on first run
   - [ ] File not recreated on second run (idempotent)
   - [ ] Log format: `[YYYY-MM-DD HH:MM:SS] INFO: Test Operation - starting`
   - [ ] No platform-specific errors on either darwin or linux

**Troubleshooting**:

- If file not created: Check permissions, verify path is writable
- If logs missing: Verify activation script output in system log
- If errors on second run: Check idempotency logic in function

______________________________________________________________________

### Test 2: Validate Darwin Platform Library

**Objective**: Verify macOS-specific functions work correctly on darwin systems.

**Procedure**:

1. Create test module: `modules/darwin/test-darwin.nix`

   ```nix
   { config, lib, pkgs, ... }:

   let
     macLib = import ./lib/mac.nix { inherit pkgs lib; };
   in
   {
     system.activationScripts.testDock = {
       text = ''
         ${macLib.mkDockClear}
         ${macLib.mkDockAddApp { path = "/Applications/Safari.app"; position = 1; }}
         ${macLib.mkDockAddApp { path = "/System/Applications/Mail.app"; position = 2; }}
         ${macLib.mkDockAddSpacer}
         ${macLib.mkDockAddFolder { 
           path = "/Applications"; 
           view = "grid"; 
           display = "folder"; 
         }}
         ${macLib.mkDockRestart}
       '';
     };
     
     system.activationScripts.testNvram = {
       text = ''
         ${macLib.mkNvramSet { variable = "TestVariable"; value = "TestValue"; }}
       '';
     };
   }
   ```

1. Build and activate:

   ```bash
   darwin-rebuild switch --flake .
   ```

1. **Expected Results**:

   - ✅ Dock cleared of all existing items
   - ✅ Safari added as first item
   - ✅ Mail added as second item
   - ✅ Spacer added after Mail
   - ✅ Applications folder added with grid view
   - ✅ Dock restarts automatically
   - ✅ NVRAM variable `TestVariable` set to `TestValue`

1. **Manual Verification**:

   ```bash
   # Check Dock items
   dockutil --list

   # Check NVRAM
   sudo nvram TestVariable

   # Verify idempotency
   darwin-rebuild switch --flake .  # Run again, should be no-op
   dockutil --list  # Dock unchanged
   ```

1. **Validation Checklist**:

   - [ ] Dock items match expected configuration
   - [ ] Dock items in correct order (Safari, Mail, spacer, Applications)
   - [ ] Applications folder displays as grid
   - [ ] Second activation produces no visible changes
   - [ ] NVRAM variable persists across reboots

**Troubleshooting**:

- Dock not clearing: Check dockutil is installed (`which dockutil`)
- Apps not added: Verify app paths exist (`ls /Applications/Safari.app`)
- NVRAM not set: Verify sudo privileges, check System Preferences → Security

______________________________________________________________________

### Test 3: Validate Linux Systemd Library

**Objective**: Verify systemd functions work on any systemd-based Linux distribution.

**Procedure**:

1. Create test module: `modules/linux/test-systemd.nix`

   ```nix
   { config, lib, pkgs, ... }:

   let
     systemdLib = import ./lib/systemd.nix { inherit pkgs lib; };
   in
   {
     system.activationScripts.testSystemd = {
       text = ''
         ${systemdLib.mkSystemdEnable "sshd.service"}
         ${systemdLib.mkSystemdStart "sshd.service"}
         ${systemdLib.mkEnsureGroup { groupname = "testgroup"; }}
         ${systemdLib.mkEnsureUser { 
           username = "testuser"; 
           uid = 9999; 
           shell = "/usr/sbin/nologin"; 
         }}
       '';
     };
   }
   ```

1. Build and activate:

   ```bash
   sudo nixos-rebuild switch --flake .
   ```

1. **Expected Results**:

   - ✅ sshd.service enabled at boot
   - ✅ sshd.service started immediately
   - ✅ Group "testgroup" exists
   - ✅ User "testuser" exists with UID 9999 and nologin shell

1. **Manual Verification**:

   ```bash
   # Check service status
   systemctl is-enabled sshd.service
   systemctl is-active sshd.service

   # Check user and group
   id testuser
   getent group testgroup

   # Verify idempotency
   sudo nixos-rebuild switch --flake .  # Run again
   systemctl is-enabled sshd.service  # Should still be enabled, no errors
   ```

1. **Validation Checklist**:

   - [ ] Service enabled on both NixOS and Kali (if testing on Kali)
   - [ ] Service running after activation
   - [ ] User and group created only on first run
   - [ ] Second activation shows no errors or state changes
   - [ ] Functions work identically on NixOS and Kali

**Troubleshooting**:

- Service not starting: Check service exists (`systemctl list-unit-files | grep sshd`)
- User not created: Verify activation script runs as root
- Idempotency failure: Check if function uses `systemctl is-enabled` before enabling

______________________________________________________________________

### Test 4: Validate NixOS Platform Library

**Objective**: Verify NixOS library inherits systemd functions and adds NixOS-specific extensions.

**Procedure**:

1. Create test module: `modules/nixos/test-nixos.nix`

   ```nix
   { config, lib, pkgs, ... }:

   let
     nixosLib = import ./lib/nixos.nix { inherit pkgs lib; };
   in
   {
     system.activationScripts.testNixOS = {
       text = ''
         # Test inherited systemd function
         ${nixosLib.mkSystemdEnable "sshd.service"}
         
         # Test NixOS-specific function
         ${nixosLib.mkChannelUpdate { channel = "nixos"; }}
         ${nixosLib.mkGenerationCleanup { keepGenerations = 10; }}
       '';
     };
   }
   ```

1. Build and activate:

   ```bash
   sudo nixos-rebuild switch --flake .
   ```

1. **Expected Results**:

   - ✅ sshd.service enabled (proves systemd inheritance)
   - ✅ nixos channel updated
   - ✅ Old generations cleaned up (only 10 most recent kept)

1. **Manual Verification**:

   ```bash
   # Verify systemd inheritance
   systemctl is-enabled sshd.service

   # Check generations
   nix-env --list-generations
   # Should show max 10 generations

   # Verify channel update
   nix-channel --list
   ```

1. **Validation Checklist**:

   - [ ] All systemd functions accessible (proves import successful)
   - [ ] NixOS-specific functions work correctly
   - [ ] No duplicate code between nixos.nix and systemd.nix
   - [ ] Second activation handles already-cleaned generations gracefully

**Troubleshooting**:

- Systemd function not found: Check import path in nixos.nix (`../../linux/lib/systemd.nix`)
- Channel update fails: Verify internet connection, check channel exists
- Generation cleanup error: Verify nix-env permissions

______________________________________________________________________

### Test 5: Validate Module-Specific Scripts

**Objective**: Verify complex scripts can be extracted to lib/scripts/ and sourced correctly.

**Procedure**:

1. Create complex script: `modules/darwin/system/lib/scripts/dock-workflow.sh`

   ```bash
   #!/usr/bin/env bash
   # Purpose: Complex Dock configuration workflow
   # Usage: source this script and call configureDockWorkflow <username>

   configureDockWorkflow() {
     local username="$1"
     
     echo "Starting Dock configuration for ${username}..."
     
     # Clear existing Dock
     dockutil --remove all --no-restart "${username}"
     
     # Development apps
     local dev_apps=("iTerm" "Visual Studio Code" "Firefox" "Docker")
     for app in "${dev_apps[@]}"; do
       if [ -d "/Applications/${app}.app" ]; then
         dockutil --add "/Applications/${app}.app" --no-restart "${username}"
         echo "Added ${app}"
       fi
     done
     
     # Spacer
     dockutil --add '' --type spacer --section apps --no-restart "${username}"
     
     # Folders
     dockutil --add "/Applications" --view grid --display folder --no-restart "${username}"
     dockutil --add "/Users/${username}/Downloads" --view fan --display stack --no-restart "${username}"
     
     # Restart Dock
     killall Dock
     echo "Dock configuration complete"
   }
   ```

1. Use script in activation: `modules/darwin/system/dock.nix`

   ```nix
   { config, lib, pkgs, ... }:

   {
     system.activationScripts.configureDock = {
       text = ''
         source ${./lib/scripts/dock-workflow.sh}
         configureDockWorkflow "${config.users.primaryUser}"
       '';
     };
   }
   ```

1. Build and activate:

   ```bash
   darwin-rebuild switch --flake .
   ```

1. **Expected Results**:

   - ✅ Script sourced successfully
   - ✅ Function `configureDockWorkflow` executes
   - ✅ Dock configured with development apps and folders
   - ✅ Script output appears in activation log

1. **Validation Checklist**:

   - [ ] Script executable (`chmod +x lib/scripts/dock-workflow.sh`)
   - [ ] Proper shebang (`#!/usr/bin/env bash`)
   - [ ] Function callable after sourcing
   - [ ] Error handling for missing apps (e.g., Docker not installed)
   - [ ] Clear log output for debugging

**Troubleshooting**:

- Script not found: Verify path `${./lib/scripts/dock-workflow.sh}` is correct
- Function not found: Ensure script properly sourced before calling function
- Permission denied: Make script executable (`chmod +x`)

______________________________________________________________________

## Validation Workflows

### Workflow 1: Idempotency Validation

**Purpose**: Ensure all helper functions produce idempotent activation scripts.

**Steps**:

1. Run activation script first time:

   ```bash
   darwin-rebuild switch --flake . 2>&1 | tee activation-log-1.txt
   ```

1. Immediately run activation again:

   ```bash
   darwin-rebuild switch --flake . 2>&1 | tee activation-log-2.txt
   ```

1. Compare logs:

   ```bash
   diff activation-log-1.txt activation-log-2.txt
   ```

1. **Expected Results**:

   - ✅ First run shows changes (files created, services enabled, etc.)
   - ✅ Second run shows NO changes (all operations skipped)
   - ✅ No errors on second run
   - ✅ System state identical after both runs

1. **Validation Criteria**:

   - [ ] Second run faster than first (no actual work performed)
   - [ ] Log shows "already configured" or "no changes needed" messages
   - [ ] No duplicate Dock items, users, or service states
   - [ ] File timestamps unchanged on second run

______________________________________________________________________

### Workflow 2: Platform Abstraction Validation

**Purpose**: Verify shared libraries contain zero platform-specific logic.

**Steps**:

1. Review shared library code:

   ```bash
   cat modules/shared/lib/shell.nix
   ```

1. Search for platform checks:

   ```bash
   grep -r "isDarwin\|isLinux\|stdenv\.is" modules/shared/lib/
   ```

1. **Expected Results**:

   - ✅ Zero matches for platform checks in shared library
   - ✅ All functions work identically on darwin and linux
   - ✅ Platform-specific behavior only in platform libraries

1. **Validation Criteria**:

   - [ ] No `pkgs.stdenv.isDarwin` in shared/lib/
   - [ ] No `pkgs.stdenv.isLinux` in shared/lib/
   - [ ] No conditional imports based on platform
   - [ ] All shared functions documented as "cross-platform"

______________________________________________________________________

### Workflow 3: Dependency Flow Validation

**Purpose**: Ensure unidirectional dependency flow (module scripts → platform → linux → shared).

**Steps**:

1. Generate dependency graph:

   ```bash
   # Find all imports
   grep -r "import.*lib" modules/ > dependency-map.txt
   ```

1. Check import directions:

   ```bash
   # Shared should import nothing from other libs
   grep "shared/lib" modules/shared/lib/*.nix
   # Should return EMPTY

   # Platform libs should only import shared or linux
   grep "import.*lib" modules/darwin/lib/*.nix
   # Should only show: ../../shared/lib or ../../linux/lib

   # Linux libs should only import shared
   grep "import.*lib" modules/linux/lib/*.nix
   # Should only show: ../../shared/lib
   ```

1. **Expected Results**:

   - ✅ Shared libs import nothing
   - ✅ Linux libs import only shared libs
   - ✅ Platform libs import only shared and linux libs
   - ✅ No circular dependencies

1. **Validation Criteria**:

   - [ ] Zero imports from shared lib to platform libs
   - [ ] All platform libs import shared via `../../shared/lib`
   - [ ] Distro libs import linux via `../../linux/lib/systemd.nix`
   - [ ] No module-specific code imported by libraries

______________________________________________________________________

### Workflow 4: Documentation Validation

**Purpose**: Verify all public functions have complete documentation.

**Steps**:

1. Review function signatures:

   ```bash
   # Extract all function definitions
   grep -r "mk[A-Z].*=" modules/*/lib/*.nix
   ```

1. For each function, verify documentation exists:

   - Purpose statement
   - Parameter descriptions (name, type, required/optional, default)
   - Return value type
   - Usage example
   - Validation rules (if applicable)

1. **Expected Results**:

   - ✅ Every `mk*` function has documentation comment
   - ✅ Documentation follows consistent format
   - ✅ Examples are executable and accurate

1. **Documentation Template**:

   ```nix
   # Purpose: Brief one-line description
   # Parameters:
   #   - param1 (Type, required): Description
   #   - param2 (Type, optional, default "value"): Description
   # Returns: String (shell script text)
   # Example:
   #   mkFunctionName { param1 = "value"; param2 = "value"; }
   #   # Generates: shell command here
   # Validation:
   #   - param1 must be non-empty
   #   - Function is idempotent
   mkFunctionName = { param1, param2 ? "default" }: ''
     # shell script here
   '';
   ```

1. **Validation Criteria**:

   - [ ] All 6 shared functions documented
   - [ ] All 10+ systemd functions documented
   - [ ] All 15+ darwin functions documented
   - [ ] Documentation format consistent across all libraries

______________________________________________________________________

## Usage Examples

### Example 1: Simple Dock Configuration

**Use Case**: Configure Dock with common apps for development environment.

**Code**:

```nix
{ config, lib, pkgs, ... }:

let
  macLib = import ../lib/mac.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configureDock = {
    text = ''
      ${macLib.mkDockClear}
      ${macLib.mkDockAddApp { path = "/Applications/iTerm.app"; position = 1; }}
      ${macLib.mkDockAddApp { path = "/Applications/Visual Studio Code.app"; position = 2; }}
      ${macLib.mkDockAddApp { path = "/Applications/Firefox.app"; position = 3; }}
      ${macLib.mkDockAddSpacer}
      ${macLib.mkDockAddFolder { 
        path = "/Applications"; 
        view = "grid"; 
        display = "folder"; 
      }}
      ${macLib.mkDockRestart}
    '';
  };
}
```

**Testing**:

```bash
darwin-rebuild switch --flake .
dockutil --list  # Verify configuration
```

______________________________________________________________________

### Example 2: NVRAM Boot Arguments

**Use Case**: Set boot arguments for development (verbose mode, debugging).

**Code**:

```nix
{ config, lib, pkgs, ... }:

let
  macLib = import ../lib/mac.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configureBootArgs = {
    text = ''
      ${macLib.mkNvramSet { 
        variable = "boot-args"; 
        value = "-v debug=0x14e"; 
      }}
      ${macLib.mkNvramSet { 
        variable = "StartupMute"; 
        value = "%01"; 
      }}
    '';
  };
}
```

**Testing**:

```bash
darwin-rebuild switch --flake .
sudo nvram boot-args  # Should show: -v debug=0x14e
sudo nvram StartupMute  # Should show: %01
# Reboot and verify verbose mode and muted startup sound
```

______________________________________________________________________

### Example 3: Systemd Service Management

**Use Case**: Enable and start Docker service on NixOS.

**Code**:

```nix
{ config, lib, pkgs, ... }:

let
  nixosLib = import ../lib/nixos.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configureDocker = {
    text = ''
      ${nixosLib.mkEnsureGroup { groupname = "docker"; }}
      ${nixosLib.mkSystemdEnable "docker.service"}
      ${nixosLib.mkSystemdStart "docker.service"}
    '';
  };
}
```

**Testing**:

```bash
sudo nixos-rebuild switch --flake .
systemctl is-enabled docker.service  # Should show: enabled
systemctl is-active docker.service   # Should show: active
docker ps  # Verify docker works
```

______________________________________________________________________

### Example 4: Power Management Settings

**Use Case**: Configure battery and AC power settings for laptop.

**Code**:

```nix
{ config, lib, pkgs, ... }:

let
  macLib = import ../lib/mac.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configurePowerManagement = {
    text = ''
      # Battery settings (aggressive power saving)
      ${macLib.mkPmsetSet { 
        source = "battery"; 
        settings = {
          displaysleep = 2;
          disksleep = 5;
          sleep = 10;
          powernap = 0;
        };
      }}
      
      # AC power settings (performance)
      ${macLib.mkPmsetSet { 
        source = "ac"; 
        settings = {
          displaysleep = 10;
          disksleep = 0;
          sleep = 0;
          powernap = 1;
        };
      }}
    '';
  };
}
```

**Testing**:

```bash
darwin-rebuild switch --flake .
pmset -g  # Verify settings for each power source
```

______________________________________________________________________

### Example 5: Complex Module-Specific Script

**Use Case**: Extract complex Dock configuration to separate script for maintainability.

**Script**: `modules/darwin/system/lib/scripts/dock-professional.sh`

```bash
#!/usr/bin/env bash
# Purpose: Professional Dock configuration with project-specific apps
# Usage: source this script and call configureProfessionalDock <username> <project>

configureProfessionalDock() {
  local username="$1"
  local project="${2:-default}"
  
  # Clear existing
  dockutil --remove all --no-restart "${username}"
  
  # Core apps (always)
  local core_apps=("Safari" "Mail" "Calendar" "Notes")
  for app in "${core_apps[@]}"; do
    [ -d "/Applications/${app}.app" ] && \
      dockutil --add "/Applications/${app}.app" --no-restart "${username}"
  done
  
  dockutil --add '' --type spacer --section apps --no-restart "${username}"
  
  # Project-specific apps
  case "$project" in
    web)
      local web_apps=("Visual Studio Code" "Firefox" "Docker" "Postman")
      for app in "${web_apps[@]}"; do
        [ -d "/Applications/${app}.app" ] && \
          dockutil --add "/Applications/${app}.app" --no-restart "${username}"
      done
      ;;
    data)
      local data_apps=("PyCharm" "DataGrip" "Tableau")
      for app in "${data_apps[@]}"; do
        [ -d "/Applications/${app}.app" ] && \
          dockutil --add "/Applications/${app}.app" --no-restart "${username}"
      done
      ;;
  esac
  
  # Common folders
  dockutil --add "/Applications" --view grid --display folder --no-restart "${username}"
  dockutil --add "/Users/${username}/Downloads" --view fan --display stack --no-restart "${username}"
  
  killall Dock
}
```

**Module**: `modules/darwin/system/dock.nix`

```nix
{ config, lib, pkgs, ... }:

{
  system.activationScripts.configureDock = {
    text = ''
      source ${./lib/scripts/dock-professional.sh}
      configureProfessionalDock "${config.users.primaryUser}" "web"
    '';
  };
}
```

**Testing**:

```bash
darwin-rebuild switch --flake .
dockutil --list  # Verify web project apps present
```

______________________________________________________________________

## Troubleshooting Guide

### Issue: Function Not Found

**Symptoms**: Error like `attribute 'mkDockClear' missing`

**Causes**:

1. Import path incorrect
1. Function not exported from library
1. Typo in function name

**Solutions**:

```bash
# Verify import path
cat modules/darwin/system/dock.nix | grep "import"
# Should show: import ../lib/mac.nix

# Verify function exists in library
grep "mkDockClear" modules/darwin/lib/mac.nix

# Check for typos (case-sensitive)
# Correct: mkDockClear
# Wrong: mkDockclear, mkDockCLear
```

______________________________________________________________________

### Issue: Activation Script Fails

**Symptoms**: `darwin-rebuild` or `nixos-rebuild` fails during activation phase

**Causes**:

1. Generated shell code has syntax errors
1. Required tools not installed (dockutil, systemctl, etc.)
1. Permission issues (not running as root)
1. Path to apps/files doesn't exist

**Solutions**:

```bash
# Check generated activation script
darwin-rebuild build --flake .
# Look in result/activate for generated scripts

# Verify tools installed
which dockutil  # Darwin
which systemctl  # Linux

# Check permissions
id  # Should show root or admin group

# Verify paths exist
ls /Applications/Safari.app  # Darwin
ls /usr/lib/systemd  # Linux
```

______________________________________________________________________

### Issue: Idempotency Failure

**Symptoms**: Second activation shows changes or errors even though nothing should change

**Causes**:

1. Function doesn't check current state
1. Non-deterministic behavior (timestamps, random values)
1. Missing existence checks

**Solutions**:

```bash
# Review function implementation
cat modules/shared/lib/shell.nix | grep -A 20 "mkIdempotentFile"

# Should see pattern like:
# if [ ! -f "${path}" ] || ! grep -qF "${content}" "${path}"; then
#   # modify state
# fi

# Test explicitly
darwin-rebuild switch --flake .  # First run
darwin-rebuild switch --flake .  # Second run - should be no-op
```

**Fix Pattern**:

```nix
# BAD (not idempotent)
mkBadFunction = path: ''
  echo "timestamp: $(date)" > ${path}
'';

# GOOD (idempotent)
mkGoodFunction = { path, content }: ''
  if [ ! -f "${path}" ] || ! grep -qF "${content}" "${path}"; then
    echo "${content}" > ${path}
  fi
'';
```

______________________________________________________________________

### Issue: Platform-Specific Error in Shared Library

**Symptoms**: Shared library function fails on darwin but works on linux (or vice versa)

**Causes**:

1. Platform-specific command used (defaults vs systemctl)
1. Platform check in shared library (violates constitutional rule)
1. Path differences between platforms (/usr/bin vs /bin)

**Solutions**:

```bash
# Audit shared library for platform checks
grep -r "isDarwin\|isLinux" modules/shared/lib/
# Should return EMPTY

# Identify platform-specific command
# BAD: Using 'defaults' in shared lib (macOS-only)
# GOOD: Move to modules/darwin/lib/mac.nix

# Use POSIX-compatible commands in shared lib
# Instead of: defaults write (macOS-only)
# Use: echo/printf (cross-platform)
```

______________________________________________________________________

### Issue: Import Path Not Found

**Symptoms**: Error like `file '../../shared/lib' was not found`

**Causes**:

1. Relative path incorrect
1. File moved or renamed
1. Working directory assumption wrong

**Solutions**:

```bash
# Verify relative path from import location
cd modules/darwin/lib
ls ../../shared/lib/default.nix  # Should exist

# Count directory levels
# From: modules/darwin/lib/mac.nix
# To: modules/shared/lib/default.nix
# Up 2 levels: ../../
# Then: shared/lib/default.nix

# Fix import
# Correct: import ../../shared/lib { inherit pkgs lib; };
# Wrong: import ../shared/lib { inherit pkgs lib; };
```

______________________________________________________________________

### Issue: Function Returns Wrong Type

**Symptoms**: Type error like `expected string but got attribute set`

**Causes**:

1. Function returns attrset instead of string
1. Missing string interpolation
1. Forgot to use indented string (`'' ... ''`)

**Solutions**:

```nix
# BAD (returns attrset)
mkBadFunction = { path }: {
  text = "echo ${path}";
};

# GOOD (returns string)
mkGoodFunction = { path }: ''
  echo ${path}
'';

# Usage in activation script
system.activationScripts.test = {
  text = mkGoodFunction { path = "/tmp/test"; };  # String directly
};
```

______________________________________________________________________

## Performance Benchmarks

### Baseline Performance (Empty Activation)

```bash
# Measure baseline activation time
time darwin-rebuild switch --flake .

# Expected: 5-10 seconds (build + activation with no scripts)
```

### With Helper Library Functions

```bash
# Measure activation with 10 Dock operations
time darwin-rebuild switch --flake .

# Expected: 15-25 seconds (build + Dock configuration)
# Target: <30 seconds per constitutional requirement
```

### Idempotent Second Run

```bash
# Measure second activation (idempotent)
time darwin-rebuild switch --flake .

# Expected: 8-12 seconds (build + no-op activation)
# Should be faster than first run
```

______________________________________________________________________

## Next Steps

After completing quickstart testing:

1. **Implement remaining helper functions**: Review FR requirements in spec.md and implement any missing functions

1. **Refactor existing activation scripts**: Migrate at least 3 existing activation scripts to use new helper libraries

1. **Implement unresolved migrations**: Use helper functions to implement the 5 unresolved items from spec 002 (NVRAM, power, firewall, security, Borders)

1. **Update constitution**: Ensure constitutional standards reflect actual implementation patterns

1. **Documentation**: Create comprehensive library guides with all function signatures and examples

1. **Run `/speckit.tasks`**: Generate detailed implementation task list for Phase 2

______________________________________________________________________

## Additional Resources

- **Spec**: `specs/006-reusable-helper-library/spec.md` - Full feature specification
- **Data Model**: `specs/006-reusable-helper-library/data-model.md` - Function signatures and relationships
- **Constitution**: `.specify/memory/constitution.md` - Activation script standards
- **nix-darwin docs**: https://daiderd.com/nix-darwin/manual/
- **NixOS manual**: https://nixos.org/manual/nixos/stable/
- **dockutil**: https://github.com/kcrawford/dockutil
- **systemd**: https://www.freedesktop.org/wiki/Software/systemd/
