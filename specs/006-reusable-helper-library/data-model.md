# Data Model: Helper Library Function Signatures

**Feature**: 006-reusable-helper-library\
**Purpose**: Define all library function signatures, type contracts, relationships, and dependency flow for the activation script helper library system.

## Overview

This data model documents the interface design for the helper library system. In this context, the "data model" represents:

- **Function signatures**: Type contracts for each helper function
- **Relationships**: How functions compose and depend on each other
- **Import/export structure**: How libraries relate to each other
- **Dependency graph**: Unidirectional flow from shared → linux → platform → module scripts

All functions are Nix functions that generate shell script strings (string generators). They are evaluated at build time and produce shell code executed during system activation.

## Library Hierarchy and Dependency Flow

```
┌─────────────────────────────────────────┐
│  Module Scripts                         │
│  modules/<platform>/system/lib/scripts/ │
│  (Complex bash scripts >50 lines)       │
└─────────────────┬───────────────────────┘
                  │ can source
                  ▼
┌─────────────────────────────────────────┐
│  Platform Libraries                     │
│  - modules/darwin/lib/mac.nix           │
│  - modules/nixos/lib/nixos.nix          │
│  - modules/kali/lib/kali.nix            │
└─────────────────┬───────────────────────┘
                  │ imports
                  ▼
┌─────────────────────────────────────────┐
│  Linux System Type Libraries            │
│  - modules/linux/lib/systemd.nix        │
│  (Future: openrc.nix, runit.nix)        │
└─────────────────┬───────────────────────┘
                  │ imports
                  ▼
┌─────────────────────────────────────────┐
│  Shared Libraries (Pure Cross-Platform) │
│  - modules/shared/lib/shell.nix         │
│  - modules/shared/lib/default.nix       │
└─────────────────────────────────────────┘
```

**Validation Rule**: Dependencies MUST flow unidirectionally downward. Shared libraries MUST NOT import platform-specific or module code.

## Entity 1: Shared Library (modules/shared/lib/)

### Purpose

Provides pure cross-platform shell function generators with zero platform-specific logic.

### Structure

**modules/shared/lib/default.nix**

```nix
# Entry point that aggregates and re-exports all shared utilities
{ pkgs, lib, ... }:

{
  shell = import ./shell.nix { inherit pkgs lib; };
}
```

**modules/shared/lib/shell.nix**

```nix
# Shell function generators for common patterns
{ pkgs, lib, ... }:

{
  mkRunAsUser = /* function */;
  mkIdempotentFile = /* function */;
  mkIdempotentDir = /* function */;
  mkLoggedCommand = /* function */;
  mkConditional = /* function */;
  mkKillProcess = /* function */;
}
```

### Function Signatures

#### mkRunAsUser

**Type Signature**:

```nix
mkRunAsUser :: String -> String -> String
```

**Parameters**:

- `user` (String, required): Username to execute command as
- `cmd` (String, required): Shell command to execute

**Returns**: String (shell script text)

**Validation Rules**:

- `user` must be non-empty string
- `cmd` must be valid shell command syntax

**Example**:

```nix
mkRunAsUser "charles" "defaults write com.apple.dock autohide -bool true"
# Generates: sudo -u charles bash -c 'defaults write com.apple.dock autohide -bool true'
```

**Related Functions**: Used by all platform-specific user-level operations

______________________________________________________________________

#### mkIdempotentFile

**Type Signature**:

```nix
mkIdempotentFile :: { path :: String, content :: String, mode :: String? } -> String
```

**Parameters**:

- `path` (String, required): Absolute file path
- `content` (String, required): File content
- `mode` (String, optional, default "644"): File permission mode

**Returns**: String (shell script text)

**Validation Rules**:

- `path` must be absolute path (starts with `/`)
- `mode` must be valid octal permission string (e.g., "644", "755")
- Function must check if file exists and content matches before writing

**Example**:

```nix
mkIdempotentFile { 
  path = "/etc/myconfig.conf"; 
  content = "setting=value"; 
  mode = "600"; 
}
# Generates shell code that:
# 1. Checks if /etc/myconfig.conf exists
# 2. Checks if content matches "setting=value"
# 3. Only writes if missing or content differs
# 4. Sets mode to 600
```

**State Transitions**:

- File missing → File created with content and mode
- File exists with different content → Content updated, mode adjusted
- File exists with matching content → No operation (idempotent)

______________________________________________________________________

#### mkIdempotentDir

**Type Signature**:

```nix
mkIdempotentDir :: { path :: String, owner :: String?, group :: String?, mode :: String? } -> String
```

**Parameters**:

- `path` (String, required): Absolute directory path
- `owner` (String, optional): Directory owner username
- `group` (String, optional): Directory group name
- `mode` (String, optional, default "755"): Directory permission mode

**Returns**: String (shell script text)

**Validation Rules**:

- `path` must be absolute path (starts with `/`)
- `mode` must be valid octal permission string
- Function must check if directory exists before creating
- Ownership/permissions set only if specified

**Example**:

```nix
mkIdempotentDir { 
  path = "/var/lib/myservice"; 
  owner = "myuser"; 
  group = "mygroup"; 
  mode = "750"; 
}
```

**State Transitions**:

- Directory missing → Directory created with specified owner/group/mode
- Directory exists → Ownership/permissions adjusted if specified
- Directory exists with correct attributes → No operation (idempotent)

______________________________________________________________________

#### mkLoggedCommand

**Type Signature**:

```nix
mkLoggedCommand :: { name :: String, cmd :: String, level :: String? } -> String
```

**Parameters**:

- `name` (String, required): Human-readable operation name
- `cmd` (String, required): Shell command to execute
- `level` (String, optional, default "INFO"): Log level (INFO, WARN, ERROR)

**Returns**: String (shell script text)

**Validation Rules**:

- `name` must be non-empty string
- `cmd` must be valid shell command
- `level` must be one of: INFO, WARN, ERROR
- Logs should include timestamp, level, name, and status (success/failure)

**Example**:

```nix
mkLoggedCommand { 
  name = "Configure Dock"; 
  cmd = "defaults write com.apple.dock autohide -bool true"; 
  level = "INFO"; 
}
# Generates:
# echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: Configure Dock - starting"
# defaults write com.apple.dock autohide -bool true
# echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: Configure Dock - completed"
```

______________________________________________________________________

#### mkConditional

**Type Signature**:

```nix
mkConditional :: { condition :: String, thenCmd :: String, elseCmd :: String? } -> String
```

**Parameters**:

- `condition` (String, required): Shell test condition (e.g., `[ -f /path/to/file ]`)
- `thenCmd` (String, required): Command to run if condition true
- `elseCmd` (String, optional): Command to run if condition false

**Returns**: String (shell script text)

**Validation Rules**:

- `condition` must be valid shell test syntax
- `thenCmd` must be valid shell command
- `elseCmd` if provided must be valid shell command

**Example**:

```nix
mkConditional {
  condition = "[ -d /Applications/Firefox.app ]";
  thenCmd = "echo 'Firefox installed'";
  elseCmd = "echo 'Firefox not found'";
}
```

______________________________________________________________________

#### mkKillProcess

**Type Signature**:

```nix
mkKillProcess :: { name :: String, signal :: String? } -> String
```

**Parameters**:

- `name` (String, required): Process name to kill
- `signal` (String, optional, default "TERM"): Signal to send (TERM, KILL, HUP, etc.)

**Returns**: String (shell script text)

**Validation Rules**:

- `name` must be non-empty string
- `signal` must be valid Unix signal name
- Function must check if process exists before attempting kill
- Should be idempotent (no error if process not running)

**Example**:

```nix
mkKillProcess { name = "Dock"; signal = "KILL"; }
# Generates:
# if pgrep -x "Dock" > /dev/null; then
#   killall -KILL Dock
# fi
```

**State Transitions**:

- Process running → Process terminated with signal
- Process not running → No operation (idempotent, no error)

______________________________________________________________________

## Entity 2: Linux System Type Libraries (modules/linux/lib/)

### Purpose

Provides libraries for various Linux init systems. Currently implements systemd-based distributions. Container for future init systems (openrc, runit, sysvinit).

### Structure

**modules/linux/lib/systemd.nix**

```nix
{ pkgs, lib, ... }:

let
  sharedLib = import ../../shared/lib { inherit pkgs lib; };
in
{
  # Systemd service management
  mkSystemdEnable = /* function */;
  mkSystemdDisable = /* function */;
  mkSystemdStart = /* function */;
  mkSystemdStop = /* function */;
  mkSystemdRestart = /* function */;
  mkSystemdReload = /* function */;
  mkSystemdMask = /* function */;
  
  # Systemd user services
  mkSystemdUserEnable = /* function */;
  mkSystemdUserStart = /* function */;
  
  # User management
  mkEnsureUser = /* function */;
  mkEnsureGroup = /* function */;
  
  # Firewall (generic - works with firewalld, ufw)
  mkFirewallRule = /* function */;
}
```

**Validation Rule**: All systemd functions MUST work on any systemd-based Linux (NixOS, Kali, Ubuntu, Debian, Arch, Fedora, etc.)

### Function Signatures (Systemd Library)

#### mkSystemdEnable

**Type Signature**:

```nix
mkSystemdEnable :: String -> String
```

**Parameters**:

- `service` (String, required): Systemd service name (e.g., "sshd.service")

**Returns**: String (shell script text)

**Validation Rules**:

- `service` must be valid systemd unit name
- Function must check if service already enabled (idempotent)
- Should handle both system and user services

**Example**:

```nix
mkSystemdEnable "docker.service"
# Generates:
# if ! systemctl is-enabled docker.service >/dev/null 2>&1; then
#   systemctl enable docker.service
# fi
```

**Related Functions**: mkSystemdStart, mkSystemdDisable

______________________________________________________________________

#### mkSystemdStart

**Type Signature**:

```nix
mkSystemdStart :: String -> String
```

**Parameters**:

- `service` (String, required): Systemd service name

**Returns**: String (shell script text)

**Validation Rules**:

- `service` must be valid systemd unit name
- Function must check if service already running (idempotent)

**Example**:

```nix
mkSystemdStart "docker.service"
# Generates:
# if ! systemctl is-active docker.service >/dev/null 2>&1; then
#   systemctl start docker.service
# fi
```

______________________________________________________________________

#### mkSystemdRestart

**Type Signature**:

```nix
mkSystemdRestart :: String -> String
```

**Parameters**:

- `service` (String, required): Systemd service name

**Returns**: String (shell script text)

**Example**:

```nix
mkSystemdRestart "nginx.service"
# Generates: systemctl restart nginx.service
```

______________________________________________________________________

#### mkEnsureUser

**Type Signature**:

```nix
mkEnsureUser :: { username :: String, uid :: Int?, shell :: String?, home :: String? } -> String
```

**Parameters**:

- `username` (String, required): Username to create
- `uid` (Int, optional): User ID
- `shell` (String, optional, default "/bin/bash"): User shell
- `home` (String, optional): Home directory path

**Returns**: String (shell script text)

**Validation Rules**:

- `username` must be valid Unix username (alphanumeric, underscore, hyphen)
- Function must check if user exists (idempotent)
- Should use `useradd` on Linux

**Example**:

```nix
mkEnsureUser { 
  username = "serviceuser"; 
  uid = 1001; 
  shell = "/usr/sbin/nologin"; 
  home = "/var/lib/service"; 
}
```

**State Transitions**:

- User missing → User created with specified attributes
- User exists → No operation (idempotent)

______________________________________________________________________

## Entity 3: Darwin Platform Library (modules/darwin/lib/)

### Purpose

Provides macOS-specific activation helpers for Dock, NVRAM, power management, firewall, and LaunchAgents.

### Structure

**modules/darwin/lib/mac.nix**

```nix
{ pkgs, lib, ... }:

let
  sharedLib = import ../../shared/lib { inherit pkgs lib; };
in
{
  # Dock management
  mkDockClear = /* function */;
  mkDockAddApp = /* function */;
  mkDockAddFolder = /* function */;
  mkDockAddSpacer = /* function */;
  mkDockAddSmallSpacer = /* function */;
  mkDockRestart = /* function */;
  
  # NVRAM
  mkNvramSet = /* function */;
  mkNvramGet = /* function */;
  mkNvramDelete = /* function */;
  
  # Power management
  mkPmsetSet = /* function */;
  
  # Firewall
  mkFirewallEnable = /* function */;
  mkFirewallSetStealthMode = /* function */;
  mkFirewallAllowSigned = /* function */;
  
  # LaunchAgents/Daemons
  mkLoadLaunchAgent = /* function */;
  mkLoadLaunchDaemon = /* function */;
  mkUnloadLaunchAgent = /* function */;
}
```

### Function Signatures (Darwin Library)

#### mkDockClear

**Type Signature**:

```nix
mkDockClear :: String
```

**Parameters**: None (nullary function)

**Returns**: String (shell script text)

**Validation Rules**:

- Must generate dockutil command to remove all items
- Should be idempotent (safe to run on empty Dock)

**Example**:

```nix
mkDockClear
# Generates: dockutil --remove all --no-restart
```

**Related Functions**: mkDockAddApp, mkDockRestart

______________________________________________________________________

#### mkDockAddApp

**Type Signature**:

```nix
mkDockAddApp :: { path :: String, position :: Int? } -> String
```

**Parameters**:

- `path` (String, required): Full path to .app bundle (e.g., "/Applications/Safari.app")
- `position` (Int, optional): Position in Dock (1-based index)

**Returns**: String (shell script text)

**Validation Rules**:

- `path` must point to valid .app bundle
- Function must check if app already in Dock (idempotent)
- If app exists in Dock, no operation performed

**Example**:

```nix
mkDockAddApp { path = "/Applications/Safari.app"; position = 1; }
# Generates:
# if ! dockutil --find 'Safari' >/dev/null 2>&1; then
#   dockutil --add '/Applications/Safari.app' --position 1 --no-restart
# fi
```

**State Transitions**:

- App not in Dock → App added at specified position
- App already in Dock → No operation (idempotent)

______________________________________________________________________

#### mkDockAddFolder

**Type Signature**:

```nix
mkDockAddFolder :: { path :: String, view :: String?, display :: String?, sort :: String? } -> String
```

**Parameters**:

- `path` (String, required): Full path to folder
- `view` (String, optional, default "auto"): View style (fan, grid, list, auto)
- `display` (String, optional, default "folder"): Display as (folder, stack)
- `sort` (String, optional, default "name"): Sort by (name, dateadded, datemodified, datecreated, kind)

**Returns**: String (shell script text)

**Example**:

```nix
mkDockAddFolder { 
  path = "/Users/charles/Downloads"; 
  view = "fan"; 
  display = "stack"; 
  sort = "dateadded"; 
}
```

______________________________________________________________________

#### mkDockAddSpacer

**Type Signature**:

```nix
mkDockAddSpacer :: String
```

**Parameters**: None

**Returns**: String (shell script text)

**Example**:

```nix
mkDockAddSpacer
# Generates: dockutil --add '' --type spacer --section apps --no-restart
```

______________________________________________________________________

#### mkDockRestart

**Type Signature**:

```nix
mkDockRestart :: String
```

**Parameters**: None

**Returns**: String (shell script text)

**Example**:

```nix
mkDockRestart
# Generates: killall Dock
```

**Related Functions**: Called after all mkDockAdd\* operations complete

______________________________________________________________________

#### mkNvramSet

**Type Signature**:

```nix
mkNvramSet :: { variable :: String, value :: String } -> String
```

**Parameters**:

- `variable` (String, required): NVRAM variable name (e.g., "boot-args")
- `value` (String, required): Value to set

**Returns**: String (shell script text)

**Validation Rules**:

- Requires root privileges (uses sudo nvram)
- Function must check current value before setting (idempotent)
- Common variables: boot-args, SystemAudioVolume, StartupMute

**Example**:

```nix
mkNvramSet { variable = "StartupMute"; value = "%01"; }
# Generates:
# current=$(sudo nvram StartupMute 2>/dev/null | cut -f2 || echo "__unset__")
# if [ "$current" != "%01" ]; then
#   sudo nvram StartupMute=%01
# fi
```

**State Transitions**:

- Variable unset → Variable set to value
- Variable has different value → Variable updated to new value
- Variable has matching value → No operation (idempotent)

______________________________________________________________________

#### mkPmsetSet

**Type Signature**:

```nix
mkPmsetSet :: { source :: String?, settings :: AttrSet } -> String
```

**Parameters**:

- `source` (String, optional): Power source (battery, ac, ups). If omitted, applies to all sources
- `settings` (AttrSet, required): Key-value pairs of pmset settings

**Returns**: String (shell script text)

**Validation Rules**:

- Requires root privileges (uses sudo pmset)
- `source` must be one of: battery, ac, ups, or null
- Function should check current settings before applying (idempotent)
- Common settings: displaysleep, disksleep, sleep, womp, ring, autorestart, lidwake, powernap

**Example**:

```nix
mkPmsetSet { 
  source = "battery"; 
  settings = { 
    displaysleep = 5; 
    disksleep = 10; 
    sleep = 15; 
  }; 
}
# Generates:
# sudo pmset -b displaysleep 5 disksleep 10 sleep 15
```

______________________________________________________________________

#### mkFirewallEnable

**Type Signature**:

```nix
mkFirewallEnable :: String
```

**Parameters**: None

**Returns**: String (shell script text)

**Validation Rules**:

- Uses socketfilterfw on macOS
- Function must check if firewall already enabled (idempotent)

**Example**:

```nix
mkFirewallEnable
# Generates:
# if ! /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "enabled"; then
#   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
# fi
```

______________________________________________________________________

#### mkFirewallSetStealthMode

**Type Signature**:

```nix
mkFirewallSetStealthMode :: Bool -> String
```

**Parameters**:

- `enabled` (Bool, required): Whether to enable stealth mode

**Returns**: String (shell script text)

**Example**:

```nix
mkFirewallSetStealthMode true
# Generates: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
```

______________________________________________________________________

#### mkLoadLaunchAgent

**Type Signature**:

```nix
mkLoadLaunchAgent :: { user :: String, plist :: String } -> String
```

**Parameters**:

- `user` (String, required): Username to load agent for
- `plist` (String, required): Path to .plist file

**Returns**: String (shell script text)

**Validation Rules**:

- plist must exist at specified path
- Function should check if agent already loaded (idempotent)
- Uses launchctl bootstrap or launchctl load

**Example**:

```nix
mkLoadLaunchAgent { 
  user = "charles"; 
  plist = "/Users/charles/Library/LaunchAgents/com.example.agent.plist"; 
}
```

______________________________________________________________________

## Entity 4: NixOS Platform Library (modules/nixos/lib/)

### Purpose

Extends systemd library with NixOS-specific functionality. Inherits all systemd-based functions.

### Structure

**modules/nixos/lib/nixos.nix**

```nix
{ pkgs, lib, ... }:

let
  systemdLib = import ../../linux/lib/systemd.nix { inherit pkgs lib; };
in
systemdLib // {
  # NixOS-specific extensions
  mkChannelUpdate = /* function */;
  mkGenerationCleanup = /* function */;
  mkRebuildSwitch = /* function */;
}
```

**Validation Rule**: MUST NOT duplicate any functionality from systemd.nix. All systemd functions inherited via `//` operator.

### Function Signatures (NixOS Extensions)

#### mkChannelUpdate

**Type Signature**:

```nix
mkChannelUpdate :: { channel :: String? } -> String
```

**Parameters**:

- `channel` (String, optional): Channel name to update (default: all channels)

**Returns**: String (shell script text)

**Example**:

```nix
mkChannelUpdate { channel = "nixos"; }
# Generates: nix-channel --update nixos
```

______________________________________________________________________

#### mkGenerationCleanup

**Type Signature**:

```nix
mkGenerationCleanup :: { keepGenerations :: Int } -> String
```

**Parameters**:

- `keepGenerations` (Int, required): Number of generations to keep

**Returns**: String (shell script text)

**Example**:

```nix
mkGenerationCleanup { keepGenerations = 10; }
# Generates: nix-env --delete-generations +10
```

______________________________________________________________________

## Entity 5: Kali Platform Library (modules/kali/lib/)

### Purpose

Extends systemd library with Kali Linux-specific functionality. Inherits all systemd-based functions.

### Structure

**modules/kali/lib/kali.nix** (Future implementation)

```nix
{ pkgs, lib, ... }:

let
  systemdLib = import ../../linux/lib/systemd.nix { inherit pkgs lib; };
in
systemdLib // {
  # Kali-specific extensions
  mkKaliMetapackage = /* function */;
  mkAddKaliRepo = /* function */;
  mkAptUpdate = /* function */;
}
```

**Validation Rule**: MUST NOT duplicate any functionality from systemd.nix.

______________________________________________________________________

## Entity 6: Module Scripts (modules/<platform>/system/lib/scripts/)

### Purpose

Complex bash scripts (>50 lines) that are module-specific and too large for inline activation scripts.

### Structure

**Example: modules/darwin/system/lib/scripts/dock.sh**

```bash
#!/usr/bin/env bash
# Purpose: Complex Dock configuration workflow
# Usage: source this script and call configureDockWorkflow

configureDockWorkflow() {
  local username="$1"
  
  # Clear existing Dock
  dockutil --remove all --no-restart "$username"
  
  # Add development apps
  for app in "iTerm" "Visual Studio Code" "Firefox"; do
    if [ -d "/Applications/${app}.app" ]; then
      dockutil --add "/Applications/${app}.app" --no-restart "$username"
    fi
  done
  
  # Add spacer
  dockutil --add '' --type spacer --section apps --no-restart "$username"
  
  # Restart Dock
  killall Dock
}
```

**Validation Rules**:

- Scripts MUST include header comments (Purpose, Usage)
- Scripts CAN source shared and platform libraries
- Scripts MUST be executable and use proper shebang
- Dependency direction: scripts can use libraries, libraries never use scripts

______________________________________________________________________

## Import Relationships

### modules/shared/lib/default.nix

```nix
{ pkgs, lib, ... }:
{
  shell = import ./shell.nix { inherit pkgs lib; };
}
```

**Exports**: `{ shell = { mkRunAsUser, mkIdempotentFile, ... }; }`

______________________________________________________________________

### modules/linux/lib/systemd.nix

```nix
{ pkgs, lib, ... }:

let
  sharedLib = import ../../shared/lib { inherit pkgs lib; };
in
{
  # Uses sharedLib.shell.mkLoggedCommand, etc.
  mkSystemdEnable = service: 
    sharedLib.shell.mkLoggedCommand {
      name = "Enable ${service}";
      cmd = "systemctl enable ${service}";
    };
  # ... more functions
}
```

**Imports**: `modules/shared/lib`\
**Exports**: `{ mkSystemdEnable, mkSystemdStart, ... }`

______________________________________________________________________

### modules/darwin/lib/mac.nix

```nix
{ pkgs, lib, ... }:

let
  sharedLib = import ../../shared/lib { inherit pkgs lib; };
in
{
  # Uses sharedLib.shell functions
  mkDockClear = 
    sharedLib.shell.mkLoggedCommand {
      name = "Clear Dock";
      cmd = "${pkgs.dockutil}/bin/dockutil --remove all --no-restart";
    };
  # ... more functions
}
```

**Imports**: `modules/shared/lib`\
**Exports**: `{ mkDockClear, mkDockAddApp, mkNvramSet, ... }`

______________________________________________________________________

### modules/nixos/lib/nixos.nix

```nix
{ pkgs, lib, ... }:

let
  systemdLib = import ../../linux/lib/systemd.nix { inherit pkgs lib; };
in
systemdLib // {
  # Inherits ALL systemd functions
  # Adds NixOS-specific extensions
  mkChannelUpdate = { channel ? "nixos" }: ''
    nix-channel --update ${channel}
  '';
}
```

**Imports**: `modules/linux/lib/systemd.nix`\
**Exports**: All systemd functions + `{ mkChannelUpdate, mkGenerationCleanup, ... }`

______________________________________________________________________

### modules/kali/lib/kali.nix (Future)

```nix
{ pkgs, lib, ... }:

let
  systemdLib = import ../../linux/lib/systemd.nix { inherit pkgs lib; };
in
systemdLib // {
  # Inherits ALL systemd functions
  # Adds Kali-specific extensions
  mkKaliMetapackage = { package }: ''
    apt-get install -y ${package}
  '';
}
```

**Imports**: `modules/linux/lib/systemd.nix`\
**Exports**: All systemd functions + `{ mkKaliMetapackage, mkAddKaliRepo, ... }`

______________________________________________________________________

## Usage in Activation Scripts

### Example: Darwin Dock Module

**modules/darwin/system/dock.nix**

```nix
{ config, lib, pkgs, ... }:

let
  macLib = import ../lib/mac.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configureDock = {
    text = ''
      ${macLib.mkDockClear}
      ${macLib.mkDockAddApp { path = "/Applications/Safari.app"; position = 1; }}
      ${macLib.mkDockAddApp { path = "/Applications/iTerm.app"; position = 2; }}
      ${macLib.mkDockAddSpacer}
      ${macLib.mkDockAddFolder { 
        path = "/Users/${config.users.primaryUser}/Downloads"; 
        view = "fan"; 
      }}
      ${macLib.mkDockRestart}
    '';
  };
}
```

______________________________________________________________________

### Example: NixOS Service Module

**modules/nixos/system/docker.nix**

```nix
{ config, lib, pkgs, ... }:

let
  nixosLib = import ../lib/nixos.nix { inherit pkgs lib; };
in
{
  system.activationScripts.configureDocker = {
    text = ''
      ${nixosLib.mkSystemdEnable "docker.service"}
      ${nixosLib.mkSystemdStart "docker.service"}
      ${nixosLib.mkEnsureGroup { groupname = "docker"; }}
      ${nixosLib.mkEnsureUser { 
        username = "dockeruser"; 
        shell = "/usr/sbin/nologin"; 
      }}
    '';
  };
}
```

______________________________________________________________________

## Validation Rules Summary

1. **Dependency Flow (FR-037, FR-038, FR-039, FR-040)**:

   - ✅ VALID: module scripts → platform libs → linux libs → shared libs
   - ❌ INVALID: shared libs importing platform libs
   - ❌ INVALID: platform libs importing module scripts

1. **Platform Agnosticism (FR-004)**:

   - ✅ VALID: Shared library functions with no platform checks
   - ❌ INVALID: `if pkgs.stdenv.isDarwin` in shared/lib/shell.nix
   - ✅ VALID: Platform-specific behavior duplicated in darwin/lib/mac.nix and linux/lib/systemd.nix

1. **Idempotency (FR-041)**:

   - ✅ VALID: Functions check current state before modifying
   - ❌ INVALID: Functions that always modify state without checking
   - ✅ VALID: Safe to run activation scripts multiple times

1. **Documentation (FR-005)**:

   - ✅ VALID: Every public function has purpose, parameters, return value, examples
   - ❌ INVALID: Undocumented helper functions

1. **Import Structure (FR-037, FR-038)**:

   - ✅ VALID: Platform libs use `../../shared/lib`
   - ✅ VALID: Distro libs use `../../linux/lib/systemd.nix`
   - ❌ INVALID: Absolute paths in imports

1. **No Duplication (FR-022, FR-026)**:

   - ✅ VALID: nixos.nix and kali.nix inherit systemd functions via `systemdLib //`
   - ❌ INVALID: Copying mkSystemdEnable into nixos.nix

______________________________________________________________________

## State Transition Examples

### mkIdempotentFile State Diagram

```
┌─────────────────┐
│  File Missing   │
└────────┬────────┘
         │ mkIdempotentFile called
         ▼
┌─────────────────────────────┐
│ Check: File Exists?         │
│ NO → Create file            │
│ YES → Check content matches │
└────────┬────────────────────┘
         │
         ▼
┌───────────────────────────────┐
│ File Exists                   │
│ Content: "old content"        │
└────────┬──────────────────────┘
         │ mkIdempotentFile called with "new content"
         ▼
┌────────────────────────────────┐
│ Check: Content Matches?        │
│ NO → Update file               │
│ YES → No operation (idempotent)│
└────────┬───────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ File Exists                 │
│ Content: "new content"      │
│ Mode: 644                   │
└─────────────────────────────┘
```

______________________________________________________________________

### mkDockAddApp State Diagram

```
┌──────────────────────┐
│ App Not in Dock      │
└──────────┬───────────┘
           │ mkDockAddApp called
           ▼
┌────────────────────────────┐
│ Check: App in Dock?        │
│ NO → Add app with dockutil │
│ YES → No operation         │
└──────────┬─────────────────┘
           │
           ▼
┌──────────────────────────┐
│ App in Dock at Position  │
└──────────────────────────┘
           │ mkDockAddApp called again
           ▼
┌────────────────────────────────┐
│ Check: App in Dock?            │
│ YES → No operation (idempotent)│
└────────────────────────────────┘
```

______________________________________________________________________

## Performance Characteristics

- **Build-time evaluation**: All library functions evaluated during `darwin-rebuild`/`nixos-rebuild` build phase
- **Activation-time execution**: Generated shell scripts execute during system activation
- **Target performance**: Activation scripts complete in \<30 seconds (FR from constitution)
- **Memory footprint**: Minimal (simple shell scripts, no persistent processes)

______________________________________________________________________

## Extension Points

### Adding New Shared Functions

1. Add function to `modules/shared/lib/shell.nix`
1. Ensure function is pure (no platform checks)
1. Add type signature, parameters, validation rules, examples
1. Update constitution if introducing new pattern

### Adding New Platform Library

1. Create `modules/<platform>/lib/<platform>.nix`
1. Import shared library: `../../shared/lib`
1. If Linux-based, import systemd library: `../../linux/lib/systemd.nix`
1. Define platform-specific functions
1. Update spec and constitution

### Adding New Linux Init System

1. Create `modules/linux/lib/<init>.nix` (e.g., openrc.nix)
1. Import shared library
1. Implement init-system-specific functions
1. Distro libraries import appropriate init system library
1. Update spec FR-009, FR-010

______________________________________________________________________

## Summary

This data model defines:

- **43 functional requirements** mapped to function signatures
- **6 entity types** (Shared, Linux, Darwin, NixOS, Kali, Module Scripts)
- **25+ helper functions** with complete type signatures
- **Unidirectional dependency flow** enforcing clean architecture
- **Idempotency guarantees** through state-checking patterns
- **Platform abstraction** via physical separation and imports
- **Validation rules** ensuring constitutional compliance

All functions generate shell script strings evaluated at build time and executed during system activation. The hierarchical structure enables code reuse, eliminates duplication, and maintains clear separation of concerns across platforms.
