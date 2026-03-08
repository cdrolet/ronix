# Data Model: Platform-Agnostic Activation System

**Feature**: 015-platform-agnostic-activation\
**Date**: 2025-11-11

## Overview

This document defines the conceptual entities and relationships involved in the platform-agnostic activation system. While this is infrastructure code (not a traditional data model), understanding these entities helps clarify the system's architecture.

______________________________________________________________________

## Entities

### 1. Platform Configuration

**Description**: Represents a deployment target platform with its specific build output structure.

**Attributes**:

- `name` (string): Platform identifier (e.g., "darwin", "nixos", "kali")
- `flake_output_path` (string): Nix flake output path pattern for this platform
  - Example: `"darwinConfigurations.{user}-{profile}.system"`
  - Example: `"nixosConfigurations.{user}-{profile}.config.system.build.toplevel"`
- `activation_script_path` (string): Relative path to activation script within build result
  - Example: `"sw/bin/darwin-rebuild"`
  - Example: `"bin/switch-to-configuration"`
- `requires_sudo` (boolean): Whether activation requires elevated permissions
  - darwin: `false`
  - nixos: `true`

**Relationships**:

- Has many: User Profile Configurations
- Provides: Build Result structure

**Invariants**:

- Platform name must match directory name in `platform/{name}/`
- Flake output path must be valid nix flake output reference
- Activation script path must exist in all build results for this platform

______________________________________________________________________

### 2. User Profile Configuration

**Description**: A specific configuration instance for a user on a platform with a profile context.

**Attributes**:

- `user` (string): Username (e.g., "cdrokar", "cdrolet", "cdronix")
- `platform` (string): Platform name (references Platform Configuration)
- `profile` (string): Profile context (e.g., "home-macmini-m4", "work", "desktop")
- `flake_ref` (string): Complete flake reference for building
  - Computed: `"{platform}Configurations.{user}-{profile}"`

**Relationships**:

- Belongs to: Platform Configuration
- Belongs to: User
- Produces: Build Result

**Invariants**:

- User must exist in `user/{user}/default.nix`
- Platform must exist in `platform/{platform}/`
- Profile must exist in `platform/{platform}/profiles/{profile}/`
- Combination must produce valid nix build output

______________________________________________________________________

### 3. Build Result

**Description**: Output of `nix build` operation, containing compiled configuration and activation script.

**Attributes**:

- `symlink_path` (path): Location of result symlink (typically `./result`)
- `store_path` (path): Actual nix store path (e.g., `/nix/store/abc...`)
- `activation_script` (path): Full path to activation script within result
  - Computed: `{symlink_path}/{platform.activation_script_path}`
- `is_valid` (boolean): Whether result symlink exists and points to valid store path

**Relationships**:

- Produced by: User Profile Configuration build operation
- Contains: Activation Script
- References: Nix store derivation

**Operations**:

- `build()`: Execute nix build to create/update result
- `validate()`: Check if result exists and activation script is present
- `get_activation_script()`: Return path to activation script

**State Transitions**:

```
[Not Built] --build()--> [Valid Result] --nix-collect-garbage--> [Invalid Result]
                              |
                              +--activate()--> [Activated]
```

______________________________________________________________________

### 4. Activation Script

**Description**: Executable script within build result that applies configuration to running system.

**Attributes**:

- `path` (path): Full path to script (e.g., `result/sw/bin/darwin-rebuild`)
- `platform` (string): Platform this script is for
- `supported_commands` (list<string>): Subcommands supported (e.g., ["switch", "boot", "test"])

**Relationships**:

- Contained in: Build Result
- Targets: Running System

**Operations**:

- `execute(command)`: Run activation with specific command (switch, boot, etc.)
- `requires_sudo()`: Return whether sudo is needed for execution
- `validate_exists()`: Check if script path exists and is executable

**Behavior Contract**:

- Exit code 0 on success
- Non-zero exit code on failure
- Error messages written to stderr
- Progress messages written to stdout
- Idempotent (safe to run multiple times)

______________________________________________________________________

### 5. Justfile Recipe

**Description**: Command interface that orchestrates build and activation operations.

**Attributes**:

- `name` (string): Recipe name (e.g., "build", "install", "diff")
- `parameters` (list<string>): Required parameters (e.g., ["user", "platform", "profile"])
- `validates` (boolean): Whether recipe performs validation before execution

**Relationships**:

- Invokes: Helper Functions
- Produces: Build Result (for build recipes)
- Executes: Activation Script (for install recipes)

**Key Recipes**:

- `build`: Validates parameters → calls `_rebuild-command` with "build"
- `install`: Validates parameters → calls `_rebuild-command` with "switch"
- `_validate-all`: Validates user, platform, and profile exist
- `_flake-output-path`: Returns flake output path for platform
- `_rebuild-command`: Core logic for build and activation

______________________________________________________________________

### 6. Validation State

**Description**: Result of validating user/platform/profile combination before operation.

**Attributes**:

- `user_valid` (boolean): User exists in `user/` directory
- `platform_valid` (boolean): Platform exists in `platform/` directory
- `profile_valid` (boolean): Profile exists for the platform
- `error_message` (string | null): Descriptive error if validation fails

**Relationships**:

- Validates: User Profile Configuration

**Operations**:

- `validate_user(user)`: Check if user directory exists
- `validate_platform(platform)`: Check if platform directory exists
- `validate_profile(platform, profile)`: Check if profile exists for platform
- `validate_all(user, platform, profile)`: Run all validations

**State Flow**:

```
[Start] --> validate_user() --> validate_platform() --> validate_profile() --> [Valid]
              |                      |                        |
              v                      v                        v
           [Invalid]             [Invalid]                [Invalid]
```

______________________________________________________________________

## Relationships Diagram

```
Platform Configuration (1) ---(has many)---> User Profile Configuration (*)
        |                                              |
        | (defines structure)                          | (produces)
        v                                              v
Activation Script Path                          Build Result
                                                       |
                                                       | (contains)
                                                       v
                                                Activation Script
                                                       |
                                                       | (applies to)
                                                       v
                                                 Running System

Justfile Recipe
    |
    +--(validates)---> Validation State
    |
    +--(invokes)-----> _rebuild-command
                            |
                            +--(if build)---> nix build ---> Build Result
                            |
                            +--(if activate)---> Activation Script ---> Running System
```

______________________________________________________________________

## Workflow Models

### Build Workflow

```
User executes: just build <user> <platform> <profile>
    |
    v
Validation State: validate_all()
    |
    v
[PASS] --> _rebuild-command(platform, "build", user, profile)
                |
                v
           _flake-output-path(platform, user, profile)
                |
                v
           nix build ".#{output_path}"
                |
                v
           Build Result created at ./result
                |
                v
           Activation Script available in result/
```

### Activation Workflow

```
User executes: just install <user> <platform> <profile>
    |
    v
Validation State: validate_all()
    |
    v
[PASS] --> _rebuild-command(platform, "switch", user, profile)
                |
                v
           Check if ./result exists
                |
                +-[NO]---> Error: "Build result not found. Run 'just build' first."
                |
                +-[YES]--> Detect activation script path
                              |
                              v
                         Platform-specific execution:
                              |
                              +-[darwin]--> result/sw/bin/darwin-rebuild switch
                              |
                              +-[nixos]---> sudo result/bin/switch-to-configuration switch
                                               |
                                               v
                                          Running System Updated
```

______________________________________________________________________

## Error States

### Build Errors

| State | Cause | Recovery |
|-------|-------|----------|
| Invalid User | User directory doesn't exist | Create user in `user/{name}/` |
| Invalid Platform | Platform directory doesn't exist | Create platform in `platform/{name}/` |
| Invalid Profile | Profile doesn't exist for platform | Create profile in `platform/{platform}/profiles/{name}/` |
| Build Failure | Nix evaluation or build error | Fix configuration error, retry build |
| Missing Result | Build succeeded but result symlink missing | Re-run build, check disk space |

### Activation Errors

| State | Cause | Recovery |
|-------|-------|----------|
| No Build Result | Tried to activate without building first | Run `just build` first |
| Missing Activation Script | Script not at expected path in result | Verify platform configuration, rebuild |
| Permission Denied | Insufficient permissions for activation | Use sudo (nixos) or check admin group (darwin) |
| Activation Failure | Script returned non-zero exit code | Check error message, fix configuration, retry |
| Partial Activation | Some services started, others failed | Review activation logs, fix failed services |

______________________________________________________________________

## Extensibility

### Adding a New Platform

To add support for a new platform (e.g., "kali"), define:

1. **Platform Configuration**:

   - name: `"kali"`
   - flake_output_path: `"nixosConfigurations.{user}-{profile}.config.system.build.toplevel"`
   - activation_script_path: `"bin/switch-to-configuration"` (reuses nixos)
   - requires_sudo: `true`

1. **Implementation**:

   - Add case to `_flake-output-path` helper
   - Add case to `_rebuild-command` for activation script location
   - Document in quickstart.md

1. **No Other Changes Needed**:

   - `build` and `install` recipes work automatically
   - Validation automatically discovers new platform
   - All helper functions work without modification

This demonstrates the power of the platform-agnostic design.
